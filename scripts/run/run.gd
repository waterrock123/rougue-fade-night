class_name Run
extends Node

const PLAY_SCENE_PATH := "res://scenes/play_scene.tscn"
const REST_SCENE_PATH := "res://scenes/rest_period/rest_period.tscn"

# 角色选择界面切场景后，会先把本次开局数据暂存在这里。
static var pending_startup: RunStartup

@export var run_startup: RunStartup

@onready var current_view: Node = $CurrentView
@onready var map: Map = $Map
@onready var player_build_proxy: PlayerBuildProxy = $PlayerBuildProxy
@onready var package_ui: PackageUI = $UI/PackageUI
@onready var attributes_panel: AttributesPanel = $UI/AttributesPanel
@onready var package_button: Button = $TopBar/PackageButton

var run_stats: RunStats
var current_room: Room


# 先准备本局数据，再初始化常驻节点和地图流程。
func _ready() -> void:
	_initialize_run_state()
	_initialize_runtime_proxy()
	_initialize_persistent_ui()
	_connect_signals()
	_initialize_map()


# 主动进入当前房间对应的战斗场景。
func change_to_play_scene() -> void:
	if current_room == null:
		return

	_open_battle_scene(current_room)


# 战斗胜利后进入修整期，并发放本回合修整奖励金币。
func change_to_rest_period() -> void:
	if run_stats != null:
		run_stats.grant_rest_period_gold()
	_refresh_persistent_ui()

	var rest_scene_resource := load(REST_SCENE_PATH) as PackedScene
	if rest_scene_resource == null:
		return

	var rest_scene := rest_scene_resource.instantiate()
	if rest_scene == null:
		return

	_bind_run_stats(rest_scene)
	_replace_current_view(rest_scene)
	if map != null:
		map.hide_map()


# 修整期结束后返回地图，并解锁下一批可进入房间。
func finish_rest_period() -> void:
	_clear_current_view()
	_refresh_persistent_ui()

	if map != null:
		map.show_map()
		map.unlock_next_rooms()


# 统一连接 Run 关心的常驻信号。
func _connect_signals() -> void:
	if map != null and not map.room_selected.is_connected(_on_map_room_selected):
		map.room_selected.connect(_on_map_room_selected)

	if not EventBus.event_room_exited.is_connected(_on_event_room_exited):
		EventBus.event_room_exited.connect(_on_event_room_exited)

	if package_button != null and not package_button.pressed.is_connected(_on_package_button_pressed):
		package_button.pressed.connect(_on_package_button_pressed)


# Run 自己负责创建一份新的 RunStats，并用 RunStartup 把它补完整。
func _initialize_run_state() -> void:
	if run_stats != null:
		return

	run_stats = RunStats.new()
	var startup := _resolve_startup()
	if startup == null:
		push_warning("Run 缺少 RunStartup，无法初始化本局数据。")
		return

	match startup.type:
		RunStartup.Type.NEW_RUN:
			_initialize_new_run(startup)
		RunStartup.Type.CONTINUED_RUN:
			_initialize_continued_run(startup)


# 新开局时，从角色选择传来的角色资源构建 PlayerBuild。
func _initialize_new_run(startup: RunStartup) -> void:
	if not startup.can_start_new_run():
		push_warning("RunStartup 中没有有效的角色数据，无法开始新的一局。")
		return

	var build := startup.create_player_build()
	var shop := startup.create_shop()
	var shop_config := startup.create_shop_config()
	run_stats.setup_new_run(build, shop, shop_config)


# 目前续档逻辑还没展开，这里先做最小兼容。
func _initialize_continued_run(startup: RunStartup) -> void:
	if startup.can_start_new_run():
		var build := startup.create_player_build()
		var shop := startup.create_shop()
		var shop_config := startup.create_shop_config()
		run_stats.setup_new_run(build, shop, shop_config)


# 把 run_stats.player_build 绑定给修整期常驻的属性与装备管理节点。
func _initialize_runtime_proxy() -> void:
	if player_build_proxy == null or run_stats == null or run_stats.player_build == null:
		return

	player_build_proxy.bind_player_build(run_stats.player_build)


# 初始化 Run 下常驻的背包和属性面板 UI。
func _initialize_persistent_ui() -> void:
	if run_stats == null or run_stats.player_build == null:
		return

	if package_ui != null:
		package_ui.open_bag(run_stats.player_build.player_inventory, run_stats.player_build.player_equipment)
		package_ui.close_bag()

	if attributes_panel != null:
		attributes_panel.stats_controller = _get_runtime_stats_controller()
		attributes_panel.setup()
		attributes_panel.close_panel()


# 当 RunStats 或 PlayerBuild 中的数据被更新后，刷新 Run 下常驻 UI。
func _refresh_persistent_ui() -> void:
	if run_stats == null or run_stats.player_build == null:
		return

	if player_build_proxy != null:
		player_build_proxy.bind_player_build(run_stats.player_build)

	if package_ui != null:
		package_ui.set_player_inventory(run_stats.player_build.player_inventory)
		package_ui.set_player_equipment(run_stats.player_build.player_equipment)
		package_ui.bag_update()
		package_ui.equipment_update()

	if attributes_panel != null:
		attributes_panel.stats_controller = _get_runtime_stats_controller()
		attributes_panel.setup()
		if package_ui != null and package_ui.visible:
			attributes_panel.open_panel()
		else:
			attributes_panel.close_panel()


# 生成并显示本局地图。
func _initialize_map() -> void:
	if map == null:
		return

	map.generate_new_map()
	map.show_map()


# 优先读取角色选择场景传来的临时启动数据，其次再使用场景上兜底的导出资源。
func _resolve_startup() -> RunStartup:
	if pending_startup != null:
		var startup := pending_startup
		pending_startup = null
		return startup

	return run_startup


# 记录当前被选择的房间，并进入它的事件场景。
func _on_map_room_selected(room: Room) -> void:
	current_room = room
	_open_event_room(room)


# 事件场景点击离开后，进入该房间绑定的战斗场景。
func _on_event_room_exited() -> void:
	if current_room == null:
		return

	_open_battle_scene(current_room)


# 顶部按钮控制常驻背包界面的开关。
func _on_package_button_pressed() -> void:
	if package_ui == null or run_stats == null or run_stats.player_build == null:
		push_warning("Run 当前没有可用的玩家背包数据。")
		return

	if package_ui.visible:
		package_ui.close_bag()
		if attributes_panel != null:
			attributes_panel.close_panel()
	else:
		package_ui.open_bag(run_stats.player_build.player_inventory, run_stats.player_build.player_equipment)
		if attributes_panel != null:
			attributes_panel.stats_controller = _get_runtime_stats_controller()
			attributes_panel.setup()
			attributes_panel.open_panel()


# 把地图房间对应的事件场景塞进 CurrentView。
func _open_event_room(room: Room) -> void:
	if room == null or room.event_scene == null:
		return

	var event_room := room.event_scene.instantiate()
	if event_room == null:
		return

	_bind_run_stats(event_room)
	_replace_current_view(event_room)
	if map != null:
		map.hide_map()

	if event_room.has_method("setup"):
		event_room.setup()


# 把地图房间对应的战斗场景塞进 CurrentView，并注入本局数据。
func _open_battle_scene(room: Room) -> void:
	if room == null:
		return

	var play_scene_resource := load(PLAY_SCENE_PATH) as PackedScene
	if play_scene_resource == null:
		return

	var play_scene := play_scene_resource.instantiate()
	if play_scene == null:
		return

	if play_scene.has_method("setup_run_battle"):
		play_scene.setup_run_battle(run_stats, room.battle_stats)
	else:
		_bind_run_stats(play_scene)

	_replace_current_view(play_scene)
	if map != null:
		map.hide_map()


# 用新的子场景替换 CurrentView 当前显示的内容。
func _replace_current_view(scene: Node) -> void:
	_clear_current_view()
	current_view.add_child(scene)


# 清理 CurrentView 当前的唯一子场景。
func _clear_current_view() -> void:
	var current_scene := _get_current_scene()
	if current_scene == null:
		return

	current_view.remove_child(current_scene)
	current_scene.queue_free()


# 统一给支持 run_stats 的子场景注入同一份本局数据。
func _bind_run_stats(scene: Node) -> void:
	if scene == null:
		return

	if "run_stats" in scene:
		scene.run_stats = run_stats


func _get_current_scene() -> Node:
	if current_view.get_child_count() == 0:
		return null

	return current_view.get_child(0)


# 获取 Run 下常驻的运行时属性控制器，供属性面板等 UI 读取。
func _get_runtime_stats_controller() -> StatsController:
	if player_build_proxy == null:
		return null

	return player_build_proxy.get_stats_controller()
