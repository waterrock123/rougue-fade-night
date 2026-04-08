class_name SlotButton
extends Button



@onready var slot_background: ColorRect = $SlotBackground
@onready var center_container: CenterContainer = $SlotBackground/CenterContainer

#定义变量，储存格子里的遗物显示节点
var slot_button_slot_relic: RelicUI

func _ready() -> void:
	reset_color()


#重置格子背景的颜色
func reset_color():
	slot_background.color = Color(0.5,0.5,0.5,0.8)
	

#放入函数
func insert(relic_ui:RelicUI):
	slot_button_slot_relic = relic_ui
	slot_background.color = Color(0.402, 0.547, 0.371, 0.8)
	center_container.add_child(slot_button_slot_relic)
	
