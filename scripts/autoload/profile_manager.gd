extends Node

## 局外档案总控：保存事件、解锁内容和永久修正器，不与单局继续存档混用。
signal profile_loaded(profile_data: ProfileData)
signal profile_saved()
signal profile_event_completed(event_id: StringName, event_data: ProfileEventData)
signal profile_content_unlocked(content_id: StringName)
signal profile_modifier_unlocked(modifier_id: StringName)
signal equipped_tokens_changed(token_ids: Array[StringName])
signal relic_warehouse_changed()

const PROFILE_PATH: String = "user://profile.json"
const PROFILE_VERSION: int = 3
const EVENT_DATABASE: ProfileEventDatabase = preload("res://resource/profile/profile_event_database.tres")
const MODIFIER_DATABASE: ProfileModifierDatabase = preload("res://resource/profile/profile_modifier_database.tres")
const DEFAULT_RELIC_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")
const PRIMARY_STAT_NAMES: Array[StringName] = [&"strength", &"dexterity", &"intelligence", &"constitution", &"speed", &"charm", &"luck"]
## 每局可携带的局外信物上限。后续可由局外等级、事件或难度规则调整。
const MAX_EQUIPPED_TOKENS: int = 3
const SCAVENGER_WAREHOUSE_CONTENT_ID: StringName = &"scavenger_warehouse"
const CARRY_PENALTY_START_LEVEL: int = 3
const CARRY_PENALTY_PER_LEVEL: float = 0.05
const CARRY_PENALTY_MAXIMUM: float = 0.30
const WAREHOUSE_BASE_CAPACITY: int = 8
const WAREHOUSE_UPGRADE_CAPACITY: int = 16
const WAREHOUSE_UPGRADE_CONTENT_ID: StringName = &"warehouse_capacity_upgrade_1"

var profile_data: ProfileData = ProfileData.new()
## 仓库装备只在档案变更后重新反序列化，避免每次打开大厅面板都深拷贝整套效果资源。
var warehouse_relic_cache: Dictionary = {}


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	profile_data = ProfileData.new()
	warehouse_relic_cache.clear()
	if not FileAccess.file_exists(PROFILE_PATH):
		profile_loaded.emit(profile_data)
		return
	var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("无法读取局外档案：%s" % PROFILE_PATH)
		profile_loaded.emit(profile_data)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		profile_data.load_from_dictionary(parsed as Dictionary)
	profile_loaded.emit(profile_data)


func save_profile() -> bool:
	var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入局外档案：%s" % PROFILE_PATH)
		return false
	var data: Dictionary = profile_data.to_dictionary()
	data["version"] = PROFILE_VERSION
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	profile_saved.emit()
	return true


func has_completed_event(event_id: StringName) -> bool:
	return profile_data != null and profile_data.has_completed_event(event_id)


func has_completed_basic_tutorial(character_id: StringName) -> bool:
	return profile_data != null and profile_data.completed_basic_tutorial_character_ids.has(character_id)


## 只记录教学完成，不触发局外事件奖励、解锁、仓库回收或冒险存档写入。
func record_basic_tutorial_completion(character_id: StringName) -> bool:
	if character_id == &"" or profile_data == null:
		return false
	if has_completed_basic_tutorial(character_id):
		return true
	profile_data.completed_basic_tutorial_character_ids.append(character_id)
	if save_profile():
		return true
	profile_data.completed_basic_tutorial_character_ids.erase(character_id)
	return false


func has_completed_tutorial_chapter(character_id: StringName, chapter_id: StringName) -> bool:
	if chapter_id == &"basic":
		return has_completed_basic_tutorial(character_id)
	if profile_data == null or character_id == &"" or chapter_id == &"":
		return false
	var chapters: Array = profile_data.completed_tutorial_chapter_ids.get(String(character_id), [])
	return chapters.has(String(chapter_id))


## 章节进度独立写入局外档案，失败时回滚，不触发任何奖励或解锁。
func record_tutorial_chapter_completion(character_id: StringName, chapter_id: StringName) -> bool:
	if chapter_id == &"basic":
		return record_basic_tutorial_completion(character_id)
	if profile_data == null or character_id == &"" or chapter_id == &"":
		return false
	if has_completed_tutorial_chapter(character_id, chapter_id):
		return true
	var previous: Dictionary = profile_data.completed_tutorial_chapter_ids.duplicate(true)
	var chapters: Array = previous.get(String(character_id), []).duplicate()
	chapters.append(String(chapter_id))
	profile_data.completed_tutorial_chapter_ids[String(character_id)] = chapters
	if save_profile():
		return true
	profile_data.completed_tutorial_chapter_ids = previous
	return false


func is_relic_warehouse_unlocked() -> bool:
	return profile_data != null and profile_data.unlocked_content_ids.has(SCAVENGER_WAREHOUSE_CONTENT_ID)


func get_relic_warehouse_capacity() -> int:
	if profile_data != null and profile_data.unlocked_content_ids.has(WAREHOUSE_UPGRADE_CONTENT_ID):
		return WAREHOUSE_UPGRADE_CAPACITY
	return WAREHOUSE_BASE_CAPACITY


func is_relic_warehouse_full() -> bool:
	return profile_data != null and profile_data.relic_warehouse_entries.size() >= get_relic_warehouse_capacity()


## 返回仓库当前还能存放多少件装备。
func get_relic_warehouse_free_slots() -> int:
	if profile_data == null:
		return 0
	return max(get_relic_warehouse_capacity() - profile_data.relic_warehouse_entries.size(), 0)


## 收集玩家装备栏与背包中的全部非临时装备，供死亡回收和胜利结算共用。
func get_recoverable_relics_from_build(player_build: PlayerBuild) -> Array[Relic]:
	return _collect_recoverable_relics(player_build)


## 将一组装备作为一次事务写入局外仓库。
## 只有全部装备都能序列化且容量足够时才会落盘，保存失败会完整回滚。
func store_relics_in_warehouse(relics: Array[Relic]) -> bool:
	if profile_data == null:
		return false

	var valid_relics: Array[Relic] = []
	var serialized_relics: Array[Dictionary] = []
	for relic: Relic in relics:
		if relic == null or relic.is_temporary:
			continue
		var relic_data: Dictionary = SaveManager.serialize_relic_for_profile(relic)
		if relic_data.is_empty():
			push_warning("胜利装备无法写入仓库：%s" % relic.relic_name)
			return false
		valid_relics.append(relic)
		serialized_relics.append(relic_data)

	if valid_relics.is_empty():
		return true
	if valid_relics.size() > get_relic_warehouse_free_slots():
		return false

	var previous_entry_count: int = profile_data.relic_warehouse_entries.size()
	var previous_next_index: int = profile_data.next_warehouse_entry_index
	var recovered_at: int = int(Time.get_unix_time_from_system())
	for relic_data: Dictionary in serialized_relics:
		var entry_id: String = "warehouse_%d" % profile_data.next_warehouse_entry_index
		profile_data.next_warehouse_entry_index += 1
		profile_data.relic_warehouse_entries.append({
			"entry_id": entry_id,
			"relic": relic_data,
			"recovered_at": recovered_at,
			"locked": false,
		})

	if not save_profile():
		profile_data.relic_warehouse_entries.resize(previous_entry_count)
		profile_data.next_warehouse_entry_index = previous_next_index
		return false

	relic_warehouse_changed.emit()
	return true


## 装备结算时提交玩家选择的最终仓库内容，胜利与死亡保护共用。
## 原仓库条目会保留自己的 id、锁定状态和获取时间，新装备才会创建新条目。
func replace_warehouse_after_victory(
	kept_entry_ids: Array[String],
	victory_relics: Array[Relic]
) -> bool:
	if profile_data == null:
		return false

	var unique_kept_ids: Array[String] = []
	for entry_id: String in kept_entry_ids:
		if entry_id.is_empty() or unique_kept_ids.has(entry_id):
			continue
		if _find_warehouse_entry_index(entry_id) < 0:
			return false
		unique_kept_ids.append(entry_id)

	# 锁定装备属于玩家明确保护的内容，胜利结算不能绕过锁定将其丢弃。
	for entry: Dictionary in profile_data.relic_warehouse_entries:
		var entry_id: String = str(entry.get("entry_id", ""))
		if bool(entry.get("locked", false)) and not unique_kept_ids.has(entry_id):
			return false

	var serialized_victory_relics: Array[Dictionary] = []
	for relic: Relic in victory_relics:
		if relic == null or relic.is_temporary:
			return false
		var relic_data: Dictionary = SaveManager.serialize_relic_for_profile(relic)
		if relic_data.is_empty():
			return false
		serialized_victory_relics.append(relic_data)

	if unique_kept_ids.size() + serialized_victory_relics.size() > get_relic_warehouse_capacity():
		return false

	var previous_entries: Array[Dictionary] = profile_data.relic_warehouse_entries.duplicate(true)
	var previous_selected_id: String = profile_data.selected_warehouse_entry_id
	var previous_next_index: int = profile_data.next_warehouse_entry_index
	var final_entries: Array[Dictionary] = []
	for entry: Dictionary in profile_data.relic_warehouse_entries:
		if unique_kept_ids.has(str(entry.get("entry_id", ""))):
			final_entries.append(entry.duplicate(true))

	var recovered_at: int = int(Time.get_unix_time_from_system())
	for relic_data: Dictionary in serialized_victory_relics:
		var entry_id: String = "warehouse_%d" % profile_data.next_warehouse_entry_index
		profile_data.next_warehouse_entry_index += 1
		final_entries.append({
			"entry_id": entry_id,
			"relic": relic_data,
			"recovered_at": recovered_at,
			"locked": false,
		})

	profile_data.relic_warehouse_entries = final_entries
	if not unique_kept_ids.has(profile_data.selected_warehouse_entry_id):
		profile_data.selected_warehouse_entry_id = ""
	if not save_profile():
		profile_data.relic_warehouse_entries = previous_entries
		profile_data.selected_warehouse_entry_id = previous_selected_id
		profile_data.next_warehouse_entry_index = previous_next_index
		return false

	relic_warehouse_changed.emit()
	return true


## 死亡时从背包和装备栏随机回收一件非临时装备。
func recover_random_relic_from_build(player_build: PlayerBuild) -> Relic:
	if not is_relic_warehouse_unlocked() or player_build == null or is_relic_warehouse_full():
		return null
	var candidates: Array[Relic] = _collect_recoverable_relics(player_build)
	if candidates.is_empty():
		return null
	var recovered: Relic = candidates.pick_random()
	var relic_data: Dictionary = SaveManager.serialize_relic_for_profile(recovered)
	if relic_data.is_empty():
		return null
	var entry_id: String = "warehouse_%d" % profile_data.next_warehouse_entry_index
	profile_data.next_warehouse_entry_index += 1
	profile_data.relic_warehouse_entries.append({
		"entry_id": entry_id,
		"relic": relic_data,
		"recovered_at": int(Time.get_unix_time_from_system()),
		"locked": false,
	})
	if not save_profile():
		profile_data.relic_warehouse_entries.pop_back()
		profile_data.next_warehouse_entry_index -= 1
		return null
	relic_warehouse_changed.emit()
	return recovered


func get_warehouse_entries() -> Array[Dictionary]:
	return profile_data.relic_warehouse_entries.duplicate(true) if profile_data != null else []


## 自动消耗、随机献祭等系统只能从此列表选择，锁定装备不会进入候选池。
func get_unlocked_warehouse_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in get_warehouse_entries():
		if not bool(entry.get("locked", false)):
			result.append(entry)
	return result


func get_warehouse_relic(entry_id: String) -> Relic:
	var cached_relic: Relic = warehouse_relic_cache.get(entry_id) as Relic
	if cached_relic != null:
		return cached_relic
	var entry: Dictionary = _find_warehouse_entry(entry_id)
	if entry.is_empty():
		return null
	var relic: Relic = SaveManager.deserialize_relic_from_profile(entry.get("relic", {}) as Dictionary)
	if relic != null:
		warehouse_relic_cache[entry_id] = relic
	return relic


func get_selected_warehouse_entry_id() -> String:
	return profile_data.selected_warehouse_entry_id if profile_data != null else ""


func get_selected_warehouse_relic() -> Relic:
	return get_warehouse_relic(get_selected_warehouse_entry_id())


func is_warehouse_entry_locked(entry_id: String) -> bool:
	var entry: Dictionary = _find_warehouse_entry(entry_id)
	return not entry.is_empty() and bool(entry.get("locked", false))


## 锁定状态属于局外存档。保存失败时回滚，避免界面状态与磁盘数据不一致。
func set_warehouse_entry_locked(entry_id: String, locked: bool) -> bool:
	if profile_data == null:
		return false
	var entry_index: int = _find_warehouse_entry_index(entry_id)
	if entry_index < 0:
		return false
	var entry: Dictionary = profile_data.relic_warehouse_entries[entry_index]
	var previous_locked: bool = bool(entry.get("locked", false))
	if previous_locked == locked:
		return true
	entry["locked"] = locked
	profile_data.relic_warehouse_entries[entry_index] = entry
	if not save_profile():
		entry["locked"] = previous_locked
		profile_data.relic_warehouse_entries[entry_index] = entry
		return false
	relic_warehouse_changed.emit()
	return true


func select_warehouse_entry(entry_id: String) -> bool:
	if profile_data == null or (not entry_id.is_empty() and not profile_data.has_warehouse_entry(entry_id)):
		return false
	var previous_id: String = profile_data.selected_warehouse_entry_id
	profile_data.selected_warehouse_entry_id = entry_id
	var saved: bool = save_profile()
	if saved:
		relic_warehouse_changed.emit()
	else:
		profile_data.selected_warehouse_entry_id = previous_id
	return saved


## 主动丢弃仓库装备；若它正在大厅背包中，也同步取消携带。
func discard_warehouse_entry(entry_id: String) -> bool:
	if profile_data == null:
		return false
	if is_warehouse_entry_locked(entry_id):
		return false
	var entry_index: int = _find_warehouse_entry_index(entry_id)
	if entry_index < 0:
		return false
	var removed_entry: Dictionary = profile_data.relic_warehouse_entries[entry_index]
	var previous_selected_id: String = profile_data.selected_warehouse_entry_id
	profile_data.relic_warehouse_entries.remove_at(entry_index)
	if previous_selected_id == entry_id:
		profile_data.selected_warehouse_entry_id = ""
	if not save_profile():
		profile_data.relic_warehouse_entries.insert(entry_index, removed_entry)
		profile_data.selected_warehouse_entry_id = previous_selected_id
		return false
	warehouse_relic_cache.erase(entry_id)
	relic_warehouse_changed.emit()
	return true


## 用同等阶随机装备替换仓库中的一条记录；保留记录编号与获取时间，便于 UI 继续选中。
func exchange_warehouse_relic(entry_id: String, replacement: Relic) -> bool:
	if profile_data == null or replacement == null or is_warehouse_entry_locked(entry_id):
		return false
	var entry_index: int = _find_warehouse_entry_index(entry_id)
	if entry_index < 0:
		return false
	var replacement_data: Dictionary = SaveManager.serialize_relic_for_profile(replacement)
	if replacement_data.is_empty():
		return false
	var entry: Dictionary = profile_data.relic_warehouse_entries[entry_index]
	var previous_relic_data: Dictionary = (entry.get("relic", {}) as Dictionary).duplicate(true)
	entry["relic"] = replacement_data
	profile_data.relic_warehouse_entries[entry_index] = entry
	if not save_profile():
		entry["relic"] = previous_relic_data
		profile_data.relic_warehouse_entries[entry_index] = entry
		return false
	# 同一个 entry_id 已经换成另一件装备，必须清掉旧缓存。
	warehouse_relic_cache.erase(entry_id)
	relic_warehouse_changed.emit()
	return true


## 剧情或机关成功完成后消耗当前携带装备；复用仓库删除事务，失败时会自动回滚。
func consume_selected_warehouse_relic_for_event() -> bool:
	var entry_id: String = get_selected_warehouse_entry_id()
	if entry_id.is_empty() or is_warehouse_entry_locked(entry_id):
		return false
	return discard_warehouse_entry(entry_id)


## 携带仓库装备完成一局时记录实验结果；中途出售装备不会影响该标记。
func record_warehouse_field_test_if_needed(run_stats: RunStats) -> void:
	if run_stats == null or run_stats.carried_relic_name.is_empty():
		return
	if not has_completed_event(&"warehouse_upgrade_plan_started"):
		return
	try_complete_event(&"warehouse_relic_field_test_complete")


## 第一次赠送佳肴后，只要完成一次冒险，无论胜败都推进“食欲无边”。
func record_appetite_adventure_if_needed() -> void:
	if not has_completed_event(&"appetite_first_cuisine_gift"):
		return
	if has_completed_event(&"appetite_gift_adventure_complete"):
		return
	try_complete_event(&"appetite_gift_adventure_complete")


## 新局创建时才真正把携带装备从仓库转入构筑，续档和训练场不会调用这里。
func consume_selected_relic_for_new_run(run_stats: RunStats) -> Relic:
	if run_stats == null or run_stats.player_build == null or profile_data == null:
		return null
	var entry_id: String = profile_data.selected_warehouse_entry_id
	var relic: Relic = get_warehouse_relic(entry_id)
	if relic == null or not run_stats.player_build.add_relic(relic):
		return null
	_apply_carried_relic_penalty(run_stats, relic)
	_remove_warehouse_entry(entry_id)
	profile_data.selected_warehouse_entry_id = ""
	save_profile()
	warehouse_relic_cache.erase(entry_id)
	relic_warehouse_changed.emit()
	return relic


func get_carry_penalty_rate(relic: Relic) -> float:
	if relic == null or relic.level < CARRY_PENALTY_START_LEVEL:
		return 0.0
	return min(float(relic.level - CARRY_PENALTY_START_LEVEL + 1) * CARRY_PENALTY_PER_LEVEL, CARRY_PENALTY_MAXIMUM)


func _collect_recoverable_relics(player_build: PlayerBuild) -> Array[Relic]:
	var result: Array[Relic] = []
	if player_build.player_equipment != null:
		_append_relics_from_slots(result, player_build.player_equipment.equip_slots)
	if player_build.player_inventory != null:
		_append_relics_from_slots(result, player_build.player_inventory.slots)
	return result


func _append_relics_from_slots(result: Array[Relic], slots: Array[Slot]) -> void:
	for slot: Slot in slots:
		if slot != null and slot.item != null and not slot.item.is_temporary:
			result.append(slot.item)


func _find_warehouse_entry(entry_id: String) -> Dictionary:
	if profile_data == null or entry_id.is_empty():
		return {}
	for entry: Dictionary in profile_data.relic_warehouse_entries:
		if str(entry.get("entry_id", "")) == entry_id:
			return entry
	return {}


func _find_warehouse_entry_index(entry_id: String) -> int:
	if profile_data == null or entry_id.is_empty():
		return -1
	for index: int in range(profile_data.relic_warehouse_entries.size()):
		if str(profile_data.relic_warehouse_entries[index].get("entry_id", "")) == entry_id:
			return index
	return -1


func _remove_warehouse_entry(entry_id: String) -> void:
	for index: int in range(profile_data.relic_warehouse_entries.size() - 1, -1, -1):
		if str(profile_data.relic_warehouse_entries[index].get("entry_id", "")) == entry_id:
			profile_data.relic_warehouse_entries.remove_at(index)
			return


func _apply_carried_relic_penalty(run_stats: RunStats, relic: Relic) -> void:
	var rate: float = get_carry_penalty_rate(relic)
	run_stats.carried_relic_name = relic.relic_name
	run_stats.carried_relic_penalty_rate = rate
	if rate <= 0.0 or run_stats.player_build.player_stats == null:
		return
	var stats: StatsData = run_stats.player_build.player_stats
	var old_health: float = stats.base_max_health + float(stats.constitution) * 5.0
	var old_energy: float = stats.base_max_energy + float(stats.intelligence) * 3.0
	stats.base_max_health = max(old_health * (1.0 - rate) - float(stats.constitution) * 5.0, 1.0)
	stats.base_max_energy = max(old_energy * (1.0 - rate) - float(stats.intelligence) * 3.0, 1.0)
	run_stats.player_build.current_health = stats.base_max_health + float(stats.constitution) * 5.0
	run_stats.player_build.current_energy = stats.base_max_energy + float(stats.intelligence) * 3.0


## UI 与大厅可通过此接口读取事件标题和描述，避免各处重复维护事件文案。
func get_event_data(event_id: StringName) -> ProfileEventData:
	return EVENT_DATABASE.find_event(event_id)


## 图鉴仅展示已完成事件，顺序与事件数据库一致，便于手动安排剧情阅读顺序。
func get_completed_events() -> Array[ProfileEventData]:
	var result: Array[ProfileEventData] = []
	for event_id: StringName in EVENT_DATABASE.get_event_ids():
		var event_data: ProfileEventData = EVENT_DATABASE.find_event(event_id)
		if event_data != null and event_data.show_in_codex and has_completed_event(event_data.event_id):
			result.append(event_data)
	return result


func get_equippable_tokens() -> Array[ProfileModifierData]:
	if profile_data == null:
		return []
	return MODIFIER_DATABASE.get_equippable_tokens(profile_data.unlocked_modifier_ids)


func get_equipped_token_ids() -> Array[StringName]:
	if profile_data == null:
		return []
	return profile_data.equipped_token_modifier_ids.duplicate()


## 保存玩家本次选择的信物构筑；无效、未解锁或超上限的 ID 会被自动过滤。
func set_equipped_token_ids(requested_ids: Array[StringName]) -> void:
	if profile_data == null:
		return
	var valid_ids: Array[StringName] = []
	for modifier_id: StringName in requested_ids:
		if valid_ids.size() >= MAX_EQUIPPED_TOKENS or valid_ids.has(modifier_id):
			continue
		var modifier_data: ProfileModifierData = MODIFIER_DATABASE.find_modifier(modifier_id)
		if modifier_data == null:
			continue
		if modifier_data.activation_mode != ProfileModifierData.ActivationMode.EQUIPPABLE_TOKEN:
			continue
		if profile_data.unlocked_modifier_ids.has(modifier_id):
			valid_ids.append(modifier_id)
	profile_data.equipped_token_modifier_ids = valid_ids
	save_profile()
	equipped_tokens_changed.emit(valid_ids.duplicate())


func are_events_completed(event_ids: Array[StringName]) -> bool:
	for event_id: StringName in event_ids:
		if not has_completed_event(event_id):
			return false
	return true


func try_complete_event(event_id: StringName, released_warehouse_slots: int = 0) -> bool:
	var event_data: ProfileEventData = EVENT_DATABASE.find_event(event_id)
	if event_data == null:
		push_warning("未在局外事件数据库中找到事件：%s" % event_id)
		return false
	if not event_data.repeatable and has_completed_event(event_id):
		return false
	if not are_events_completed(event_data.required_completed_event_ids):
		return false
	if not _can_receive_event_warehouse_rewards(event_data, released_warehouse_slots):
		return false

	profile_data.record_event_completion(event_id)
	for content_id: StringName in event_data.unlock_content_ids:
		if profile_data.unlock_content(content_id):
			profile_content_unlocked.emit(content_id)
	for modifier_id: StringName in event_data.unlock_modifier_ids:
		if profile_data.unlock_modifier(modifier_id):
			profile_modifier_unlocked.emit(modifier_id)
	var granted_warehouse_rewards: int = _grant_event_warehouse_rewards(event_data)
	save_profile()
	if granted_warehouse_rewards > 0:
		relic_warehouse_changed.emit()
	profile_event_completed.emit(event_id, event_data)
	return true


func _can_receive_event_warehouse_rewards(event_data: ProfileEventData, released_warehouse_slots: int = 0) -> bool:
	if event_data == null or event_data.warehouse_relic_reward_count <= 0:
		return true
	if not is_relic_warehouse_unlocked():
		return false
	var free_slots: int = get_relic_warehouse_capacity() - profile_data.relic_warehouse_entries.size() + max(released_warehouse_slots, 0)
	if free_slots < event_data.warehouse_relic_reward_count:
		return false
	return not DEFAULT_RELIC_POOL.get_relics_by_level(event_data.warehouse_relic_reward_level).is_empty()


func _grant_event_warehouse_rewards(event_data: ProfileEventData) -> int:
	if event_data == null or event_data.warehouse_relic_reward_count <= 0:
		return 0
	var candidates: Array[Relic] = DEFAULT_RELIC_POOL.get_relics_by_level(event_data.warehouse_relic_reward_level)
	if candidates.is_empty():
		return 0
	var granted_count: int = 0
	for _index: int in range(event_data.warehouse_relic_reward_count):
		var reward: Relic = candidates.pick_random() as Relic
		if reward == null:
			continue
		var relic_data: Dictionary = SaveManager.serialize_relic_for_profile(reward.duplicate(true) as Relic)
		if relic_data.is_empty():
			continue
		var entry_id: String = "warehouse_%d" % profile_data.next_warehouse_entry_index
		profile_data.next_warehouse_entry_index += 1
		profile_data.relic_warehouse_entries.append({
			"entry_id": entry_id,
			"relic": relic_data,
			"recovered_at": int(Time.get_unix_time_from_system()),
			"locked": false,
		})
		granted_count += 1
	return granted_count


## 新局创建后统一应用自动生效奖励与本次携带的信物，避免污染角色原始资源。
func apply_new_run_modifiers(run_stats: RunStats) -> void:
	if run_stats == null or profile_data == null:
		return
	for modifier_id: StringName in profile_data.unlocked_modifier_ids:
		var modifier_data: ProfileModifierData = MODIFIER_DATABASE.find_modifier(modifier_id)
		if modifier_data == null or modifier_data.activation_mode != ProfileModifierData.ActivationMode.PERMANENT:
			continue
		_apply_modifier(run_stats, modifier_data)
	for modifier_id: StringName in profile_data.equipped_token_modifier_ids:
		var token_data: ProfileModifierData = MODIFIER_DATABASE.find_modifier(modifier_id)
		if token_data != null and token_data.activation_mode == ProfileModifierData.ActivationMode.EQUIPPABLE_TOKEN:
			_apply_modifier(run_stats, token_data)


func _apply_modifier(run_stats: RunStats, modifier_data: ProfileModifierData) -> void:
	match modifier_data.modifier_type:
		ProfileModifierData.ModifierType.PRIMARY_STAT:
			_apply_primary_stat_modifier(run_stats, modifier_data)
		ProfileModifierData.ModifierType.STARTING_GOLD:
			run_stats.set_gold(run_stats.gold + roundi(modifier_data.amount))


func _apply_primary_stat_modifier(run_stats: RunStats, modifier_data: ProfileModifierData) -> void:
	if run_stats.player_build == null or run_stats.player_build.player_stats == null:
		return
	if not PRIMARY_STAT_NAMES.has(modifier_data.stat_name):
		push_warning("局外修正器使用了不支持的一级属性：%s" % modifier_data.stat_name)
		return
	var stats: StatsData = run_stats.player_build.player_stats
	var current_value: int = int(stats.get(String(modifier_data.stat_name)))
	stats.set(String(modifier_data.stat_name), current_value + roundi(modifier_data.amount))
