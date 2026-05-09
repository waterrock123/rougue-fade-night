class_name SlotButton
extends Button

signal mouse_button_left_press 		#鼠标左键点击信号
signal mouse_button_right_press 		#鼠标右键点击信号

@onready var slot_background: ColorRect = $SlotBackground
@onready var center_container: CenterContainer = $SlotBackground/CenterContainer

#储存当前格子关联的库存：Inventory
var slot_inventory: Inventory



#在库存中的索引
var slot_index: int

#定义变量，储存格子里的遗物显示节点
var slot_button_slot_relic: RelicUI




func _ready() -> void:
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT
	reset_color()


#重置格子背景的颜色
func reset_color():
	slot_background.color = Color(0.674, 0.423, 0.271, 1.0)
	tooltip_text = ""
	
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
#放入函数
func insert(relic_ui:RelicUI):
	#把传入的物品显示节点赋值当前格子变量，记录当前格子有物品
	slot_button_slot_relic = relic_ui
	
	slot_background.color = Color(0.402, 0.547, 0.371, 0.8)
	tooltip_text = " "
	#把物品显示节点添加到居中容器中
	center_container.add_child(slot_button_slot_relic)
	
	if !slot_button_slot_relic.slot_:
		return
	#调用库存的insert_slot函数，同步插入物品到库存
	slot_inventory.insert_slot(slot_index,slot_button_slot_relic.slot_)
	
	
#（核心）抓取物品函数，被bag_ui脚本调用，取出格子里的物品
func take_relic():
	#记录抓取物品
	var take_relic_ = slot_button_slot_relic 
	var source_slot := slot_button_slot_relic.slot_
	
	# 先从格子里摘下 UI，再改库存数据；否则 inventory_update 会把正在拿起的 RelicUI 清理掉。
	center_container.remove_child(slot_button_slot_relic)
	#把当前格子的物品节点设为null，重置格子状态
	slot_button_slot_relic = null
	
	#重置颜色
	reset_color()
	#对格子对应的库存位置清空
	slot_inventory.remove_slot(source_slot)
	return take_relic_


func is_empty():
	#判断格子中是否有物品
	return !slot_button_slot_relic


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			
			mouse_button_left_press.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			mouse_button_right_press.emit()
