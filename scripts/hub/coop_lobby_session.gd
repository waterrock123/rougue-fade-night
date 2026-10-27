## 等候室传输层：名单可靠同步，输入与位移独立通道；客户端不能指定其他玩家身份或坐标。
## @tool用于编辑器内真实回环测试；离线时不创建端口、不读写任何存档。
@tool
class_name CoopLobbySession
extends Node

signal room_changed(snapshot: Dictionary)
signal motion_changed(entries: Array)
signal notice_changed(message: String)

enum Mode { OFFLINE, HOSTING, JOINING, CONNECTED }
var mode: Mode = Mode.OFFLINE
var state: CoopLobbyState = CoopLobbyState.new()
var peer: ENetMultiplayerPeer
var last_notice: String = "创建房间，或输入房主地址加入。"
var room_port: int = CoopLobbyRules.DEFAULT_PORT
var pending_name: String = "旅人"
var pending_character: String = "warrior"
var join_deadline_ms: int = 0
var pending_registrations: Dictionary = {}
var send_elapsed: float = 0.0
var input_sequence: int = 0
var motion_tick: int = 0
var received_motion_tick: int = 0


func host_room(display_name: String, character_id: String, port: int, bind_address: String = "*") -> Error:
	if mode != Mode.OFFLINE:
		return ERR_ALREADY_IN_USE
	if not CoopLobbyRules.valid_port(port) or not CoopLobbyRules.valid_character(character_id):
		return ERR_INVALID_PARAMETER
	_bind_transport_signals()
	var candidate: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	candidate.set_bind_ip(bind_address)
	var error: Error = candidate.create_server(port, CoopLobbyRules.MAX_PLAYERS - 1, 2)
	if error != OK:
		candidate.close()
		_notice("创建失败：%s。请检查端口是否被占用。" % error_string(error))
		return error
	peer = candidate
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOSTING
	room_port = port
	state.add_player(1, display_name, character_id)
	_notice("房间已创建，等待一位队友加入。端口：%d" % port)
	_publish_roster()
	return OK


func join_room(address: String, display_name: String, character_id: String, port: int) -> Error:
	if mode != Mode.OFFLINE:
		return ERR_ALREADY_IN_USE
	if address.strip_edges().is_empty() or address.length() > 253 or not CoopLobbyRules.valid_port(port) or not CoopLobbyRules.valid_character(character_id):
		_notice("请输入有效的地址、端口和角色。")
		return ERR_INVALID_PARAMETER
	_bind_transport_signals()
	var candidate: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = candidate.create_client(address.strip_edges(), port, 2)
	if error != OK:
		candidate.close()
		_notice("无法发起连接：%s" % error_string(error))
		return error
	peer = candidate
	multiplayer.multiplayer_peer = peer
	mode = Mode.JOINING
	room_port = port
	pending_name = CoopLobbyRules.clean_name(display_name)
	pending_character = character_id
	join_deadline_ms = Time.get_ticks_msec() + 10000
	_notice("正在连接房主，可点击取消连接。")
	room_changed.emit({})
	return OK


func leave_room(message: String = "已离开房间，可以重新创建或加入。") -> void:
	# 只关闭自己持有的连接，不能影响将来由其他系统管理的MultiplayerPeer。
	if peer != null:
		if is_inside_tree() and multiplayer.multiplayer_peer == peer:
			multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		peer.close()
	peer = null
	mode = Mode.OFFLINE
	state.clear()
	pending_registrations.clear()
	join_deadline_ms = 0
	send_elapsed = 0.0
	input_sequence = 0
	motion_tick = 0
	received_motion_tick = 0
	_notice(message)
	room_changed.emit({})
	motion_changed.emit([])


func is_in_room() -> bool:
	return mode == Mode.HOSTING or mode == Mode.CONNECTED


func local_peer_id() -> int:
	return multiplayer.get_unique_id() if is_in_room() else 0


func choose_character(character_id: String) -> void:
	if not CoopLobbyRules.valid_character(character_id):
		return
	if mode == Mode.HOSTING and state.choose_character(1, character_id):
		_publish_roster()
	elif mode == Mode.CONNECTED:
		_request_character.rpc_id(1, character_id)


func set_ready(ready: bool) -> void:
	if mode == Mode.HOSTING and state.set_ready(1, ready):
		_publish_roster()
	elif mode == Mode.CONNECTED:
		_request_ready.rpc_id(1, ready)


func submit_input(direction: Vector2) -> void:
	if not is_in_room() or not direction.is_finite():
		return
	input_sequence += 1
	if mode == Mode.HOSTING:
		state.accept_input(1, direction, input_sequence, Time.get_ticks_msec())
	else:
		_request_input.rpc_id(1, direction, input_sequence)


func _bind_transport_signals() -> void:
	if multiplayer.peer_connected.is_connected(_peer_connected):
		return
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	if multiplayer is SceneMultiplayer:
		(multiplayer as SceneMultiplayer).allow_object_decoding = false


func _physics_process(delta: float) -> void:
	if mode == Mode.JOINING and Time.get_ticks_msec() >= join_deadline_ms:
		leave_room("连接超时。请检查房主地址、端口、防火墙及房间是否已满。")
	if mode != Mode.HOSTING:
		return
	_expire_registrations()
	state.advance(delta, Time.get_ticks_msec())
	send_elapsed += delta
	if send_elapsed >= CoopLobbyRules.SYNC_SECONDS:
		send_elapsed = 0.0
		motion_tick += 1
		var entries: Array = state.motion_snapshot()
		motion_changed.emit(entries)
		if not multiplayer.get_peers().is_empty():
			_receive_motion.rpc(entries, motion_tick)


func _expire_registrations() -> void:
	for id: int in pending_registrations.keys():
		if Time.get_ticks_msec() >= int(pending_registrations[id]):
			pending_registrations.erase(id)
			if peer != null and multiplayer.get_peers().has(id):
				peer.disconnect_peer(id)


func _peer_connected(id: int) -> void:
	if mode == Mode.HOSTING:
		pending_registrations[id] = Time.get_ticks_msec() + 5000


func _peer_disconnected(id: int) -> void:
	if mode != Mode.HOSTING:
		return
	pending_registrations.erase(id)
	state.remove_player(id)
	_notice("队友已离开，等待新的队友加入。")
	_publish_roster()


func _connected_to_server() -> void:
	if mode == Mode.JOINING:
		_register_player.rpc_id(1, pending_name, pending_character, CoopLobbyRules.PROTOCOL)


func _connection_failed() -> void:
	if mode == Mode.JOINING:
		leave_room("加入失败。请确认房主在线、地址正确且房间未满。")


func _server_disconnected() -> void:
	if mode in [Mode.JOINING, Mode.CONNECTED]:
		leave_room("房主已离开或连接中断。已安全退出等候室。")


func _publish_roster() -> void:
	var snapshot: Dictionary = state.roster_snapshot()
	room_changed.emit(snapshot)
	if not multiplayer.get_peers().is_empty():
		_receive_roster.rpc(snapshot)


@rpc("any_peer", "call_remote", "reliable", 0)
func _register_player(display_name: String, character_id: String, protocol: int) -> void:
	if mode != Mode.HOSTING:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not pending_registrations.has(sender) or not multiplayer.get_peers().has(sender):
		return
	if protocol != CoopLobbyRules.PROTOCOL or not CoopLobbyRules.valid_character(character_id) or display_name.length() > 80:
		_registration_rejected.rpc_id(sender, "角色数据或联机协议不一致，请使用相同版本。")
		return
	if not state.add_player(sender, display_name, character_id):
		_registration_rejected.rpc_id(sender, "房间已满或玩家已登记。")
		return
	pending_registrations.erase(sender)
	_notice("队友已加入，可以选择角色并准备。")
	_publish_roster()


@rpc("authority", "call_remote", "reliable", 0)
func _registration_rejected(message: String) -> void:
	if mode == Mode.JOINING and multiplayer.get_remote_sender_id() == 1:
		leave_room(message.left(120))


@rpc("authority", "call_remote", "reliable", 0)
func _receive_roster(snapshot: Dictionary) -> void:
	if mode not in [Mode.JOINING, Mode.CONNECTED] or multiplayer.get_remote_sender_id() != 1:
		return
	if not state.apply_roster(snapshot) or not state.players.has(multiplayer.get_unique_id()):
		return
	mode = Mode.CONNECTED
	join_deadline_ms = 0
	_notice("已加入双人等候室。")
	room_changed.emit(state.roster_snapshot())


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_character(character_id: String) -> void:
	if mode == Mode.HOSTING and state.choose_character(multiplayer.get_remote_sender_id(), character_id):
		_publish_roster()


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_ready(ready: bool) -> void:
	if mode == Mode.HOSTING and state.set_ready(multiplayer.get_remote_sender_id(), ready):
		_publish_roster()


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _request_input(direction: Vector2, sequence: int) -> void:
	if mode == Mode.HOSTING:
		state.accept_input(multiplayer.get_remote_sender_id(), direction, sequence, Time.get_ticks_msec())


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_motion(entries: Array, tick: int) -> void:
	if mode != Mode.CONNECTED or multiplayer.get_remote_sender_id() != 1 or tick <= received_motion_tick:
		return
	if state.apply_motion(entries):
		received_motion_tick = tick
		motion_changed.emit(entries)


func _notice(message: String) -> void:
	last_notice = message
	notice_changed.emit(message)


func _exit_tree() -> void:
	leave_room()
