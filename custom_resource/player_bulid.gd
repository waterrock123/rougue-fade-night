class_name PlayerBuild
extends Resource

# 玩家构筑数据。
# 这份资源用于在战斗场景和修整期之间共享玩家当前的属性、背包、装备和技能状态。
@export var player_stats: StatsData
@export var player_inventory: Inventory
@export var player_equipment: Equipment
@export var current_health: float = 0.0
@export var current_energy: float = 0.0

@export_group("技能构筑")
## Legacy field kept for old saves. It represents the extra active loadout limit.
@export var active_skill_slot_limit: int = 4
@export var active_skill_owned_limit: int = 6
@export var active_skill_equipped_limit: int = 4
@export var passive_skill_slot_limit: int = 2
@export var owned_active_skills: Array[SkillEntry] = []
@export var owned_passive_skills: Array[SkillEntry] = []


# 玩家构筑是否能接收一件遗物：背包有空位，或满背包但会立刻和背包/装备栏里的同 id 遗物合成。
func can_accept_relic(relic: Relic) -> bool:
	if relic == null or player_inventory == null:
		return false

	if player_inventory.can_accept_relic(relic):
		return true

	return _can_merge_with_external_relic(relic)


# 统一获得遗物入口。添加到背包后，立刻用背包+装备栏一起参与合成检测。
func add_relic(relic: Relic) -> bool:
	if relic == null or player_inventory == null:
		return false

	if player_inventory.has_empty_slot() or player_inventory.has_empty_locked_slot():
		var success := player_inventory.add_relic(relic)
		if success:
			AudioController.play_ui_sound(&"get_item")
		check_relic_merges()
		if success:
			# 所有永久获得装备的入口统一通知，供历史教材等装备监听。
			EventBus.relic_added.emit(relic, self)
		return success

	if _can_merge_with_external_relic(relic):
		_merge_with_external_relic(relic)
		EventBus.relic_added.emit(relic, self)
		return true

	return false


# 添加一件临时遗物：优先寻找可用装备栏，装备栏没有空位时再放入背包。
# 这里刻意不调用普通 add_relic 的合成逻辑，避免临时遗物参与合成后变成永久装备。
func add_temporary_relic_to_equipment_or_inventory(relic: Relic) -> bool:
	if relic == null:
		return false

	relic.is_temporary = true
	if not relic.relic_name.begins_with("临时"):
		relic.relic_name = "临时" + relic.relic_name

	if _try_place_temporary_relic_in_equipment(relic):
		AudioController.play_ui_sound(&"get_item")
		EventBus.equipment_update.emit()
		return true

	if _try_place_temporary_relic_in_inventory(relic):
		AudioController.play_ui_sound(&"get_item")
		EventBus.inventory_update.emit()
		return true

	return false


# 战斗结束时删除所有临时遗物，并让装备效果重新计算。
func clear_temporary_relics() -> int:
	var cleared_count: int = 0
	var equipment_changed: bool = false
	var inventory_changed: bool = false

	for slot: Slot in _get_all_relic_slots():
		if slot == null or slot.item == null or not slot.item.is_temporary:
			continue

		EventBus.relic_removed.emit(slot.item, "battle_end")
		slot.item = null
		cleared_count += 1
		if player_equipment != null and player_equipment.equip_slots.has(slot):
			equipment_changed = true
		else:
			inventory_changed = true

	if cleared_count <= 0:
		return 0

	if equipment_changed:
		EventBus.equipment_update.emit()
	if inventory_changed:
		EventBus.inventory_update.emit()
	return cleared_count


func _try_place_temporary_relic_in_equipment(relic: Relic) -> bool:
	if player_equipment == null:
		return false

	for slot_index in range(player_equipment.equip_slots.size()):
		var slot: Slot = player_equipment.equip_slots[slot_index]
		if slot == null:
			slot = Slot.new()
			player_equipment.equip_slots[slot_index] = slot
		if slot.item != null or not _slot_allows_relic(slot, relic):
			continue

		slot.item = relic
		return true

	return false


func _try_place_temporary_relic_in_inventory(relic: Relic) -> bool:
	if player_inventory == null:
		return false

	# 先找普通空格，再找锁格，和普通获得装备的优先级保持一致。
	var locked_passes: Array[bool] = [false, true]
	for locked_only: bool in locked_passes:
		for slot_index in range(player_inventory.slots.size()):
			var slot: Slot = player_inventory.slots[slot_index]
			if slot == null:
				slot = Slot.new()
				player_inventory.slots[slot_index] = slot
			if slot.item != null:
				continue
			if player_inventory.is_slot_locked_for_use(slot_index) != locked_only:
				continue

			slot.item = relic
			return true

	return false


func _slot_allows_relic(slot: Slot, relic: Relic) -> bool:
	if slot == null or relic == null:
		return false

	for blocked_tag: String in slot.limit_tag:
		for relic_tag: RelicTag in relic.tags:
			if relic_tag != null and relic_tag.tag_name == blocked_tag:
				return false

	return true


# 离开修整期时清理锁格中的临时装备。
# 锁格只负责给玩家整理背包的缓冲空间，不会把装备永久带到下一段流程。
func clear_locked_inventory_relics() -> int:
	if player_inventory == null:
		return 0

	var cleared_count := player_inventory.clear_locked_items()
	if cleared_count > 0:
		check_relic_merges()
	return cleared_count


# 统一检测背包和装备栏中的未升级遗物，满足数量时合成一件升级态遗物。
func check_relic_merges() -> void:
	var checked_ids: Array[String] = []
	for slot in _get_all_relic_slots():
		if slot == null or slot.item == null:
			continue
		if checked_ids.has(slot.item.id):
			continue

		checked_ids.append(slot.item.id)
		_try_merge_relic_id(slot.item.id)


# 添加角色起始技能条目；根据 SkillData 类型自动放进主动或被动列表。
func add_start_skill_entry(skill_entry: SkillEntry) -> SkillEntry:
	if skill_entry == null or skill_entry.skill_data == null:
		return null

	if skill_entry.skill_data is ActiveSkillData:
		return _add_active_skill_entry(skill_entry)
	if skill_entry.skill_data is PassiveSkillData:
		return _add_passive_skill_entry(skill_entry)

	push_warning("PlayerBuild 收到未知类型的起始技能：%s" % String(skill_entry.get_skill_id()))
	return null


# 添加一个主动技能条目；如果已经拥有，则只负责升级。
func grant_active_skill(skill_data: ActiveSkillData) -> SkillEntry:
	if skill_data == null:
		return null

	var existing := find_permanent_active_skill_entry(skill_data.id)
	if existing != null:
		return existing
	if not can_add_active_skill(skill_data):
		return null

	var entry := SkillEntry.new()
	entry.skill_data = skill_data
	entry.is_equipped = _is_basic_attack_data(skill_data) or get_equipped_active_skill_count() < get_active_skill_equipped_limit()
	owned_active_skills.append(entry)
	normalize_active_skill_loadout()
	return entry


# 添加一个临时主动技能。
# 装备、事件、状态提供的技能走这里，方便卸下装备或状态结束时精准移除，不污染永久构筑。
func grant_temporary_active_skill(skill_data: ActiveSkillData, source_key: StringName) -> SkillEntry:
	if skill_data == null or source_key == &"":
		return null

	var permanent_existing := find_permanent_active_skill_entry(skill_data.id)
	if permanent_existing != null and not permanent_existing.is_temporary:
		return permanent_existing

	for entry in owned_active_skills:
		if entry == null:
			continue
		if entry.is_temporary and entry.temporary_source_key == source_key:
			return entry

	var entry := SkillEntry.new()
	entry.skill_data = skill_data
	entry.is_temporary = true
	entry.temporary_source_key = source_key
	entry.slot_index = owned_active_skills.size()
	owned_active_skills.append(entry)
	return entry


# 移除指定来源提供的临时主动技能。
func remove_temporary_active_skill(source_key: StringName) -> void:
	if source_key == &"":
		return

	for index in range(owned_active_skills.size() - 1, -1, -1):
		var entry := owned_active_skills[index]
		if entry == null:
			continue
		if entry.is_temporary and entry.temporary_source_key == source_key:
			owned_active_skills.remove_at(index)

	_reindex_active_skill_slots()


# 添加一个被动技能条目；如果已经拥有，则只负责升级。
func grant_passive_skill(skill_data: PassiveSkillData) -> SkillEntry:
	return grant_passive_skill_with_replacement(skill_data)


func grant_passive_skill_with_replacement(
	skill_data: PassiveSkillData,
	replace_skill_id: StringName = &""
) -> SkillEntry:
	if skill_data == null:
		return null

	var existing := find_passive_skill_entry(skill_data.id)
	if existing != null:
		return existing

	if owned_passive_skills.size() >= get_passive_skill_limit():
		var replacement := _find_passive_replacement(replace_skill_id)
		if replacement == null:
			return null
		replacement.skill_data = skill_data
		replacement.level = 1
		return replacement

	var entry := SkillEntry.new()
	entry.skill_data = skill_data
	owned_passive_skills.append(entry)
	return entry


# 直接添加已经配置好的主动技能条目，保留它在资源里设置的等级和装备状态。
func _add_active_skill_entry(skill_entry: SkillEntry) -> SkillEntry:
	var skill_data := skill_entry.skill_data as ActiveSkillData
	if skill_data == null:
		return null

	var existing := find_active_skill_entry(skill_data.id)
	if existing != null:
		existing.is_equipped = existing.is_equipped or skill_entry.is_equipped
		normalize_active_skill_loadout()
		return existing

	skill_entry.is_equipped = _is_basic_attack_data(skill_data) or skill_entry.is_equipped
	owned_active_skills.append(skill_entry)
	normalize_active_skill_loadout()
	return skill_entry


# 直接添加已经配置好的被动技能条目，保留它在资源里设置的等级和装备状态。
func _add_passive_skill_entry(skill_entry: SkillEntry) -> SkillEntry:
	var skill_data := skill_entry.skill_data as PassiveSkillData
	if skill_data == null:
		return null

	var existing := find_passive_skill_entry(skill_data.id)
	if existing != null:
		return existing

	owned_passive_skills.append(skill_entry)
	return skill_entry


func find_active_skill_entry(skill_id: StringName) -> SkillEntry:
	return _find_skill_entry(owned_active_skills, skill_id)


func find_permanent_active_skill_entry(skill_id: StringName) -> SkillEntry:
	for entry in owned_active_skills:
		if entry != null and not entry.is_temporary and entry.get_skill_id() == skill_id:
			return entry
	return null


func find_passive_skill_entry(skill_id: StringName) -> SkillEntry:
	return _find_skill_entry(owned_passive_skills, skill_id)


func _find_skill_entry(entries: Array[SkillEntry], skill_id: StringName) -> SkillEntry:
	for entry in entries:
		if entry != null and entry.get_skill_id() == skill_id:
			return entry

	return null


func _reindex_active_skill_slots() -> void:
	normalize_active_skill_loadout()


func can_add_active_skill(skill_data: ActiveSkillData = null) -> bool:
	if skill_data != null and find_permanent_active_skill_entry(skill_data.id) != null:
		return true
	return get_owned_active_skill_count() < get_active_skill_owned_limit()


func get_owned_active_skill_count() -> int:
	var result: int = 0
	for entry: SkillEntry in owned_active_skills:
		if entry == null or entry.is_temporary or _is_basic_attack_entry(entry):
			continue
		result += 1
	return result


func get_active_skill_owned_limit() -> int:
	return max(active_skill_owned_limit, 0)


func get_active_skill_equipped_limit() -> int:
	# 兼容旧资源中手动设置的 active_skill_slot_limit。
	if active_skill_equipped_limit == 4 and active_skill_slot_limit != 4:
		return max(active_skill_slot_limit, 0)
	return max(active_skill_equipped_limit, 0)


func get_passive_skill_limit() -> int:
	return max(passive_skill_slot_limit, 0)


func get_equipped_active_skill_count() -> int:
	var result: int = 0
	for entry: SkillEntry in owned_active_skills:
		if entry == null or not entry.is_equipped:
			continue
		if entry.is_temporary or _is_basic_attack_entry(entry):
			continue
		result += 1
	return result


func get_equipped_active_skill_entries() -> Array[SkillEntry]:
	var result: Array[SkillEntry] = []
	var basic_entries: Array[SkillEntry] = []
	var normal_entries: Array[SkillEntry] = []
	var temporary_entries: Array[SkillEntry] = []

	for entry: SkillEntry in owned_active_skills:
		if entry == null or not entry.is_equipped:
			continue
		if _is_basic_attack_entry(entry):
			basic_entries.append(entry)
		elif entry.is_temporary:
			temporary_entries.append(entry)
		else:
			normal_entries.append(entry)

	for entry: SkillEntry in basic_entries:
		result.append(entry)

	var carried_count: int = 0
	for entry: SkillEntry in normal_entries:
		if carried_count >= get_active_skill_equipped_limit():
			break
		result.append(entry)
		carried_count += 1

	for entry: SkillEntry in temporary_entries:
		result.append(entry)

	for index in range(result.size()):
		result[index].slot_index = index
	return result


func set_active_skill_equipped(entry: SkillEntry, should_equip: bool) -> bool:
	if entry == null or entry.is_temporary or not owned_active_skills.has(entry):
		return false
	if _is_basic_attack_entry(entry):
		entry.is_equipped = true
		return true
	if should_equip and not entry.is_equipped and get_equipped_active_skill_count() >= get_active_skill_equipped_limit():
		return false
	entry.is_equipped = should_equip
	normalize_active_skill_loadout()
	return true


func normalize_active_skill_loadout() -> void:
	var carried_count: int = 0
	for entry: SkillEntry in owned_active_skills:
		if entry == null:
			continue
		if _is_basic_attack_entry(entry) or entry.is_temporary:
			entry.is_equipped = true
			continue
		if entry.is_equipped:
			if carried_count >= get_active_skill_equipped_limit():
				entry.is_equipped = false
			else:
				carried_count += 1

	get_equipped_active_skill_entries()


func evolve_skill_entry(entry: SkillEntry, target_skill_data: SkillData) -> bool:
	if entry == null or target_skill_data == null:
		return false
	return entry.evolve_to(target_skill_data)


func _find_passive_replacement(skill_id: StringName) -> SkillEntry:
	if skill_id != &"":
		var requested: SkillEntry = find_passive_skill_entry(skill_id)
		if requested != null:
			return requested
	if owned_passive_skills.is_empty():
		return null
	return owned_passive_skills[0]


func _is_basic_attack_entry(entry: SkillEntry) -> bool:
	return entry != null and _is_basic_attack_data(entry.skill_data as ActiveSkillData)


func _is_basic_attack_data(skill_data: ActiveSkillData) -> bool:
	if skill_data == null:
		return false
	return skill_data.is_basic_attack or skill_data.id == &"101"


func _try_merge_relic_id(relic_id: String) -> void:
	if relic_id.is_empty():
		return

	while true:
		var matching_slots := _find_mergeable_slots(relic_id)
		if matching_slots.is_empty():
			return

		var base_relic := matching_slots[0].item
		var upgraded_relic := base_relic.duplicate(true) as Relic
		upgraded_relic.leveltip = Relic.LevelTip.LEVELUP

		# 第一件变成升级态，其余参与合成的格子清空。装备栏中的遗物也会参与。
		matching_slots[0].item = upgraded_relic
		for index in range(1, matching_slots.size()):
			matching_slots[index].item = null

		EventBus.relic_merged_to_levelup.emit(upgraded_relic)
		AudioController.play_ui_sound(&"level_up_item")
		EventBus.inventory_update.emit()
		EventBus.equipment_update.emit()


func _find_mergeable_slots(relic_id: String) -> Array[Slot]:
	var result: Array[Slot] = []
	var required_count := 3

	for slot in _get_all_relic_slots():
		if slot == null or slot.item == null:
			continue

		var relic := slot.item
		if relic.is_temporary:
			continue
		if relic.id != relic_id:
			continue
		if relic.leveltip != Relic.LevelTip.UNLEVELUP:
			continue

		if result.is_empty():
			required_count = max(relic.upgrade_merge_count, 2)
		result.append(slot)

		if result.size() >= required_count:
			return result

	return []


func _get_all_relic_slots() -> Array[Slot]:
	var result: Array[Slot] = []
	# 装备栏优先参与排序；如果装备中的遗物参与合成，升级态会保留在装备栏位置。
	if player_equipment != null:
		for slot in player_equipment.equip_slots:
			result.append(slot)

	if player_inventory != null:
		for slot in player_inventory.slots:
			result.append(slot)

	return result


func _can_merge_with_external_relic(relic: Relic) -> bool:
	if relic == null or relic.is_temporary or relic.leveltip != Relic.LevelTip.UNLEVELUP:
		return false

	var required_count = max(relic.upgrade_merge_count, 2)
	var existing_count := 0
	for slot in _get_all_relic_slots():
		if slot == null or slot.item == null:
			continue
		if slot.item.is_temporary:
			continue
		if slot.item.id == relic.id and slot.item.leveltip == Relic.LevelTip.UNLEVELUP:
			existing_count += 1

	return existing_count + 1 >= required_count


func _merge_with_external_relic(relic: Relic) -> void:
	if relic == null or relic.is_temporary:
		return

	var required_count = max(relic.upgrade_merge_count, 2)
	var matching_slots: Array[Slot] = []

	for slot in _get_all_relic_slots():
		if slot == null or slot.item == null:
			continue
		if slot.item.is_temporary:
			continue
		if slot.item.id == relic.id and slot.item.leveltip == Relic.LevelTip.UNLEVELUP:
			matching_slots.append(slot)
		if matching_slots.size() >= required_count - 1:
			break

	if matching_slots.size() < required_count - 1:
		return

	var upgraded_relic := relic.duplicate(true) as Relic
	upgraded_relic.leveltip = Relic.LevelTip.LEVELUP
	matching_slots[0].item = upgraded_relic

	for index in range(1, matching_slots.size()):
		matching_slots[index].item = null

	EventBus.relic_merged_to_levelup.emit(upgraded_relic)
	AudioController.play_ui_sound(&"level_up_item")
	EventBus.inventory_update.emit()
	EventBus.equipment_update.emit()
