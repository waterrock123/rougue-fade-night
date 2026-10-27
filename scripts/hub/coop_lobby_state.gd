## 等候室纯数据模型，不创建RunStats、不访问局外存档。只有房主推进移动。
@tool
class_name CoopLobbyState
extends RefCounted

var players: Dictionary = {}
var inputs: Dictionary = {}
var revision: int = 0


func clear() -> void:
	players.clear()
	inputs.clear()
	revision = 0


func add_player(peer_id: int, display_name: String, character_id: String) -> bool:
	if peer_id <= 0 or players.has(peer_id) or players.size() >= CoopLobbyRules.MAX_PLAYERS:
		return false
	if not CoopLobbyRules.valid_character(character_id):
		return false
	var spawn: Vector2 = Vector2(-48, 0) if peer_id == 1 else Vector2(48, 0)
	players[peer_id] = {"peer_id": peer_id, "name": CoopLobbyRules.clean_name(display_name), "character_id": character_id, "ready": false, "position": spawn, "movement": Vector2.ZERO, "facing": 1}
	inputs[peer_id] = {"direction": Vector2.ZERO, "sequence": -1, "received_ms": 0}
	revision += 1
	return true


func remove_player(peer_id: int) -> void:
	if not players.has(peer_id):
		return
	players.erase(peer_id)
	inputs.erase(peer_id)
	# 队伍成员变化后需要重新确认，不能沿用上一位队友的准备状态。
	for entry: Dictionary in players.values():
		entry["ready"] = false
	revision += 1


func choose_character(peer_id: int, character_id: String) -> bool:
	if not players.has(peer_id) or not CoopLobbyRules.valid_character(character_id):
		return false
	var entry: Dictionary = players[peer_id]
	if bool(entry["ready"]):
		return false
	if entry["character_id"] == character_id:
		return false
	entry["character_id"] = character_id
	revision += 1
	return true


func set_ready(peer_id: int, ready: bool) -> bool:
	if not players.has(peer_id) or bool(players[peer_id]["ready"]) == ready:
		return false
	players[peer_id]["ready"] = ready
	revision += 1
	return true


func all_ready() -> bool:
	if players.size() != CoopLobbyRules.MAX_PLAYERS:
		return false
	for entry: Dictionary in players.values():
		if not bool(entry["ready"]):
			return false
	return true


func accept_input(peer_id: int, direction: Vector2, sequence: int, now_ms: int) -> bool:
	if not players.has(peer_id) or not direction.is_finite() or sequence < 0 or sequence > 2147483647:
		return false
	var previous: Dictionary = inputs.get(peer_id, {})
	if sequence <= int(previous.get("sequence", -1)):
		return false
	inputs[peer_id] = {"direction": direction.limit_length(1.0), "sequence": sequence, "received_ms": now_ms}
	return true


func advance(delta: float, now_ms: int) -> void:
	var step: float = clampf(delta, 0.0, 0.05)
	for peer_id: int in players.keys():
		var entry: Dictionary = players[peer_id]
		var input: Dictionary = inputs.get(peer_id, {})
		var direction: Vector2 = input.get("direction", Vector2.ZERO)
		if now_ms - int(input.get("received_ms", 0)) > CoopLobbyRules.INPUT_TIMEOUT_MS:
			direction = Vector2.ZERO
		var previous: Vector2 = entry["position"]
		var position: Vector2 = CoopLobbyRules.bounded_position(previous + direction * CoopLobbyRules.MOVE_SPEED * step)
		entry["position"] = position
		entry["movement"] = position - previous
		if not is_zero_approx(direction.x):
			entry["facing"] = -1 if direction.x < 0.0 else 1


func roster_snapshot() -> Dictionary:
	var entries: Array = []
	var ids: Array = players.keys()
	ids.sort()
	for id: int in ids:
		entries.append(players[id].duplicate(true))
	return {"protocol": CoopLobbyRules.PROTOCOL, "revision": revision, "players": entries}


func motion_snapshot() -> Array:
	var result: Array = []
	for entry: Dictionary in players.values():
		result.append({"peer_id": entry["peer_id"], "position": entry["position"], "movement": entry["movement"], "facing": entry["facing"]})
	return result


func apply_roster(payload: Dictionary) -> bool:
	if payload.get("protocol") != CoopLobbyRules.PROTOCOL or typeof(payload.get("revision")) != TYPE_INT:
		return false
	if int(payload["revision"]) <= revision or not payload.get("players") is Array:
		return false
	var entries: Array = payload["players"]
	if entries.is_empty() or entries.size() > CoopLobbyRules.MAX_PLAYERS:
		return false
	var next: Dictionary = {}
	for raw: Variant in entries:
		if not raw is Dictionary or not _valid_entry(raw):
			return false
		var id: int = int(raw["peer_id"])
		if next.has(id):
			return false
		next[id] = {"peer_id": id, "name": CoopLobbyRules.clean_name(str(raw["name"])), "character_id": str(raw["character_id"]), "ready": bool(raw["ready"]), "position": raw["position"], "movement": raw["movement"], "facing": int(raw["facing"])}
	if not next.has(1):
		return false
	players = next
	revision = int(payload["revision"])
	return true


func _valid_entry(entry: Dictionary) -> bool:
	if typeof(entry.get("peer_id")) != TYPE_INT or int(entry["peer_id"]) <= 0:
		return false
	if not entry.get("name") is String or str(entry["name"]).length() > 20:
		return false
	if not entry.get("character_id") is String or not CoopLobbyRules.valid_character(entry["character_id"]):
		return false
	if typeof(entry.get("ready")) != TYPE_BOOL or typeof(entry.get("facing")) != TYPE_INT:
		return false
	return valid_motion(entry)


func valid_motion(entry: Dictionary) -> bool:
	if typeof(entry.get("facing")) != TYPE_INT:
		return false
	if not entry.get("position") is Vector2 or not entry.get("movement") is Vector2:
		return false
	var position: Vector2 = entry["position"]
	var movement: Vector2 = entry["movement"]
	return position.is_finite() and movement.is_finite() and position == CoopLobbyRules.bounded_position(position) and movement.length() <= 8.0 and int(entry.get("facing", 0)) in [-1, 1]


func apply_motion(entries: Array) -> bool:
	if entries.size() > CoopLobbyRules.MAX_PLAYERS:
		return false
	for raw: Variant in entries:
		if not raw is Dictionary or typeof(raw.get("peer_id")) != TYPE_INT or not valid_motion(raw):
			return false
	for raw: Dictionary in entries:
		var id: int = int(raw["peer_id"])
		if players.has(id):
			for key: String in ["position", "movement", "facing"]:
				players[id][key] = raw[key]
	return true
