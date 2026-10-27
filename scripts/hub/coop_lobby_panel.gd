## 建房/加入/准备界面与本地输入采集。网络规则交给LobbyNetwork，角色展示交给独立世界。
class_name CoopLobbyPanel
extends Control

signal closed()
var input_elapsed: float = 0.0
var refreshing: bool = false
@onready var nickname: LineEdit = %Nickname
@onready var address: LineEdit = %Address
@onready var port: SpinBox = %Port
@onready var characters: OptionButton = %Characters
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var leave_button: Button = %LeaveButton
@onready var ready_button: Button = %ReadyButton
@onready var back_button: Button = %BackButton
@onready var notice: Label = %Notice
@onready var team_title: Label = %TeamTitle
@onready var team_status: Label = %TeamStatus
@onready var member_one: Label = %MemberOne
@onready var member_two: Label = %MemberTwo
@onready var world: CoopLobbyWorld = %LobbyWorld
@onready var world_viewport: SubViewport = %LobbyViewport


func _ready() -> void:
	world_viewport.world_2d = World2D.new()
	_populate_characters()
	host_button.pressed.connect(_host)
	join_button.pressed.connect(_join)
	leave_button.pressed.connect(_leave)
	back_button.pressed.connect(_close)
	ready_button.toggled.connect(_ready_toggled)
	characters.item_selected.connect(_character_selected)
	LobbyNetwork.room_changed.connect(_refresh)
	LobbyNetwork.notice_changed.connect(_on_notice)
	world.bind_session(LobbyNetwork)
	_on_notice(LobbyNetwork.last_notice)
	_refresh({})


func configure(character: Character, ground_tiles: TileSet) -> void:
	if character != null:
		_select_character(str(character.get_character_id()))
	world.build_floor(ground_tiles)
	back_button.grab_focus()


func _populate_characters() -> void:
	characters.clear()
	for id: String in CoopLobbyRules.CHARACTER_PATHS.keys():
		var data: Character = CoopLobbyRules.get_character(id) as Character
		characters.add_item(data.character_name if data != null else id)
		characters.set_item_metadata(characters.item_count - 1, id)


func _chosen_character() -> String:
	return str(characters.get_item_metadata(characters.selected))


func _select_character(id: String) -> void:
	for index: int in range(characters.item_count):
		if str(characters.get_item_metadata(index)) == id:
			characters.select(index)
			return


func _host() -> void:
	LobbyNetwork.host_room(nickname.text, _chosen_character(), int(port.value))


func _join() -> void:
	LobbyNetwork.join_room(address.text, nickname.text, _chosen_character(), int(port.value))


func _leave() -> void:
	LobbyNetwork.leave_room()


func _ready_toggled(value: bool) -> void:
	if not refreshing:
		LobbyNetwork.set_ready(value)


func _character_selected(_index: int) -> void:
	if not refreshing and LobbyNetwork.is_in_room():
		LobbyNetwork.choose_character(_chosen_character())
	characters.release_focus()


func _refresh(_snapshot: Dictionary) -> void:
	refreshing = true
	var active: bool = LobbyNetwork.is_in_room()
	var offline: bool = LobbyNetwork.mode == CoopLobbySession.Mode.OFFLINE
	var local: Dictionary = LobbyNetwork.state.players.get(LobbyNetwork.local_peer_id(), {})
	var ready: bool = bool(local.get("ready", false))
	nickname.editable = offline
	address.editable = offline
	port.editable = offline
	host_button.disabled = not offline
	join_button.disabled = not offline
	leave_button.disabled = offline
	leave_button.text = "取消连接" if LobbyNetwork.mode == CoopLobbySession.Mode.JOINING else "离开房间"
	characters.disabled = not offline and (not active or ready)
	ready_button.disabled = not active
	ready_button.set_pressed_no_signal(ready)
	ready_button.text = "取消准备" if ready else "准备"
	if not local.is_empty():
		_select_character(str(local["character_id"]))
	team_title.text = "队伍  %d / 2" % LobbyNetwork.state.players.size()
	_refresh_members()
	team_status.text = "双方已准备完成！共斗战斗将在下一阶段接入。" if LobbyNetwork.state.all_ready() else "进入房间后可移动、选择角色并准备。"
	refreshing = false


func _refresh_members() -> void:
	var labels: Array[Label] = [member_one, member_two]
	var ids: Array = LobbyNetwork.state.players.keys()
	ids.sort()
	for index: int in range(labels.size()):
		var label: Label = labels[index]
		if index >= ids.size():
			label.text = "空席位\n等待队友加入"
			label.modulate = Color(0.6, 0.67, 0.75)
			continue
		var id: int = int(ids[index])
		var entry: Dictionary = LobbyNetwork.state.players[id]
		var data: Character = CoopLobbyRules.get_character(str(entry["character_id"])) as Character
		var role: String = "房主" if id == 1 else "队友"
		var own: String = " · 你" if id == LobbyNetwork.local_peer_id() else ""
		label.text = "%s%s · %s\n%s  |  %s" % [role, own, str(entry["name"]), data.character_name, "已准备" if entry["ready"] else "未准备"]
		label.modulate = Color(1, 0.86, 0.5) if entry["ready"] else Color.WHITE


func _on_notice(message: String) -> void:
	notice.text = message


func _physics_process(delta: float) -> void:
	if not LobbyNetwork.is_in_room():
		input_elapsed = 0.0
		return
	input_elapsed += delta
	if input_elapsed < CoopLobbyRules.SYNC_SECONDS:
		return
	input_elapsed = 0.0
	var direction: Vector2 = Vector2.ZERO
	var focus: Control = get_viewport().gui_get_focus_owner()
	if get_window().has_focus() and not focus is LineEdit and not focus is TextEdit:
		direction = Input.get_vector(&"leftmove", &"rightmove", &"upmove", &"downmove")
	LobbyNetwork.submit_input(direction)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	LobbyNetwork.leave_room()
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	if LobbyNetwork.room_changed.is_connected(_refresh):
		LobbyNetwork.room_changed.disconnect(_refresh)
	if LobbyNetwork.notice_changed.is_connected(_on_notice):
		LobbyNetwork.notice_changed.disconnect(_on_notice)
	LobbyNetwork.leave_room()
