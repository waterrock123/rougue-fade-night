class_name Inventory
extends Resource




#装格子的数组
@export var slots: Array[Slot]

#移除库存各种物品的函数
func remove_slot(slot_:Slot):
	#搜寻当前库存格子在数组里的索引
	var index_ = slots.find(slot_)
	
	
	if index_ < 0: return
	#将此索引格赋值为新的空格子
	slots[index_] = Slot.new()
	
	#发送库存更新信号
	EventBus.inventory_update.emit()
	
#插入物品函数，背包UI放入物品时，调用这个函数更新库存
func insert_slot(slot_index:int,slot_:Slot):
	#核心：把传入物品的格子数据赋值给slots数组中指定索引位置
	slots[slot_index] = slot_
	#发送库存更新信号
	EventBus.inventory_update.emit()
	
	
	
	
	
	
	
	
	
