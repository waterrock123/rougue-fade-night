class_name ShopKeeperUI
extends Control

@export var run_stats: RunStats
@export var shop: Shop

@onready var glod_label: Label = %GoldLabel
@onready var level_label: Label = %LevelLabel
@onready var shop_keeper_texture: TextureRect = %ShopKeeperTexture
@onready var dialogue_ui: DialogueUI = $DialogueUI


func _ready() -> void:
	if not EventBus.gold_changed.is_connected(updata_ui):
		EventBus.gold_changed.connect(updata_ui)

	updata_ui()


# 更新商店老板头像、金币和商店等级。
func updata_ui() -> void:
	if run_stats != null:
		glod_label.text = str(run_stats.gold)

	if shop != null:
		level_label.text = "Lv.%s" % shop.level
		if shop.shopkeeper != null:
			shop_keeper_texture.texture = shop.shopkeeper.texture


func speak_enter() -> void:
	_speak_from_pool(_get_shop_keeper().enter_rest_period_dialogues)


func speak_buy() -> void:
	_speak_from_pool(_get_shop_keeper().buy_relic_dialogues)


func speak_sell() -> void:
	_speak_from_pool(_get_shop_keeper().sell_relic_dialogues)


func speak_exit_and_wait() -> void:
	var keeper := _get_shop_keeper()
	if keeper == null:
		return

	var line := keeper.get_dialogue(keeper.exit_rest_period_dialogues)
	if dialogue_ui == null or line.is_empty():
		return

	await dialogue_ui.show_dialogue_and_wait(keeper.name, line, 1.6)


func _speak_from_pool(pool: ShopKeeperDialoguePool) -> void:
	var keeper := _get_shop_keeper()
	if keeper == null or dialogue_ui == null:
		return

	var line := keeper.get_dialogue(pool)
	if line.is_empty():
		return

	dialogue_ui.show_dialogue(keeper.name, line)


func _get_shop_keeper() -> ShopKeeper:
	if shop == null:
		return null
	return shop.shopkeeper
