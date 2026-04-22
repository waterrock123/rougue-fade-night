class_name Inventory
extends Resource


@export var slots: Array[Slot]


# 判断库存里是否还有空位。
func has_empty_slot() -> bool:
	for slot_ in slots:
		if slot_ == null:
			return true
		if slot_.item == null:
			return true

	return false


# 根据 slot 资源对象移除一个库存格。
func remove_slot(slot_: Slot) -> void:
	var index_ := slots.find(slot_)
	if index_ < 0:
		return

	slots[index_] = Slot.new()
	EventBus.inventory_update.emit()


# 用指定 slot 数据覆盖某个库存位置。
func insert_slot(slot_index: int, slot_: Slot) -> void:
	slots[slot_index] = slot_
	EventBus.inventory_update.emit()


# 将一个遗物放入库存中索引最小的空位。
# 成功返回 true，失败返回 false。
func add_relic(relic: Relic) -> bool:
	if relic == null:
		return false

	for slot_index in range(slots.size()):
		var slot_ := slots[slot_index]
		if slot_ == null:
			slot_ = Slot.new()
			slots[slot_index] = slot_

		if slot_.item == null:
			slot_.item = relic
			EventBus.inventory_update.emit()
			return true

	return false
