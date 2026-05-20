class_name Inventory
extends Resource


@export var slots: Array[Slot]


# 判断背包里是否还有“正常可用”的空格。
# 锁住的空格不算正常容量，只会在普通格满时作为临时缓冲区使用。
func has_empty_slot() -> bool:
	return _find_empty_slot_index(false) >= 0


# 是否还有空锁格可以作为临时缓冲。
func has_empty_locked_slot() -> bool:
	return _find_empty_slot_index(true) >= 0


# 背包是否存在放在锁格里的临时装备。
func has_locked_items() -> bool:
	for slot_ in slots:
		if slot_ != null and slot_.is_locked and slot_.item != null:
			return true

	return false


# 背包是否能接收这件遗物。
# 普通空格优先；若普通格已满但会立刻合成，也允许接收；最后才使用锁格缓冲。
func can_accept_relic(relic: Relic) -> bool:
	if relic == null:
		return false
	if has_empty_slot():
		return true
	if _can_merge_with_external_relic(relic):
		return true
	if has_empty_locked_slot():
		return true
	return false


# 根据 slot 资源对象移除一个库存格里的装备。
# 这里会保留目标格子的锁定状态，避免拖走锁格装备后锁格变成普通格。
func remove_slot(slot_: Slot) -> void:
	var index_ := slots.find(slot_)
	if index_ < 0:
		return

	var new_slot := Slot.new()
	new_slot.limit_tag = slot_.limit_tag.duplicate()
	new_slot.is_locked = slot_.is_locked
	slots[index_] = new_slot
	EventBus.inventory_update.emit()


# 用传入 slot 的物品填入指定位置，并返回实际承载物品的目标 slot。
# 这里不会直接替换目标 slot 资源，是为了保留锁格、限制标签等格子自身状态。
func insert_slot(slot_index: int, slot_: Slot) -> Slot:
	if slot_index < 0 or slot_index >= slots.size():
		return null

	if slots[slot_index] == null:
		slots[slot_index] = Slot.new()

	var target_slot := slots[slot_index]
	target_slot.item = slot_.item if slot_ != null else null

	if target_slot.item != null:
		_try_merge_levelup_relics(target_slot.item.id)
	EventBus.inventory_update.emit()
	return target_slot


# 将一件遗物放入背包。
# 优先放入正常空格；若正常格已满但可以合成，则直接合成；
# 最后才放入锁格作为临时缓冲，给玩家在修整期里整理背包的余地。
func add_relic(relic: Relic) -> bool:
	if relic == null:
		return false

	if not has_empty_slot() and _can_merge_with_external_relic(relic):
		_merge_with_external_relic(relic)
		EventBus.inventory_update.emit()
		return true

	var empty_index := _find_empty_slot_index(false)
	if empty_index < 0:
		empty_index = _find_empty_slot_index(true)
	if empty_index < 0:
		return false

	var slot_ := slots[empty_index]
	if slot_ == null:
		slot_ = Slot.new()
		slots[empty_index] = slot_

	slot_.item = relic
	_try_merge_levelup_relics(relic.id)
	EventBus.inventory_update.emit()
	return true


# 清理所有锁格中的临时装备。通常在离开修整期时调用。
func clear_locked_items() -> int:
	var cleared_count := 0
	for slot_ in slots:
		if slot_ == null:
			continue
		if not slot_.is_locked:
			continue
		if slot_.item == null:
			continue

		slot_.item = null
		cleared_count += 1

	if cleared_count > 0:
		EventBus.inventory_update.emit()
	return cleared_count


func _find_empty_slot_index(locked_only: bool) -> int:
	for slot_index in range(slots.size()):
		var slot_ := slots[slot_index]
		if slot_ == null:
			if not locked_only:
				return slot_index
			continue
		if slot_.is_locked != locked_only:
			continue
		if slot_.item == null:
			return slot_index

	return -1


# 检查指定 id 的未升级遗物是否达到合成数量，达到后合成为一件升级态遗物。
func _try_merge_levelup_relics(relic_id: String) -> void:
	if relic_id.is_empty():
		return

	while true:
		var matching_indices := _find_mergeable_relic_indices(relic_id)
		if matching_indices.is_empty():
			return

		var base_relic := slots[matching_indices[0]].item
		var upgraded_relic := base_relic.duplicate(true) as Relic
		upgraded_relic.leveltip = Relic.LevelTip.LEVELUP

		# 第一件变成升级态，其余参与合成的格子清空。
		slots[matching_indices[0]].item = upgraded_relic
		for index_position in range(1, matching_indices.size()):
			slots[matching_indices[index_position]].item = null

		EventBus.relic_merged_to_levelup.emit(upgraded_relic)


# 找到一组可以合成的同 id、未升级遗物索引；数量不足时返回空数组。
func _find_mergeable_relic_indices(relic_id: String) -> Array[int]:
	var result: Array[int] = []
	var required_count := 3

	for slot_index in range(slots.size()):
		var slot_ := slots[slot_index]
		if slot_ == null or slot_.item == null:
			continue

		var relic := slot_.item
		if relic.id != relic_id:
			continue
		if relic.leveltip != Relic.LevelTip.UNLEVELUP:
			continue

		if result.is_empty():
			required_count = max(relic.upgrade_merge_count, 2)
		result.append(slot_index)

		if result.size() >= required_count:
			return result

	return []


func _can_merge_with_external_relic(relic: Relic) -> bool:
	if relic == null or relic.leveltip != Relic.LevelTip.UNLEVELUP:
		return false

	var required_count = max(relic.upgrade_merge_count, 2)
	var existing_count := 0
	for slot_ in slots:
		if slot_ == null or slot_.item == null:
			continue
		if slot_.item.id == relic.id and slot_.item.leveltip == Relic.LevelTip.UNLEVELUP:
			existing_count += 1

	return existing_count + 1 >= required_count


# 背包满时使用“外部新获得的遗物”参与合成，不需要先占用一个空格。
func _merge_with_external_relic(relic: Relic) -> void:
	var required_count = max(relic.upgrade_merge_count, 2)
	var matching_indices: Array[int] = []

	for slot_index in range(slots.size()):
		var slot_ := slots[slot_index]
		if slot_ == null or slot_.item == null:
			continue
		if slot_.item.id == relic.id and slot_.item.leveltip == Relic.LevelTip.UNLEVELUP:
			matching_indices.append(slot_index)
		if matching_indices.size() >= required_count - 1:
			break

	if matching_indices.size() < required_count - 1:
		return

	var upgraded_relic := relic.duplicate(true) as Relic
	upgraded_relic.leveltip = Relic.LevelTip.LEVELUP
	slots[matching_indices[0]].item = upgraded_relic

	for index_position in range(1, matching_indices.size()):
		slots[matching_indices[index_position]].item = null

	EventBus.relic_merged_to_levelup.emit(upgraded_relic)
