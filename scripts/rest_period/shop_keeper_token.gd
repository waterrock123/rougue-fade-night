class_name ShopKeeperUI
extends Control

@export var run_stats: RunStats
@export var shop: Shop

@onready var glod_label: Label = %GoldLabel
@onready var level_label: Label = %LevelLabel
@onready var shop_keeper_texture: TextureRect = %ShopKeeperTexture


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
