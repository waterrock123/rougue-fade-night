class_name SlotButton
extends Button

signal mouse_button_left_press
signal mouse_button_right_press

@onready var slot_background: ColorRect = $SlotBackground
@onready var center_container: CenterContainer = $SlotBackground/CenterContainer
@onready var disable_icon: TextureRect = $SlotBackground/DisableIcon

# 当前格子关联的背包数据。
var slot_inventory: Inventory
# 当前格子在背包数组中的索引。
var slot_index: int
# 当前格子里的遗物显示节点。
var slot_button_slot_relic: RelicUI
# 只代表这个格子是否被锁住；具体数据来源仍然是 Slot.is_locked。
var slot_locked := false


func _ready() -> void:
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	reset_color()


# 重置格子背景。锁格使用更暗的颜色，避免玩家误以为它是普通空格。
func reset_color():
	if slot_locked:
		slot_background.color = Color(0.24, 0.24, 0.26, 0.72)
	else:
		slot_background.color = Color(0.674, 0.423, 0.271, 1.0)
	tooltip_text = ""


# 设置有物品时的格子视觉。
# 背包刷新锁定状态时也会调用，避免有物品的格子被重置成空格颜色并丢失 tooltip。
func set_occupied_visual() -> void:
	slot_background.color = Color(0.332, 0.455, 0.32, 0.86) if slot_locked else Color(0.402, 0.547, 0.371, 0.8)
	tooltip_text = " "


# 同步数据层的锁定状态到按钮视觉层。
func set_locked_state(locked: bool) -> void:
	slot_locked = locked
	if disable_icon != null:
		disable_icon.visible = locked
	if slot_button_slot_relic != null:
		set_occupied_visual()
	else:
		reset_color()


func is_locked() -> bool:
	return slot_locked


func _make_custom_tooltip(for_text: String) -> Object:
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


# 放入遗物 UI，并把数据同步回背包对应的 Slot。
func insert(relic_ui: RelicUI):
	slot_button_slot_relic = relic_ui
	set_occupied_visual()
	center_container.add_child(slot_button_slot_relic)

	if slot_button_slot_relic.slot_ == null or slot_inventory == null:
		return

	var target_slot := slot_inventory.insert_slot(slot_index, slot_button_slot_relic.slot_)
	if target_slot != null:
		slot_button_slot_relic.slot_ = target_slot


# 抓取格子中的遗物 UI。背包数据会被清空，但格子的锁定状态会保留。
func take_relic():
	var take_relic_ := slot_button_slot_relic
	var source_slot := slot_button_slot_relic.slot_

	center_container.remove_child(slot_button_slot_relic)
	slot_button_slot_relic = null
	reset_color()

	if slot_inventory != null:
		slot_inventory.remove_slot(source_slot)
	return take_relic_


func is_empty():
	return slot_button_slot_relic == null


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			mouse_button_left_press.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			mouse_button_right_press.emit()
