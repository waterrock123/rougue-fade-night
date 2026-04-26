class_name RunStats
extends Resource

# 一局开始时的初始金币。
const STARTING_GOLD := 0
# 每次进入修整期时额外获得的金币。
const EACH_TURN_GOLD := 6

@export var gold: int = STARTING_GOLD : set = set_gold
@export var player_build: PlayerBuild
@export var shop: Shop
@export var shop_config: ShopConfig


# 设置当前金币，并在运行时通知 UI 刷新。
func set_gold(new_amount: int) -> void:
	gold = max(new_amount, 0)
	if Engine.is_editor_hint():
		return

	if EventBus != null:
		EventBus.gold_changed.emit()


# 用新的玩家构筑与商店数据初始化这一局的数据。
# shop 会作为本局唯一的商店运行时状态，修整期修改后会直接保留下来。
func setup_new_run(new_player_build: PlayerBuild, new_shop: Shop = null, new_shop_config: ShopConfig = null) -> void:
	player_build = new_player_build
	shop = new_shop
	shop_config = new_shop_config
	set_gold(STARTING_GOLD)


# 进入修整期时发放固定金币奖励。
func grant_rest_period_gold() -> void:
	set_gold(gold + EACH_TURN_GOLD)
