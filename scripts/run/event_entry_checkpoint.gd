@tool
class_name EventEntryCheckpoint
extends RefCounted
## 冻结入房时的纯存档数据；战斗未胜利前，只允许补记地图模板。

const CHECKPOINT_VERSION: int = 1

var _snapshot: Dictionary = {}


func capture(save_data: Dictionary) -> void:
	_snapshot = save_data.duplicate(true)
	_snapshot["event_checkpoint_version"] = CHECKPOINT_VERSION
	_snapshot["replay_event"] = true


func restore(save_data: Dictionary) -> void:
	capture(save_data)
	var stats: Dictionary = save_data.get("run_stats", {})
	# 旧版入战保存可能已含事件奖励，缺失原始快照时只能续战，不能再领事件奖励。
	var legacy_battle: bool = not save_data.has("event_checkpoint_version") and not str(stats.get("current_battle_map_template_path", "")).is_empty()
	_snapshot["replay_event"] = bool(save_data.get("replay_event", not legacy_battle))


func clear() -> void:
	_snapshot.clear()


func should_replay_event() -> bool:
	return bool(_snapshot.get("replay_event", true))


func build_save_data(room_key: Dictionary, floor_index: int, template_path: String) -> Dictionary:
	if _snapshot.is_empty() or not _matches_room(room_key):
		return {}
	var stats: Dictionary = _snapshot.get("run_stats", {})
	if int(stats.get("current_floor_index", 0)) != floor_index:
		return {}
	var result: Dictionary = _snapshot.duplicate(true)
	if not template_path.is_empty():
		result["run_stats"]["current_battle_map_template_path"] = template_path
	return result


func _matches_room(room_key: Dictionary) -> bool:
	var saved_room: Dictionary = _snapshot.get("current_room", {})
	# JSON 会把数字读成浮点值，不直接比较字典，避免续档后误判检查点失效。
	return not saved_room.is_empty() and not room_key.is_empty() \
		and int(saved_room.get("row", -1)) == int(room_key.get("row", -2)) \
		and int(saved_room.get("column", -1)) == int(room_key.get("column", -2))
