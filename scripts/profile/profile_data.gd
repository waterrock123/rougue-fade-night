class_name ProfileData
extends Resource

## 玩家局外档案：只保存跨局长期进度，绝不混入当前 RunStats。
var completed_event_ids: Array[StringName] = []
var event_completion_counts: Dictionary = {}
var unlocked_content_ids: Array[StringName] = []
var unlocked_modifier_ids: Array[StringName] = []
## 已选择的 NPC 信物。它们属于局外构筑，会在下次新开局时应用。
var equipped_token_modifier_ids: Array[StringName] = []
## 拾荒仓库保存装备快照。每条记录都有独立 entry_id，同种装备也能分别存放。
var relic_warehouse_entries: Array[Dictionary] = []
## 大厅中选定、准备带入下一局的仓库记录。装备仍在仓库中，成功开局时才移除。
var selected_warehouse_entry_id: String = ""
var next_warehouse_entry_index: int = 1
## NPC 服务的跨局计数与交付清单，不与局内检查点混用。
var npc_service_state: Dictionary = {}
## 教学按角色独立记录，完成战狂教学不代表已经练习过浪子或贵人。
var completed_basic_tutorial_character_ids: Array[StringName] = []
## character_id -> 已完成的非基础教学章节id；基础章保留旧字段，兼容已有进度。
var completed_tutorial_chapter_ids: Dictionary = {}


func has_completed_event(event_id: StringName) -> bool:
	return event_id != &"" and completed_event_ids.has(event_id)


func get_event_completion_count(event_id: StringName) -> int:
	return int(event_completion_counts.get(String(event_id), 0))


func record_event_completion(event_id: StringName) -> void:
	if event_id == &"":
		return
	if not completed_event_ids.has(event_id):
		completed_event_ids.append(event_id)
	event_completion_counts[String(event_id)] = get_event_completion_count(event_id) + 1


func unlock_content(content_id: StringName) -> bool:
	if content_id == &"" or unlocked_content_ids.has(content_id):
		return false
	unlocked_content_ids.append(content_id)
	return true


func unlock_modifier(modifier_id: StringName) -> bool:
	if modifier_id == &"" or unlocked_modifier_ids.has(modifier_id):
		return false
	unlocked_modifier_ids.append(modifier_id)
	return true


func to_dictionary() -> Dictionary:
	return {
		"completed_event_ids": _string_name_array_to_strings(completed_event_ids),
		"event_completion_counts": event_completion_counts.duplicate(true),
		"unlocked_content_ids": _string_name_array_to_strings(unlocked_content_ids),
		"unlocked_modifier_ids": _string_name_array_to_strings(unlocked_modifier_ids),
		"equipped_token_modifier_ids": _string_name_array_to_strings(equipped_token_modifier_ids),
		"relic_warehouse_entries": relic_warehouse_entries.duplicate(true),
		"selected_warehouse_entry_id": selected_warehouse_entry_id,
		"next_warehouse_entry_index": next_warehouse_entry_index,
		"npc_service_state": npc_service_state.duplicate(true),
		"completed_basic_tutorial_character_ids": _string_name_array_to_strings(completed_basic_tutorial_character_ids),
		"completed_tutorial_chapter_ids": completed_tutorial_chapter_ids.duplicate(true),
	}


func load_from_dictionary(data: Dictionary) -> void:
	completed_tutorial_chapter_ids = _parse_tutorial_chapters(data.get("completed_tutorial_chapter_ids", {}))
	completed_basic_tutorial_character_ids = _to_string_name_array(data.get("completed_basic_tutorial_character_ids", []))
	var raw_services: Variant = data.get("npc_service_state", {})
	npc_service_state = (raw_services as Dictionary).duplicate(true) if raw_services is Dictionary else {}
	completed_event_ids = _to_string_name_array(data.get("completed_event_ids", []))
	unlocked_content_ids = _to_string_name_array(data.get("unlocked_content_ids", []))
	unlocked_modifier_ids = _to_string_name_array(data.get("unlocked_modifier_ids", []))
	equipped_token_modifier_ids = _to_string_name_array(data.get("equipped_token_modifier_ids", []))
	relic_warehouse_entries = _to_dictionary_array(data.get("relic_warehouse_entries", []))
	# 旧存档没有 locked 字段时默认未锁定，保持向后兼容。
	for index: int in range(relic_warehouse_entries.size()):
		var entry: Dictionary = relic_warehouse_entries[index]
		if not entry.has("locked"):
			entry["locked"] = false
			relic_warehouse_entries[index] = entry
	selected_warehouse_entry_id = str(data.get("selected_warehouse_entry_id", ""))
	next_warehouse_entry_index = max(int(data.get("next_warehouse_entry_index", 1)), 1)
	event_completion_counts.clear()
	var raw_counts: Variant = data.get("event_completion_counts", {})
	if raw_counts is Dictionary:
		for key: Variant in (raw_counts as Dictionary).keys():
			event_completion_counts[str(key)] = int((raw_counts as Dictionary)[key])
	if not has_warehouse_entry(selected_warehouse_entry_id):
		selected_warehouse_entry_id = ""


func _parse_tutorial_chapters(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key: Variant in value:
			if not str(key).is_empty():
				result[str(key)] = _string_name_array_to_strings(_to_string_name_array(value[key]))
	return result


func has_warehouse_entry(entry_id: String) -> bool:
	if entry_id.is_empty():
		return false
	for entry: Dictionary in relic_warehouse_entries:
		if str(entry.get("entry_id", "")) == entry_id:
			return true
	return false


func _to_dictionary_array(values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not values is Array:
		return result
	for value: Variant in values:
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result


func _to_string_name_array(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		for value: Variant in values:
			var id: StringName = StringName(str(value))
			if id != &"" and not result.has(id):
				result.append(id)
	return result


func _string_name_array_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result
