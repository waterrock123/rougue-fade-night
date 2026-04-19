class_name RelicUI
extends Control

@export var relic: Relic : set = set_relic

@onready var icon: TextureRect = $Icon
@onready var level_icon:TextureRect = $LevelupTip
@onready var relic_type_icon:TextureRect = $RelicType
#定义：存储当前物品对应的库存格子数据
var slot_:Slot = null





func set_relic(new_relic: Relic) -> void:
	if not is_node_ready():
		await ready

	relic = new_relic
	if relic == null:
		icon.texture = null
		icon.visible = false
		level_icon.visible = false
		return
	icon.texture = relic.icon
	level_icon.modulate = Relic.LEVEL_TIP_COLORS[relic.leveltip]
	if relic.relic_type == Relic.RelicType.COMMON:
		relic_type_icon.visible = false
	icon.visible = true

#物品显示更新函数(同步库存数据到图标)
func slot_relic_update():
	if !slot_ or !slot_.item:
		relic = null
		icon.texture = null
		icon.visible = false
		return
	relic = slot_.item
	icon.visible = true
	icon.texture = slot_.item.icon
	level_icon.modulate = Relic.LEVEL_TIP_COLORS[relic.leveltip]
