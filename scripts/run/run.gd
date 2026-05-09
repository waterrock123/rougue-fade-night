class_name Run
extends Node

const PLAY_SCENE_PATH := "res://scenes/play_scene.tscn"
const LEVEL_UP_SCENE_PATH := "res://scenes/ability/level_up_controller.tscn"
const REST_SCENE_PATH := "res://scenes/rest_period/rest_period.tscn"
const DEATH_SCENE_PATH := "res://scenes/ui/death_screen.tscn"

# 角色选择界面切场景后，会先把本次开局数据暂存在这里。
static var pending_startup: RunStartup

@export var run_startup: RunStartup

@onready var current_view: Node = $CurrentView
@onready var map: Map = $Map
@onready var player_build_proxy: PlayerBuildProxy = $PlayerBuildProxy
@onready var package_ui: PackageUI = $UI/PackageUI
@onready var attributes_panel: AttributesPanel = $UI/AttributesPanel
@onready var skill_overview_panel: SkillOverviewPanel = $UI/SkillOverviewPanel
@onready var top_bar: CanvasLayer = $TopBar
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


# 战斗胜利后先进入升级奖励场景，由玩家选择奖励后再进入修整期。
func change_to_level_up() -> void:
	_show_top_bar()
	_refresh_persistent_ui()

	var level_up_scene_resource := load(LEVEL_UP_SCENE_PATH) as PackedScene
	if level_up_scene_resource == null:
		return

	var level_up_scene := level_up_scene_resource.instantiate()
	if level_up_scene == null:
		return

	_bind_run_stats(level_up_scene)
	if level_up_scene.has_method("setup_level_up"):
		level_up_scene.setup_level_up(
			run_stats,
			self,
			_get_runtime_stats_controller(),
			_get_runtime_skill_controller()
		)

	_replace_current_view(level_up_scene)
	if attributes_panel != null:
		attributes_panel.close_panel()
	if map != null:
		map.hide_map()


# 战斗胜利后进入修整期，并发放本回合修整奖励金币。
func change_to_rest_period() -> void:
	_show_top_bar()
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


# 玩家战败时打开死亡界面，由死亡界面决定重新开始或回主菜单。
func change_to_death_screen() -> void:
	_refresh_persistent_ui()
	_close_persistent_panels()
	_hide_top_bar()

	var death_scene_resource := load(DEATH_SCENE_PATH) as PackedScene
	if death_scene_resource == null:
		return

	var death_scene := death_scene_resource.instantiate()
	if death_scene == null:
		return

	_replace_current_view(death_scene)
	if map != null:
		map.hide_map()


# 修整期结束后返回地图，并解锁下一批可进入房间。
func finish_rest_period() -> void:
	_show_top_bar()
	if run_stats != null:
		run_stats.clear_free_relic_choices()
	_clear_current_view()
	_refresh_persistent_ui()

	if map != null:
		map.show_map()
		map.unlock_next_rooms()


# 统一连接 Run 关心的常驻信号。
func _connect_signals() -> void:
	if map != null and not map.room_selected.is_connected(_on_map_room_selected):
		map.room_selected.connect(_on_map_room_selected)
	
	if  not EventBus.battle_win.is_connected(change_to_level_up):
		EventBus.battle_win.connect(change_to_level_up)

	if not EventBus.battle_lost.is_connected(change_to_death_screen):
		EventBus.battle_lost.connect(change_to_death_screen)
	
	if not EventBus.event_room_exited.is_connected(_on_event_room_exited):
		EventBus.event_room_exited.connect(_on_event_room_exited)

	if not EventBus.relic_merged_to_levelup.is_connected(_on_relic_merged_to_levelup):
		EventBus.relic_merged_to_levelup.connect(_on_relic_merged_to_levelup)

	if not EventBus.inventory_update.is_connected(_on_player_relic_slots_changed):
		EventBus.inventory_update.connect(_on_player_relic_slots_changed)

	if not EventBus.equipment_update.is_connected(_on_player_relic_slots_changed):
		EventBus.equipment_update.connect(_on_player_relic_slots_changed)

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
	if shop != null and not startup.picked_character.shop_keeper_pool.is_empty():
		shop.shopkeeper = startup.picked_character.shop_keeper_pool.pick_random()
	var shop_config := startup.create_shop_config()
	run_stats.setup_new_run(build, shop, shop_config, startup.picked_character)


# 目前续档逻辑还没展开，这里先做最小兼容。
func _initialize_continued_run(startup: RunStartup) -> void:
	if startup.can_start_new_run():
		var build := startup.create_player_build()
		var shop := startup.create_shop()
		var shop_config := startup.create_shop_config()
		run_stats.setup_new_run(build, shop, shop_config, startup.picked_character)


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

	if skill_overview_panel != null:
		skill_overview_panel.setup(run_stats.player_build)
		skill_overview_panel.close_panel()


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
		if package_ui != null and package_ui.visible and not _is_level_up_scene_open():
			attributes_panel.open_panel()
		else:
			attributes_panel.close_panel()

	if skill_overview_panel != null:
		skill_overview_panel.setup(run_stats.player_build)
		if package_ui != null and package_ui.visible:
			skill_overview_panel.open_panel()
		else:
			skill_overview_panel.close_panel()


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


# 只要发生“未升级遗物合成升级”的行为，就按当时商店等级锁定一次免费三选一机会。
func _on_relic_merged_to_levelup(_upgraded_relic: Relic) -> void:
	if run_stats == null:
		return

	run_stats.queue_free_relic_choice(run_stats.get_free_relic_choice_level_for_now())


# 背包或装备栏变化时，用 PlayerBuild 统一检测合成，保证装备栏里的遗物也能参与。
func _on_player_relic_slots_changed() -> void:
	if run_stats == null or run_stats.player_build == null:
		return

	run_stats.player_build.check_relic_merges()


# 顶部按钮控制常驻背包界面的开关。
func _on_package_button_pressed() -> void:
	if package_ui == null or run_stats == null or run_stats.player_build == null:
		push_warning("Run 当前没有可用的玩家背包数据。")
		return

	if package_ui.visible:
		package_ui.close_bag()
		if attributes_panel != null:
			attributes_panel.close_panel()
		if skill_overview_panel != null:
			skill_overview_panel.close_panel()
	else:
		package_ui.open_bag(run_stats.player_build.player_inventory, run_stats.player_build.player_equipment)
		if skill_overview_panel != null:
			skill_overview_panel.setup(run_stats.player_build)
			skill_overview_panel.open_panel()
		if attributes_panel != null and not _is_level_up_scene_open():
			attributes_panel.stats_controller = _get_runtime_stats_controller()
			attributes_panel.setup()
			attributes_panel.open_panel()
		elif attributes_panel != null:
			attributes_panel.close_panel()


# 把地图房间对应的事件场景塞进 CurrentView。
func _open_event_room(room: Room) -> void:
	if room == null or room.event_scene == null:
		return

	var event_room := room.event_scene.instantiate()
	if event_room == null:
		return

	_show_top_bar()
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

	_show_top_bar()
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


func _is_level_up_scene_open() -> bool:
	return _get_current_scene() is LevelUPController


func _close_persistent_panels() -> void:
	if package_ui != null:
		package_ui.close_bag()
	if attributes_panel != null:
		attributes_panel.close_panel()
	if skill_overview_panel != null:
		skill_overview_panel.close_panel()


func _show_top_bar() -> void:
	if top_bar != null:
		top_bar.show()


func _hide_top_bar() -> void:
	if top_bar != null:
		top_bar.hide()


# 获取 Run 下常驻的运行时属性控制器，供属性面板等 UI 读取。
func _get_runtime_stats_controller() -> StatsController:
	if player_build_proxy == null:
		return null

	return player_build_proxy.get_stats_controller()


func _get_runtime_skill_controller() -> SkillController:
	if player_build_proxy == null:
		return null

	return player_build_proxy.get_skill_controller()
