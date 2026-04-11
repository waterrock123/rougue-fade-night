class_name  Equipment
extends Resource


#装格子的数组
@export var equip_slots: Array[Slot]



#装备物品函数
func equip(slot_index:int,slot_:Slot):
	
	equip_slots[slot_index] = slot_
	
	#发送装备更新信号
	EventBus.equipment_update.emit()
	
	

#卸下物品函数
func unequip(slot_:Slot):
	
	
	#搜寻当前库存格子在数组里的索引
	var index_ = equip_slots.find(slot_)
	
	
	if index_ < 0: return
	#将此索引格赋值为新的空格子
	equip_slots[index_] = Slot.new()
	#发送装备更新信号
	EventBus.equipment_update.emit()
	
	
	
