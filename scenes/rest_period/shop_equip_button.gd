class_name ShopEquipButton
extends Button
signal mouse_button_left_press 		#鼠标左键点击信号
signal mouse_button_right_press 		#鼠标右键点击信号

@onready var slot_background: ColorRect = $SlotBackground
@onready var center_container: CenterContainer = $SlotBackground/CenterContainer

@onready var number_label: Label = %NumberLabel
var gold_icon: TextureRect





@onready var slot_button_slot_relic:RelicUI = $SlotBackground/CenterContainer/RelicUI



#储存当前格子关联的商店库存：
var slot_inventory: Equipment



#在库存中的索引
var slot_index: int



func _ready() -> void:
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	
	gold_icon = get_child(0).get_child(0)
	update_button()
	
	
	
#更新价格标签
func update_button():
	if slot_button_slot_relic!=null:
		var relic = slot_button_slot_relic.relic
		number_label.text = str(relic.price)
		number_label.visible = true
		gold_icon.visible = true
	else:
		number_label.visible = false
		gold_icon.visible = false
		
		

	
func _make_custom_tooltip(for_text: String) -> Object:
	var relic_data := _get_slot_relic_data()
	if relic_data == null:
		return null
	
	var tool_tip_panel: RelicToolTip = FloatText.RELIC_TOOL_TIP_PANEL.instantiate()
	tool_tip_panel.set_tool_tip(relic_data.relic_name,relic_data.desc,relic_data.tooltip,relic_data.icon)
	
	return tool_tip_panel


func _get_slot_relic_data() -> Relic:
	if slot_button_slot_relic == null:
		return null
	if slot_button_slot_relic.slot_ == null:
		return null
	return slot_button_slot_relic.slot_.item


func is_empty():
	#判断格子中是否有物品
	return !slot_button_slot_relic


func _on_gui_input(event: InputEvent) -> void:
	pass
