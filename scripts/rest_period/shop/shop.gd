class_name Shop
extends Resource

# 商店的当前状态数据。
@export var level: int = 1
@export var slot_count: int = 4
@export var current_slot: Array[Slot] = []
@export var shopkeeper: ShopKeeper


# 保证 current_slot 的长度和 slot_count 一致。
func ensure_slot_count() -> void:
	while current_slot.size() < slot_count:
		current_slot.append(Slot.new())

	while current_slot.size() > slot_count:
		current_slot.pop_back()
