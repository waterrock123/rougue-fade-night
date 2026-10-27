## 游戏内开发调试面板。
## 仅在 Debug 构建中由 Run 顶栏开放；所有授予操作仍走 PlayerBuild 和 SkillController，
## 以便背包合成、技能栏刷新、被动效果等正常游戏链路都能一并验证。
class_name DebugConsole
extends Control

signal opened
signal closed

const RELIC_ROOT_PATH: String = "res://relics"
const ACTIVE_SKILL_ROOT_PATH: String = "res://activate_skill"
const PASSIVE_SKILL_ROOT_PATH: String = "res://passive_skill"
const EVENT_ROOM_ROOT_PATH: String = "res://event_room"
const EXCLUDED_EVENT_SCENE_FILES: Array[String] = ["event_button.tscn", "event_room.tscn"]
const STAT_FIELDS := [
	{"key": &"strength", "name": "力量", "integer": true},
	{"key": &"dexterity", "name": "敏捷", "integer": true},
	{"key": &"intelligence", "name": "智力", "integer": true},
	{"key": &"constitution", "name": "体质", "integer": true},
	{"key": &"speed", "name": "速度", "integer": true},
	{"key": &"charm", "name": "魅力", "integer": true},
	{"key": &"luck", "name": "幸运", "integer": true},
	{"key": &"base_max_health", "name": "基础最大生命", "integer": false},
	{"key": &"base_max_energy", "name": "基础最大能量", "integer": false},
	{"key": &"base_move_speed", "name": "基础移动速度", "integer": false},
	{"key": &"base_energy_regen_tick_value", "name": "基础能量恢复", "integer": false},
	{"key": &"base_crit_chance", "name": "基础暴击率", "integer": false},
	{"key": &"base_dodge_rate", "name": "基础闪避率", "integer": false},
]

enum SkillFilter {
	ALL,
	ACTIVE,
	PASSIVE,
}

@export var pause_game_while_open: bool = true
@export var allow_in_release: bool = false

@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Header/CloseButton
@onready var reload_button: Button = $Panel/MarginContainer/VBoxContainer/Header/ReloadButton
@onready var relic_search: LineEdit = $Panel/MarginContainer/VBoxContainer/Content/RelicColumn/VBoxContainer/SearchRow/RelicSearch
@onready var relic_amount: SpinBox = $Panel/MarginContainer/VBoxContainer/Content/RelicColumn/VBoxContainer/SearchRow/RelicAmount
@onready var relic_list: ItemList = $Panel/MarginContainer/VBoxContainer/Content/RelicColumn/VBoxContainer/RelicList
@onready var add_relic_button: Button = $Panel/MarginContainer/VBoxContainer/Content/RelicColumn/VBoxContainer/AddRelicButton
@onready var skill_search: LineEdit = $Panel/MarginContainer/VBoxContainer/Content/SkillColumn/VBoxContainer/SearchRow/SkillSearch
@onready var skill_filter: OptionButton = $Panel/MarginContainer/VBoxContainer/Content/SkillColumn/VBoxContainer/SearchRow/SkillFilter
@onready var skill_list: ItemList = $Panel/MarginContainer/VBoxContainer/Content/SkillColumn/VBoxContainer/SkillList
@onready var add_skill_button: Button = $Panel/MarginContainer/VBoxContainer/Content/SkillColumn/VBoxContainer/AddSkillButton
@onready var event_room_option: OptionButton = $Panel/MarginContainer/VBoxContainer/EventOverrideRow/EventRoomOption
@onready var set_next_event_button: Button = $Panel/MarginContainer/VBoxContainer/EventOverrideRow/SetNextEventButton
@onready var clear_next_event_button: Button = $Panel/MarginContainer/VBoxContainer/EventOverrideRow/ClearNextEventButton
@onready var event_override_status: Label = $Panel/MarginContainer/VBoxContainer/EventOverrideRow/EventOverrideStatus
@onready var battle_map_option: OptionButton = $Panel/MarginContainer/VBoxContainer/BattleMapOverride/MapRow/BattleMapOption
@onready var set_battle_map_button: Button = $Panel/MarginContainer/VBoxContainer/BattleMapOverride/MapRow/SetBattleMapButton
@onready var clear_battle_map_button: Button = $Panel/MarginContainer/VBoxContainer/BattleMapOverride/MapRow/ClearBattleMapButton
@onready var reload_battle_maps_button: Button = $Panel/MarginContainer/VBoxContainer/BattleMapOverride/MapRow/ReloadBattleMapsButton
@onready var battle_map_status: Label = $Panel/MarginContainer/VBoxContainer/BattleMapOverride/MapStatus
@onready var stat_option: OptionButton = $Panel/MarginContainer/VBoxContainer/StatsDebugRow/StatOption
@onready var stat_value: SpinBox = $Panel/MarginContainer/VBoxContainer/StatsDebugRow/StatValue
@onready var apply_stat_button: Button = $Panel/MarginContainer/VBoxContainer/StatsDebugRow/ApplyStatButton
@onready var weather_option: OptionButton = $Panel/MarginContainer/VBoxContainer/WorldConditionRow/WeatherOption
@onready var weather_rooms: SpinBox = $Panel/MarginContainer/VBoxContainer/WorldConditionRow/WeatherRooms
@onready var environment_option: OptionButton = $Panel/MarginContainer/VBoxContainer/WorldConditionRow/EnvironmentOption
@onready var environment_rooms: SpinBox = $Panel/MarginContainer/VBoxContainer/WorldConditionRow/EnvironmentRooms
@onready var apply_world_condition_button: Button = $Panel/MarginContainer/VBoxContainer/WorldConditionRow/ApplyWorldConditionButton
@onready var selection_detail: RichTextLabel = $Panel/MarginContainer/VBoxContainer/SelectionDetail
@onready var feedback_label: Label = $Panel/MarginContainer/VBoxContainer/FeedbackLabel

var run: Run
var relic_catalog: Array[Relic] = []
var skill_catalog: Array[SkillData] = []
var event_room_catalog: Array[PackedScene] = []
var paused_by_console: bool = false
var battle_map_catalog_paths: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_setup_skill_filter()
	_setup_stat_fields()
	_connect_controls()
	_reload_catalogs()


func bind_run(new_run: Run) -> void:
	run = new_run
	_refresh_event_override_status()
	_refresh_battle_map_override_status()
	_refresh_debug_values()


func can_open() -> bool:
	return allow_in_release or OS.is_debug_build()


func open_panel() -> void:
	if not can_open():
		return

	show()
	move_to_front()
	_refresh_lists()
	_refresh_event_override_status()
	# 只在第一次打开或发现新增文件时加载地图元数据；不会实例化地图。
	if run != null and run.can_debug_battle_map_override() and (battle_map_option.item_count == 0 or DebugBattleMapCatalog.collect_paths() != battle_map_catalog_paths):
		_reload_battle_map_catalog()
	_refresh_battle_map_override_status()
	_refresh_debug_values()
	_set_feedback("开发调试模式：修改会直接写入当前 Run 数据。")
	_pause_game_for_console()
	opened.emit()


func close_panel() -> void:
	if not visible:
		return

	hide()
	_resume_game_after_console()
	closed.emit()


func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open_panel()


func _exit_tree() -> void:
	_resume_game_after_console()


func _setup_skill_filter() -> void:
	if skill_filter == null:
		return

	skill_filter.clear()
	skill_filter.add_item("全部技能", SkillFilter.ALL)
	skill_filter.add_item("主动技能", SkillFilter.ACTIVE)
	skill_filter.add_item("被动技能", SkillFilter.PASSIVE)


func _setup_stat_fields() -> void:
	stat_option.clear()
	for field: Dictionary in STAT_FIELDS:
		stat_option.add_item(String(field["name"]))
		stat_option.set_item_metadata(stat_option.item_count - 1, field["key"])
	if stat_option.item_count > 0:
		stat_option.select(0)


func _connect_controls() -> void:
	if close_button != null and not close_button.pressed.is_connected(close_panel):
		close_button.pressed.connect(close_panel)
	if reload_button != null and not reload_button.pressed.is_connected(_on_reload_button_pressed):
		reload_button.pressed.connect(_on_reload_button_pressed)
	if relic_search != null and not relic_search.text_changed.is_connected(_on_relic_search_changed):
		relic_search.text_changed.connect(_on_relic_search_changed)
	if skill_search != null and not skill_search.text_changed.is_connected(_on_skill_search_changed):
		skill_search.text_changed.connect(_on_skill_search_changed)
	if skill_filter != null and not skill_filter.item_selected.is_connected(_on_skill_filter_selected):
		skill_filter.item_selected.connect(_on_skill_filter_selected)
	if add_relic_button != null and not add_relic_button.pressed.is_connected(_on_add_relic_pressed):
		add_relic_button.pressed.connect(_on_add_relic_pressed)
	if add_skill_button != null and not add_skill_button.pressed.is_connected(_on_add_skill_pressed):
		add_skill_button.pressed.connect(_on_add_skill_pressed)
	if set_next_event_button != null and not set_next_event_button.pressed.is_connected(_on_set_next_event_pressed):
		set_next_event_button.pressed.connect(_on_set_next_event_pressed)
	if clear_next_event_button != null and not clear_next_event_button.pressed.is_connected(_on_clear_next_event_pressed):
		clear_next_event_button.pressed.connect(_on_clear_next_event_pressed)
	stat_option.item_selected.connect(_on_stat_option_selected)
	apply_stat_button.pressed.connect(_on_apply_stat_pressed)
	apply_world_condition_button.pressed.connect(_on_apply_world_condition_pressed)
	set_battle_map_button.pressed.connect(_on_set_battle_map_pressed)
	clear_battle_map_button.pressed.connect(_on_clear_battle_map_pressed)
	reload_battle_maps_button.pressed.connect(_reload_battle_map_catalog)
	if relic_list != null:
		if not relic_list.item_selected.is_connected(_on_relic_selected):
			relic_list.item_selected.connect(_on_relic_selected)
		if not relic_list.item_activated.is_connected(_on_relic_activated):
			relic_list.item_activated.connect(_on_relic_activated)
	if skill_list != null:
		if not skill_list.item_selected.is_connected(_on_skill_selected):
			skill_list.item_selected.connect(_on_skill_selected)
		if not skill_list.item_activated.is_connected(_on_skill_activated):
			skill_list.item_activated.connect(_on_skill_activated)


## 递归扫描静态资源目录。调试工具只读取 .tres/.res，忽略场景和导入文件。
func _reload_catalogs() -> void:
	relic_catalog.clear()
	skill_catalog.clear()
	event_room_catalog.clear()

	var relic_paths: Array[String] = []
	_collect_resource_paths(RELIC_ROOT_PATH, relic_paths)
	for resource_path: String in relic_paths:
		var resource: Resource = ResourceLoader.load(resource_path)
		var relic: Relic = resource as Relic
		if relic != null:
			relic_catalog.append(relic)

	var active_skill_paths: Array[String] = []
	_collect_resource_paths(ACTIVE_SKILL_ROOT_PATH, active_skill_paths)
	_collect_skill_resources(active_skill_paths)

	var passive_skill_paths: Array[String] = []
	_collect_resource_paths(PASSIVE_SKILL_ROOT_PATH, passive_skill_paths)
	_collect_skill_resources(passive_skill_paths)

	relic_catalog.sort_custom(_sort_relics)
	skill_catalog.sort_custom(_sort_skills)
	_reload_event_room_catalog()
	_refresh_lists()
	_refresh_event_room_options()
	_refresh_event_override_status()


# 扫描事件房间场景，让以后新增事件时无需再手动维护调试台列表。
func _reload_event_room_catalog() -> void:
	var event_scene_paths: Array[String] = []
	_collect_scene_paths(EVENT_ROOM_ROOT_PATH, event_scene_paths)
	for scene_path: String in event_scene_paths:
		if EXCLUDED_EVENT_SCENE_FILES.has(scene_path.get_file()):
			continue
		var event_scene := ResourceLoader.load(scene_path) as PackedScene
		if event_scene != null:
			event_room_catalog.append(event_scene)

	event_room_catalog.sort_custom(_sort_event_scenes)


func _collect_scene_paths(folder_path: String, result: Array[String]) -> void:
	if folder_path.is_empty() or not DirAccess.dir_exists_absolute(folder_path):
		return

	var file_names: PackedStringArray = DirAccess.get_files_at(folder_path)
	file_names.sort()
	for file_name: String in file_names:
		if file_name.get_extension().to_lower() == "tscn":
			result.append(folder_path.path_join(file_name))

	var directory_names: PackedStringArray = DirAccess.get_directories_at(folder_path)
	directory_names.sort()
	for directory_name: String in directory_names:
		if not directory_name.begins_with("."):
			_collect_scene_paths(folder_path.path_join(directory_name), result)


func _sort_event_scenes(first: PackedScene, second: PackedScene) -> bool:
	return _get_event_scene_display_name(first).naturalnocasecmp_to(_get_event_scene_display_name(second)) < 0


func _collect_resource_paths(folder_path: String, result: Array[String]) -> void:
	if folder_path.is_empty() or not DirAccess.dir_exists_absolute(folder_path):
		return

	var file_names: PackedStringArray = DirAccess.get_files_at(folder_path)
	file_names.sort()
	for file_name: String in file_names:
		var extension: String = file_name.get_extension().to_lower()
		if extension != "tres" and extension != "res":
			continue
		result.append(folder_path.path_join(file_name))

	var directory_names: PackedStringArray = DirAccess.get_directories_at(folder_path)
	directory_names.sort()
	for directory_name: String in directory_names:
		if directory_name.begins_with("."):
			continue
		_collect_resource_paths(folder_path.path_join(directory_name), result)


func _collect_skill_resources(paths: Array[String]) -> void:
	for resource_path: String in paths:
		var resource: Resource = ResourceLoader.load(resource_path)
		var skill_data: SkillData = resource as SkillData
		if skill_data != null:
			skill_catalog.append(skill_data)


func _sort_relics(first: Relic, second: Relic) -> bool:
	if first.level != second.level:
		return first.level < second.level
	return first.relic_name.naturalnocasecmp_to(second.relic_name) < 0


func _sort_skills(first: SkillData, second: SkillData) -> bool:
	var first_type: int = _get_skill_type_order(first)
	var second_type: int = _get_skill_type_order(second)
	if first_type != second_type:
		return first_type < second_type
	return first.skill_name.naturalnocasecmp_to(second.skill_name) < 0


func _get_skill_type_order(skill_data: SkillData) -> int:
	if skill_data is ActiveSkillData:
		return 0
	if skill_data is PassiveSkillData:
		return 1
	return 2


func _refresh_lists() -> void:
	_refresh_relic_list()
	_refresh_skill_list()


func _refresh_relic_list() -> void:
	if relic_list == null:
		return

	relic_list.clear()
	var query: String = relic_search.text.strip_edges().to_lower() if relic_search != null else ""
	for relic: Relic in relic_catalog:
		if relic == null or not _matches_relic_query(relic, query):
			continue

		var item_index: int = relic_list.get_item_count()
		relic_list.add_item(_get_relic_list_text(relic), relic.icon, true)
		relic_list.set_item_metadata(item_index, relic)

	# 列表构建完成后只刷新一次选中详情，避免大量资源时重复触发 UI 更新。
	_select_first_relic()


func _refresh_skill_list() -> void:
	if skill_list == null:
		return

	skill_list.clear()
	var query: String = skill_search.text.strip_edges().to_lower() if skill_search != null else ""
	var filter_type: int = skill_filter.get_selected_id() if skill_filter != null else SkillFilter.ALL
	for skill_data: SkillData in skill_catalog:
		if skill_data == null or not _matches_skill_filter(skill_data, filter_type):
			continue
		if not _matches_skill_query(skill_data, query):
			continue

		var item_index: int = skill_list.get_item_count()
		skill_list.add_item(_get_skill_list_text(skill_data), skill_data.icon, true)
		skill_list.set_item_metadata(item_index, skill_data)

	# 技能列表同样在重建结束后统一同步详情，保证搜索响应稳定。
	_select_first_skill()


func _matches_relic_query(relic: Relic, query: String) -> bool:
	if query.is_empty():
		return true

	var searchable_text: String = "%s %s %s" % [relic.relic_name, relic.id, relic.desc]
	for tag: RelicTag in relic.tags:
		if tag != null:
			searchable_text += " %s" % tag.tag_name
	return searchable_text.to_lower().contains(query)


func _matches_skill_filter(skill_data: SkillData, filter_type: int) -> bool:
	match filter_type:
		SkillFilter.ACTIVE:
			return skill_data is ActiveSkillData
		SkillFilter.PASSIVE:
			return skill_data is PassiveSkillData
		_:
			return true


func _matches_skill_query(skill_data: SkillData, query: String) -> bool:
	if query.is_empty():
		return true
	var searchable_text: String = "%s %s %s" % [skill_data.skill_name, String(skill_data.id), skill_data.desc]
	return searchable_text.to_lower().contains(query)


func _get_relic_list_text(relic: Relic) -> String:
	var tag_names: Array[String] = []
	for tag: RelicTag in relic.tags:
		if tag != null:
			tag_names.append(tag.tag_name)
	var tags_text: String = "、".join(tag_names)
	return "Lv.%s  %s  [%s]" % [str(relic.level), relic.relic_name, tags_text]


func _get_skill_list_text(skill_data: SkillData) -> String:
	var type_name: String = "主动" if skill_data is ActiveSkillData else "被动"
	var upgrade_text: String = " [升级]" if skill_data.is_upgrade_skill else ""
	return "%s  %s%s" % [type_name, skill_data.skill_name, upgrade_text]


func _select_first_relic() -> void:
	if relic_list == null or relic_list.get_item_count() <= 0:
		return
	relic_list.select(0)
	_on_relic_selected(0)


func _select_first_skill() -> void:
	if skill_list == null or skill_list.get_item_count() <= 0:
		return
	skill_list.select(0)
	_on_skill_selected(0)


func _on_relic_search_changed(_new_text: String) -> void:
	_refresh_relic_list()


func _on_skill_search_changed(_new_text: String) -> void:
	_refresh_skill_list()


func _on_skill_filter_selected(_index: int) -> void:
	_refresh_skill_list()


func _on_reload_button_pressed() -> void:
	_reload_catalogs()
	_reload_battle_map_catalog()
	_set_feedback("已重新扫描装备、技能、事件与战斗地图。")


func _reload_battle_map_catalog() -> void:
	var selected_path: String = str(battle_map_option.get_selected_metadata()) if battle_map_option.selected >= 0 else ""
	battle_map_option.clear()
	battle_map_catalog_paths = DebugBattleMapCatalog.collect_paths()
	for path: String in battle_map_catalog_paths:
		var info: Dictionary = DebugBattleMapCatalog.read_info(path)
		if info.is_empty():
			continue
		battle_map_option.add_item(str(info["label"]))
		var index: int = battle_map_option.item_count - 1
		battle_map_option.set_item_metadata(index, path)
		battle_map_option.get_popup().set_item_tooltip(index, path)
		if path == selected_path:
			battle_map_option.select(index)
	_refresh_battle_map_override_status()


func _on_set_battle_map_pressed() -> void:
	if run == null or battle_map_option.selected < 0:
		_set_feedback("请先选择一张战斗地图；新导出的模板可点击重扫地图。")
		return
	var path: String = str(battle_map_option.get_selected_metadata())
	if not run.set_debug_next_battle_map_template(path):
		_set_feedback("设置失败：文件不存在或场景根节点不是BattleMap。")
		return
	_refresh_battle_map_override_status()
	_set_feedback("下一场新战斗将使用%s，仅一次；当前战斗及本房续档地图不会改变。" % path.get_file())


func _on_clear_battle_map_pressed() -> void:
	if run != null:
		run.clear_debug_next_battle_map_template()
	_refresh_battle_map_override_status()
	_set_feedback("已取消待测试地图，后续新战斗恢复正常地图选择。")


func _refresh_battle_map_override_status() -> void:
	var available: bool = run != null and run.can_debug_battle_map_override()
	var pending: String = run.get_debug_next_battle_map_template() if run != null else ""
	var current: String = run.run_stats.current_battle_map_template_path if run != null and run.run_stats != null else ""
	battle_map_status.text = "待测试：%s ｜ 本房已锁定：%s" % [pending.get_file() if not pending.is_empty() else "跟随正常规则", current.get_file() if not current.is_empty() else "尚未选择"]
	battle_map_status.tooltip_text = "待测试路径：%s\n本房路径：%s\n优先使用本房存档地图，再使用一次性测试地图，最后才是Boss固定地图或普通随机地图。" % [pending, current]
	set_battle_map_button.disabled = not available or battle_map_option.item_count == 0
	clear_battle_map_button.disabled = not available or pending.is_empty()
	battle_map_option.disabled = not available
	reload_battle_maps_button.disabled = not available
	if run != null and not available:
		battle_map_status.text = "训练场不支持下一场地图覆盖，也不会修改正式局内存档。"


func _on_relic_selected(index: int) -> void:
	var relic: Relic = _get_relic_at(index)
	if relic == null:
		return
	_set_selection_detail("[b]%s[/b]\n%s" % [relic.relic_name, relic.desc])


func _on_skill_selected(index: int) -> void:
	var skill_data: SkillData = _get_skill_at(index)
	if skill_data == null:
		return
	_set_selection_detail("[b]%s[/b]\n%s" % [skill_data.skill_name, skill_data.desc])


func _on_relic_activated(_index: int) -> void:
	_add_selected_relic()


func _on_skill_activated(_index: int) -> void:
	_add_selected_skill()


func _on_add_relic_pressed() -> void:
	_add_selected_relic()


func _on_add_skill_pressed() -> void:
	_add_selected_skill()


func _on_set_next_event_pressed() -> void:
	if run == null:
		_set_feedback("当前场景没有可绑定的 Run，无法覆盖地图事件。")
		return
	if event_room_option == null or event_room_option.selected < 0:
		_set_feedback("请先选择一个事件房间。")
		return

	var selected_index: int = event_room_option.get_selected_id()
	if selected_index < 0 or selected_index >= event_room_catalog.size():
		_set_feedback("所选事件房间无效，请重新扫描资源。")
		return

	var event_scene: PackedScene = event_room_catalog[selected_index]
	if not run.set_debug_next_event_scene(event_scene):
		_set_feedback("设置下一个事件房间失败。")
		return

	_refresh_event_override_status()
	_set_feedback("已设置：下一个进入的地图房间将触发 %s。" % _get_event_scene_display_name(event_scene))


func _on_clear_next_event_pressed() -> void:
	if run != null:
		run.clear_debug_next_event_scene()
	_refresh_event_override_status()
	_set_feedback("已取消下一个房间的事件覆盖。")


func _refresh_debug_values() -> void:
	_on_stat_option_selected(stat_option.selected)
	if run == null or run.world_condition_controller == null or run.run_stats == null:
		return
	var controller: WorldConditionController = run.world_condition_controller
	_fill_condition_option(weather_option, controller.weather_pool, controller.get_active_weather())
	_fill_condition_option(environment_option, controller.environment_pool, controller.get_active_environment())
	weather_rooms.value = run.run_stats.weather_remaining_rooms
	environment_rooms.value = run.run_stats.environment_remaining_rooms


func _fill_condition_option(option: OptionButton, pool: Array[WorldConditionData], selected: WorldConditionData) -> void:
	option.clear()
	for condition: WorldConditionData in pool:
		if condition == null:
			continue
		option.add_item(condition.display_name)
		var index: int = option.item_count - 1
		option.set_item_metadata(index, condition)
		if selected != null and condition.condition_id == selected.condition_id:
			option.select(index)


func _on_stat_option_selected(index: int) -> void:
	var build: PlayerBuild = _get_player_build()
	if build == null or build.player_stats == null or index < 0 or index >= STAT_FIELDS.size():
		return
	var field: Dictionary = STAT_FIELDS[index]
	stat_value.step = 1.0 if bool(field["integer"]) else 0.01
	stat_value.min_value = 0.0
	stat_value.value = float(build.player_stats.get(field["key"]))


func _on_apply_stat_pressed() -> void:
	if run == null or stat_option.selected < 0 or stat_option.selected >= STAT_FIELDS.size():
		_set_feedback("本局尚未初始化，无法修改属性。")
		return
	var field: Dictionary = STAT_FIELDS[stat_option.selected]
	var new_value: float = stat_value.value
	if not run.apply_debug_base_stat(StringName(field["key"]), new_value):
		_set_feedback("属性修改失败，请确认人物数据已初始化。")
		return
	_on_stat_option_selected(stat_option.selected)
	_set_feedback("已将%s的本局基础值设为 %s。" % [field["name"], str(stat_value.value)])


func _on_apply_world_condition_pressed() -> void:
	if run == null or weather_option.selected < 0 or environment_option.selected < 0:
		_set_feedback("本局尚未初始化，无法修改天气或环境。")
		return
	var weather: WorldConditionData = weather_option.get_selected_metadata() as WorldConditionData
	var environment: WorldConditionData = environment_option.get_selected_metadata() as WorldConditionData
	if not run.apply_debug_world_conditions(weather, int(weather_rooms.value), environment, int(environment_rooms.value)):
		_set_feedback("天气或环境修改失败，请确认所选资源有效。")
		return
	_refresh_debug_values()
	_set_feedback("已设置天气：%s；环境：%s。战斗中的环境视觉效果已更新。" % [weather.display_name, environment.display_name])


func _add_selected_relic() -> void:
	var relic: Relic = _get_selected_relic()
	var player_build: PlayerBuild = _get_player_build()
	if relic == null or player_build == null:
		_set_feedback("请先选择一件装备，并确保本局构筑已完成初始化。")
		return

	var requested_amount: int = maxi(int(relic_amount.value) if relic_amount != null else 1, 1)
	var granted_amount: int = 0
	for _index: int in range(requested_amount):
		var relic_copy: Relic = relic.duplicate(true) as Relic
		if relic_copy == null or not player_build.add_relic(relic_copy):
			break
		granted_amount += 1

	if granted_amount <= 0:
		_set_feedback("背包没有可用空间，且无法与现有装备合成。")
		return

	_sync_run_after_debug_change()
	_set_feedback("已添加 %s x%s。" % [relic.relic_name, str(granted_amount)])


func _add_selected_skill() -> void:
	var skill_data: SkillData = _get_selected_skill()
	var player_build: PlayerBuild = _get_player_build()
	if skill_data == null or player_build == null:
		_set_feedback("请先选择一个技能，并确保本局构筑已完成初始化。")
		return

	if skill_data is ActiveSkillData:
		_add_active_skill(player_build, skill_data as ActiveSkillData)
		return
	if skill_data is PassiveSkillData:
		_add_passive_skill(player_build, skill_data as PassiveSkillData)
		return

	_set_feedback("所选资源不是可授予的主动或被动技能。")


func _add_active_skill(player_build: PlayerBuild, skill_data: ActiveSkillData) -> void:
	if player_build.find_permanent_active_skill_entry(skill_data.id) != null:
		_set_feedback("已经拥有主动技能：%s" % skill_data.skill_name)
		return

	var entry: SkillEntry = player_build.grant_active_skill(skill_data)
	if entry == null:
		_set_feedback("主动技能拥有数量已达上限，无法添加：%s" % skill_data.skill_name)
		return

	_sync_run_after_debug_change()
	var equipped_text: String = "已自动携带" if entry.is_equipped else "已加入未携带列表"
	_set_feedback("已添加主动技能：%s（%s）。" % [skill_data.skill_name, equipped_text])


func _add_passive_skill(player_build: PlayerBuild, skill_data: PassiveSkillData) -> void:
	if player_build.find_passive_skill_entry(skill_data.id) != null:
		_set_feedback("已经拥有被动技能：%s" % skill_data.skill_name)
		return

	var replaced_name: String = ""
	if player_build.owned_passive_skills.size() >= player_build.get_passive_skill_limit() and not player_build.owned_passive_skills.is_empty():
		var replaced_entry: SkillEntry = player_build.owned_passive_skills[0]
		if replaced_entry != null and replaced_entry.skill_data != null:
			replaced_name = replaced_entry.skill_data.skill_name

	var entry: SkillEntry = player_build.grant_passive_skill_with_replacement(skill_data)
	if entry == null:
		_set_feedback("被动技能添加失败：%s" % skill_data.skill_name)
		return

	_sync_run_after_debug_change()
	if replaced_name.is_empty():
		_set_feedback("已添加被动技能：%s。" % skill_data.skill_name)
	else:
		_set_feedback("已用 %s 替换被动技能：%s。" % [skill_data.skill_name, replaced_name])


func _get_selected_relic() -> Relic:
	if relic_list == null:
		return null
	var selected_items: PackedInt32Array = relic_list.get_selected_items()
	if selected_items.is_empty():
		return null
	return _get_relic_at(selected_items[0])


func _get_selected_skill() -> SkillData:
	if skill_list == null:
		return null
	var selected_items: PackedInt32Array = skill_list.get_selected_items()
	if selected_items.is_empty():
		return null
	return _get_skill_at(selected_items[0])


func _get_relic_at(index: int) -> Relic:
	if relic_list == null or index < 0 or index >= relic_list.get_item_count():
		return null
	return relic_list.get_item_metadata(index) as Relic


func _get_skill_at(index: int) -> SkillData:
	if skill_list == null or index < 0 or index >= skill_list.get_item_count():
		return null
	return skill_list.get_item_metadata(index) as SkillData


func _get_player_build() -> PlayerBuild:
	if run == null or run.run_stats == null:
		return null
	return run.run_stats.player_build


func _sync_run_after_debug_change() -> void:
	if run == null:
		return
	run.refresh_debug_runtime_state()


func _refresh_event_room_options() -> void:
	if event_room_option == null:
		return

	event_room_option.clear()
	for scene_index: int in range(event_room_catalog.size()):
		var event_scene: PackedScene = event_room_catalog[scene_index]
		event_room_option.add_item(_get_event_scene_display_name(event_scene), scene_index)

	if event_room_option.item_count > 0:
		event_room_option.select(0)


func _refresh_event_override_status() -> void:
	if event_override_status == null:
		return

	var pending_scene: PackedScene = run.get_debug_next_event_scene() if run != null else null
	if pending_scene == null:
		event_override_status.text = "当前：跟随地图随机"
	else:
		event_override_status.text = "当前：%s（一次）" % _get_event_scene_display_name(pending_scene)

	if set_next_event_button != null:
		set_next_event_button.disabled = run == null or event_room_catalog.is_empty()
	if clear_next_event_button != null:
		clear_next_event_button.disabled = pending_scene == null


func _get_event_scene_display_name(event_scene: PackedScene) -> String:
	if event_scene == null:
		return "未知事件"

	var scene_state: SceneState = event_scene.get_state()
	if scene_state != null and scene_state.get_node_count() > 0:
		var root_name: String = String(scene_state.get_node_name(0))
		if not root_name.is_empty():
			return "%s [%s]" % [root_name, event_scene.resource_path.get_file().get_basename()]

	return event_scene.resource_path.get_file().get_basename()


func _pause_game_for_console() -> void:
	if not pause_game_while_open or get_tree().paused:
		return

	paused_by_console = true
	EventBus.game_paused.emit(true)
	get_tree().paused = true


func _resume_game_after_console() -> void:
	if not paused_by_console:
		return

	paused_by_console = false
	EventBus.game_paused.emit(false)
	get_tree().paused = false


func _set_selection_detail(text: String) -> void:
	if selection_detail == null:
		return
	selection_detail.clear()
	selection_detail.append_text(text)


func _set_feedback(message: String) -> void:
	if feedback_label != null:
		feedback_label.text = message
