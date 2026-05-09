class_name RunStats
extends Resource

# 一局开始时的初始金币。
const STARTING_GOLD := 0

@export var gold: int = STARTING_GOLD : set = set_gold
@export var player_build: PlayerBuild
@export var shop: Shop
@export var shop_config: ShopConfig
@export var picked_character: Character
# 待消费的免费装备三选一等级队列。每次遗物合成升级会加入一次机会。
@export var pending_free_relic_choice_levels: Array[int] = []

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
	pending_free_relic_choice_levels.clear()
	set_gold(STARTING_GOLD)


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
