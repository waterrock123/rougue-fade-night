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


# 背包是否能接收这件遗物：有空格可以接收；满格时如果会立即触发合成，也允许接收。
func can_accept_relic(relic: Relic) -> bool:
	if relic == null:
		return false
	if has_empty_slot():
		return true
	return _can_merge_with_external_relic(relic)


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
	if slot_ != null and slot_.item != null:
		_try_merge_levelup_relics(slot_.item.id)
	EventBus.inventory_update.emit()


# 将一个遗物放入库存中索引最小的空位。
# 成功返回 true，失败返回 false。
func add_relic(relic: Relic) -> bool:
	if relic == null:
		return false

	if not has_empty_slot() and _can_merge_with_external_relic(relic):
		_merge_with_external_relic(relic)
		EventBus.inventory_update.emit()
		return true

	for slot_index in range(slots.size()):
		var slot_ := slots[slot_index]
		if slot_ == null:
			slot_ = Slot.new()
			slots[slot_index] = slot_

		if slot_.item == null:
			slot_.item = relic
			_try_merge_levelup_relics(relic.id)
			EventBus.inventory_update.emit()
			return true

	return false


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
			slots[matching_indices[index_position]] = Slot.new()

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
		slots[matching_indices[index_position]] = Slot.new()

	EventBus.relic_merged_to_levelup.emit(upgraded_relic)
