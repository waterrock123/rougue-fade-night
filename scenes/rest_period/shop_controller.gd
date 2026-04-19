class_name ShopController
extends Control


#
@export var run_stats:RunStats
#售卖栏，可以往里面填充shop_equip_button
@onready var EquipContainer:HBoxContainer = %EquipContainer
#获取售卖栏里的格子，接下来会根据shop里的数据更新实际的格子数量
@onready var shop_slots: Array = %EquipContainer.get_children()

@export var shop_config: ShopConfig
@export var shop: Shop

#升级
func level_up():
	var next_level = shop.level + 1
	
	var data = get_level_data(next_level)
	if data == null:
		return
	
	shop.level = next_level
	
	for effect in data.effects:
		effect.apply(shop)




func get_level_data(level: int) -> ShopLevelData:
	for data in shop_config.level_data:
		if data.level == level:
			return data
	return null





#刷新功能：被冻结的商品不会被刷新。用商人的货物里的遗物随机填满格子，遗物的等级不能超过商店的等级
func refresh():
	pass
	
	
