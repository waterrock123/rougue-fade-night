## 编辑器模式检查数据、资源绑定及底层ENet回环；不启动游戏，不在辅助SceneTree中测试RPC。
extends SceneTree

var checks: int = 0
var failures: int = 0
var server_peer: ENetMultiplayerPeer
var client_peer: ENetMultiplayerPeer
var test_port: int = 28951


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_state()
	_check_input()
	_check_snapshots()
	_check_session_cleanup()
	_check_scenes()
	await _check_network()
	print("双人等候室编辑器检查：%d项，失败%d项；仅本机回环，未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("等候室检查失败：" + message)


func _pair() -> CoopLobbyState:
	var model: CoopLobbyState = CoopLobbyState.new()
	model.add_player(1, "房主", "warrior")
	model.add_player(22, "队友", "scount")
	return model


func _check_state() -> void:
	var model: CoopLobbyState = CoopLobbyState.new()
	_check(not model.add_player(1, "冒充", "res://project.godot"), "拒绝非白名单角色")
	_check(model.add_player(1, "\n 房主\t ", "warrior"), "允许房主进入")
	_check(model.players[1]["name"] == "房主", "过滤称呼控制字符")
	_check(not model.add_player(1, "重复", "warrior"), "拒绝重复身份")
	model.set_ready(1, true)
	_check(not model.all_ready(), "单人准备不视为队伍就绪")
	_check(not model.choose_character(1, "wizard"), "准备期间不能换角色")
	_check(model.add_player(22, "队友", "wizard"), "第二人登记")
	_check(not model.add_player(33, "第三人", "scount"), "房间最多两人")
	model.set_ready(22, true)
	_check(model.all_ready(), "两人准备才就绪")
	model.remove_player(22)
	_check(model.players.size() == 1 and not model.players[1]["ready"], "队友退出清除房主准备")
	_check(CoopLobbyRules.clean_name("x".repeat(40)).length() == 20, "称呼最多20字")
	_check(not CoopLobbyRules.valid_port(0) and not CoopLobbyRules.valid_port(65536), "端口上下限")


func _check_input() -> void:
	var model: CoopLobbyState = _pair()
	_check(not model.accept_input(99, Vector2.RIGHT, 1, 1000), "未知玩家不能移动")
	_check(not model.accept_input(1, Vector2(NAN, 0), 1, 1000), "拒绝NaN输入")
	_check(not model.accept_input(1, Vector2(INF, 0), 1, 1000), "拒绝无限大输入")
	_check(model.accept_input(1, Vector2(100, 0), 1, 1000), "有效输入归一化")
	_check(not model.accept_input(1, Vector2.LEFT, 1, 1000), "忽略重复输入序号")
	var before: Vector2 = model.players[1]["position"]
	model.advance(1.0, 1000)
	_check(is_equal_approx((model.players[1]["position"] as Vector2).distance_to(before), 7.5), "单帧时间上限防止异常大位移")
	before = model.players[1]["position"]
	model.advance(0.05, 1400)
	_check(model.players[1]["position"] == before, "输入超时自动停步")
	model.players[1]["position"] = Vector2(239, 0)
	model.accept_input(1, Vector2.RIGHT, 2, 1500)
	model.advance(0.05, 1500)
	_check(model.players[1]["position"] == Vector2(240, 0), "房主限制活动边界")


func _check_snapshots() -> void:
	var model: CoopLobbyState = _pair()
	var replica: CoopLobbyState = CoopLobbyState.new()
	_check(replica.apply_roster(model.roster_snapshot()), "名单快照可完整复制")
	_check(not replica.apply_roster(model.roster_snapshot()), "忽略旧名单版本")
	var bad: Dictionary = model.roster_snapshot()
	bad["revision"] += 1
	bad["players"][1]["character_id"] = "unknown"
	_check(not replica.apply_roster(bad) and replica.players[22]["character_id"] == "scount", "无效快照不污染现有数据")
	bad = model.roster_snapshot()
	bad["revision"] += 1
	bad["players"][1]["peer_id"] = 1
	_check(not replica.apply_roster(bad), "拒绝重复名单身份")
	var motion: Array = model.motion_snapshot()
	motion[0]["position"] = Vector2(99999, 0)
	_check(not replica.apply_motion(motion), "拒绝场外坐标")
	_check(replica.apply_motion(model.motion_snapshot()), "普通运动快照有效")


func _check_scenes() -> void:
	var scene: PackedScene = load("res://scenes/hub/coop_lobby_panel.tscn") as PackedScene
	_check(scene != null and scene.can_instantiate(), "界面场景可实例化")
	if scene == null:
		return
	var panel: Node = scene.instantiate()
	for id: String in ["Nickname", "Address", "Port", "Characters", "HostButton", "JoinButton", "LeaveButton", "ReadyButton", "BackButton", "Notice", "TeamTitle", "TeamStatus", "MemberOne", "MemberTwo", "LobbyWorld", "LobbyViewport"]:
		_check(panel.get_node_or_null(NodePath("%" + id)) != null, "界面节点绑定：" + id)
	panel.free()
	var avatar_scene: PackedScene = load("res://scenes/hub/coop_lobby_avatar.tscn") as PackedScene
	var avatar: Node = avatar_scene.instantiate()
	_check(avatar is CharacterBody2D and avatar.get_node_or_null("AnimatedSprite2D") != null, "复用角色外观显示")
	_check(avatar.get("collision_layer") == 0 and avatar.get("collision_mask") == 0, "展示角色不干扰大厅碰撞")
	avatar.free()


func _check_session_cleanup() -> void:
	var session: CoopLobbySession = CoopLobbySession.new()
	_check(session.host_room("旅人", "warrior", 0) == ERR_INVALID_PARAMETER, "会话拒绝无效端口且不绑定网络")
	_check(session.join_room("", "旅人", "warrior", 28080) == ERR_INVALID_PARAMETER, "会话拒绝空地址")
	session.state.add_player(1, "旅人", "warrior")
	session.mode = CoopLobbySession.Mode.HOSTING
	session.pending_registrations[22] = 1234
	session.input_sequence = 10
	session.leave_room()
	_check(session.mode == CoopLobbySession.Mode.OFFLINE and session.state.players.is_empty(), "离开清空会话与名单")
	_check(session.pending_registrations.is_empty() and session.input_sequence == 0, "离开清空握手和输入序列")
	session.mode = CoopLobbySession.Mode.JOINING
	session.join_deadline_ms = 0
	session._physics_process(0.0)
	_check(session.mode == CoopLobbySession.Mode.OFFLINE, "加入超时可安全退出")
	session.free()


func _check_network() -> void:
	server_peer = ENetMultiplayerPeer.new()
	client_peer = ENetMultiplayerPeer.new()
	server_peer.set_bind_ip("127.0.0.1")
	var result: Error = server_peer.create_server(test_port, 1, 2)
	_check(result == OK, "真实ENet房主绑定本机端口")
	if result == OK:
		_check(client_peer.create_client("127.0.0.1", test_port, 2) == OK, "真实ENet发起连接")
		var joined: bool = await _wait_until(func() -> bool: return client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, 4.0)
		_check(joined, "底层ENet握手完成")
		if joined:
			await _check_transport_packets()
	client_peer.close()
	server_peer.close()
	_check(server_peer.create_server(test_port, 1, 2) == OK, "关闭后端口可再次用于建房")
	server_peer.close()


func _wait_until(condition: Callable, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		server_peer.poll()
		client_peer.poll()
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _check_transport_packets() -> void:
	client_peer.set_target_peer(1)
	client_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	client_peer.transfer_channel = 0
	var model: CoopLobbyState = _pair()
	_check(client_peer.put_packet(var_to_bytes(model.roster_snapshot())) == OK, "可靠通道发送名单数据")
	var arrived: bool = await _wait_until(func() -> bool: return server_peer.get_available_packet_count() > 0, 2.0)
	_check(arrived, "本机实际接收名单数据")
	if arrived:
		var payload: Variant = bytes_to_var(server_peer.get_packet())
		var replica: CoopLobbyState = CoopLobbyState.new()
		_check(payload is Dictionary and replica.apply_roster(payload), "经过网络序列化后的名单仍可校验")
	client_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	client_peer.transfer_channel = 1
	_check(client_peer.put_packet(var_to_bytes(model.motion_snapshot())) == OK, "独立通道发送运动数据")
	arrived = await _wait_until(func() -> bool: return server_peer.get_available_packet_count() > 0, 2.0)
	_check(arrived, "本机实际接收运动数据")
	if arrived:
		var motion: Variant = bytes_to_var(server_peer.get_packet())
		_check(motion is Array and model.apply_motion(motion), "运动数据网络往返后仍有效")
