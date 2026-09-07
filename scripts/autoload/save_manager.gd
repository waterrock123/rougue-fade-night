
extends Node

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

var _cached_save_data: Dictionary = {}


func has_continue_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_cached_save_data.clear()


# 把 Run 当前持有的核心运行数据写入 JSON。
# 保存内容偏“状态快照”：玩家构筑、商店、地图、当前房间与本局随机数状态。
func save_run(run: Run) -> bool:
	if run == null or run.run_stats == null:
		return false

	var save_data := {
		"version": SAVE_VERSION,
		"flow_state": run.current_flow_state,
		"rng": RunRng.get_save_data(),
		"run_stats": _serialize_run_stats(run.run_stats),
		"map": run.map.get_save_data() if run.map != null and run.map.has_method("get_save_data") else {},
		"current_room": _serialize_room_key(run.current_room),
		"level_up_rewards": _serialize_level_up_rewards(run.level_up_reward_options),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入存档：%s" % SAVE_PATH)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	_cached_save_data = save_data
	return true


func load_save_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}

	_cached_save_data = parsed
	return parsed


func restore_rng(save_data: Dictionary) -> void:
	var rng_data := save_data.get("rng", {}) as Dictionary
	var seed := int(rng_data.get("seed", 0))
	var state := int(rng_data.get("state", 0))
	if seed == 0:
		RunRng.start_new_run()
		return

	RunRng.restore_from_save(seed, state)


func build_run_stats_from_save(save_data: Dictionary) -> RunStats:
	var run_stats_data := save_data.get("run_stats", {}) as Dictionary
	if run_stats_data.is_empty():
		return null

	var result := RunStats.new()
	result.player_build = _deserialize_player_build(run_stats_data.get("player_build", {}) as Dictionary)
	result.shop = _deserialize_shop(run_stats_data.get("shop", {}) as Dictionary)
	result.picked_character = _load_resource_or_null(str(run_stats_data.get("character_path", ""))) as Character
	result.shop_config = _load_resource_or_null(str(run_stats_data.get("shop_config_path", ""))) as ShopConfig
	if result.shop_config == null and result.picked_character != null and result.picked_character.start_shop_config != null:
		result.shop_config = result.picked_character.start_shop_config.duplicate(true) as ShopConfig
	result.base_rest_period_gold = int(run_stats_data.get("base_rest_period_gold", result.base_rest_period_gold))
	result.rest_period_gold_growth = int(run_stats_data.get("rest_period_gold_growth", result.rest_period_gold_growth))
	result.rest_period_gold_flat_bonus = int(run_stats_data.get("rest_period_gold_flat_bonus", result.rest_period_gold_flat_bonus))
	result.rest_period_count = int(run_stats_data.get("rest_period_count", result.rest_period_count))
	result.pending_free_relic_choice_levels = _to_int_array(run_stats_data.get("pending_free_relic_choice_levels", []))
	result.level_up_reward_refresh_count = int(run_stats_data.get("level_up_reward_refresh_count", 0))
	result.level_up_reward_phase = int(run_stats_data.get("level_up_reward_phase", 0))
	result.shop_free_refresh_count = int(run_stats_data.get("shop_free_refresh_count", 0))
	result.shop_refresh_count_this_rest_period = int(run_stats_data.get("shop_refresh_count_this_rest_period", 0))
	result.pending_bounty_enemy_entries = _deserialize_bounty_enemy_entries(run_stats_data.get("pending_bounty_enemy_entries", []))
	result.persistent_status_stacks = _to_int_dictionary(run_stats_data.get("persistent_status_stacks", {}))
	result.persistent_passive_counters = _to_int_dictionary(run_stats_data.get("persistent_passive_counters", {}))
	result.current_battle_map_template_path = str(run_stats_data.get("current_battle_map_template_path", ""))
	result.selected_tag_effects = _deserialize_tag_effects(run_stats_data.get("selected_tag_effects", []))
	result.completed_once_tag_effect_ids = _to_string_name_array(run_stats_data.get("completed_once_tag_effect_ids", []))
	result.map_tag_enable_limit = int(run_stats_data.get("map_tag_enable_limit", result.map_tag_enable_limit))
	result.enabled_map_tag_keys = _to_string_array(run_stats_data.get("enabled_map_tag_keys", []))
	result.trim_enabled_map_tags_to_limit()
	result.set_gold(int(run_stats_data.get("gold", result.gold)))
	return result


func get_saved_map_data(save_data: Dictionary) -> Dictionary:
	return save_data.get("map", {}) as Dictionary


func get_saved_current_room_data(save_data: Dictionary) -> Dictionary:
	return save_data.get("current_room", {}) as Dictionary


func get_saved_flow_state(save_data: Dictionary) -> String:
	return str(save_data.get("flow_state", Run.FLOW_MAP))


func get_saved_level_up_rewards(save_data: Dictionary) -> Array[LevelUpReward]:
	return _deserialize_level_up_rewards(save_data.get("level_up_rewards", []))


func _serialize_run_stats(run_stats: RunStats) -> Dictionary:
	return {
		"gold": run_stats.gold,
		"player_build": _serialize_player_build(run_stats.player_build),
		"shop": _serialize_shop(run_stats.shop),
		"shop_config_path": _get_resource_path(run_stats.shop_config),
		"character_path": _get_resource_path(run_stats.picked_character),
		"base_rest_period_gold": run_stats.base_rest_period_gold,
		"rest_period_gold_growth": run_stats.rest_period_gold_growth,
		"rest_period_gold_flat_bonus": run_stats.rest_period_gold_flat_bonus,
		"rest_period_count": run_stats.rest_period_count,
		"pending_free_relic_choice_levels": run_stats.pending_free_relic_choice_levels,
		"level_up_reward_refresh_count": run_stats.level_up_reward_refresh_count,
		"level_up_reward_phase": run_stats.level_up_reward_phase,
		"shop_free_refresh_count": run_stats.shop_free_refresh_count,
		"shop_refresh_count_this_rest_period": run_stats.shop_refresh_count_this_rest_period,
		"pending_bounty_enemy_entries": _serialize_bounty_enemy_entries(run_stats.pending_bounty_enemy_entries),
		"persistent_status_stacks": run_stats.persistent_status_stacks,
		"persistent_passive_counters": run_stats.persistent_passive_counters,
		"current_battle_map_template_path": run_stats.current_battle_map_template_path,
		"selected_tag_effects": _serialize_tag_effects(run_stats.selected_tag_effects),
		"completed_once_tag_effect_ids": _string_name_array_to_strings(run_stats.completed_once_tag_effect_ids),
		"map_tag_enable_limit": run_stats.map_tag_enable_limit,
		"enabled_map_tag_keys": run_stats.enabled_map_tag_keys,
	}


func _serialize_bounty_enemy_entries(entries: Array[BountyEnemyEntry]) -> Array:
	var result := []
	for entry: BountyEnemyEntry in entries:
		if entry == null:
			continue

		result.append({
			"enemy_scene_path": _get_resource_path(entry.enemy_scene),
			"bounty_gold": entry.bounty_gold,
			"starts_neutral": entry.starts_neutral,
			"neutral_speed_multiplier": entry.neutral_speed_multiplier,
			"neutral_wander_radius": entry.neutral_wander_radius,
			"neutral_wander_repick_interval": entry.neutral_wander_repick_interval,
		})
	return result


func _deserialize_bounty_enemy_entries(data) -> Array[BountyEnemyEntry]:
	var result: Array[BountyEnemyEntry] = []
	if not (data is Array):
		return result

	for value in data:
		if not (value is Dictionary):
			continue

		var entry_data: Dictionary = value as Dictionary
		var enemy_scene: PackedScene = _load_resource_or_null(str(entry_data.get("enemy_scene_path", ""))) as PackedScene
		if enemy_scene == null:
			continue

		var entry := BountyEnemyEntry.new()
		entry.enemy_scene = enemy_scene
		entry.bounty_gold = int(entry_data.get("bounty_gold", entry.bounty_gold))
		entry.starts_neutral = bool(entry_data.get("starts_neutral", entry.starts_neutral))
		entry.neutral_speed_multiplier = float(entry_data.get("neutral_speed_multiplier", entry.neutral_speed_multiplier))
		entry.neutral_wander_radius = float(entry_data.get("neutral_wander_radius", entry.neutral_wander_radius))
		entry.neutral_wander_repick_interval = float(entry_data.get("neutral_wander_repick_interval", entry.neutral_wander_repick_interval))
		result.append(entry)

	return result


func _serialize_player_build(player_build: PlayerBuild) -> Dictionary:
	if player_build == null:
		return {}

	return {
		"player_stats": _serialize_stats_data(player_build.player_stats),
		"inventory_slots": _serialize_slots(player_build.player_inventory.slots if player_build.player_inventory != null else []),
		"equipment_slots": _serialize_slots(player_build.player_equipment.equip_slots if player_build.player_equipment != null else []),
		"current_health": player_build.current_health,
		"current_energy": player_build.current_energy,
		"active_skill_slot_limit": player_build.active_skill_slot_limit,
		"active_skill_owned_limit": player_build.active_skill_owned_limit,
		"active_skill_equipped_limit": player_build.active_skill_equipped_limit,
		"passive_skill_slot_limit": player_build.passive_skill_slot_limit,
		"owned_active_skills": _serialize_skill_entries(player_build.owned_active_skills),
		"owned_passive_skills": _serialize_skill_entries(player_build.owned_passive_skills),
	}


func _deserialize_player_build(data: Dictionary) -> PlayerBuild:
	var build := PlayerBuild.new()
	build.player_stats = _deserialize_stats_data(data.get("player_stats", {}) as Dictionary)
	build.player_inventory = Inventory.new()
	build.player_inventory.slots = _deserialize_slots(data.get("inventory_slots", []))
	build.player_equipment = Equipment.new()
	build.player_equipment.equip_slots = _deserialize_slots(data.get("equipment_slots", []))
	build.current_health = float(data.get("current_health", 0.0))
	build.current_energy = float(data.get("current_energy", 0.0))
	build.active_skill_slot_limit = int(data.get("active_skill_slot_limit", build.active_skill_slot_limit))
	build.active_skill_owned_limit = int(data.get("active_skill_owned_limit", build.active_skill_owned_limit))
	build.active_skill_equipped_limit = int(data.get("active_skill_equipped_limit", build.active_skill_equipped_limit))
	build.passive_skill_slot_limit = int(data.get("passive_skill_slot_limit", build.passive_skill_slot_limit))
	build.normalize_active_skill_loadout()
	build.owned_active_skills = _deserialize_skill_entries(data.get("owned_active_skills", []), true)
	build.owned_passive_skills = _deserialize_skill_entries(data.get("owned_passive_skills", []), false)
	return build


func _serialize_stats_data(stats: StatsData) -> Dictionary:
	if stats == null:
		return {}

	return {
		"entity_name": stats.entity_name,
		"base_max_health": stats.base_max_health,
		"base_max_energy": stats.base_max_energy,
		"base_energy_regen_tick_value": stats.base_energy_regen_tick_value,
		"base_damage_reduction_rate": stats.base_damage_reduction_rate,
		"base_static_damage_reduction": stats.base_static_damage_reduction,
		"base_dodge_rate": stats.base_dodge_rate,
		"base_crit_chance": stats.base_crit_chance,
		"base_crit_damage": stats.base_crit_damage,
		"base_cooldown_reduction": stats.base_cooldown_reduction,
		"base_move_speed": stats.base_move_speed,
		"base_poise_damage_multiplier": stats.base_poise_damage_multiplier,
		"strength": stats.strength,
		"dexterity": stats.dexterity,
		"intelligence": stats.intelligence,
		"constitution": stats.constitution,
		"speed": stats.speed,
		"charm": stats.charm,
		"luck": stats.luck,
	}


func _deserialize_stats_data(data: Dictionary) -> StatsData:
	var stats := StatsData.new()
	stats.entity_name = str(data.get("entity_name", ""))
	stats.base_max_health = float(data.get("base_max_health", 0.0))
	stats.base_max_energy = float(data.get("base_max_energy", 0.0))
	stats.base_energy_regen_tick_value = float(data.get("base_energy_regen_tick_value", 0.0))
	stats.base_damage_reduction_rate = float(data.get("base_damage_reduction_rate", 0.0))
	stats.base_static_damage_reduction = int(data.get("base_static_damage_reduction", 0))
	stats.base_dodge_rate = float(data.get("base_dodge_rate", 0.0))
	stats.base_crit_chance = float(data.get("base_crit_chance", 0.05))
	stats.base_crit_damage = float(data.get("base_crit_damage", 1.5))
	stats.base_cooldown_reduction = float(data.get("base_cooldown_reduction", 0.0))
	stats.base_move_speed = float(data.get("base_move_speed", 0.0))
	stats.base_poise_damage_multiplier = float(data.get("base_poise_damage_multiplier", 1.0))
	stats.strength = int(data.get("strength", 0))
	stats.dexterity = int(data.get("dexterity", 0))
	stats.intelligence = int(data.get("intelligence", 0))
	stats.constitution = int(data.get("constitution", 0))
	stats.speed = int(data.get("speed", 0))
	stats.charm = int(data.get("charm", 0))
	stats.luck = int(data.get("luck", 0))
	return stats


func _serialize_shop(shop: Shop) -> Dictionary:
	if shop == null:
		return {}

	return {
		"level": shop.level,
		"slot_count": shop.slot_count,
		"current_slot": _serialize_slots(shop.current_slot),
		"frozen_slots": shop.frozen_slots,
		"shopkeeper_path": _get_resource_path(shop.shopkeeper),
	}


func _deserialize_shop(data: Dictionary) -> Shop:
	var shop := Shop.new()
	shop.level = int(data.get("level", shop.level))
	shop.slot_count = int(data.get("slot_count", shop.slot_count))
	shop.current_slot = _deserialize_slots(data.get("current_slot", []))
	shop.frozen_slots = _to_bool_array(data.get("frozen_slots", []))
	shop.shopkeeper = _load_resource_or_null(str(data.get("shopkeeper_path", ""))) as ShopKeeper
	shop.ensure_slot_count()
	return shop


func _serialize_slots(slots: Array) -> Array:
	var result := []
	for slot in slots:
		result.append(_serialize_slot(slot))
	return result


func _deserialize_slots(data) -> Array[Slot]:
	var result: Array[Slot] = []
	if not (data is Array):
		return result

	for slot_data in data:
		result.append(_deserialize_slot(slot_data as Dictionary))
	return result


func _serialize_slot(slot: Slot) -> Dictionary:
	if slot == null:
		return {"limit_tag": [], "is_locked": false, "item": {}}

	return {
		"limit_tag": slot.limit_tag,
		"is_locked": slot.is_locked,
		"item": _serialize_relic(slot.item),
	}


func _deserialize_slot(data: Dictionary) -> Slot:
	var slot := Slot.new()
	slot.limit_tag = _to_string_array(data.get("limit_tag", []))
	slot.is_locked = bool(data.get("is_locked", false))
	slot.item = _deserialize_relic(data.get("item", {}) as Dictionary)
	return slot


func _serialize_relic(relic: Relic) -> Dictionary:
	if relic == null:
		return {}

	return {
		"path": _get_resource_path(relic),
		"id": relic.id,
		"relic_name": relic.relic_name,
		"leveltip": int(relic.leveltip),
		"level": relic.level,
		"price": relic.price,
		"sell_price": relic.sell_price,
		"accumulated_stat_bonuses": relic.accumulated_stat_bonuses,
		"is_temporary": relic.is_temporary,
		"temporary_source_key": String(relic.temporary_source_key),
	}


func _deserialize_relic(data: Dictionary) -> Relic:
	if data.is_empty():
		return null

	var relic := _load_resource_or_null(str(data.get("path", ""))) as Relic
	if relic == null:
		relic = _find_relic_by_id(str(data.get("id", "")))
	if relic == null:
		return null

	relic = relic.duplicate(true) as Relic
	relic.relic_name = str(data.get("relic_name", relic.relic_name))
	relic.leveltip = int(data.get("leveltip", int(relic.leveltip)))
	relic.level = int(data.get("level", relic.level))
	relic.price = int(data.get("price", relic.price))
	relic.sell_price = int(data.get("sell_price", relic.sell_price))
	relic.accumulated_stat_bonuses = (data.get("accumulated_stat_bonuses", relic.accumulated_stat_bonuses) as Dictionary).duplicate(true)
	relic.is_temporary = bool(data.get("is_temporary", false))
	relic.temporary_source_key = StringName(str(data.get("temporary_source_key", "")))
	return relic


func _serialize_skill_entries(entries: Array[SkillEntry]) -> Array:
	var result := []
	for entry in entries:
		if entry == null:
			continue
		# 装备/状态提供的临时技能会由对应效果在读档后重新生成，不写进永久存档。
		if entry.is_temporary:
			continue

		result.append({
			"level": entry.level,
			"is_equipped": entry.is_equipped,
			"slot_index": entry.slot_index,
			"skill_data": _serialize_skill_data(entry.skill_data),
		})
	return result


func _serialize_level_up_rewards(rewards: Array[LevelUpReward]) -> Array:
	var result := []
	for reward in rewards:
		if reward == null:
			continue

		var data := {
			"type": _get_reward_type(reward),
			"id": String(reward.id),
			"title": reward.title,
			"desc": reward.desc,
			"icon_path": _get_resource_path(reward.icon),
			"rarity": reward.rarity,
		}

		if reward is RewardGrantActiveSkill:
			data["skill_data"] = _serialize_skill_data((reward as RewardGrantActiveSkill).skill_data)
		elif reward is RewardGrantPassiveSkill:
			var passive_reward := reward as RewardGrantPassiveSkill
			data["skill_data"] = _serialize_skill_data(passive_reward.skill_data)
			data["replace_skill_id"] = String(passive_reward.replace_skill_id)
		elif reward is RewardIncreaseStat:
			var stat_reward := reward as RewardIncreaseStat
			data["stat_name"] = String(stat_reward.stat_name)
			data["amount"] = stat_reward.amount
		elif reward is RewardUpgradeSkill:
			var upgrade_reward := reward as RewardUpgradeSkill
			data["target_skill_id"] = String(upgrade_reward.target_skill_id)
			data["target_skill_data"] = _serialize_skill_data(upgrade_reward.target_skill_data)
			data["source_skill_id"] = String(upgrade_reward.source_skill_id)
			data["source_skill_data"] = _serialize_skill_data(upgrade_reward.source_skill_data)
			data["search_passive_first"] = upgrade_reward.search_passive_first

		result.append(data)
	return result


func _deserialize_level_up_rewards(data) -> Array[LevelUpReward]:
	var result: Array[LevelUpReward] = []
	if not (data is Array):
		return result

	for reward_data in data:
		var reward := _deserialize_level_up_reward(reward_data as Dictionary)
		if reward != null:
			result.append(reward)
	return result


func _deserialize_level_up_reward(data: Dictionary) -> LevelUpReward:
	if data.is_empty():
		return null

	var reward_type := str(data.get("type", ""))
	var reward: LevelUpReward = null
	match reward_type:
		"grant_active_skill":
			var active_reward := RewardGrantActiveSkill.new()
			active_reward.skill_data = _deserialize_skill_data(data.get("skill_data", {}) as Dictionary, true) as ActiveSkillData
			reward = active_reward
		"grant_passive_skill":
			var passive_reward := RewardGrantPassiveSkill.new()
			passive_reward.skill_data = _deserialize_skill_data(data.get("skill_data", {}) as Dictionary, false) as PassiveSkillData
			passive_reward.replace_skill_id = StringName(str(data.get("replace_skill_id", "")))
			reward = passive_reward
		"increase_stat":
			var stat_reward := RewardIncreaseStat.new()
			stat_reward.stat_name = StringName(str(data.get("stat_name", "")))
			stat_reward.amount = float(data.get("amount", 1.0))
			reward = stat_reward
		"upgrade_skill":
			var upgrade_reward := RewardUpgradeSkill.new()
			upgrade_reward.target_skill_id = StringName(str(data.get("target_skill_id", "")))
			upgrade_reward.target_skill_data = _deserialize_skill_data(data.get("target_skill_data", {}) as Dictionary, bool(data.get("search_passive_first", false)))
			upgrade_reward.source_skill_id = StringName(str(data.get("source_skill_id", "")))
			upgrade_reward.source_skill_data = _deserialize_skill_data(data.get("source_skill_data", {}) as Dictionary, bool(data.get("search_passive_first", false)))
			upgrade_reward.search_passive_first = bool(data.get("search_passive_first", false))
			reward = upgrade_reward
		_:
			reward = LevelUpReward.new()

	reward.id = StringName(str(data.get("id", "")))
	reward.title = str(data.get("title", ""))
	reward.desc = str(data.get("desc", ""))
	reward.icon = _load_resource_or_null(str(data.get("icon_path", ""))) as Texture2D
	reward.rarity = int(data.get("rarity", 0))
	return reward


func _get_reward_type(reward: LevelUpReward) -> String:
	if reward is RewardGrantActiveSkill:
		return "grant_active_skill"
	if reward is RewardGrantPassiveSkill:
		return "grant_passive_skill"
	if reward is RewardIncreaseStat:
		return "increase_stat"
	if reward is RewardUpgradeSkill:
		return "upgrade_skill"
	return "base"


func _deserialize_skill_entries(data, active: bool) -> Array[SkillEntry]:
	var result: Array[SkillEntry] = []
	if not (data is Array):
		return result

	for entry_data in data:
		var entry_dict := entry_data as Dictionary
		var entry := SkillEntry.new()
		entry.skill_data = _deserialize_skill_data(entry_dict.get("skill_data", {}) as Dictionary, active)
		entry.level = int(entry_dict.get("level", 1))
		entry.is_equipped = bool(entry_dict.get("is_equipped", true))
		entry.slot_index = int(entry_dict.get("slot_index", -1))
		if entry.skill_data != null:
			result.append(entry)
	return result


func _serialize_skill_data(skill_data: SkillData) -> Dictionary:
	if skill_data == null:
		return {}

	var result := {
		"path": _get_resource_path(skill_data),
		"id": String(skill_data.id),
		"skill_name": skill_data.skill_name,
		"desc": skill_data.desc,
		"icon_path": _get_resource_path(skill_data.icon),
		"rarity": skill_data.rarity,
		"max_level": skill_data.max_level,
		"is_upgrade_skill": skill_data.is_upgrade_skill,
		"tags": _string_name_array_to_strings(skill_data.tags),
		"allowed_character_ids": _string_name_array_to_strings(skill_data.allowed_character_ids),
		"is_active": skill_data is ActiveSkillData,
	}

	if skill_data is ActiveSkillData:
		var active_data := skill_data as ActiveSkillData
		result["ability_scene_path"] = _get_resource_path(active_data.ability_scene)
		result["base_cooldown"] = active_data.base_cooldown
		result["base_energy_cost"] = active_data.base_energy_cost
		result["slot_type"] = String(active_data.slot_type)
		result["is_basic_attack"] = active_data.is_basic_attack

	return result


func _deserialize_skill_data(data: Dictionary, active: bool) -> SkillData:
	if data.is_empty():
		return null

	var skill_data := _load_resource_or_null(str(data.get("path", ""))) as SkillData
	if skill_data == null:
		skill_data = _find_skill_by_id(str(data.get("id", "")), active)
	if skill_data != null:
		return skill_data.duplicate(true) as SkillData

	if active:
		var active_data := ActiveSkillData.new()
		_fill_basic_skill_data(active_data, data)
		active_data.ability_scene = _load_resource_or_null(str(data.get("ability_scene_path", ""))) as PackedScene
		active_data.base_cooldown = float(data.get("base_cooldown", 0.0))
		active_data.base_energy_cost = float(data.get("base_energy_cost", 0.0))
		active_data.slot_type = StringName(str(data.get("slot_type", "")))
		active_data.is_basic_attack = bool(data.get("is_basic_attack", false))
		return active_data

	var passive_data := PassiveSkillData.new()
	_fill_basic_skill_data(passive_data, data)
	return passive_data


func _serialize_tag_effects(tag_effects: Array[TagEffect]) -> Array:
	var result := []
	for tag_effect in tag_effects:
		if tag_effect == null:
			continue
		result.append({
			"path": _get_resource_path(tag_effect),
			"id": String(tag_effect.id),
		})
	return result


func _deserialize_tag_effects(data) -> Array[TagEffect]:
	var result: Array[TagEffect] = []
	if not (data is Array):
		return result

	for value in data:
		var effect_data := value as Dictionary
		var effect := _load_resource_or_null(str(effect_data.get("path", ""))) as TagEffect
		if effect == null:
			effect = _find_tag_effect_by_id(str(effect_data.get("id", "")))
		if effect != null:
			result.append(effect.duplicate(true) as TagEffect)
	return result


func _fill_basic_skill_data(skill_data: SkillData, data: Dictionary) -> void:
	skill_data.id = StringName(str(data.get("id", "")))
	skill_data.skill_name = str(data.get("skill_name", ""))
	skill_data.desc = str(data.get("desc", ""))
	skill_data.icon = _load_resource_or_null(str(data.get("icon_path", ""))) as Texture2D
	skill_data.rarity = int(data.get("rarity", 0))
	skill_data.max_level = int(data.get("max_level", 1))
	skill_data.is_upgrade_skill = bool(data.get("is_upgrade_skill", false))
	skill_data.tags = _to_string_name_array(data.get("tags", []))
	skill_data.allowed_character_ids = _to_string_name_array(data.get("allowed_character_ids", []))


func _serialize_room_key(room: Room) -> Dictionary:
	if room == null:
		return {}

	return {
		"row": room.row,
		"column": room.column,
	}


func _get_resource_path(resource: Resource) -> String:
	if resource == null:
		return ""
	return resource.resource_path


func _load_resource_or_null(path: String) -> Resource:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)


func _find_relic_by_id(relic_id: String) -> Relic:
	if relic_id.is_empty():
		return null
	return _find_resource_by_id_in_dirs(relic_id, ["res://relics"]) as Relic


func _find_skill_by_id(skill_id: String, active: bool) -> SkillData:
	if skill_id.is_empty():
		return null

	var dirs := ["res://activate_skill"] if active else ["res://passive_skill"]
	return _find_resource_by_id_in_dirs(skill_id, dirs) as SkillData


func _find_tag_effect_by_id(effect_id: String) -> TagEffect:
	if effect_id.is_empty():
		return null
	return _find_resource_by_id_in_dirs(effect_id, ["res://tag_effects"]) as TagEffect


func _find_resource_by_id_in_dirs(resource_id: String, dirs: Array) -> Resource:
	for dir_path in dirs:
		var found := _find_resource_by_id_recursive(resource_id, str(dir_path))
		if found != null:
			return found
	return null


func _find_resource_by_id_recursive(resource_id: String, dir_path: String) -> Resource:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return null

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var child_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			var nested := _find_resource_by_id_recursive(resource_id, child_path)
			if nested != null:
				return nested
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource := load(child_path)
			var loaded_id = resource.get("id") if resource != null else null
			if loaded_id != null and str(loaded_id) == resource_id:
				return resource

		file_name = dir.get_next()

	return null


func _to_int_array(data) -> Array[int]:
	var result: Array[int] = []
	if data is Array:
		for value in data:
			result.append(int(value))
	return result


func _to_bool_array(data) -> Array[bool]:
	var result: Array[bool] = []
	if data is Array:
		for value in data:
			result.append(bool(value))
	return result


func _to_string_array(data) -> Array[String]:
	var result: Array[String] = []
	if data is Array:
		for value in data:
			result.append(str(value))
	return result


func _to_string_name_array(data) -> Array[StringName]:
	var result: Array[StringName] = []
	if data is Array:
		for value in data:
			result.append(StringName(str(value)))
	return result


func _to_int_dictionary(data) -> Dictionary:
	var result := {}
	if not (data is Dictionary):
		return result

	for key in (data as Dictionary).keys():
		result[str(key)] = int((data as Dictionary)[key])
	return result


func _string_name_array_to_strings(data: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in data:
		result.append(String(value))
	return result
