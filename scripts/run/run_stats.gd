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
# 已经触发过的一次性 tag 效果 id，防止读档、装备刷新或进入战斗时重复结算。
@export var completed_once_tag_effect_ids: Array[StringName] = []
# 待消费的免费装备三选一等级队列。每次遗物合成升级会加入一次机会。
@export var pending_free_relic_choice_levels: Array[int] = []
# 玩家可用的升级奖励刷新次数。初始为 0，后续可以由事件、遗物或被动技能增加。
@export var level_up_reward_refresh_count: int = 0
# 玩家可储存的免费商店刷新次数。可跨修整期保存。
@export var shop_free_refresh_count: int = 0
# 持久状态层数。用于“战斗胜利后获得锋锐”这类跨战斗保留的状态。
@export var persistent_status_stacks: Dictionary = {}

# 下面两个字典只保存“当前激活效果”的运行时修正，不进存档。
# key 是效果来源，value 是具体参数；效果失效时会按 key 移除，避免互相覆盖。
var shop_intelligence_payment_sources: Dictionary = {}
var consumable_keep_chance_sources: Dictionary = {}

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
	shop_free_refresh_count = 0
	completed_once_tag_effect_ids.clear()
	pending_free_relic_choice_levels.clear()
	persistent_status_stacks.clear()
	shop_intelligence_payment_sources.clear()
	consumable_keep_chance_sources.clear()
	set_gold(STARTING_GOLD)


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
