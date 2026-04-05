class_name RelicUI
extends Control

@export var relic: Relic : set = set_relic

@onready var icon: TextureRect = $Icon

#定义：存储当前物品对应的库存格子数据
var slot_:Slot

func set_relic(new_relic: Relic) -> void:
	if not is_node_ready():
		await ready

	relic = new_relic
	icon.texture = relic.icon

#物品显示更新函数(同步库存数据到图标)
func slot_relic_update():
	if !slot_ or !slot_.item:
		return
	icon.visible = true
	icon.texture = slot_.item.icon
