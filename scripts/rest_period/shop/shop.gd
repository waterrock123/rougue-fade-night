class_name Shop
extends Resource

# 商店的当前状态数据。
@export var level: int = 1
@export var slot_count: int = 4
@export var current_slot: Array[Slot] = []
@export var frozen_slots: Array[bool] = []
@export var shopkeeper: ShopKeeper


# 保证 current_slot 的长度和 slot_count 一致。
func ensure_slot_count() -> void:
	while current_slot.size() < slot_count:
		current_slot.append(Slot.new())

	while current_slot.size() > slot_count:
		current_slot.pop_back()

	while frozen_slots.size() < slot_count:
		frozen_slots.append(false)

	while frozen_slots.size() > slot_count:
		frozen_slots.pop_back()


# 查询某个商店格是否被冻结。
func is_slot_frozen(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= frozen_slots.size():
		return false
	return frozen_slots[slot_index]


# 设置单个商店格冻结状态。
func set_slot_frozen(slot_index: int, frozen: bool) -> void:
	ensure_slot_count()
	if slot_index < 0 or slot_index >= frozen_slots.size():
		return
	frozen_slots[slot_index] = frozen


# 解除所有冻结。主动刷新时会使用它，让刷新优先级高于冻结。
func clear_all_frozen() -> void:
	ensure_slot_count()
	for index in range(frozen_slots.size()):
		frozen_slots[index] = false
