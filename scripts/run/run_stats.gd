class_name RunStats
extends Resource

# 一局开始时的初始金币。
const STARTING_GOLD := 0

@export var gold: int = STARTING_GOLD : set = set_gold
@export var player_build: PlayerBuild
@export var shop: Shop
@export var shop_config: ShopConfig
@export var picked_character: Character
# 本局每个 tag 选中的套装效果。局外选择系统完成后，只需要在开局时填充这里。
@export var selected_tag_effects: Array[TagEffect] = []
# 玩家选择让哪些标签参与战斗地图生成。保存 key 而不是直接保存 Resource，便于存档和 UI 传递。
@export var enabled_map_tag_keys: Array[String] = []
# 启用标签栏的容量上限。后续可由角色、事件或遗物增加。
@export var map_tag_enable_limit: int = 3
# 已经触发过的一次性 tag 效果 id，防止读档、装备刷新或进入战斗时重复结算。
@export var completed_once_tag_effect_ids: Array[StringName] = []
# 待消费的免费装备三选一等级队列。每次遗物合成升级会加入一次机会。
@export var pending_free_relic_choice_levels: Array[int] = []
# 玩家可用的升级奖励刷新次数。初始为 0，后续可以由事件、遗物或被动技能增加。
@export var level_up_reward_refresh_count: int = 0
# 普通战斗升级奖励阶段：0 被动，1 主动，2 属性；选完奖励后循环到下一阶段。
@export var level_up_reward_phase: int = 0
# 玩家可储存的免费商店刷新次数。可跨修整期保存。
@export var shop_free_refresh_count: int = 0
# 当前修整期已经执行过的商店刷新次数，用于区分“本次修整期第一次刷新”。
@export var shop_refresh_count_this_rest_period: int = 0
# 下场战斗额外生成的悬赏精英怪队列。事件、遗物和技能都可以往这里追加，不影响正常胜利条件。
@export var pending_bounty_enemy_entries: Array[BountyEnemyEntry] = []
# 持久状态层数。用于“战斗胜利后获得锋锐”这类跨战斗保留的状态。
@export var persistent_status_stacks: Dictionary = {}
# 被动技能的跨战斗计数和一次性标记，例如夺宝奇兵击杀数、利益交换的初始金币。
@export var persistent_passive_counters: Dictionary = {}
# 记录当前战斗实际使用的模板，继续游戏时直接复用，避免重新抽取地图。
@export var current_battle_map_template_path: String = ""

# 下面两个字典只保存“当前激活效果”的运行时修正，不进存档。
# key 是效果来源，value 是具体参数；效果失效时会按 key 移除，避免互相覆盖。
var shop_intelligence_payment_sources: Dictionary = {}
var consumable_keep_chance_sources: Dictionary = {}
## source_key -> {object_id: String, weight_bonus: float}，供地图物体变体池读取。
var map_object_spawn_weight_sources: Dictionary = {}
var shop_refresh_disabled_sources: Dictionary = {}

@export_group("修整期金币")
# 第一次进入修整期时的基础奖励。
@export var base_rest_period_gold: int = 6
# 每多经历一次修整期，奖励额外增加多少。
@export var rest_period_gold_growth: int = 1
# 固定额外奖励，适合给遗物、事件、角色天赋直接叠加。
@export var rest_period_gold_flat_bonus: int = 0
# 当前已经进入过多少次修整期。
@export var rest_period_count: int = 0


# 设置当前金币，并在运行时通知 UI 刷新。
func set_gold(new_amount: int) -> void:
	gold = max(new_amount, 0)
	if Engine.is_editor_hint():
		return

	if EventBus != null:
		EventBus.gold_changed.emit()


# 用新的玩家构筑与商店数据初始化这一局的数据。
# shop 会作为本局唯一的商店运行时状态，修整期修改后会直接保留下来。
func setup_new_run(
	new_player_build: PlayerBuild,
	new_shop: Shop = null,
	new_shop_config: ShopConfig = null,
	new_character: Character = null
) -> void:
	player_build = new_player_build
	shop = new_shop
	shop_config = new_shop_config
	picked_character = new_character
	rest_period_count = 0
	level_up_reward_refresh_count = 0
	level_up_reward_phase = 0
	shop_free_refresh_count = 0
	shop_refresh_count_this_rest_period = 0
	pending_bounty_enemy_entries.clear()
	completed_once_tag_effect_ids.clear()
	enabled_map_tag_keys.clear()
	pending_free_relic_choice_levels.clear()
	persistent_status_stacks.clear()
	persistent_passive_counters.clear()
	shop_intelligence_payment_sources.clear()
	consumable_keep_chance_sources.clear()
	map_object_spawn_weight_sources.clear()
	shop_refresh_disabled_sources.clear()
	current_battle_map_template_path = ""
	set_gold(STARTING_GOLD)


func set_shop_refresh_disabled(source_key: Variant, disabled: bool) -> void:
	var key: String = str(source_key)
	if key.is_empty():
		return

	if disabled:
		shop_refresh_disabled_sources[key] = true
	else:
		shop_refresh_disabled_sources.erase(key)

	if not Engine.is_editor_hint() and EventBus != null:
		EventBus.shop_refresh_state_changed.emit()


func is_shop_refresh_disabled() -> bool:
	return not shop_refresh_disabled_sources.is_empty()


func clear_battle_map_template() -> void:
	# 战斗结束后清空，下一场战斗才会重新抽取模板。
	current_battle_map_template_path = ""


func get_map_tag_key(tag: RelicTag) -> String:
	if tag == null:
		return ""
	if not tag.resource_path.is_empty():
		return tag.resource_path
	return tag.tag_name


func get_enabled_map_tag_keys() -> Array[String]:
	var result: Array[String] = []
	for tag_key: String in enabled_map_tag_keys:
		result.append(tag_key)
	return result


func set_map_tag_enable_limit(new_limit: int) -> void:
	map_tag_enable_limit = max(new_limit, 0)
	trim_enabled_map_tags_to_limit()


func can_enable_map_tag(tag: RelicTag) -> bool:
	return can_enable_map_tag_key(get_map_tag_key(tag))


func can_enable_map_tag_key(tag_key: String) -> bool:
	if tag_key.is_empty():
		return false
	return enabled_map_tag_keys.size() < max(map_tag_enable_limit, 0)


func is_map_tag_enabled(tag: RelicTag) -> bool:
	return enabled_map_tag_keys.has(get_map_tag_key(tag))


func enable_map_tag(tag: RelicTag) -> bool:
	return enable_map_tag_key(get_map_tag_key(tag))


func enable_map_tag_key(tag_key: String) -> bool:
	if not can_enable_map_tag_key(tag_key):
		return false

	enabled_map_tag_keys.append(tag_key)
	_notify_map_tag_selection_changed()
	return true


func disable_map_tag(tag: RelicTag) -> bool:
	return disable_map_tag_key(get_map_tag_key(tag))


func disable_map_tag_key(tag_key: String) -> bool:
	if tag_key.is_empty() or not enabled_map_tag_keys.has(tag_key):
		return false

	enabled_map_tag_keys.erase(tag_key)
	_notify_map_tag_selection_changed()
	return true


func toggle_map_tag(tag: RelicTag) -> bool:
	var tag_key: String = get_map_tag_key(tag)
	if tag_key.is_empty():
		return false
	if enabled_map_tag_keys.has(tag_key):
		disable_map_tag_key(tag_key)
		return false
	return enable_map_tag_key(tag_key)


func set_enabled_map_tag_keys(new_keys: Array[String]) -> void:
	var normalized_keys: Array[String] = []
	for tag_key: String in new_keys:
		if tag_key.is_empty():
			continue
		if normalized_keys.size() >= max(map_tag_enable_limit, 0):
			break
		normalized_keys.append(tag_key)

	if normalized_keys == enabled_map_tag_keys:
		return

	enabled_map_tag_keys = normalized_keys
	_notify_map_tag_selection_changed()


func get_enabled_map_tag_count(tag_key: String) -> int:
	var result: int = 0
	for enabled_key: String in enabled_map_tag_keys:
		if enabled_key == tag_key:
			result += 1
	return result


func get_enabled_map_tag_counts() -> Dictionary:
	var result: Dictionary = {}
	for tag_key: String in enabled_map_tag_keys:
		if tag_key.is_empty():
			continue
		result[tag_key] = int(result.get(tag_key, 0)) + 1
	return result


func trim_enabled_map_tags_to_limit() -> void:
	var safe_limit: int = max(map_tag_enable_limit, 0)
	if enabled_map_tag_keys.size() <= safe_limit:
		return

	enabled_map_tag_keys.resize(safe_limit)
	_notify_map_tag_selection_changed()


func clear_enabled_map_tags() -> void:
	if enabled_map_tag_keys.is_empty():
		return

	enabled_map_tag_keys.clear()
	_notify_map_tag_selection_changed()


func get_owned_relic_tag_counts(include_inventory: bool = true, include_equipment: bool = true) -> Dictionary:
	var result: Dictionary = {}
	if player_build == null:
		return result

	if include_equipment and player_build.player_equipment != null:
		_count_tags_from_slots(player_build.player_equipment.equip_slots, result)
	if include_inventory and player_build.player_inventory != null:
		_count_tags_from_slots(player_build.player_inventory.slots, result)

	return result


func get_owned_relic_tags(include_inventory: bool = true, include_equipment: bool = true) -> Array[RelicTag]:
	var result: Array[RelicTag] = []
	var seen_keys: Dictionary = {}
	if player_build == null:
		return result

	if include_equipment and player_build.player_equipment != null:
		_append_tags_from_slots(player_build.player_equipment.equip_slots, seen_keys, result)
	if include_inventory and player_build.player_inventory != null:
		_append_tags_from_slots(player_build.player_inventory.slots, seen_keys, result)

	return result


func _count_tags_from_slots(slots: Array[Slot], result: Dictionary) -> void:
	for slot: Slot in slots:
		if slot == null or slot.item == null:
			continue
		for tag: RelicTag in slot.item.tags:
			var tag_key: String = get_map_tag_key(tag)
			if tag_key.is_empty():
				continue
			result[tag_key] = int(result.get(tag_key, 0)) + 1


func _append_tags_from_slots(slots: Array[Slot], seen_keys: Dictionary, result: Array[RelicTag]) -> void:
	for slot: Slot in slots:
		if slot == null or slot.item == null:
			continue
		for tag: RelicTag in slot.item.tags:
			var tag_key: String = get_map_tag_key(tag)
			if tag_key.is_empty() or seen_keys.has(tag_key):
				continue
			seen_keys[tag_key] = true
			result.append(tag)


func _notify_map_tag_selection_changed() -> void:
	if Engine.is_editor_hint():
		return
	if EventBus != null:
		EventBus.map_tag_selection_changed.emit()


func is_tag_effect_once_completed(effect_id: StringName) -> bool:
	return completed_once_tag_effect_ids.has(effect_id)


func mark_tag_effect_once_completed(effect_id: StringName) -> void:
	if effect_id == &"":
		return
	if completed_once_tag_effect_ids.has(effect_id):
		return

	completed_once_tag_effect_ids.append(effect_id)


# 计算本次进入修整期应获得的金币。
# 公式拆成基础值、成长值和固定加成，方便后续拓展更多来源。
func get_next_rest_period_gold_reward() -> int:
	var reward := base_rest_period_gold
	reward += rest_period_count * rest_period_gold_growth
	reward += rest_period_gold_flat_bonus
	return max(reward, 0)


# 发放本次修整期金币奖励，并推进修整期计数。
func grant_rest_period_gold() -> int:
	var reward := get_next_rest_period_gold_reward()
	set_gold(gold + reward)
	rest_period_count += 1
	return reward


# 开始一个新的修整期时清零本期商店刷新计数；读档回到当前修整期时不要调用它。
func begin_rest_period() -> void:
	shop_refresh_count_this_rest_period = 0


# 商店每完成一次真实刷新后调用，付费刷新和免费刷新都算一次。
func record_shop_refresh() -> void:
	shop_refresh_count_this_rest_period += 1


func get_shop_refresh_count_this_rest_period() -> int:
	return max(shop_refresh_count_this_rest_period, 0)


# 读取被动技能使用的跨战斗计数。
func get_persistent_passive_counter(counter_key: StringName) -> int:
	return int(persistent_passive_counters.get(String(counter_key), 0))


# 写入被动技能的跨战斗计数或一次性标记。
func set_persistent_passive_counter(counter_key: StringName, value: int) -> void:
	if counter_key == &"":
		return
	persistent_passive_counters[String(counter_key)] = max(value, 0)


func add_persistent_passive_counter(counter_key: StringName, amount: int = 1) -> int:
	var new_value: int = get_persistent_passive_counter(counter_key) + amount
	set_persistent_passive_counter(counter_key, new_value)
	return get_persistent_passive_counter(counter_key)


# 给修整期金币奖励增加一个固定加值。
func add_rest_period_gold_bonus(amount: int) -> void:
	rest_period_gold_flat_bonus += amount


# 直接修改修整期金币成长率，适合做全局难度或角色特性。
func add_rest_period_gold_growth(amount: int) -> void:
	rest_period_gold_growth += amount


# 重置修整期金币奖励的额外修正。
func reset_rest_period_gold_modifiers() -> void:
	rest_period_gold_flat_bonus = 0


# 记录一次免费装备三选一机会，并锁定这次机会刷出的装备等阶。
func queue_free_relic_choice(relic_level: int) -> void:
	pending_free_relic_choice_levels.append(max(relic_level, 1))
	if EventBus != null:
		EventBus.free_relic_choice_changed.emit()


func has_free_relic_choice() -> bool:
	return not pending_free_relic_choice_levels.is_empty()


# 取出最早获得的一次免费三选一机会。
func pop_free_relic_choice_level() -> int:
	if pending_free_relic_choice_levels.is_empty():
		return -1

	var relic_level := pending_free_relic_choice_levels[0]
	pending_free_relic_choice_levels.remove_at(0)
	return relic_level


# 修整期结束时丢弃未使用的免费三选一机会，避免跨修整期保存。
func clear_free_relic_choices() -> void:
	if pending_free_relic_choice_levels.is_empty():
		return

	pending_free_relic_choice_levels.clear()
	if EventBus != null:
		EventBus.free_relic_choice_changed.emit()


func get_free_relic_choice_level_for_now() -> int:
	if shop == null:
		return 1
	return max(shop.level + 1, 1)


# 记录一批“下一场战斗开场额外生成”的悬赏精英怪。
# starts_neutral 为 false 时，适合事件中已经激怒敌人的情况；true 则保持普通悬赏野怪逻辑。
func queue_bounty_enemy_for_next_battle(
	enemy_scene: PackedScene,
	count: int = 1,
	new_bounty_gold: int = 0,
	starts_neutral: bool = true,
	neutral_speed_multiplier: float = 0.45,
	neutral_wander_radius: float = 120.0,
	neutral_wander_repick_interval: float = 1.8
) -> void:
	if enemy_scene == null or count <= 0:
		return

	for _index in range(count):
		var entry := BountyEnemyEntry.new()
		entry.enemy_scene = enemy_scene
		entry.bounty_gold = max(new_bounty_gold, 0)
		entry.starts_neutral = starts_neutral
		entry.neutral_speed_multiplier = neutral_speed_multiplier
		entry.neutral_wander_radius = neutral_wander_radius
		entry.neutral_wander_repick_interval = neutral_wander_repick_interval
		pending_bounty_enemy_entries.append(entry)


# 战斗场景开场时消费队列，避免同一批事件敌人在下一场以后重复生成。
func pop_pending_bounty_enemy_entries() -> Array[BountyEnemyEntry]:
	var result: Array[BountyEnemyEntry] = []
	for entry: BountyEnemyEntry in pending_bounty_enemy_entries:
		if entry != null:
			result.append(entry)

	pending_bounty_enemy_entries.clear()
	return result


# 增加升级奖励刷新次数，供事件房、遗物、被动等系统调用。
func add_level_up_reward_refresh_count(amount: int) -> void:
	if amount <= 0:
		return

	level_up_reward_refresh_count += amount
	if EventBus != null:
		EventBus.level_up_reward_refresh_changed.emit()


# 尝试消耗一次刷新次数；成功返回 true，失败表示次数不足。
func spend_level_up_reward_refresh_count(amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if level_up_reward_refresh_count < amount:
		return false

	level_up_reward_refresh_count -= amount
	if EventBus != null:
		EventBus.level_up_reward_refresh_changed.emit()
	return true


func get_level_up_reward_phase() -> int:
	return posmod(level_up_reward_phase, 3)


func advance_level_up_reward_phase() -> void:
	level_up_reward_phase = (get_level_up_reward_phase() + 1) % 3


# 增加可储存的免费商店刷新次数，供兑换券、事件或奖励调用。
func add_shop_free_refresh_count(amount: int = 1) -> void:
	if amount <= 0:
		return

	shop_free_refresh_count += amount
	if EventBus != null:
		EventBus.shop_free_refresh_changed.emit()


# 尝试消耗一次免费商店刷新次数；成功返回 true。
func spend_shop_free_refresh_count(amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if shop_free_refresh_count < amount:
		return false

	shop_free_refresh_count -= amount
	if EventBus != null:
		EventBus.shop_free_refresh_changed.emit()
	return true


# 注册“金币不足时可消耗智力购物”的来源。多个来源同时存在时取消耗最低的那个。
func set_shop_intelligence_payment(source_key: String, intelligence_cost: int) -> void:
	if source_key.is_empty() or intelligence_cost <= 0:
		return

	shop_intelligence_payment_sources[source_key] = intelligence_cost


func clear_shop_intelligence_payment(source_key: String) -> void:
	if source_key.is_empty():
		return

	shop_intelligence_payment_sources.erase(source_key)


func can_pay_shop_with_intelligence() -> bool:
	return _get_shop_intelligence_cost() > 0


# 尝试永久消耗智力支付一次商品。文本设定是“没有金币时”，所以这里要求金币为 0。
func spend_intelligence_for_shop_purchase() -> bool:
	var cost := _get_shop_intelligence_cost()
	if cost <= 0 or gold > 0:
		return false
	if player_build == null or player_build.player_stats == null:
		return false
	if player_build.player_stats.intelligence < cost:
		return false

	player_build.player_stats.intelligence -= cost
	if EventBus != null:
		EventBus.attribute_update.emit()
	return true


func _get_shop_intelligence_cost() -> int:
	var result := 0
	for value in shop_intelligence_payment_sources.values():
		var cost := int(value)
		if cost <= 0:
			continue
		if result == 0 or cost < result:
			result = cost
	return result


# 注册“使用消耗品时不消耗”的概率来源。结算时取最高概率，避免多个来源线性爆炸。
func set_consumable_keep_chance(source_key: String, chance: float) -> void:
	if source_key.is_empty():
		return

	consumable_keep_chance_sources[source_key] = clamp(chance, 0.0, 1.0)


func clear_consumable_keep_chance(source_key: String) -> void:
	if source_key.is_empty():
		return

	consumable_keep_chance_sources.erase(source_key)


func roll_keep_consumable() -> bool:
	var chance := get_consumable_keep_chance()
	if chance <= 0.0:
		return false

	return randf() <= chance


func get_consumable_keep_chance() -> float:
	var result := 0.0
	for value in consumable_keep_chance_sources.values():
		result = max(result, float(value))
	return clamp(result, 0.0, 1.0)


## 注册某个地图物体变体的权重加成，例如鸡妈妈勋章提高 animal_chicken 权重。
func set_map_object_spawn_weight_modifier(source_key: Variant, object_id: StringName, weight_bonus: float) -> void:
	var key: String = str(source_key)
	if key.is_empty() or object_id == &"":
		return
	map_object_spawn_weight_sources[key] = {
		"object_id": String(object_id),
		"weight_bonus": weight_bonus,
	}


## 移除某个来源的地图物体权重加成。
func clear_map_object_spawn_weight_modifier(source_key: Variant) -> void:
	map_object_spawn_weight_sources.erase(str(source_key))


## 合并所有来源对每个变体的权重加成。
func get_map_object_spawn_weight_bonuses() -> Dictionary:
	var result: Dictionary = {}
	for source_value in map_object_spawn_weight_sources.values():
		if not (source_value is Dictionary):
			continue
		var object_id: String = str(source_value.get("object_id", ""))
		if object_id.is_empty():
			continue
		result[object_id] = float(result.get(object_id, 0.0)) + float(source_value.get("weight_bonus", 0.0))
	return result


# 记录跨战斗保留的状态层数，常用于“每次战斗胜利后获得一层锋锐”。
func add_persistent_status_stacks(status_id: StringName, stacks: int = 1) -> void:
	if status_id == &"" or stacks <= 0:
		return

	var key := String(status_id)
	persistent_status_stacks[key] = int(persistent_status_stacks.get(key, 0)) + stacks


func get_persistent_status_stacks(status_id: StringName) -> int:
	if status_id == &"":
		return 0

	return int(persistent_status_stacks.get(String(status_id), 0))
