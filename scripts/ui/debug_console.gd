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
@onready var selection_detail: RichTextLabel = $Panel/MarginContainer/VBoxContainer/SelectionDetail
@onready var feedback_label: Label = $Panel/MarginContainer/VBoxContainer/FeedbackLabel

var run: Run
var relic_catalog: Array[Relic] = []
var skill_catalog: Array[SkillData] = []
var paused_by_console: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_setup_skill_filter()
	_connect_controls()
	_reload_catalogs()


func bind_run(new_run: Run) -> void:
	run = new_run


func can_open() -> bool:
	return allow_in_release or OS.is_debug_build()


func open_panel() -> void:
	if not can_open():
		return

	show()
	move_to_front()
	_refresh_lists()
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
	_refresh_lists()


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
	_set_feedback("已重新扫描装备与技能资源。")


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
