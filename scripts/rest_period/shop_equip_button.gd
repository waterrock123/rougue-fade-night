class_name ShopEquipButton
extends Button

signal purchase_requested(slot_index: int)

const NORMAL_MODULATE := Color(1, 1, 1, 1)
const FROZEN_MODULATE := Color(0.6, 0.8, 1.0, 1.0)

@onready var slot_background: ColorRect = $SlotBackground
@onready var center_container: CenterContainer = $SlotBackground/CenterContainer
@onready var clear_label: Label = %ClearLabel
@onready var number_label: Label = %NumberLabel
@onready var gold_icon: TextureRect = $SlotBackground/Glod
@onready var slot_button_slot_relic: RelicUI = $SlotBackground/CenterContainer/RelicUI

var slot_: Slot
var slot_index: int = -1
var is_frozen: bool = false


func _ready() -> void:
	button_mask = MOUSE_BUTTON_MASK_LEFT
	update_button()


# 用一个 slot 数据刷新当前按钮的商品显示。
func set_slot(new_slot: Slot) -> void:
	slot_ = new_slot
	slot_button_slot_relic.slot_ = slot_
	slot_button_slot_relic.slot_relic_update()
	tooltip_text = " " if not is_empty() else ""
	update_button()


# 设置冻结状态并同步显示。
func set_frozen(frozen: bool) -> void:
	is_frozen = frozen
	modulate = FROZEN_MODULATE if is_frozen else NORMAL_MODULATE


# 清空当前格子的商品。
func clear_relic() -> void:
	if slot_ == null:
		slot_ = Slot.new()

	slot_.item = null
	slot_button_slot_relic.slot_ = slot_
	slot_button_slot_relic.slot_relic_update()
	tooltip_text = ""
	update_button()


# 刷新价格、空位提示和图标显示。
func update_button() -> void:
	var relic_data := _get_slot_relic_data()
	if relic_data != null:
		number_label.text = str(relic_data.price)
		number_label.visible = true
		gold_icon.visible = true
		clear_label.visible = false
	else:
		number_label.visible = false
		gold_icon.visible = false
		clear_label.visible = true


func _make_custom_tooltip(_for_text: String) -> Object:
	var relic_data := _get_slot_relic_data()
	if relic_data == null:
		return null

	var tool_tip_panel: RelicToolTip = FloatText.RELIC_TOOL_TIP_PANEL.instantiate()
	tool_tip_panel.set_tool_tip(relic_data)
	return tool_tip_panel


func _get_slot_relic_data() -> Relic:
	if slot_button_slot_relic == null:
		return null
	if slot_button_slot_relic.slot_ == null:
		return null
	return slot_button_slot_relic.slot_.item


func is_empty() -> bool:
	return _get_slot_relic_data() == null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and mouse_event.double_click:
			purchase_requested.emit(slot_index)
