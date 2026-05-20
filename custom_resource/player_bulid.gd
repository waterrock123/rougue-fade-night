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
@export var active_skill_slot_limit: int = 4
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
		return success

	if _can_merge_with_external_relic(relic):
		_merge_with_external_relic(relic)
		return true

	return false


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
		existing.level_up()
		return existing

	var entry := SkillEntry.new()
	entry.skill_data = skill_data
	entry.slot_index = owned_active_skills.size()
	owned_active_skills.append(entry)
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
	if skill_data == null:
		return null

	var existing := find_passive_skill_entry(skill_data.id)
	if existing != null:
		existing.level_up()
		return existing

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
		existing.level = max(existing.level, skill_entry.level)
		existing.is_equipped = existing.is_equipped or skill_entry.is_equipped
		return existing

	skill_entry.slot_index = owned_active_skills.size()
	owned_active_skills.append(skill_entry)
	return skill_entry


# 直接添加已经配置好的被动技能条目，保留它在资源里设置的等级和装备状态。
func _add_passive_skill_entry(skill_entry: SkillEntry) -> SkillEntry:
	var skill_data := skill_entry.skill_data as PassiveSkillData
	if skill_data == null:
		return null

	var existing := find_passive_skill_entry(skill_data.id)
	if existing != null:
		existing.level = max(existing.level, skill_entry.level)
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
	for index in range(owned_active_skills.size()):
		var entry := owned_active_skills[index]
		if entry != null:
			entry.slot_index = index


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
	if relic == null or relic.leveltip != Relic.LevelTip.UNLEVELUP:
		return false

	var required_count = max(relic.upgrade_merge_count, 2)
	var existing_count := 0
	for slot in _get_all_relic_slots():
		if slot == null or slot.item == null:
			continue
		if slot.item.id == relic.id and slot.item.leveltip == Relic.LevelTip.UNLEVELUP:
			existing_count += 1

	return existing_count + 1 >= required_count


func _merge_with_external_relic(relic: Relic) -> void:
	var required_count = max(relic.upgrade_merge_count, 2)
	var matching_slots: Array[Slot] = []

	for slot in _get_all_relic_slots():
		if slot == null or slot.item == null:
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
