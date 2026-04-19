class_name ShopInventory
extends Resource



@export var equip_slots: Array[Slot]


#移除商店库存函数
func remove_slot(slot_:Slot):
	#搜寻当前库存格子在数组里的索引
	var index_ = equip_slots.find(slot_)
	
	
	if index_ < 0: return
	#将此索引格赋值为新的空格子
	equip_slots[index_] = Slot.new()
	EventBus.shop_inventory_update.emit()
	#发送库存更新信号
	
	
#插入商店库存函数
func insert_slot(slot_index:int,slot_:Slot):
	#核心：把传入物品的格子数据赋值给slots数组中指定索引位置
	equip_slots[slot_index] = slot_
	#发送库存更新信号
	EventBus.shop_inventory_update.emit()
	
#添加商店库存的函数:在商店库存中额外多添加一个格子
func add_slot():
	var slot_ = Slot.new()
	equip_slots.append(slot_)
	EventBus.shop_inventory_update.emit()
	

	
	
	
