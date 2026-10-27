class_name MainHomeMap
extends Node2D

## 局外大厅地图的总控脚本。
## 大厅不创建 RunStats，也不承载战斗、商店或修整期数据；它只提供局外移动、入口和 NPC 的容器。

signal hub_portal_requested(portal_id: StringName)
## 功能 NPC 播完对白后统一抛出，后续剧情、任务和场景机关都可订阅此信号。
signal hub_npc_interaction_completed(npc_id: StringName, event_id: StringName)

const PORTAL_SINGLE_RUN: StringName = &"single_run"
const PORTAL_LOBBY: StringName = &"lobby"
const PORTAL_TRAINING: StringName = &"training"
const COOP_LOBBY_PANEL: PackedScene = preload("res://scenes/hub/coop_lobby_panel.tscn")
const TUTORIAL_CHAPTER_PANEL: PackedScene = preload("res://scenes/hub/tutorial_chapter_panel.tscn")
const DEPARTURE_PANEL: PackedScene = preload("res://scenes/hub/hub_departure_panel.tscn")
const RUN_SCENE_PATH: String = "res://scenes/run/run.tscn"
const CHARACTER_NPC_SCENE: PackedScene = preload("res://scenes/hub/hub_character_npc.tscn")
const HUB_NPC_SCENE: PackedScene = preload("res://scenes/hub/hub_npc.tscn")
const PICTORIAL_BOOK_SCENE: PackedScene = preload("res://scenes/ui/pictorial_book.tscn")
const SPEAK_UI_SCENE: PackedScene = preload("res://speak_ui.tscn")
const RELIC_WAREHOUSE_PANEL_SCENE: PackedScene = preload("res://scenes/hub/relic_warehouse_panel.tscn")
const ANTIQUE_TRADE_PANEL_SCENE: PackedScene = preload("res://scenes/hub/antique_trade_panel.tscn")
const ARCHIVIST_INTERACTION: HubNpcInteractionData = preload("res://resource/hub_npc/archivist_interaction.tres")
const LOST_RECORDER_INTERACTION: HubNpcInteractionData = preload("res://resource/hub_npc/lost_recorder_interaction.tres")
const ANTIQUE_CLERK_INTERACTION: HubNpcInteractionData = preload("res://resource/hub_npc/antique_clerk_interaction.tres")
const ZHANG_SAN_INTERACTION: HubNpcInteractionData = preload("res://resource/hub_npc/zhang_san_interaction.tres")

@export_group("角色驻点")
## 与驻点按索引配对，可增加更多角色；路径为空时使用 NpcContainer 下的 Marker2D。
@export var npc_characters: Array[Character] = [preload("res://character_resource/warrior/warrior.tres"), preload("res://character_resource/scount/scount.tres"), preload("res://character_resource/wizard/wizard.tres")]
@export var npc_marker_paths: Array[NodePath] = []
@export var character_interact_action: StringName = &"ui_accept"

@export_group("功能 NPC")
## 请在 NpcContainer 下添加 ArchivistMarker 后填写此路径；未配置时档案管理员不会生成。
@export var archivist_marker_path: NodePath = NodePath("NpcContainer/ArchivistMarker")
## 迷途记录员是普通剧情 NPC 样例，只播放一次初见对白并发出剧情事件。
@export var lost_recorder_marker_path: NodePath = NodePath("NpcContainer/LostRecorderMarker")
## 古董店女店员会在玩家认识迷途记录员后出现，是事件前置解锁的样例 NPC。
@export var antique_clerk_marker_path: NodePath = NodePath("NpcContainer/AntiqueClerkMarker")
@export var zhang_san_marker_path: NodePath = NodePath("NpcContainer/ZhangSanMarker")
## 设施齐备后显示的装饰实例由你在场景中布置，美术未配置时保持空容器。
@export var improved_facilities_path: NodePath = NodePath("ImprovedFacilities")

## 角色选择场景切换到大厅时暂存的数据。
## 大厅接收后只读取角色外观，真正创建 RunStats 仍应由单人入口或多人房主开始游戏时完成。
static var pending_startup: RunStartup

@export_group("节点路径")
@export var player_spawn_path: NodePath = NodePath("SpawnPoints/PlayerSpawn")
@export var hub_player_path: NodePath = NodePath("HubPlayer")

@onready var player_spawn: Marker2D = get_node_or_null(player_spawn_path) as Marker2D
@onready var hub_player: HubPlayer = get_node_or_null(hub_player_path) as HubPlayer
@onready var status_label: Label = $HubUI/StatusLabel
@onready var hub_ui: CanvasLayer = $HubUI
@onready var event_notice_label: Label = $HubUI/EventNoticeLabel
@onready var hub_backpack_button: Button = $HubUI/HubBackpackButton
@onready var tutorial_button: Button = $HubUI/TutorialButton

var startup: RunStartup
var departure_panel: ConfirmationDialog
var departing: bool = false
var character_npcs: Array[HubCharacterNpc] = []
var character_dialog: ConfirmationDialog
var requested_character: Character
var focused_npc: HubCharacterNpc
var hub_npcs: Array[HubNpc] = []
var focused_hub_npc: HubNpc
var pictorial_book: PictorialBook
var speak_ui: SpeakUi
var active_speaking_npc: HubNpc
var hub_controls_enabled: bool = true
var exit_dialog: ConfirmationDialog
var relic_warehouse_panel: RelicWarehousePanel
var antique_trade_panel: AntiqueTradePanel
var coop_lobby_panel: CoopLobbyPanel
var tutorial_chapter_panel: TutorialChapterPanel


func _ready() -> void:
	add_to_group("hub_world")
	_receive_startup()
	_spawn_hub_player()
	_connect_portals()
	_create_character_npcs()
	_create_function_npcs()
	hub_backpack_button.visible = ProfileManager.is_relic_warehouse_unlocked()
	hub_backpack_button.pressed.connect(_open_relic_warehouse)
	tutorial_button.pressed.connect(_open_basic_tutorial)
	_show_status("主大厅已就绪：靠近入口后按空格交互。")
	call_deferred("_warm_warehouse_relic_cache")


## 将仓库装备的深度反序列化拆到多个空闲帧，避免首次点击大厅背包时集中卡顿。
func _warm_warehouse_relic_cache() -> void:
	if not ProfileManager.is_relic_warehouse_unlocked():
		return
	for entry: Dictionary in ProfileManager.get_warehouse_entries():
		if not is_inside_tree():
			return
		ProfileManager.get_warehouse_relic(str(entry.get("entry_id", "")))
		await get_tree().process_frame


## 入口的具体跳转暂时由此处统一占位，避免未来改联机流程时修改多个入口脚本。
func _on_hub_portal_activated(portal_id: StringName) -> void:
	if departing or not hub_controls_enabled:
		return
	hub_portal_requested.emit(portal_id)
	match portal_id:
		PORTAL_SINGLE_RUN:
			_open_departure_panel()
		PORTAL_LOBBY:
			_open_coop_lobby()
		PORTAL_TRAINING:
			TrainingRoom.selected_character = hub_player.character
			get_tree().change_scene_to_file("res://scenes/hub/training_room.tscn")
		_:
			_show_status("入口尚未配置：%s" % portal_id)


## 等候室独立承载联机状态；打开期间隔离大厅输入，不创建或修改单人存档。
func _open_coop_lobby() -> void:
	if is_instance_valid(coop_lobby_panel):
		return
	_set_hub_controls_enabled(false)
	coop_lobby_panel = COOP_LOBBY_PANEL.instantiate() as CoopLobbyPanel
	hub_ui.add_child(coop_lobby_panel)
	coop_lobby_panel.closed.connect(_on_coop_lobby_closed)
	var ground: TileMapLayer = get_node_or_null("GroundLayer") as TileMapLayer
	coop_lobby_panel.configure(hub_player.character, ground.tile_set if ground != null else null)


func _on_coop_lobby_closed() -> void:
	coop_lobby_panel = null
	if not departing:
		_set_hub_controls_enabled(true)


## 独立教学入口始终携带大厅当前角色，不把新手教学伪装成正式开局。
func _open_basic_tutorial() -> void:
	if departing or not hub_controls_enabled or hub_player == null or hub_player.character == null:
		return
	_set_hub_controls_enabled(false)
	tutorial_chapter_panel = TUTORIAL_CHAPTER_PANEL.instantiate() as TutorialChapterPanel
	hub_ui.add_child(tutorial_chapter_panel)
	tutorial_chapter_panel.configure(hub_player.character)
	tutorial_chapter_panel.chapter_requested.connect(_enter_tutorial_chapter)
	tutorial_chapter_panel.closed.connect(_on_tutorial_chapters_closed)


func _enter_tutorial_chapter(chapter: TutorialChapterData) -> void:
	if departing or chapter == null or not is_instance_valid(tutorial_chapter_panel):
		return
	# 两章共用训练容器的角色入口，不通过正式 RunStartup 开局或消费仓库。
	var previous_character: Character = TrainingRoom.selected_character
	TrainingRoom.selected_character = hub_player.character
	departing = true
	var error: Error = get_tree().change_scene_to_file(chapter.scene_path)
	if error != OK:
		departing = false
		TrainingRoom.selected_character = previous_character
		tutorial_chapter_panel.show_error("无法进入教学：%s" % error_string(error))


func _on_tutorial_chapters_closed() -> void:
	tutorial_chapter_panel = null
	if not departing:
		_set_hub_controls_enabled(true)


func _spawn_hub_player() -> void:
	if hub_player == null or player_spawn == null:
		return
	hub_player.global_position = player_spawn.global_position
	if startup != null and startup.picked_character != null:
		hub_player.set_character(startup.picked_character)


## 从角色选择界面接收开局信息，但此时只用于展示所选角色。
## RunStartup 会保留在大厅实例上，等待后续单人入口或多人房主真正开始一局游戏时使用。
func _receive_startup() -> void:
	if pending_startup == null:
		return

	startup = pending_startup
	pending_startup = null


func _connect_portals() -> void:
	for portal_node: Node in get_tree().get_nodes_in_group("hub_portal"):
		var portal := portal_node as HubPortal
		if portal != null and not portal.portal_activated.is_connected(_on_hub_portal_activated):
			portal.portal_activated.connect(_on_hub_portal_activated)


func _show_status(message: String) -> void:
	if status_label != null:
		status_label.text = message


## 局外事件完成后，用大厅中央的短提示明确告知玩家记录已保存。
func _show_event_notice(event_data: ProfileEventData) -> void:
	if event_notice_label == null or event_data == null:
		return
	event_notice_label.text = "新记录已收录\n《%s》" % event_data.display_name
	event_notice_label.modulate = Color.WHITE
	event_notice_label.show()
	var tween: Tween = create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(event_notice_label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(event_notice_label.hide)


## 直接运行大厅场景时，也可以使用大厅角色自带的 Character 测试出发。
func _open_departure_panel() -> void:
	if hub_player == null or hub_player.character == null:
		_show_status("尚未选择角色，无法出发。")
		return
	if departure_panel == null:
		departure_panel = DEPARTURE_PANEL.instantiate() as ConfirmationDialog
		add_child(departure_panel)
		departure_panel.confirmed.connect(_confirm_departure)
		departure_panel.canceled.connect(_cancel_departure)
		departure_panel.connect("continue_requested", _continue_adventure)
	_set_hub_controls_enabled(false)
	departure_panel.call("show_character", hub_player.character)


func _cancel_departure() -> void:
	if not departing:
		_set_hub_controls_enabled(true)


## 每次出发创建独立的启动资源，保留角色选择时设置的种子等导出数据。
func _confirm_departure() -> void:
	if departing:
		return
	var new_startup: RunStartup = startup.duplicate() as RunStartup if startup != null else RunStartup.new()
	new_startup.type = RunStartup.Type.NEW_RUN
	new_startup.picked_character = hub_player.character
	if not new_startup.can_start_new_run():
		_show_status("角色的开局数据不完整，请检查 Character 配置。")
		_set_hub_controls_enabled(true)
		return
	departing = true
	Run.pending_startup = new_startup
	_enter_run_scene()


## 继续时由 Run 从存档还原角色与构筑，不用大厅角色覆盖存档。
func _continue_adventure() -> void:
	if departing or not SaveManager.has_continue_save():
		_set_hub_controls_enabled(true)
		return
	var continued_startup: RunStartup = RunStartup.new()
	continued_startup.type = RunStartup.Type.CONTINUED_RUN
	Run.pending_startup = continued_startup
	departing = true
	_enter_run_scene()


func _enter_run_scene() -> void:
	var error: Error = get_tree().change_scene_to_file(RUN_SCENE_PATH)
	if error != OK:
		Run.pending_startup = null
		departing = false
		_set_hub_controls_enabled(true)
		_show_status("无法进入冒险，场景加载失败：%s" % error_string(error))


## 面板期间同时关闭移动、入口交互与镜头缩放，不影响动画与 UI 更新。
func _set_hub_controls_enabled(enabled: bool) -> void:
	hub_controls_enabled = enabled
	if tutorial_button != null:
		tutorial_button.disabled = not enabled or departing
	if hub_player != null:
		hub_player.controls_enabled = enabled
		var camera: Node = hub_player.get_node_or_null("Camera2D")
		if camera != null:
			camera.set_process_unhandled_input(enabled)
	for portal_node: Node in get_tree().get_nodes_in_group("hub_portal"):
		var portal: HubPortal = portal_node as HubPortal
		if portal != null and is_ancestor_of(portal):
			portal.set_process_unhandled_input(enabled)
			portal.set_prompts_enabled(enabled)
	for npc: HubNpc in hub_npcs:
		npc.set_ambient_bubbles_enabled(enabled)


## 功能与剧情 NPC 均由资源和驻点生成，避免把 NPC 的具体内容写死在场景里。
func _create_function_npcs() -> void:
	_spawn_function_npc(archivist_marker_path, ARCHIVIST_INTERACTION, "档案管理员")
	_spawn_function_npc(lost_recorder_marker_path, LOST_RECORDER_INTERACTION, "迷途记录员")
	_spawn_function_npc(antique_clerk_marker_path, ANTIQUE_CLERK_INTERACTION, "古董店女店员")
	_spawn_function_npc(zhang_san_marker_path, ZHANG_SAN_INTERACTION, "张三")
	_refresh_improved_facilities()


## 新增大厅 NPC 时，只需准备交互资源、外观资源与一个 Marker2D 驻点。
func _spawn_function_npc(marker_path: NodePath, interaction_data: HubNpcInteractionData, npc_label: String) -> void:
	if interaction_data == null:
		push_warning("%s 的交互资源未配置。" % npc_label)
		return
	var marker: Marker2D = get_node_or_null(marker_path) as Marker2D
	if marker == null:
		push_warning("未找到%s驻点：%s" % [npc_label, marker_path])
		return
	var npc: HubNpc = HUB_NPC_SCENE.instantiate() as HubNpc
	npc.interaction_data = interaction_data
	marker.add_child(npc)
	npc.interaction_completed.connect(_on_hub_npc_interaction_completed.bind(npc))
	hub_npcs.append(npc)


## 复用编辑器里的驻点，不改动用户摆放的位置。
func _create_character_npcs() -> void:
	var markers: Array[Node] = []
	if npc_marker_paths.is_empty():
		markers = $NpcContainer.find_children("*", "Marker2D", true, false)
	else:
		for marker_path: NodePath in npc_marker_paths:
			markers.append(get_node_or_null(marker_path))
	for index: int in range(npc_characters.size()):
		if index >= markers.size() or not markers[index] is Marker2D:
			push_warning("大厅角色驻点未配置，索引：%d" % index)
			continue
		if npc_characters[index] == null:
			continue
		var npc: HubCharacterNpc = CHARACTER_NPC_SCENE.instantiate() as HubCharacterNpc
		npc.character = npc_characters[index]
		markers[index].add_child(npc)
		character_npcs.append(npc)
	_refresh_character_npcs()


func _refresh_character_npcs() -> void:
	if hub_player == null:
		return
	for npc: HubCharacterNpc in character_npcs:
		npc.set_selected_character(hub_player.character)


## 角色 NPC 与功能 NPC 共用同一焦点，避免一次交互打开多个面板。
func _process(_delta: float) -> void:
	focused_npc = null
	focused_hub_npc = null
	var closest_distance: float = INF
	if hub_controls_enabled and hub_player != null:
		for npc: HubCharacterNpc in character_npcs:
			var distance: float = npc.global_position.distance_to(hub_player.global_position)
			if npc.visible and distance <= npc.interaction_radius and distance < closest_distance:
				focused_npc = npc
				closest_distance = distance
		for npc: HubNpc in hub_npcs:
			var distance: float = npc.global_position.distance_to(hub_player.global_position)
			if npc.visible and npc.can_interact() and distance <= npc.get_interaction_radius() and distance < closest_distance:
				focused_npc = null
				focused_hub_npc = npc
				closest_distance = distance
	for npc: HubCharacterNpc in character_npcs:
		npc.update_prompt(npc == focused_npc)
	for npc: HubNpc in hub_npcs:
		npc.update_prompt(npc == focused_hub_npc)


func _unhandled_input(event: InputEvent) -> void:
	if hub_controls_enabled and not departing and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_open_exit_dialog()
		return
	if hub_controls_enabled and focused_npc != null and event.is_action_pressed(character_interact_action) and not event.is_echo():
		get_viewport().set_input_as_handled()
		_open_character_dialog(focused_npc.character)
	elif hub_controls_enabled and focused_hub_npc != null and event.is_action_pressed(character_interact_action) and not event.is_echo():
		get_viewport().set_input_as_handled()
		_interact_with_hub_npc(focused_hub_npc)


## 沿用大厅的输入锁，弹窗期间停止移动、缩放以及入口和 NPC 交互。
func _open_exit_dialog() -> void:
	if exit_dialog == null:
		exit_dialog = ConfirmationDialog.new()
		exit_dialog.title = "离开大厅"
		exit_dialog.dialog_text = "是否返回主菜单？"
		exit_dialog.ok_button_text = "返回主菜单"
		exit_dialog.cancel_button_text = "留在大厅"
		exit_dialog.exclusive = true
		add_child(exit_dialog)
		exit_dialog.confirmed.connect(_confirm_exit_to_menu)
		exit_dialog.canceled.connect(_cancel_exit_to_menu)
	_set_hub_controls_enabled(false)
	exit_dialog.popup_centered(Vector2i(460, 200))
	exit_dialog.get_cancel_button().grab_focus()


func _cancel_exit_to_menu() -> void:
	if not departing:
		_set_hub_controls_enabled(true)


func _confirm_exit_to_menu() -> void:
	departing = true
	ResourceLocator.go_to_home_scene()


## 所有功能 NPC 的开场对话和功能入口都集中在此处，方便后续增加服务类型。
func _interact_with_hub_npc(npc: HubNpc) -> void:
	if npc == null or npc.interaction_data == null:
		return
	_set_hub_controls_enabled(false)
	if not npc.begin_interaction():
		_set_hub_controls_enabled(true)
		return
	_open_speak_ui(npc)


## 功能对话框只负责展示与选择；具体服务仍由大厅根据 ActionType 调度。
func _open_speak_ui(npc: HubNpc) -> void:
	if hub_ui == null:
		npc.end_interaction(false)
		_set_hub_controls_enabled(true)
		return
	if speak_ui != null and is_instance_valid(speak_ui):
		speak_ui.queue_free()
	active_speaking_npc = npc
	speak_ui = SPEAK_UI_SCENE.instantiate() as SpeakUi
	if speak_ui == null:
		active_speaking_npc.end_interaction(false)
		active_speaking_npc = null
		_set_hub_controls_enabled(true)
		return
	hub_ui.add_child(speak_ui)
	speak_ui.closed.connect(_on_speak_ui_closed)
	speak_ui.action_selected.connect(_on_speak_ui_action_selected)
	if npc.interaction_data.npc_id == &"zhang_san":
		npc.active_dialogue_data.dialogue_lines.append(ZhangSanService.get_progress_text())
	speak_ui.open_for_npc(npc.active_dialogue_data)


func _on_speak_ui_closed() -> void:
	var completed: bool = is_instance_valid(speak_ui) and speak_ui.is_dialogue_complete()
	_close_speak_ui(completed)
	_set_hub_controls_enabled(true)


func _on_speak_ui_action_selected(action_data: HubNpcActionData) -> void:
	_close_speak_ui(true)
	if action_data == null:
		_set_hub_controls_enabled(true)
		return
	match action_data.action_type:
		HubNpcActionData.ActionType.OPEN_PICTORIAL_BOOK:
			_open_pictorial_book()
		HubNpcActionData.ActionType.OPEN_RELIC_WAREHOUSE:
			_open_relic_warehouse()
		HubNpcActionData.ActionType.OPEN_ANTIQUE_TRADE:
			_open_antique_trade()
		HubNpcActionData.ActionType.DELIVER_ZHANG_SAN_SUPPLY:
			_show_status(ZhangSanService.deliver_selected_supply())
			_refresh_function_npc_availability()
			_set_hub_controls_enabled(true)
		HubNpcActionData.ActionType.HARVEST_ZHANG_SAN_MOOD:
			_open_zhang_san_harvest()
		HubNpcActionData.ActionType.NONE:
			_set_hub_controls_enabled(true)
		_:
			_show_status("该 NPC 功能尚未配置。")
			_set_hub_controls_enabled(true)


func _open_relic_warehouse() -> void:
	if not ProfileManager.is_relic_warehouse_unlocked():
		_show_status("先与迷途记录员完成拾荒约定。")
		_set_hub_controls_enabled(true)
		return
	if relic_warehouse_panel != null and is_instance_valid(relic_warehouse_panel):
		return
	_set_hub_controls_enabled(false)
	relic_warehouse_panel = RELIC_WAREHOUSE_PANEL_SCENE.instantiate() as RelicWarehousePanel
	if relic_warehouse_panel == null:
		_set_hub_controls_enabled(true)
		return
	hub_ui.add_child(relic_warehouse_panel)
	relic_warehouse_panel.closed.connect(_on_relic_warehouse_closed)


func _on_relic_warehouse_closed() -> void:
	relic_warehouse_panel = null
	if not departing:
		_set_hub_controls_enabled(true)


func _open_antique_trade() -> void:
	if antique_trade_panel != null and is_instance_valid(antique_trade_panel):
		return
	_set_hub_controls_enabled(false)
	antique_trade_panel = ANTIQUE_TRADE_PANEL_SCENE.instantiate() as AntiqueTradePanel
	if antique_trade_panel == null:
		_set_hub_controls_enabled(true)
		return
	hub_ui.add_child(antique_trade_panel)
	antique_trade_panel.closed.connect(_on_antique_trade_closed)
	antique_trade_panel.cuisine_offered.connect(_on_xiaole_cuisine_offered)


func _on_antique_trade_closed() -> void:
	antique_trade_panel = null
	if not departing:
		_set_hub_controls_enabled(true)


func _on_xiaole_cuisine_offered() -> void:
	_refresh_function_npc_availability()
	_show_status("小乐似乎很在意这份佳肴，再和她谈谈吧。")


## 功能按钮与离开按钮共享收尾流程，确保一次性事件只触发一次。
func _close_speak_ui(completed: bool) -> void:
	if speak_ui != null and is_instance_valid(speak_ui):
		speak_ui.queue_free()
	speak_ui = null
	if active_speaking_npc != null and is_instance_valid(active_speaking_npc):
		active_speaking_npc.end_interaction(completed)
	active_speaking_npc = null


## 这里只转发配置中的事件标识，不把具体剧情、奖励或开门逻辑写死在通用 NPC 中。
func _on_hub_npc_interaction_completed(event_id: StringName, npc: HubNpc) -> void:
	if npc == null or npc.interaction_data == null:
		return
	var should_consume_relic: bool = npc.should_consume_carried_relic_on_completion()
	var released_warehouse_slots: int = 1 if should_consume_relic else 0
	if ProfileManager.try_complete_event(event_id, released_warehouse_slots):
		if should_consume_relic and not ProfileManager.consume_selected_warehouse_relic_for_event():
			push_warning("事件已完成，但大厅携带装备未能成功消耗：%s" % event_id)
		var event_data: ProfileEventData = ProfileManager.get_event_data(event_id)
		if event_data != null and event_data.show_in_codex:
			_show_event_notice(event_data)
		hub_backpack_button.visible = ProfileManager.is_relic_warehouse_unlocked()
		_refresh_function_npc_availability()
		hub_npc_interaction_completed.emit(npc.interaction_data.npc_id, event_id)
	else:
		_show_status("事件暂未完成。若包含仓库奖励，请先腾出足够空间。")


## 同一大厅中完成前置事件后，立即刷新后续 NPC 的显隐状态。
func _refresh_function_npc_availability() -> void:
	for npc: HubNpc in hub_npcs:
		npc.refresh_profile_availability()
	_refresh_improved_facilities()


func _refresh_improved_facilities() -> void:
	var facilities: CanvasItem = get_node_or_null(improved_facilities_path) as CanvasItem
	if facilities != null:
		facilities.visible = ProfileManager.has_completed_event(&"zhang_san_facilities_ready")


## 首次点击只打开说明对白；听完说明才解锁实际领取，不抢先消耗次数。
func _open_zhang_san_harvest() -> void:
	if ProfileManager.has_completed_event(&"zhang_san_mood_introduction"):
		_show_status(ZhangSanService.harvest_mood())
		_set_hub_controls_enabled(true)
		return
	for npc: HubNpc in hub_npcs:
		if npc.interaction_data.npc_id != &"zhang_san" or not npc.begin_interaction():
			continue
		npc.active_dialogue_data.completion_event_id = &"zhang_san_mood_introduction"
		npc.active_dialogue_data.dialogue_lines = ["因为荒域的原因，有些情感会具象化为物品。好的情感能带来不错的结果。", "生活环境好了，大家的心情也会变好，我会把那些好心情收集起来。", "每完成一局冒险，无论胜败，都能来领取一次。仓库装不下时，机会会替你留着。"]
		npc.active_dialogue_data.actions = []
		_open_speak_ui(npc)
		return
	_set_hub_controls_enabled(true)


## 图鉴作为大厅 UI 的子节点打开，关闭后回到同一个大厅实例。
func _open_pictorial_book() -> void:
	if pictorial_book != null and is_instance_valid(pictorial_book):
		return
	if hub_ui == null:
		_set_hub_controls_enabled(true)
		return
	pictorial_book = PICTORIAL_BOOK_SCENE.instantiate() as PictorialBook
	if pictorial_book == null:
		_set_hub_controls_enabled(true)
		return
	pictorial_book.return_to_home_on_exit = false
	hub_ui.add_child(pictorial_book)
	pictorial_book.closed.connect(_on_pictorial_book_closed)


func _on_pictorial_book_closed() -> void:
	pictorial_book = null
	_set_hub_controls_enabled(true)


func _open_character_dialog(character: Character) -> void:
	requested_character = character
	if character_dialog == null:
		character_dialog = ConfirmationDialog.new()
		character_dialog.exclusive = true
		character_dialog.dialog_autowrap = true
		add_child(character_dialog)
		character_dialog.confirmed.connect(_confirm_character_switch)
		character_dialog.canceled.connect(_cancel_character_switch)
	character_dialog.title = "与%s交谈" % character.character_name
	character_dialog.dialog_text = _build_character_preview_text(character)
	character_dialog.ok_button_text = "切换角色"
	character_dialog.cancel_button_text = "取消"
	_set_hub_controls_enabled(false)
	character_dialog.popup_centered(Vector2i(760, 520))
	character_dialog.get_cancel_button().grab_focus()


## 大厅预览只读取角色初始 StatsData，不包含装备、被动和任何单局修正。
func _build_character_preview_text(character: Character) -> String:
	var stats: StatsData = character.start_stats
	var summary: String = character.description
	if stats == null:
		return "%s\n\n该角色尚未配置初始属性。\n\n是否切换为%s？" % [summary, character.character_name]

	# 此处与 StatsController 的派生属性公式保持一致，避免预览与实际开局不一致。
	var max_health: float = stats.base_max_health + stats.constitution * 5.0
	var max_energy: float = stats.base_max_energy + stats.intelligence * 3.0
	var move_speed: float = stats.base_move_speed + stats.speed * 10.0
	var crit_chance: float = (stats.base_crit_chance + stats.luck * 0.002) * 100.0
	var dodge_rate: float = (stats.base_dodge_rate + stats.speed * 0.001) * 100.0
	return "%s\n\n初始一级属性\n力量 %d    敏捷 %d    智力 %d\n体质 %d    速度 %d    魅力 %d    幸运 %d\n\n初始战斗属性\n生命 %.0f    能量 %.0f    移速 %.0f\n暴击率 %.1f%%    闪避率 %.1f%%\n\n是否切换为%s？\n切换影响新冒险，继续冒险仍使用存档角色。" % [summary, stats.strength, stats.dexterity, stats.intelligence, stats.constitution, stats.speed, stats.charm, stats.luck, max_health, max_energy, move_speed, crit_chance, dodge_rate, character.character_name]


func _cancel_character_switch() -> void:
	requested_character = null
	_set_hub_controls_enabled(true)


## 玩家保持原地，旧角色回驻点；只更新开局选择，不修改存档构筑。
func _confirm_character_switch() -> void:
	if requested_character != null and hub_player != null:
		hub_player.set_character(requested_character)
		if startup == null:
			startup = RunStartup.new()
		startup.picked_character = requested_character
		_refresh_character_npcs()
		_show_status("当前角色：%s" % requested_character.character_name)
	_cancel_character_switch()
