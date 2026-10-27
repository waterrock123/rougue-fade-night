class_name Run
extends Node

const PLAY_SCENE_PATH := "res://scenes/play_scene.tscn"
const LEVEL_UP_SCENE_PATH := "res://scenes/ability/level_up_controller.tscn"
const REST_SCENE_PATH := "res://scenes/rest_period/rest_period.tscn"
const DEATH_SCENE_PATH := "res://scenes/ui/death_screen.tscn"
const VICTORY_SCENE_PATH := "res://scenes/ui/victory_screen.tscn"
const VICTORY_RELIC_SELECTION_SCENE_PATH := "res://scenes/ui/victory_relic_selection_panel.tscn"
const FLOW_MAP := "map"
const FLOW_EVENT_ROOM := "event_room"
const FLOW_LEVEL_UP := "level_up"
const FLOW_STARTING_SKILL := "starting_skill"
const FLOW_REST_PERIOD := "rest_period"
const TAG_EFFECT_DATABASE := preload("res://custom_resource/default_tag_effect_database.tres")

# 角色选择界面切场景后，会先把本次开局数据暂存在这里。
static var pending_startup: RunStartup

@export var run_startup: RunStartup
## 按顺序引用各层配置，扩层无需复制 Run 场景。
@export var floor_configs: Array[RunFloorConfig] = [
	preload("res://custom_resource/run_floor_01.tres"),
	preload("res://custom_resource/run_floor_02.tres"),
]
## 开发版可从顶栏打开调试台；发布版默认不显示，避免把测试命令交给正式玩家。
@export var enable_debug_console: bool = true

@onready var current_view: Node = $CurrentView
@onready var map: Map = $Map
@onready var player_build_proxy: PlayerBuildProxy = $PlayerBuildProxy
@onready var package_ui: PackageUI = $UI/PackageUI
@onready var attributes_panel: AttributesPanel = $UI/AttributesPanel
@onready var skill_overview_panel: SkillOverviewPanel = $UI/SkillOverviewPanel
@onready var tag_effect_ui: TagEffectUI = $UI/TagEffectBar
@onready var map_tag_config_panel: MapTagConfigPanel = $UI/MapTagConfigPanel
@onready var debug_console: DebugConsole = $UI/DebugConsole
@onready var top_bar: CanvasLayer = $TopBar
@onready var package_button: Button = $TopBar/PackageButton
@onready var map_tag_button: Button = $TopBar/MapTagButton
@onready var debug_button: Button = $TopBar/DebugButton
@onready var pause_button: Button = $TopBar/PauseButton
@onready var pause_menu: PauseMenu = $UI/PauseMenu

var run_stats: RunStats
var current_room: Room
## 调试台设置的一次性事件覆盖；进入下一个地图房间后立即消费并清空。
var debug_next_event_scene: PackedScene
## 独立于本房已锁定模板的一次性测试配置，存档时只补记此字段，不覆盖检查点奖励。
var debug_next_battle_map_template_path: String = ""
var pending_map_save_data: Dictionary = {}
var pending_current_room_data: Dictionary = {}
var pending_flow_state: String = FLOW_MAP
var current_flow_state: String = FLOW_MAP
var level_up_checkpoint_locked := false
var level_up_reward_options: Array[LevelUpReward] = []
var battle_active := false
var tag_effect_controller: TagEffectController
var world_condition_controller: WorldConditionController
var death_salvage_resolved: bool = false
var death_recovery_relics: Array[Relic] = []
var victory_resolution_started: bool = false
var pending_received_relic: Relic
var event_entry_checkpoint: EventEntryCheckpoint = EventEntryCheckpoint.new()


# 先准备本局数据，再初始化常驻节点和地图流程。
func _ready() -> void:
	_initialize_run_state()
	_ensure_default_tag_effect_selection()
	_initialize_runtime_proxy()
	_initialize_persistent_ui()
	_initialize_tag_effect_controller()
	_initialize_world_condition_controller()
	_connect_signals()
	_initialize_map()
	# 大厅携带发生在代理/天气控制器初始化前，只补发这件新开局遗物的通知，不重放续档。
	if pending_received_relic != null:
		_on_relic_received(pending_received_relic, run_stats.player_build)
		pending_received_relic = null
	_restore_saved_flow_view()
	if current_flow_state == FLOW_MAP:
		_save_current_run()


# 主动进入当前房间对应的战斗场景。
func change_to_play_scene() -> void:
	if current_room == null:
		return

	_open_battle_scene(current_room)


# 战斗胜利后先进入升级奖励场景，由玩家选择奖励后再进入修整期。
func change_to_level_up() -> void:
	current_flow_state = FLOW_LEVEL_UP
	level_up_checkpoint_locked = false
	battle_active = false
	if run_stats != null:
		run_stats.clear_battle_map_template()
	_show_top_bar()
	_set_package_equipment_locked(false)
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
			_get_runtime_skill_controller(),
			level_up_reward_options
		)

	_replace_current_view(level_up_scene)
	if level_up_scene.has_method("get_current_rewards"):
		level_up_reward_options = level_up_scene.get_current_rewards()
	if attributes_panel != null:
		attributes_panel.close_panel()
	if map != null:
		map.hide_map()
	_save_current_run(true)
	level_up_checkpoint_locked = true


# 新开局时先进入一次特殊奖励界面，只抽主动技能，让玩家第一场战斗更有操作空间。
func change_to_starting_skill_select() -> void:
	current_flow_state = FLOW_STARTING_SKILL
	level_up_checkpoint_locked = false
	battle_active = false
	_show_top_bar()
	_set_package_equipment_locked(false)
	_refresh_persistent_ui()
	_close_persistent_panels()

	var level_up_scene_resource := load(LEVEL_UP_SCENE_PATH) as PackedScene
	if level_up_scene_resource == null:
		return

	var level_up_scene := level_up_scene_resource.instantiate()
	if level_up_scene == null:
		return

	_bind_run_stats(level_up_scene)
	if level_up_scene.has_method("setup_starting_skill"):
		level_up_scene.setup_starting_skill(
			run_stats,
			self,
			_get_runtime_stats_controller(),
			_get_runtime_skill_controller(),
			level_up_reward_options
		)

	_replace_current_view(level_up_scene)
	if level_up_scene.has_method("get_current_rewards"):
		level_up_reward_options = level_up_scene.get_current_rewards()
	if map != null:
		map.hide_map()
	_save_current_run(true)
	level_up_checkpoint_locked = true


# 战斗胜利后进入修整期，并发放本回合修整奖励金币。
# restore_gold=false 只用于读取“已经进入修整期”的存档，避免重复发放金币。
func change_to_rest_period(restore_gold: bool = true) -> void:
	current_flow_state = FLOW_REST_PERIOD
	level_up_checkpoint_locked = false
	battle_active = false
	if run_stats != null:
		run_stats.clear_battle_map_template()
	_show_top_bar()
	_set_package_equipment_locked(false)
	if restore_gold and run_stats != null:
		run_stats.begin_rest_period()
		run_stats.grant_rest_period_gold()
		if world_condition_controller != null:
			world_condition_controller.settle_completed_room()
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
	_open_package_for_rest_period()
	# 商店与常驻 UI 都初始化完成后，再通知套装效果进入本次修整期。
	EventBus.rest_period_started.emit()


# 用无参数转发函数接收结束点的“直接进入修整期”信号。
func _handle_battle_win_direct_to_rest() -> void:
	change_to_rest_period()


# 玩家战败时打开死亡界面，由死亡界面决定重新开始或回主菜单。
func change_to_death_screen() -> void:
	if death_salvage_resolved:
		return
	death_salvage_resolved = true
	battle_active = false
	_refresh_persistent_ui()
	_close_persistent_panels()
	_hide_top_bar()
	_set_package_equipment_locked(false)

	if run_stats != null:
		ProfileManager.record_warehouse_field_test_if_needed(run_stats)
		ProfileManager.record_appetite_adventure_if_needed()
		ZhangSanService.record_finished_adventure()
	if map != null:
		map.hide_map()
	_resolve_death_recovery()


## 普通死亡沿用随机回收一件；装备提供的策略可提升数量或回收全部。
## 先拍下死亡时的候选列表，之后切场景、卸载效果都不会改变本次结算。
func _resolve_death_recovery() -> void:
	death_recovery_relics.clear()
	if not ProfileManager.is_relic_warehouse_unlocked() or run_stats == null or run_stats.player_build == null:
		_finish_death_transition()
		return
	var build: PlayerBuild = run_stats.player_build
	var limit: int = build.get_death_recovery_limit()
	if limit == 0 and ProfileManager.is_relic_warehouse_full():
		_finish_death_transition()
		return
	death_recovery_relics = ProfileManager.get_recoverable_relics_from_build(build)
	if limit != -1:
		death_recovery_relics.shuffle()
		death_recovery_relics.resize(mini(death_recovery_relics.size(), maxi(limit, 1)))
	if death_recovery_relics.size() > ProfileManager.get_relic_warehouse_free_slots():
		_open_relic_recovery_selection(death_recovery_relics, true)
		return
	if ProfileManager.store_relics_in_warehouse(death_recovery_relics):
		_finish_death_transition()
	else:
		# 保留同一批候选供重试，不重复抽取、不提前删除本局检查点。
		var panel: VictoryRelicSelectionPanel = _open_relic_recovery_selection(death_recovery_relics, true)
		if panel != null:
			panel.show_store_error("装备保存失败，请重试。本局存档尚未删除。")


func _on_death_relics_selected(kept_entry_ids: Array[String], selected_relics: Array[Relic]) -> void:
	if not ProfileManager.replace_warehouse_after_victory(kept_entry_ids, selected_relics):
		_show_recovery_store_error()
		return
	death_recovery_relics = selected_relics.duplicate()
	_finish_death_transition()


## 仓库事务完成后再进入死亡界面并删掉本局存档，避免选择界面重复写入。
func _finish_death_transition() -> void:
	var scene: PackedScene = load(DEATH_SCENE_PATH) as PackedScene
	if scene == null:
		push_warning("无法加载死亡界面。")
		return
	var death_screen: DeathScreen = scene.instantiate() as DeathScreen
	if death_screen == null:
		return
	_replace_current_view(death_screen)
	death_screen.show_recovered_relics(
		death_recovery_relics, ProfileManager.is_relic_warehouse_unlocked(), ProfileManager.is_relic_warehouse_full()
	)
	SaveManager.delete_save()


# Boss 战胜利后先结算身上的装备；仓库容量不足时让玩家决定保留哪些装备。
func change_to_victory_screen() -> void:
	if victory_resolution_started:
		return
	victory_resolution_started = true

	# 首次通关作为局外剧情条件保存，不会重复领取奖励。
	ProfileManager.try_complete_event(&"first_run_victory")
	ProfileManager.record_warehouse_field_test_if_needed(run_stats)
	ProfileManager.record_appetite_adventure_if_needed()
	ZhangSanService.record_finished_adventure()
	battle_active = false
	level_up_checkpoint_locked = false
	level_up_reward_options.clear()
	_close_persistent_panels()
	_hide_top_bar()
	_set_package_equipment_locked(false)
	if map != null:
		map.hide_map()

	var victory_relics: Array[Relic] = []
	if run_stats != null and run_stats.player_build != null:
		victory_relics = ProfileManager.get_recoverable_relics_from_build(run_stats.player_build)
	var free_slots: int = ProfileManager.get_relic_warehouse_free_slots()
	if victory_relics.size() <= free_slots:
		if ProfileManager.store_relics_in_warehouse(victory_relics):
			_finish_victory_transition()
		else:
			victory_resolution_started = false
			push_warning("胜利装备写入局外仓库失败，本局存档仍然保留。")
		return

	_open_relic_recovery_selection(victory_relics)


## 死亡保护和通关共用装备保留界面；按结算类型连接唯一的确认回调。
func _open_relic_recovery_selection(relics: Array[Relic], after_death: bool = false) -> VictoryRelicSelectionPanel:
	var selection_scene_resource := load(VICTORY_RELIC_SELECTION_SCENE_PATH) as PackedScene
	if selection_scene_resource == null:
		_reset_recovery_resolution(after_death)
		push_warning("无法加载装备选择界面，本局存档仍然保留。")
		return null

	var selection_panel := selection_scene_resource.instantiate() as VictoryRelicSelectionPanel
	if selection_panel == null:
		_reset_recovery_resolution(after_death)
		push_warning("无法实例化装备选择界面，本局存档仍然保留。")
		return null

	var callback: Callable = _on_death_relics_selected if after_death else _on_victory_relics_selected
	selection_panel.selection_confirmed.connect(callback)
	_replace_current_view(selection_panel)
	selection_panel.setup(
		relics,
		ProfileManager.get_warehouse_entries(),
		ProfileManager.get_relic_warehouse_capacity(),
		after_death
	)
	return selection_panel


func _reset_recovery_resolution(after_death: bool) -> void:
	if after_death:
		death_salvage_resolved = false
	else:
		victory_resolution_started = false


func _on_victory_relics_selected(kept_entry_ids: Array[String], selected_relics: Array[Relic]) -> void:
	if not ProfileManager.replace_warehouse_after_victory(kept_entry_ids, selected_relics):
		_show_recovery_store_error()
		return
	_finish_victory_transition()


func _show_recovery_store_error() -> void:
	if current_view == null or current_view.get_child_count() == 0:
		return
	var panel: VictoryRelicSelectionPanel = current_view.get_child(0) as VictoryRelicSelectionPanel
	if panel != null:
		panel.show_store_error("装备保存失败，请重试。你的本局存档尚未删除。")


# 只有装备结算成功后，才删除本局存档并播放通关演出。
func _finish_victory_transition() -> void:
	SaveManager.delete_save()

	var victory_scene_resource := load(VICTORY_SCENE_PATH) as PackedScene
	if victory_scene_resource == null:
		return

	var victory_scene := victory_scene_resource.instantiate()
	if victory_scene == null:
		return

	_replace_current_view(victory_scene)


# 修整期结束后返回地图，并解锁下一批可进入房间。
func finish_rest_period() -> void:
	current_flow_state = FLOW_MAP
	level_up_checkpoint_locked = false
	battle_active = false
	_show_top_bar()
	_set_package_equipment_locked(false)
	if run_stats != null:
		_clear_locked_inventory_relics()
		run_stats.clear_free_relic_choices()
		run_stats.clear_battle_map_template()
		if world_condition_controller != null:
			world_condition_controller.roll_conditions_after_rest()
		# 金币只在当前修整期内使用，离开修整期后清零，下一次进入时重新发放奖励。
		run_stats.set_gold(0)
	level_up_reward_options.clear()
	_clear_current_view()
	_refresh_persistent_ui()

	if map != null:
		_advance_floor_after_boss()
		map.show_map()
		map.unlock_next_rooms()
	_save_current_run(true)


func _has_next_floor() -> bool:
	return run_stats != null and run_stats.current_floor_index + 1 < floor_configs.size()


func _get_current_floor_config() -> RunFloorConfig:
	if floor_configs.is_empty():
		return null
	return floor_configs[clampi(run_stats.current_floor_index, 0, floor_configs.size() - 1)]


## 中间层 Boss 沿用普通升级与修整流程，不提前执行整局通关奖励。
func _on_boss_battle_won() -> void:
	if _has_next_floor():
		change_to_level_up()
	else:
		EventBus.game_victory.emit()


## 离开 Boss 后的修整期才换层，保留原有升级奖励检查点的读档语义。
func _advance_floor_after_boss() -> void:
	if current_room == null or current_room.type != Room.Type.BOSS or not _has_next_floor():
		return
	run_stats.current_floor_index += 1
	current_room = null
	map.configure_floor(_get_current_floor_config())
	map.generate_new_map()


func _clear_locked_inventory_relics() -> void:
	if run_stats == null or run_stats.player_build == null:
		return

	run_stats.player_build.clear_locked_inventory_relics()


# 开局技能选完后，才正式露出地图，进入正常跑图流程。
func finish_starting_skill_select() -> void:
	current_flow_state = FLOW_MAP
	level_up_checkpoint_locked = false
	battle_active = false
	level_up_reward_options.clear()
	_clear_current_view()
	_refresh_persistent_ui()
	_close_persistent_panels()
	_show_top_bar()
	_set_package_equipment_locked(false)

	if map != null:
		map.show_map()
	_save_current_run(true)


# 统一连接 Run 关心的常驻信号。
func _connect_signals() -> void:
	if map != null and not map.room_selected.is_connected(_on_map_room_selected):
		map.room_selected.connect(_on_map_room_selected)
	
	if  not EventBus.battle_win.is_connected(change_to_level_up):
		EventBus.battle_win.connect(change_to_level_up)

	if not EventBus.battle_win_direct_to_rest.is_connected(_handle_battle_win_direct_to_rest):
		EventBus.battle_win_direct_to_rest.connect(_handle_battle_win_direct_to_rest)

	if not EventBus.game_victory.is_connected(change_to_victory_screen):
		EventBus.game_victory.connect(change_to_victory_screen)
	if not EventBus.boss_battle_won.is_connected(_on_boss_battle_won):
		EventBus.boss_battle_won.connect(_on_boss_battle_won)

	if not EventBus.battle_lost.is_connected(change_to_death_screen):
		EventBus.battle_lost.connect(change_to_death_screen)
	
	if not EventBus.event_room_exited.is_connected(_on_event_room_exited):
		EventBus.event_room_exited.connect(_on_event_room_exited)

	if not EventBus.relic_merged_to_levelup.is_connected(_on_relic_merged_to_levelup):
		EventBus.relic_merged_to_levelup.connect(_on_relic_merged_to_levelup)
	if not EventBus.relic_added.is_connected(_on_relic_received):
		EventBus.relic_added.connect(_on_relic_received)
	if not EventBus.relic_upgraded.is_connected(_on_relic_upgraded):
		EventBus.relic_upgraded.connect(_on_relic_upgraded)

	if not EventBus.inventory_update.is_connected(_on_player_relic_slots_changed):
		EventBus.inventory_update.connect(_on_player_relic_slots_changed)

	if not EventBus.equipment_update.is_connected(_on_player_relic_slots_changed):
		EventBus.equipment_update.connect(_on_player_relic_slots_changed)

	if package_button != null and not package_button.pressed.is_connected(_on_package_button_pressed):
		package_button.pressed.connect(_on_package_button_pressed)

	if pause_button != null and not pause_button.pressed.is_connected(_on_pause_button_pressed):
		pause_button.pressed.connect(_on_pause_button_pressed)

	if map_tag_button != null and not map_tag_button.pressed.is_connected(_on_map_tag_button_pressed):
		map_tag_button.pressed.connect(_on_map_tag_button_pressed)

	if debug_button != null and not debug_button.pressed.is_connected(_on_debug_button_pressed):
		debug_button.pressed.connect(_on_debug_button_pressed)

	if map_tag_config_panel != null:
		if not map_tag_config_panel.opened.is_connected(_on_map_tag_config_panel_opened):
			map_tag_config_panel.opened.connect(_on_map_tag_config_panel_opened)
		if not map_tag_config_panel.closed.is_connected(_on_map_tag_config_panel_closed):
			map_tag_config_panel.closed.connect(_on_map_tag_config_panel_closed)

	if debug_console != null:
		if not debug_console.opened.is_connected(_on_debug_console_opened):
			debug_console.opened.connect(_on_debug_console_opened)
		if not debug_console.closed.is_connected(_on_debug_console_closed):
			debug_console.closed.connect(_on_debug_console_closed)

	if not EventBus.gold_changed.is_connected(_save_current_run):
		EventBus.gold_changed.connect(_save_current_run)

	if not EventBus.free_relic_choice_changed.is_connected(_save_current_run):
		EventBus.free_relic_choice_changed.connect(_save_current_run)

	if not EventBus.level_up_reward_refresh_changed.is_connected(_save_current_run):
		EventBus.level_up_reward_refresh_changed.connect(_save_current_run)

	if not EventBus.shop_free_refresh_changed.is_connected(_save_current_run):
		EventBus.shop_free_refresh_changed.connect(_save_current_run)

	if not EventBus.map_tag_selection_changed.is_connected(_save_current_run):
		EventBus.map_tag_selection_changed.connect(_save_current_run)

	if not EventBus.skill_loadout_changed.is_connected(_save_current_run):
		EventBus.skill_loadout_changed.connect(_save_current_run)


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

	# 正式开局不再沿用地图测试种子，否则每次新游戏都会生成完全相同的事件序列。
	RunRng.start_new_run()
	current_flow_state = FLOW_STARTING_SKILL
	pending_flow_state = FLOW_STARTING_SKILL
	level_up_checkpoint_locked = false
	level_up_reward_options.clear()
	var build := startup.create_player_build()
	var shop := startup.create_shop()
	if shop != null and not startup.picked_character.shop_keeper_pool.is_empty():
		shop.shopkeeper = RunRng.pick(startup.picked_character.shop_keeper_pool)
	var shop_config := startup.create_shop_config()
	run_stats.setup_new_run(build, shop, shop_config, startup.picked_character)
	# 角色原始资源已被复制为本局构筑后，再应用局外永久修正器。
	ProfileManager.apply_new_run_modifiers(run_stats)
	# 只有全新开局消费大厅携带槽；继续游戏会直接读取已经写入存档的构筑与惩罚。
	pending_received_relic = ProfileManager.consume_selected_relic_for_new_run(run_stats)
	# 快照包含本次开局的局外奖励和携带惩罚，重置不能绕过这些固定规则。
	if build != null and build.player_stats != null:
		build.initial_stats = build.player_stats.duplicate(true) as StatsData


# 目前续档逻辑还没展开，这里先做最小兼容。
func _initialize_continued_run(_startup: RunStartup) -> void:
	var save_data: Dictionary = SaveManager.load_save_data()
	if save_data.is_empty():
		push_warning("没有可用存档，无法继续游戏。")
		return

	SaveManager.restore_rng(save_data)
	var loaded_run_stats: RunStats = SaveManager.build_run_stats_from_save(save_data)
	if loaded_run_stats == null:
		push_warning("存档中的 RunStats 无法恢复。")
		return

	run_stats = loaded_run_stats
	debug_next_battle_map_template_path = str(save_data.get("debug_next_battle_map_template_path", ""))
	_ensure_default_tag_effect_selection()
	pending_map_save_data = SaveManager.get_saved_map_data(save_data)
	pending_current_room_data = SaveManager.get_saved_current_room_data(save_data)
	pending_flow_state = SaveManager.get_saved_flow_state(save_data)
	current_flow_state = pending_flow_state
	if current_flow_state == FLOW_EVENT_ROOM:
		event_entry_checkpoint.restore(save_data)
	level_up_checkpoint_locked = current_flow_state == FLOW_LEVEL_UP
	level_up_reward_options = SaveManager.get_saved_level_up_rewards(save_data)


# 把 run_stats.player_build 绑定给修整期常驻的属性与装备管理节点。
func _initialize_runtime_proxy() -> void:
	if player_build_proxy == null or run_stats == null or run_stats.player_build == null:
		return

	player_build_proxy.bind_player_build(run_stats.player_build)
	# 续档先重挂装备容量，再校验启用标签，避免把额外五个槽误当成超限删掉。
	run_stats.trim_enabled_map_tags_to_limit()


# 初始化 Run 下常驻的背包和属性面板 UI。
func _initialize_persistent_ui() -> void:
	if run_stats == null or run_stats.player_build == null:
		return

	if package_ui != null:
		package_ui.open_bag(run_stats.player_build.player_inventory, run_stats.player_build.player_equipment)
		package_ui.set_equipment_locked(false)
		package_ui.close_bag()

	if attributes_panel != null:
		attributes_panel.stats_controller = _get_runtime_stats_controller()
		attributes_panel.setup()
		attributes_panel.close_panel()

	if skill_overview_panel != null:
		skill_overview_panel.setup(run_stats.player_build)
		skill_overview_panel.close_panel()

	if tag_effect_ui != null:
		tag_effect_ui.close_panel()

	if map_tag_config_panel != null:
		map_tag_config_panel.bind_run_stats(run_stats)
		map_tag_config_panel.close_panel()

	if debug_button != null:
		debug_button.visible = _is_debug_console_available()
	if debug_console != null:
		debug_console.bind_run(self)
		debug_console.close_panel()


func _initialize_tag_effect_controller() -> void:
	if run_stats == null or run_stats.player_build == null or player_build_proxy == null:
		return

	if tag_effect_controller == null:
		tag_effect_controller = TagEffectController.new()
		tag_effect_controller.name = "TagEffectController"
		add_child(tag_effect_controller)

	tag_effect_controller.bind_context(run_stats, player_build_proxy, _load_default_tag_effects())
	if tag_effect_ui != null:
		tag_effect_ui.bind_controller(tag_effect_controller)


# 天气与环境是 Run 级常驻规则，不随地图、事件房或战斗场景切换而销毁。
func _initialize_world_condition_controller() -> void:
	if run_stats == null:
		return
	if world_condition_controller == null:
		world_condition_controller = WorldConditionController.new()
		world_condition_controller.name = "WorldConditionController"
		add_child(world_condition_controller)
	world_condition_controller.bind_run_stats(run_stats)


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

	if tag_effect_ui != null:
		if package_ui != null and package_ui.visible:
			tag_effect_ui.open_panel()
		else:
			tag_effect_ui.close_panel()

	if tag_effect_controller != null:
		tag_effect_controller.refresh()

	if map_tag_config_panel != null:
		map_tag_config_panel.bind_run_stats(run_stats)
	if debug_console != null:
		debug_console.bind_run(self)


# 生成并显示本局地图。
func _initialize_map() -> void:
	if map == null:
		return
	map.bind_run_stats(run_stats)
	map.configure_floor(_get_current_floor_config())

	if pending_map_save_data.is_empty():
		map.generate_new_map()
	else:
		map.load_from_save_data(pending_map_save_data)
		current_room = _find_room_from_map_data(pending_current_room_data)
	map.show_map()


# 继续游戏时按照存档中的流程状态恢复 CurrentView，而不是一律停在地图。
func _restore_saved_flow_view() -> void:
	match pending_flow_state:
		FLOW_EVENT_ROOM:
			if current_room != null:
				if event_entry_checkpoint.should_replay_event():
					_open_event_room(current_room)
				else:
					_open_battle_scene(current_room)
		FLOW_LEVEL_UP:
			change_to_level_up()
		FLOW_STARTING_SKILL:
			change_to_starting_skill_select()
		FLOW_REST_PERIOD:
			change_to_rest_period(false)
		_:
			current_flow_state = FLOW_MAP


# 优先读取角色选择场景传来的临时启动数据，其次再使用场景上兜底的导出资源。
func _resolve_startup() -> RunStartup:
	if pending_startup != null:
		var startup := pending_startup
		pending_startup = null
		return startup

	return run_startup


func _ensure_default_tag_effect_selection() -> void:
	if run_stats == null:
		return

	var default_effects: Array[TagEffect] = _load_default_tag_effects()
	if run_stats.selected_tag_effects.is_empty():
		run_stats.selected_tag_effects = default_effects
		return

	_append_missing_default_tag_effects(run_stats.selected_tag_effects, default_effects)


func _append_missing_default_tag_effects(selected_effects: Array[TagEffect], default_effects: Array[TagEffect]) -> void:
	var used_tag_keys: Array[String] = []
	for effect: TagEffect in selected_effects:
		if effect == null:
			continue
		var tag_key: String = effect.get_tag_key()
		if tag_key.is_empty() or used_tag_keys.has(tag_key):
			continue
		used_tag_keys.append(tag_key)

	for default_effect: TagEffect in default_effects:
		if default_effect == null:
			continue
		var default_tag_key: String = default_effect.get_tag_key()
		if default_tag_key.is_empty() or used_tag_keys.has(default_tag_key):
			continue

		# 新增 tag effect 时兼容旧存档：只补缺失 tag，不覆盖玩家已经选择的同 tag 效果。
		selected_effects.append(default_effect)
		used_tag_keys.append(default_tag_key)


func _load_default_tag_effects() -> Array[TagEffect]:
	var database := TAG_EFFECT_DATABASE.duplicate(true) as TagEffectDatabase
	database.load_selection()
	return database.get_selected_effects()


# 记录当前被选择的房间，并进入它的事件场景。
func _on_map_room_selected(room: Room) -> void:
	# 地图节点生成时还不知道玩家届时的背包；进入事件节点时再按当前装备筛选事件。
	if room != null and room.type == Room.Type.EVENT and map != null and map.map_generator.event_room_pool != null:
		var rolled_event: PackedScene = map.map_generator.event_room_pool.get_random(run_stats)
		if rolled_event != null:
			room.event_scene = rolled_event
	_apply_debug_next_event_override(room)
	current_room = room
	current_flow_state = FLOW_EVENT_ROOM
	level_up_checkpoint_locked = false
	battle_active = false
	# 在场景 _ready/setup 及任何事件奖励执行前冻结整个入房状态。
	event_entry_checkpoint.capture(SaveManager.build_run_snapshot(self))
	_save_current_run(true)
	_open_event_room(room)


## 设置下一次点击地图房间时使用的事件，仅供局内调试台调用。
func set_debug_next_event_scene(event_scene: PackedScene) -> bool:
	if event_scene == null:
		return false
	debug_next_event_scene = event_scene
	return true


func clear_debug_next_event_scene() -> void:
	debug_next_event_scene = null


func get_debug_next_event_scene() -> PackedScene:
	return debug_next_event_scene


func can_debug_battle_map_override() -> bool:
	return true


func set_debug_next_battle_map_template(path: String) -> bool:
	if not can_debug_battle_map_override():
		return false
	var clean_path: String = path.strip_edges()
	if not DebugBattleMapCatalog.is_battle_map(clean_path):
		return false
	debug_next_battle_map_template_path = clean_path
	_persist_debug_battle_map_override()
	return true


func clear_debug_next_battle_map_template() -> void:
	if not can_debug_battle_map_override():
		return
	debug_next_battle_map_template_path = ""
	_persist_debug_battle_map_override()


func get_debug_next_battle_map_template() -> String:
	return debug_next_battle_map_template_path


func _persist_debug_battle_map_override() -> void:
	if not can_debug_battle_map_override():
		return
	# 只修改存档中的调试配置，不能把事件奖励或修整期操作写进受保护的检查点。
	if not SaveManager.save_debug_battle_map_override(debug_next_battle_map_template_path):
		push_warning("测试地图配置已在本次运行中生效，但当前存档无法更新。")


func _prepare_debug_battle_map_override(play_scene: Node) -> void:
	if run_stats == null or not run_stats.current_battle_map_template_path.is_empty():
		return
	if debug_next_battle_map_template_path.is_empty():
		return
	if not bool(play_scene.get("use_battle_map_templates")):
		push_warning("本场禁用了地图模板，测试地图保留至下一场启用模板的战斗。")
		return
	var path: String = debug_next_battle_map_template_path
	debug_next_battle_map_template_path = ""
	if not DebugBattleMapCatalog.is_battle_map(path):
		push_warning("测试地图已丢失或不再是BattleMap，取消本次覆盖：%s" % path)
		return
	# 复用现有的已选模板优先级；继续游戏时也会恢复这一条路径，不重新抽图。
	run_stats.current_battle_map_template_path = path


func _apply_debug_next_event_override(room: Room) -> void:
	if room == null or debug_next_event_scene == null:
		return

	room.event_scene = debug_next_event_scene
	debug_next_event_scene = null


# 事件场景点击离开后，进入该房间绑定的战斗场景。
func _on_event_room_exited() -> void:
	if current_room == null:
		return

	_open_battle_scene(current_room)


## 接收/升级效果与商店合成奖励分开；不把直接强化误当作合成。
func _on_relic_received(relic: Relic, receiver: PlayerBuild) -> void:
	if relic != null and run_stats != null and receiver == run_stats.player_build:
		relic.notify_added(player_build_proxy, player_build_proxy.relic_controller)


func _on_relic_upgraded(relic: Relic, receiver: PlayerBuild) -> void:
	if relic != null and run_stats != null and receiver == run_stats.player_build:
		relic.notify_upgraded(player_build_proxy, player_build_proxy.relic_controller)


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
	if battle_active:
		return
	_save_current_run()


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
		if tag_effect_ui != null:
			tag_effect_ui.close_panel()
	else:
		package_ui.open_bag(run_stats.player_build.player_inventory, run_stats.player_build.player_equipment)
		if skill_overview_panel != null:
			skill_overview_panel.setup(run_stats.player_build)
			skill_overview_panel.open_panel()
		if tag_effect_ui != null:
			tag_effect_ui.open_panel()
		if attributes_panel != null and not _is_level_up_scene_open():
			attributes_panel.stats_controller = _get_runtime_stats_controller()
			attributes_panel.setup()
			attributes_panel.open_panel()
		elif attributes_panel != null:
			attributes_panel.close_panel()


# 地图标签配置只影响后续战斗地图生成；战斗中不允许调整，避免误以为当前地图会立刻刷新。
func _on_map_tag_button_pressed() -> void:
	if map_tag_config_panel == null:
		return
	if battle_active:
		push_warning("战斗中无法调整地图标签配置。")
		return

	map_tag_config_panel.bind_run_stats(run_stats)
	map_tag_config_panel.toggle_panel()


## DebugConsole 仅供开发时直接验证构筑、装备和技能链路使用。
func _on_debug_button_pressed() -> void:
	if debug_console == null or not _is_debug_console_available():
		return

	debug_console.bind_run(self)
	debug_console.toggle_panel()


func _on_map_tag_config_panel_opened() -> void:
	# 地图标签面板是一个独占配置界面，打开时锁住 Run 顶栏其它按钮，避免暂停菜单和配置面板同时抢状态。
	_set_top_bar_buttons_locked_by_map_tag_panel(true)


func _on_map_tag_config_panel_closed() -> void:
	_set_top_bar_buttons_locked_by_map_tag_panel(false)


func _on_debug_console_opened() -> void:
	_set_top_bar_buttons_locked_by_debug_console(true)


func _on_debug_console_closed() -> void:
	_set_top_bar_buttons_locked_by_debug_console(false)


func _set_top_bar_buttons_locked_by_map_tag_panel(locked: bool) -> void:
	if package_button != null:
		package_button.disabled = locked
	if map_tag_button != null:
		map_tag_button.disabled = locked
	if debug_button != null:
		debug_button.disabled = locked
	if pause_button != null:
		pause_button.disabled = locked


func _set_top_bar_buttons_locked_by_debug_console(locked: bool) -> void:
	if package_button != null:
		package_button.disabled = locked
	if map_tag_button != null:
		map_tag_button.disabled = locked
	if debug_button != null:
		debug_button.disabled = locked
	if pause_button != null:
		pause_button.disabled = locked


# Run 顶栏的暂停按钮负责全局暂停，并显示“继续 / 退出到主菜单”的选择。

func _on_pause_button_pressed() -> void:
	if pause_menu == null:
		return

	_save_current_run()
	EventBus.game_paused.emit(true)
	get_tree().paused = true
	pause_menu.show()


func _open_package_for_rest_period() -> void:
	if package_ui == null or run_stats == null or run_stats.player_build == null:
		return

	package_ui.open_bag(run_stats.player_build.player_inventory, run_stats.player_build.player_equipment)
	if skill_overview_panel != null:
		skill_overview_panel.setup(run_stats.player_build)
		skill_overview_panel.open_panel()
	if tag_effect_ui != null:
		tag_effect_ui.open_panel()
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

	_show_top_bar()
	battle_active = false
	_set_package_equipment_locked(false)
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

	_prepare_debug_battle_map_override(play_scene)
	_show_top_bar()
	battle_active = true
	_set_package_equipment_locked(true)
	if map_tag_config_panel != null:
		map_tag_config_panel.close_panel()
	if play_scene.has_method("setup_run_battle"):
		play_scene.setup_run_battle(run_stats, room.battle_stats)
	else:
		_bind_run_stats(play_scene)

	_replace_current_view(play_scene)
	if world_condition_controller != null:
		world_condition_controller.apply_to_battle(play_scene)
	if map != null:
		map.hide_map()
	# 只补记已经抽中的地图模板，构筑、金币和随机数仍使用入房检查点。
	_save_current_run(true)


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
	if tag_effect_ui != null:
		tag_effect_ui.close_panel()
	if map_tag_config_panel != null:
		map_tag_config_panel.close_panel()
	if debug_console != null:
		debug_console.close_panel()


func _show_top_bar() -> void:
	if top_bar != null:
		top_bar.show()


func _hide_top_bar() -> void:
	if top_bar != null:
		top_bar.hide()


func _set_package_equipment_locked(locked: bool) -> void:
	if package_ui != null:
		package_ui.set_equipment_locked(locked)


## 调试台修改 PlayerBuild 后，通过这里同步常驻 UI、战斗中的实际技能控制器和存档。
func refresh_debug_runtime_state() -> void:
	if run_stats == null or run_stats.player_build == null:
		return

	_refresh_persistent_ui()
	var active_scene: Node = _get_current_scene()
	var play_scene: PlayScene = active_scene as PlayScene
	if play_scene != null:
		if play_scene.player != null and play_scene.player.skill_controller != null:
			play_scene.player.skill_controller.refresh_all_skills()
		if play_scene.has_method("_refresh_skill_ui"):
			play_scene._refresh_skill_ui()
		if play_scene.has_method("_refresh_consumable_ui"):
			play_scene._refresh_consumable_ui()

	_save_current_run(true)


## 调试修改本局基础值后，同时重算常驻代理与当前战斗角色，再保存检查点。
func apply_debug_base_stat(stat_name: StringName, value: float) -> bool:
	if run_stats == null or run_stats.player_build == null or run_stats.player_build.player_stats == null:
		return false
	var build: PlayerBuild = run_stats.player_build
	var play_scene: PlayScene = _get_current_scene() as PlayScene
	var battle_player: Player = play_scene.player if play_scene != null else null
	var previous_controller: StatsController = battle_player.stats_controller if battle_player != null else _get_runtime_stats_controller()
	var previous_max_health: float = previous_controller.get_stat(&"max_health") if previous_controller != null else 0.0
	var health_ratio: float = clampf(build.current_health / previous_max_health, 0.0, 1.0) if previous_max_health > 0.0 else 1.0
	var previous_energy: float = build.current_energy
	var allowed_stats: Array[StringName] = StatsController.PRIMARY_STATS.duplicate()
	allowed_stats.append_array([&"base_max_health", &"base_max_energy", &"base_move_speed", &"base_energy_regen_tick_value", &"base_crit_chance", &"base_dodge_rate"])
	if not allowed_stats.has(stat_name):
		return false
	var stats_data: StatsData = build.player_stats
	stats_data.set(stat_name, int(roundf(value)) if StatsController.PRIMARY_STATS.has(stat_name) else value)
	_refresh_persistent_ui()
	if battle_player != null and battle_player.stats_controller != null:
		battle_player.stats_controller.bind_player_build(build)
	var final_controller: StatsController = battle_player.stats_controller if battle_player != null else _get_runtime_stats_controller()
	if final_controller != null:
		build.current_health = final_controller.get_stat(&"max_health") * health_ratio
		build.current_energy = minf(previous_energy, final_controller.get_stat(&"max_energy"))
		_sync_debug_runtime_resources(_get_runtime_stats_controller(), build)
		if battle_player != null:
			_sync_debug_runtime_resources(battle_player.stats_controller, build)
			EventBus.player_health_changed.emit(battle_player.current_health, battle_player.max_health)
			EventBus.player_energy_changed.emit(battle_player.current_energy, battle_player.max_energy)
	_save_current_run(true)
	return true


func _sync_debug_runtime_resources(controller: StatsController, build: PlayerBuild) -> void:
	if controller == null:
		return
	controller.current_health = minf(build.current_health, controller.get_stat(&"max_health"))
	controller.current_energy = minf(build.current_energy, controller.get_stat(&"max_energy"))
	if controller.entity != null:
		controller.entity.current_health = controller.current_health
		controller.entity.current_energy = controller.current_energy


## 调试天气与环境后刷新地图摘要；若正处于战斗，立即重新应用环境视觉效果。
func apply_debug_world_conditions(weather: WorldConditionData, weather_rooms: int, environment: WorldConditionData, environment_rooms: int) -> bool:
	if world_condition_controller == null:
		return false
	if not world_condition_controller.set_debug_conditions(weather, weather_rooms, environment, environment_rooms):
		return false
	var play_scene: PlayScene = _get_current_scene() as PlayScene
	if play_scene != null:
		world_condition_controller.apply_to_battle(play_scene)
	_save_current_run(true)
	return true


func _is_debug_console_available() -> bool:
	return enable_debug_console and OS.is_debug_build()


# 获取 Run 下常驻的运行时属性控制器，供属性面板等 UI 读取。
func _get_runtime_stats_controller() -> StatsController:
	if player_build_proxy == null:
		return null

	return player_build_proxy.get_stats_controller()


func _get_runtime_skill_controller() -> SkillController:
	if player_build_proxy == null:
		return null

	return player_build_proxy.get_skill_controller()


func _find_room_from_map_data(data: Dictionary) -> Room:
	if map == null or data.is_empty():
		return null

	var row := int(data.get("row", -1))
	var column := int(data.get("column", -1))
	for floor in map.map_data:
		for room: Room in floor:
			if room.row == row and room.column == column:
				return room
	return null


# 所有“本局状态已经变动”的关键节点统一走这里保存，避免每个系统单独知道存档细节。
func save_current_run() -> void:
	_save_current_run()


# LevelUPController 刷新奖励后，把新结果写回 Run，保证当前升级界面检查点可存档恢复。
func update_level_up_reward_options(new_rewards: Array[LevelUpReward], force_save: bool = true) -> void:
	level_up_reward_options = new_rewards.duplicate()
	_save_current_run(force_save)


func _save_current_run(force: bool = false) -> void:
	if run_stats == null:
		return
	if level_up_checkpoint_locked and not force:
		return
	# 普通事件保存无需重复落盘；强制保存也只能通过 SaveManager 读取入房快照。
	if current_flow_state == FLOW_EVENT_ROOM and not force:
		return
	if current_flow_state != FLOW_EVENT_ROOM:
		event_entry_checkpoint.clear()

	SaveManager.save_run(self)


## 保存入口统一读取入房快照，不允许强制保存绕过检查点保护。
func get_event_checkpoint_save_data() -> Dictionary:
	if run_stats == null or current_room == null:
		return {}
	var room_key: Dictionary = {"row": current_room.row, "column": current_room.column}
	var snapshot: Dictionary = event_entry_checkpoint.build_save_data(room_key, run_stats.current_floor_index, run_stats.current_battle_map_template_path)
	if not snapshot.is_empty():
		snapshot["debug_next_battle_map_template_path"] = debug_next_battle_map_template_path
	return snapshot
