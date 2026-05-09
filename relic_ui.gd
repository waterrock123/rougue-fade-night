class_name RelicUI
extends Control

@export var relic: Relic : set = set_relic

@onready var icon: TextureRect = $Icon
@onready var level_icon: TextureRect = $LevelupTip
@onready var relic_type_icon: TextureRect = $RelicType
@onready var sell_box: Control = _find_sell_box()
@onready var sell_label: Label = _find_sell_label()

# 定义：存储当前物品对应的库存格子数据。
var slot_: Slot = null


func set_relic(new_relic: Relic) -> void:
	if not is_node_ready():
		await ready

	relic = new_relic
	_refresh_display()


# 物品显示更新函数，同步库存格子数据到图标。
func slot_relic_update() -> void:
	if slot_ == null:
		set_relic(null)
		return

	set_relic(slot_.item)


# 所有可视状态都集中在这里刷新，避免复用 RelicUI 时残留上一个物品的显示状态。
func _refresh_display() -> void:
	if relic == null:
		icon.texture = null
		icon.visible = false
		level_icon.modulate = Color.WHITE
		level_icon.visible = false
		relic_type_icon.visible = false
		_update_sell_label()
		hide_sell_price()
		return

	icon.texture = relic.icon
	icon.visible = true

	level_icon.modulate = Relic.LEVEL_TIP_COLORS[relic.leveltip]
	level_icon.visible = true

	relic_type_icon.visible = relic.relic_type != Relic.RelicType.COMMON
	_update_sell_label()
	hide_sell_price()


# 拖到商店金币区域时显示出售价格。
func show_sell_price(price: int) -> void:
	if sell_label != null:
		sell_label.text = str(price)
	if sell_box != null:
		sell_box.show()


func hide_sell_price() -> void:
	if sell_box != null:
		sell_box.hide()


func _update_sell_label() -> void:
	if sell_label == null:
		return
	if relic == null:
		sell_label.text = ""
	else:
		sell_label.text = str(relic.sell_price)


func _find_sell_box() -> Control:
	var node := get_node_or_null("UISellBox") as Control
	if node != null:
		return node
	return get_node_or_null("Sellbox") as Control


func _find_sell_label() -> Label:
	if sell_box == null:
		return null

	var label := sell_box.get_node_or_null("SellLabel") as Label
	if label != null:
		return label

	return sell_box.find_child("SellLabel", true, false) as Label
