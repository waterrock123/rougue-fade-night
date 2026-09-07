class_name SkillTreeGraph
extends Control

signal skill_selected(skill_data: SkillData)
signal skill_hovered(skill_data: SkillData, skill_node: SkillTreeNode)
signal skill_unhovered(skill_node: SkillTreeNode)

const NODE_SCENE := preload("res://scenes/ui/skill_tree_node.tscn")
const NODE_WIDTH: float = 220.0
const NODE_HEIGHT: float = 78.0
const COLUMN_GAP: float = 28.0
const GROUP_GAP: float = 48.0
const GRAPH_MARGIN_X: float = 20.0
const GRAPH_HEIGHT: float = 430.0
const TOP_ROW_Y: float = 35.0
const BOTTOM_ROW_Y: float = 315.0
const WHEEL_SCROLL_STEP: float = 120.0

enum SkillTypeFilter {
	ALL,
	ACTIVE,
	PASSIVE,
}

enum SkillStageFilter {
	ALL,
	INITIAL,
	UPGRADE,
}

enum SkillOwnershipFilter {
	ALL,
	WARRIOR,
	SCOUNT,
}

var all_skills: Array[SkillData] = []
var type_filter: int = SkillTypeFilter.ALL
var stage_filter: int = SkillStageFilter.ALL
var ownership_filter: int = SkillOwnershipFilter.ALL
var visible_skills: Array[SkillData] = []
var node_positions: Dictionary = {}


func _ready() -> void:
	# 图层统一处理空白区域的滚轮，卡片会把滚轮委托回这里。
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not handle_wheel_event(mouse_event):
		return
	accept_event()


func handle_wheel_event(mouse_event: InputEventMouseButton) -> bool:
	if not mouse_event.pressed:
		return false
	if mouse_event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return false

	var scroll_container: ScrollContainer = get_parent() as ScrollContainer
	if scroll_container == null:
		return false

	var vertical_bar: VScrollBar = scroll_container.get_v_scroll_bar()
	var horizontal_bar: HScrollBar = scroll_container.get_h_scroll_bar()
	var has_vertical_range: bool = vertical_bar.max_value > vertical_bar.page
	var has_horizontal_range: bool = horizontal_bar.max_value > horizontal_bar.page
	if not has_vertical_range and not has_horizontal_range:
		return false

	var direction: float = -1.0 if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
	var factor: float = maxf(mouse_event.factor, 1.0)
	var step: int = int(WHEEL_SCROLL_STEP * factor)
	# 技能树通常只有横向溢出；按住 Shift 时也强制使用横向滚动。
	var should_scroll_horizontal: bool = has_horizontal_range and (mouse_event.shift_pressed or not has_vertical_range)
	if should_scroll_horizontal:
		# 不在这里二次计算上限，交给 ScrollContainer 按当前 viewport 自动限幅。
		scroll_container.scroll_horizontal += int(direction * step)
	else:
		scroll_container.scroll_vertical += int(direction * step)

	return true


func set_skills(skills: Array[SkillData]) -> void:
	all_skills = skills.duplicate()
	_refresh_graph()


func set_filters(
	new_type_filter: int,
	new_stage_filter: int,
	new_ownership_filter: int = SkillOwnershipFilter.ALL
) -> void:
	type_filter = new_type_filter
	stage_filter = new_stage_filter
	ownership_filter = new_ownership_filter
	_refresh_graph()


func _refresh_graph() -> void:
	_clear_nodes()
	node_positions.clear()
	visible_skills.clear()

	var initial_skills: Array[SkillData] = _get_filtered_skills(false)
	var upgrade_skills: Array[SkillData] = _get_filtered_skills(true)
	visible_skills.append_array(initial_skills)
	visible_skills.append_array(upgrade_skills)

	# 按父技能分组排版，避免不同技能分支共用横线而互相穿插。
	var visible_ids: Dictionary = {}
	for skill_data: SkillData in visible_skills:
		if skill_data != null:
			visible_ids[skill_data.id] = true

	var placed_ids: Dictionary = {}
	var cursor_x: float = GRAPH_MARGIN_X
	for parent_skill: SkillData in initial_skills:
		var children: Array[SkillData] = _get_visible_upgrade_children(parent_skill, visible_ids)
		var child_count: int = maxi(children.size(), 1)
		var group_width: float = child_count * NODE_WIDTH + (child_count - 1) * COLUMN_GAP
		var parent_x: float = cursor_x + (group_width - NODE_WIDTH) * 0.5

		# 父技能位于下排中央，升级技能在上排横向展开。
		_add_skill_node(parent_skill, Vector2(parent_x, BOTTOM_ROW_Y))
		placed_ids[parent_skill.id] = true
		for child_index in range(children.size()):
			var child_x: float = cursor_x + child_index * (NODE_WIDTH + COLUMN_GAP)
			_add_skill_node(children[child_index], Vector2(child_x, TOP_ROW_Y))
			placed_ids[children[child_index].id] = true

		cursor_x += group_width + GROUP_GAP

	# 只筛选升级技能时没有可见的父节点，这些技能使用备用横排布局。
	for upgrade_skill: SkillData in upgrade_skills:
		if placed_ids.has(upgrade_skill.id):
			continue
		_add_skill_node(upgrade_skill, Vector2(cursor_x, TOP_ROW_Y))
		placed_ids[upgrade_skill.id] = true
		cursor_x += NODE_WIDTH + COLUMN_GAP

	var graph_width: float = maxf(cursor_x - GROUP_GAP + GRAPH_MARGIN_X, 40.0 + NODE_WIDTH)
	custom_minimum_size = Vector2(graph_width, GRAPH_HEIGHT)

	queue_redraw()


func _get_visible_upgrade_children(parent_skill: SkillData, visible_ids: Dictionary) -> Array[SkillData]:
	var result: Array[SkillData] = []
	for child_skill: SkillData in parent_skill.get_upgrade_options():
		if child_skill == null or not visible_ids.has(child_skill.id):
			continue
		result.append(child_skill)
	result.sort_custom(Callable(self, "_sort_skills"))
	return result


func _get_filtered_skills(want_upgrade: bool) -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill_data: SkillData in all_skills:
		if skill_data == null:
			continue
		if skill_data.is_upgrade_skill != want_upgrade:
			continue
		if not _matches_type_filter(skill_data):
			continue
		if not _matches_ownership_filter(skill_data):
			continue
		if stage_filter == SkillStageFilter.INITIAL and skill_data.is_upgrade_skill:
			continue
		if stage_filter == SkillStageFilter.UPGRADE and not skill_data.is_upgrade_skill:
			continue
		result.append(skill_data)

	result.sort_custom(Callable(self, "_sort_skills"))
	return result


func _matches_type_filter(skill_data: SkillData) -> bool:
	match type_filter:
		SkillTypeFilter.ACTIVE:
			return skill_data is ActiveSkillData
		SkillTypeFilter.PASSIVE:
			return skill_data is PassiveSkillData
		_:
			return true


func _matches_ownership_filter(skill_data: SkillData) -> bool:
	if ownership_filter == SkillOwnershipFilter.ALL:
		return true

	var character_id: StringName = &"warrior"
	if ownership_filter == SkillOwnershipFilter.SCOUNT:
		character_id = &"scount"

	return _skill_belongs_to_character(skill_data, character_id, {})


func _skill_belongs_to_character(
	skill_data: SkillData,
	character_id: StringName,
	visited: Dictionary
) -> bool:
	if skill_data == null or visited.has(skill_data.id):
		return false
	visited[skill_data.id] = true
	if skill_data.allowed_character_ids.has(character_id):
		return true

	# 升级技能通常不重复填写归属，因此向上追溯它的父技能。
	for possible_parent: SkillData in all_skills:
		if possible_parent == null or not _is_upgrade_child(possible_parent, skill_data):
			continue
		if _skill_belongs_to_character(possible_parent, character_id, visited):
			return true

	return false


func _is_upgrade_child(parent_skill: SkillData, child_skill: SkillData) -> bool:
	if parent_skill == null or child_skill == null:
		return false
	for upgrade_skill: SkillData in parent_skill.get_upgrade_options():
		if upgrade_skill != null and upgrade_skill.id == child_skill.id:
			return true
	return false


func _sort_skills(first: SkillData, second: SkillData) -> bool:
	return String(first.id) < String(second.id)


func _add_skill_node(skill_data: SkillData, node_position: Vector2) -> void:
	var node := NODE_SCENE.instantiate() as SkillTreeNode
	add_child(node)
	node.position = node_position
	node.size = Vector2(NODE_WIDTH, NODE_HEIGHT)
	node.setup(skill_data)
	node.skill_selected.connect(_on_skill_selected)
	node.hover_started.connect(_on_skill_hover_started)
	node.hover_ended.connect(_on_skill_hover_ended)
	node_positions[skill_data.id] = node_position


func _on_skill_selected(skill_data: SkillData) -> void:
	skill_selected.emit(skill_data)


func _on_skill_hover_started(skill_data: SkillData, skill_node: SkillTreeNode) -> void:
	skill_hovered.emit(skill_data, skill_node)


func _on_skill_hover_ended(skill_node: SkillTreeNode) -> void:
	skill_unhovered.emit(skill_node)


## 用三段直线绘制正交折线，保持连接清晰且不遮挡技能卡片。
func _draw() -> void:
	var line_color := Color(0.96, 0.98, 1.0, 0.9)
	for source_skill: SkillData in visible_skills:
		if not node_positions.has(source_skill.id):
			continue
		var source_position: Vector2 = Vector2(node_positions.get(source_skill.id, Vector2.ZERO))
		for target_skill: SkillData in source_skill.get_upgrade_options():
			if target_skill == null or not node_positions.has(target_skill.id):
				continue

			var target_position: Vector2 = Vector2(node_positions.get(target_skill.id, Vector2.ZERO))
			var start := source_position + Vector2(NODE_WIDTH * 0.5, NODE_HEIGHT)
			var end := target_position + Vector2(NODE_WIDTH * 0.5, 0.0)
			var middle_y := (start.y + end.y) * 0.5
			var middle_start := Vector2(start.x, middle_y)
			var middle_end := Vector2(end.x, middle_y)
			draw_line(start, middle_start, line_color, 2.0, true)
			draw_line(middle_start, middle_end, line_color, 2.0, true)
			draw_line(middle_end, end, line_color, 2.0, true)


func _clear_nodes() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
