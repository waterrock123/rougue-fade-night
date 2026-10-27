class_name StatsController
extends Node

@export var stats_data: StatsData

const PRIMARY_STATS: Array[StringName] = [
	&"strength",
	&"dexterity",
	&"intelligence",
	&"constitution",
	&"speed",
	&"charm",
	&"luck",
]

var final_stats: Dictionary = {}
var modifiers: Array[Modifier] = []
var effect_modifiers: Dictionary = {}
var outgoing_damage_bonus_modifiers: Dictionary = {}
var outgoing_defense_bypass_modifiers: Dictionary = {}
var incoming_damage_taken_modifiers: Dictionary = {}
## 类型免疫独立于百分比减伤，不会被易伤抵消；多个来源可以分别撤销。
var damage_immunity_sources: Dictionary = {}
var current_health: float = 0.0
var current_energy: float = 0.0
var player_build: PlayerBuild
var temporary_gain_policy: TemporaryStatGainPolicy = TemporaryStatGainPolicy.new()
var temporary_effect_sources: Dictionary = {}

@onready var modifier_handler: ModifierHandler = get_node_or_null("../ModifierHandler") as ModifierHandler
@onready var entity: Entity = get_parent() as Entity


func _ready() -> void:
	if stats_data != null:
		stats_data = stats_data.duplicate(true)

	if modifier_handler != null:
		modifier_handler.bind_stats_controller(self)

	recompute_stats()

	if current_health <= 0.0:
		current_health = get_stat("max_health")
	if current_energy <= 0.0:
		current_energy = get_stat("max_energy")

	_sync_entity_stats(true)
	_sync_player_build()


# 将 StatsController 绑定到 PlayerBuild，使其可以在非战斗场景中独立工作。
func bind_player_build(new_player_build: PlayerBuild) -> void:
	player_build = new_player_build
	if player_build == null:
		return

	if player_build.player_stats != null:
		stats_data = player_build.player_stats.duplicate(true)

	var saved_current_health := player_build.current_health
	var saved_current_energy := player_build.current_energy
	var had_previous_health_stat := get_stat("max_health") > 0.0
	var had_previous_energy_stat := get_stat("max_energy") > 0.0

	current_health = player_build.current_health
	current_energy = player_build.current_energy

	recompute_stats()

	var max_health := get_stat("max_health")
	var max_energy := get_stat("max_energy")

	if not had_previous_health_stat:
		if saved_current_health > 0.0:
			current_health = min(saved_current_health, max_health)
		else:
			current_health = max_health
	else:
		current_health = min(current_health, max_health)

	if not had_previous_energy_stat:
		if saved_current_energy > 0.0:
			current_energy = min(saved_current_energy, max_energy)
		else:
			current_energy = max_energy
	else:
		current_energy = min(current_energy, max_energy)

	_sync_player_build()
	EventBus.attribute_update.emit()


# 用 ModifierHandler 提供的修饰器整体覆盖运行时修饰器列表。
func set_modifiers(new_modifiers: Array[Modifier]) -> void:
	modifiers.clear()
	for modifier: Modifier in new_modifiers:
		if modifier == null:
			continue
		if modifier.is_temporary():
			var key: String = modifier.gain_ledger_key if not modifier.gain_ledger_key.is_empty() else "runtime_%d" % modifier.get_instance_id()
			modifiers.append_array(temporary_gain_policy.transform(key, [modifier], 1.0, player_build))
		else:
			modifiers.append(modifier)
	recompute_stats()


# 添加单个运行时修饰器。
func add_modifier(modifier: Modifier) -> void:
	if modifier == null:
		return

	modifiers.append(modifier)
	recompute_stats()


# 移除单个运行时修饰器。
func remove_modifier(modifier: Modifier) -> void:
	if modifier == null:
		return

	modifiers.erase(modifier)
	recompute_stats()


# 注册某个外部系统提供的一组修饰器。
func set_effect_modifiers(source_key: Variant, new_modifiers: Array[Modifier]) -> void:
	if source_key == null:
		return

	var normalized_modifiers: Array[Modifier] = []
	for modifier in new_modifiers:
		if modifier != null:
			normalized_modifiers.append(modifier)

	effect_modifiers[source_key] = normalized_modifiers
	recompute_stats()


## 战斗/消耗品新增属性的统一入口；常驻装备与被动仍使用set_effect_modifiers，避免重复永久成长。
func set_temporary_effect_modifiers(
	source_key: Variant, new_modifiers: Array[Modifier], eligible_ratio: float = 1.0,
	ledger_key: String = "", resettable: bool = true
) -> void:
	var key: String = ledger_key if not ledger_key.is_empty() else str(source_key)
	temporary_effect_sources[source_key] = {"ledger_key": key, "resettable": resettable}
	var transformed: Array[Modifier] = temporary_gain_policy.transform(key, new_modifiers, eligible_ratio, player_build)
	set_effect_modifiers(source_key, transformed)


## 移除战斗属性增减及已经延长的增量，不影响普通装备/被动修饰。
func clear_temporary_attribute_effects() -> void:
	for key: Variant in temporary_effect_sources.keys():
		var record: Dictionary = temporary_effect_sources[key]
		if bool(record["resettable"]):
			effect_modifiers.erase(key)
			var ledger_key: String = str(record["ledger_key"])
			if ledger_key == str(key):
				temporary_gain_policy.reset_source(ledger_key)
			else:
				# 状态来源将在StatusController中逐项移除，无需对剩余装备层数扣基线。
				temporary_gain_policy.release_source(ledger_key)
				temporary_effect_sources.erase(key)
	temporary_gain_policy.reset_battle_gains()
	recompute_stats()


## 重置属性不作为治疗：按重置前的实际生命/能量保留，超过新上限的部分夹取。
func restore_resource_snapshot(health: float, energy: float) -> void:
	current_health = clampf(health, 0.0, get_stat(&"max_health"))
	current_energy = clampf(energy, 0.0, get_stat(&"max_energy"))
	_sync_entity_stats(false)
	_sync_player_build()


# 清除某个外部来源注册的修饰器。
func clear_effect_modifiers(source_key: Variant, preserve_gain_history: bool = false) -> void:
	if source_key == null:
		return

	if effect_modifiers.has(source_key):
		effect_modifiers.erase(source_key)
		recompute_stats()
	if not preserve_gain_history and temporary_effect_sources.has(source_key):
		var record: Dictionary = temporary_effect_sources[source_key]
		temporary_gain_policy.release_source(str(record["ledger_key"]))
		temporary_effect_sources.erase(source_key)


# 注册某个状态/被动提供的出伤加成。
func set_outgoing_damage_bonus_modifier(source_key: Variant, modifier_data: Dictionary) -> void:
	if source_key == null:
		return
	outgoing_damage_bonus_modifiers[str(source_key)] = modifier_data.duplicate(true)


# 清除某个来源注册的出伤加成。
func clear_outgoing_damage_bonus_modifier(source_key: Variant) -> void:
	if source_key == null:
		return
	outgoing_damage_bonus_modifiers.erase(str(source_key))


# 注册某个状态/效果提供的承伤修正。
# 例如“易伤”会让目标受到的所有伤害按比例提高。
func set_incoming_damage_taken_modifier(source_key: Variant, modifier_data: Dictionary) -> void:
	if source_key == null:
		return
	incoming_damage_taken_modifiers[str(source_key)] = modifier_data.duplicate(true)


# 清除指定来源注册的承伤修正。
func clear_incoming_damage_taken_modifier(source_key: Variant) -> void:
	if source_key == null:
		return
	incoming_damage_taken_modifiers.erase(str(source_key))


# 对外统一读取最终属性。
func get_stat(stat_name: StringName, default_value: float = 0.0) -> float:
	return float(final_stats.get(stat_name, default_value))


# 重算最终属性。
func recompute_stats() -> void:
	if stats_data == null:
		final_stats.clear()
		return

	var previous_max_health := get_stat("max_health")
	var previous_max_energy := get_stat("max_energy")
	var primary_stats := _build_primary_stats(stats_data)
	var direct_modifiers: Array[Modifier] = []

	for modifier in _get_all_modifiers():
		if _is_primary_stat_modifier(modifier):
			_apply_modifier(primary_stats, modifier)
		else:
			direct_modifiers.append(modifier)

	var final := _build_derived_stats(stats_data, primary_stats)
	for primary_stat in PRIMARY_STATS:
		final[primary_stat] = primary_stats.get(primary_stat, 0.0)

	for modifier in direct_modifiers:
		_apply_modifier(final, modifier)

	final_stats = final
	_clamp_resources(previous_max_health, previous_max_energy)
	_sync_entity_stats(false)
	_sync_player_build()
	EventBus.attribute_update.emit()


# 构建一级属性基础值。
func _build_primary_stats(data: StatsData) -> Dictionary:
	return {
		"strength": float(data.strength),
		"dexterity": float(data.dexterity),
		"intelligence": float(data.intelligence),
		"constitution": float(data.constitution),
		"speed": float(data.speed),
		"charm": float(data.charm),
		"luck": float(data.luck),
	}


# 用一级属性推导战斗中真正使用的派生属性。
func _build_derived_stats(data: StatsData, primary_stats: Dictionary) -> Dictionary:
	var constitution := float(primary_stats.get("constitution", 0.0))
	var intelligence := float(primary_stats.get("intelligence", 0.0))
	var speed := float(primary_stats.get("speed", 0.0))
	var luck := float(primary_stats.get("luck", 0.0))

	return {
		"max_health": data.base_max_health + constitution * 5.0,
		"max_energy": data.base_max_energy + intelligence * 3.0,
		"move_speed": data.base_move_speed + speed * 10.0,
		"energy_regen_tick_value": data.base_energy_regen_tick_value + intelligence,
		"energy_regen_multiplier": 1.0,
		"healing_received_multiplier": 1.0,
		"crit_chance": data.base_crit_chance + luck * 0.002,
		"crit_damage": data.base_crit_damage,
		"dodge_rate": data.base_dodge_rate + speed * 0.001,
		"damage_reduction_rate": data.base_damage_reduction_rate,
		"static_damage_reduction": float(data.base_static_damage_reduction),
		"cooldown_reduction": data.base_cooldown_reduction + speed * 0.002,
		# 统一影响固定削韧与目标默认削韧公式，1.0 表示不修正。
		"poise_damage_multiplier": data.base_poise_damage_multiplier,
		"projectile_range_bonus_rate": 0.0,
		# 大于 0 时，通用投射物会按该角速度追踪附近目标。
		"projectile_homing_turn_speed": 0.0,
	}


# 汇总所有来源的修饰器。
func _get_all_modifiers() -> Array[Modifier]:
	var all_modifiers: Array[Modifier] = []
	if player_build != null:
		all_modifiers.append_array(TemporaryStatGainPolicy.build_modifiers(player_build.permanent_stat_bonuses, "run_permanent_stats"))
	all_modifiers.append_array(TemporaryStatGainPolicy.build_modifiers(temporary_gain_policy.battle_bonuses, "retained_battle_stats"))
	all_modifiers.append_array(modifiers)

	for source_key in effect_modifiers.keys():
		var source_modifiers = effect_modifiers[source_key] as Array
		for modifier in source_modifiers:
			if modifier != null:
				all_modifiers.append(modifier)

	return all_modifiers


# 判断一条修饰器是不是作用于一级属性。
func _is_primary_stat_modifier(modifier: Modifier) -> bool:
	if modifier == null:
		return false

	return PRIMARY_STATS.has(StringName(modifier.stat))


# 将单个修饰器应用到属性字典上。
func _apply_modifier(final: Dictionary, modifier: Modifier) -> void:
	if modifier == null or not modifier.is_active():
		return

	var stat_name := StringName(modifier.stat)
	if not final.has(stat_name):
		return

	match modifier.modifier_type:
		Modifier.ModifierType.FLAT:
			final[stat_name] += modifier.value
		Modifier.ModifierType.PERCENT:
			final[stat_name] *= 1.0 + modifier.value


# 处理攻击方造成伤害时的结算。
func process_outgoing_damage(damage_data: DamageData) -> DamageData:
	if damage_data == null:
		return null

	damage_data.final_damage = damage_data.base_damage
	damage_data.final_damage += _get_outgoing_damage_bonus(damage_data)
	damage_data.final_damage *= maxf(1.0 + _get_total_outgoing_damage_percent_bonus(damage_data), 0.0)
	damage_data.final_damage *= maxf(damage_data.skill_damage_multiplier, 0.0)

	if damage_data.can_crit and not damage_data.is_crit:
		if randf() <= get_stat("crit_chance"):
			damage_data.is_crit = true

	damage_data.crit_multiplier = get_stat("crit_damage", damage_data.crit_multiplier)
	if damage_data.is_crit:
		damage_data.final_damage *= damage_data.crit_multiplier

	# 把攻击方当前削韧倍率快照进伤害事件，目标之后解析默认削韧公式时也能正确应用。
	var poise_multiplier: float = maxf(get_stat(&"poise_damage_multiplier", 1.0), 0.0)
	damage_data.poise_damage_multiplier *= poise_multiplier
	_apply_outgoing_defense_bypass(damage_data)

	return damage_data


## 穿透与出伤加成分开登记，卸下装备只清理自己的来源，不改变目标属性。
func set_outgoing_defense_bypass_modifier(source_key: Variant, data: Dictionary) -> void:
	if source_key != null:
		outgoing_defense_bypass_modifiers[str(source_key)] = data.duplicate(true)


func clear_outgoing_defense_bypass_modifier(source_key: Variant) -> void:
	outgoing_defense_bypass_modifiers.erase(str(source_key))


func _apply_outgoing_defense_bypass(damage_data: DamageData) -> void:
	for modifier_data: Dictionary in outgoing_defense_bypass_modifiers.values():
		if bool(modifier_data.get("exclude_self_damage", true)) and damage_data.source == damage_data.target:
			continue
		if not _outgoing_damage_modifier_matches(damage_data, modifier_data):
			continue
		damage_data.ignore_static_damage_reduction = damage_data.ignore_static_damage_reduction or bool(modifier_data.get("ignore_static_damage_reduction", false))
		damage_data.ignore_damage_reduction_rate = damage_data.ignore_damage_reduction_rate or bool(modifier_data.get("ignore_damage_reduction_rate", false))


# 受到一次伤害事件时进行闪避判定。只要 dodge_rate 大于 0，就有概率让这次伤害完全落空。
func should_dodge_damage(_damage_data: DamageData) -> bool:
	var dodge_rate: float = clamp(get_stat(&"dodge_rate"), 0.0, 1.0)
	if dodge_rate <= 0.0:
		return false

	return randf() < dodge_rate


# 处理防守方受到伤害时的减伤结算。
func process_incoming_damage(damage_data: DamageData) -> DamageData:
	if damage_data == null:
		return null
	if is_damage_type_immune(damage_data.damage_types):
		damage_data.final_damage = 0.0
		return damage_data

	var damage: float = damage_data.final_damage
	if not damage_data.ignore_static_damage_reduction:
		damage -= get_stat("static_damage_reduction")
	damage = max(damage, 0.0)

	var damage_reduction_rate: float = clamp(get_stat("damage_reduction_rate"), 0.0, 1.0)
	if not damage_data.ignore_damage_reduction_rate:
		damage *= 1.0 - damage_reduction_rate
	damage *= _get_incoming_damage_taken_multiplier(damage_data)

	damage_data.final_damage = max(damage, 0.0)
	return damage_data


func set_damage_type_immunity(source_key: Variant, damage_types: Array[int]) -> void:
	damage_immunity_sources[source_key] = damage_types.duplicate()


func clear_damage_type_immunity(source_key: Variant) -> void:
	damage_immunity_sources.erase(source_key)


## 当前伤害没有按元素拆分数值，包含任一免疫类型时整次伤害归零。
func is_damage_type_immune(damage_types: Array[int]) -> bool:
	for immune_types: Array in damage_immunity_sources.values():
		for damage_type: int in damage_types:
			if immune_types.has(damage_type):
				return true
	return false


# 从 DamageData 上挂载的成长规则里计算额外伤害。
func _get_outgoing_damage_bonus(damage_data: DamageData) -> float:
	if damage_data == null:
		return 0.0

	var bonus := 0.0
	if damage_data.scaling_rule != null:
		bonus += max(damage_data.scaling_rule.get_bonus_damage(self, damage_data), 0.0)
	bonus += _get_registered_outgoing_damage_bonus(damage_data)
	return max(bonus, 0.0)


# 计算由状态/被动注册的额外出伤，例如暴怒的“初始技能附带体质伤害”。
func _get_registered_outgoing_damage_bonus(damage_data: DamageData) -> float:
	var bonus := 0.0
	for modifier_data in outgoing_damage_bonus_modifiers.values():
		if not _outgoing_damage_modifier_matches(damage_data, modifier_data):
			continue

		bonus += float(modifier_data.get("flat_bonus", 0.0))
		var formula := str(modifier_data.get("flat_bonus_formula", ""))
		if not formula.is_empty():
			bonus += _evaluate_damage_bonus_formula(formula, damage_data)
		bonus += damage_data.base_damage * float(modifier_data.get("percent_bonus", 0.0))

	return bonus


func _get_total_outgoing_damage_percent_bonus(damage_data: DamageData) -> float:
	var bonus: float = 0.0
	for modifier_data in outgoing_damage_bonus_modifiers.values():
		if _outgoing_damage_modifier_matches(damage_data, modifier_data):
			bonus += float(modifier_data.get("total_damage_percent_bonus", 0.0))
	return bonus


func _outgoing_damage_modifier_matches(damage_data: DamageData, modifier_data: Dictionary) -> bool:
	var target_id: int = int(modifier_data.get("required_target_id", 0))
	if target_id != 0 and (not is_instance_valid(damage_data.target) or damage_data.target.get_instance_id() != target_id):
		return false
	var target_ids: Array = modifier_data.get("target_ability_ids", [])
	if not target_ids.is_empty() and not target_ids.has(damage_data.source_ability_id):
		return false

	var target_slots: Array = modifier_data.get("target_slot_indices", [])
	if not target_slots.is_empty() and not target_slots.has(damage_data.source_ability_slot_index):
		return false

	var required_tags: Array = modifier_data.get("required_tags", [])
	for required_tag in required_tags:
		if not damage_data.tags.has(str(required_tag)):
			return false

	var required_damage_types: Array = modifier_data.get("required_damage_types", [])
	for required_damage_type in required_damage_types:
		if not damage_data.damage_types.has(int(required_damage_type)):
			return false

	return true


func _evaluate_damage_bonus_formula(formula: String, damage_data: DamageData) -> float:
	var expression := Expression.new()
	var values := {
		"base_damage": damage_data.base_damage,
		"final_damage": damage_data.final_damage,
		"strength": get_stat("strength"),
		"dexterity": get_stat("dexterity"),
		"intelligence": get_stat("intelligence"),
		"constitution": get_stat("constitution"),
		"speed": get_stat("speed"),
		"charm": get_stat("charm"),
		"luck": get_stat("luck"),
	}
	var input_names: PackedStringArray = []
	var input_values: Array = []
	for key in values.keys():
		input_names.append(String(key))
		input_values.append(values[key])

	if expression.parse(formula, input_names) != OK:
		push_warning("StatsController damage bonus formula parse failed: %s" % formula)
		return 0.0

	var result = expression.execute(input_values, self, true)
	if expression.has_execute_failed():
		push_warning("StatsController damage bonus formula execute failed: %s" % formula)
		return 0.0

	return max(float(result), 0.0)


func _get_incoming_damage_taken_multiplier(damage_data: DamageData) -> float:
	var multiplier = 1.0
	for modifier_data in incoming_damage_taken_modifiers.values():
		if not _incoming_damage_modifier_matches(damage_data, modifier_data):
			continue
		multiplier += float((modifier_data as Dictionary).get("percent_bonus", 0.0))

	return max(multiplier, 0.0)


func _incoming_damage_modifier_matches(damage_data: DamageData, modifier_data: Dictionary) -> bool:
	if not _matches_incoming_direction(damage_data, float(modifier_data.get("front_angle_degrees", 0.0))):
		return false
	var required_tags: Array = modifier_data.get("required_tags", [])
	for required_tag in required_tags:
		if not damage_data.tags.has(str(required_tag)):
			return false

	var required_damage_types: Array = modifier_data.get("required_damage_types", [])
	for required_damage_type in required_damage_types:
		if not damage_data.damage_types.has(int(required_damage_type)):
			return false

	return true


## 正面防御使用真实命中方向；近战未提供方向时才回退到伤害来源位置。
## 持续伤害、地形、自伤不因为站位被当作“正面攻击”削减。
func _matches_incoming_direction(data: DamageData, angle_degrees: float) -> bool:
	if angle_degrees <= 0.0:
		return true
	if not is_instance_valid(data.target) or data.source == data.target:
		return false
	for tag: String in ["status", "periodic", "terrain", "self_damage", "reflect", "retaliation"]:
		if data.tags.has(tag):
			return false
	var toward_source: Vector2 = -data.impact_direction
	if toward_source == Vector2.ZERO and is_instance_valid(data.source):
		toward_source = data.target.global_position.direction_to(data.source.global_position)
	if toward_source == Vector2.ZERO:
		return false
	var facing: Vector2 = data.target.get_facing_direction().normalized()
	return facing.dot(toward_source.normalized()) >= cos(deg_to_rad(angle_degrees * 0.5))


# 最大生命/能量变化后，夹取当前资源值。
func _clamp_resources(previous_max_health: float, previous_max_energy: float) -> void:
	var new_max_health := get_stat("max_health")
	var new_max_energy := get_stat("max_energy")

	if previous_max_health <= 0.0:
		current_health = new_max_health
	else:
		var health_ratio = clamp(current_health / previous_max_health, 0.0, 1.0)
		current_health = new_max_health * health_ratio

	if previous_max_energy <= 0.0:
		current_energy = new_max_energy
	else:
		current_energy = min(current_energy, new_max_energy)


# 把运行时属性同步回父实体。
func _sync_entity_stats(force_fill_resources: bool) -> void:
	if entity == null:
		return

	entity.max_health = get_stat("max_health")
	entity.max_energy = get_stat("max_energy")
	entity.energy_region_tick_value = get_stat("energy_regen_tick_value")

	if force_fill_resources:
		entity.current_health = entity.max_health
		entity.current_energy = entity.max_energy
		current_health = entity.current_health
		current_energy = entity.current_energy
	else:
		entity.current_health = current_health
		entity.current_energy = current_energy

	entity.apply_runtime_stats(final_stats)


# 把当前生命、能量和属性计算结果写回 PlayerBuild。
func _sync_player_build() -> void:
	if player_build == null:
		return

	player_build.current_health = current_health
	player_build.current_energy = current_energy


func sync_runtime_resources() -> void:
	_sync_player_build()
