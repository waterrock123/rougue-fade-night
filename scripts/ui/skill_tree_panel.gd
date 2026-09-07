class_name SkillTreePanel
extends Control

signal closed

const TYPE_ALL: int = SkillTreeGraph.SkillTypeFilter.ALL
const TYPE_ACTIVE: int = SkillTreeGraph.SkillTypeFilter.ACTIVE
const TYPE_PASSIVE: int = SkillTreeGraph.SkillTypeFilter.PASSIVE
const STAGE_ALL: int = SkillTreeGraph.SkillStageFilter.ALL
const STAGE_INITIAL: int = SkillTreeGraph.SkillStageFilter.INITIAL
const STAGE_UPGRADE: int = SkillTreeGraph.SkillStageFilter.UPGRADE
const OWNERSHIP_ALL: int = SkillTreeGraph.SkillOwnershipFilter.ALL
const OWNERSHIP_WARRIOR: int = SkillTreeGraph.SkillOwnershipFilter.WARRIOR
const OWNERSHIP_SCOUNT: int = SkillTreeGraph.SkillOwnershipFilter.SCOUNT

@onready var skill_tree_graph: SkillTreeGraph = %SkillTreeGraph
@onready var all_type_button: Button = %AllTypeButton
@onready var active_type_button: Button = %ActiveTypeButton
@onready var passive_type_button: Button = %PassiveTypeButton
@onready var all_stage_button: Button = %AllStageButton
@onready var initial_stage_button: Button = %InitialStageButton
@onready var upgrade_stage_button: Button = %UpgradeStageButton
@onready var all_ownership_button: Button = %AllOwnershipButton
@onready var warrior_ownership_button: Button = %WarriorOwnershipButton
@onready var scount_ownership_button: Button = %SCountOwnershipButton
@onready var exit_button: Button = %ExitButton
@onready var window: PanelContainer = $Window

var current_type_filter: int = TYPE_ALL
var current_stage_filter: int = STAGE_ALL
var current_ownership_filter: int = OWNERSHIP_ALL
var active_tooltip: SkillToolTipPanel
var active_tooltip_node: SkillTreeNode


func _ready() -> void:
	_connect_buttons()
	if skill_tree_graph != null:
		skill_tree_graph.skill_hovered.connect(_on_skill_hovered)
		skill_tree_graph.skill_unhovered.connect(_on_skill_unhovered)
	_refresh_filter_buttons()
	hide()


func setup(active_skills: Array[ActiveSkillData], passive_skills: Array[PassiveSkillData]) -> void:
	var all_skill_data: Array[SkillData] = []
	for skill_data: ActiveSkillData in active_skills:
		if skill_data != null:
			all_skill_data.append(skill_data)
	for skill_data: PassiveSkillData in passive_skills:
		if skill_data != null:
			all_skill_data.append(skill_data)

	skill_tree_graph.set_skills(all_skill_data)
	skill_tree_graph.set_filters(current_type_filter, current_stage_filter, current_ownership_filter)


func open_panel() -> void:
	show()
	move_to_front()
	if window != null:
		window.move_to_front()
	if skill_tree_graph != null:
		skill_tree_graph.queue_redraw()
		# 等待一次布局刷新，让滚动条在打开的第一帧就能接收输入。
		skill_tree_graph.get_parent().queue_sort()


func close_panel() -> void:
	_clear_skill_tooltip()
	hide()
	closed.emit()


func _process(_delta: float) -> void:
	if active_tooltip != null and is_instance_valid(active_tooltip_node):
		_position_active_tooltip()


func _on_skill_hovered(skill_data: SkillData, skill_node: SkillTreeNode) -> void:
	_clear_skill_tooltip()
	if skill_data == null:
		return

	var tooltip: SkillToolTipPanel = FloatText.SKILL_TOOL_TIP_PANEL.instantiate() as SkillToolTipPanel
	if tooltip == null:
		return

	var skill_entry: SkillEntry = SkillEntry.new()
	skill_entry.skill_data = skill_data
	add_child(tooltip)
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.z_index = 100
	tooltip.set_skill(skill_entry)
	active_tooltip = tooltip
	active_tooltip_node = skill_node
	_position_active_tooltip()


func _on_skill_unhovered(skill_node: SkillTreeNode) -> void:
	if active_tooltip_node == skill_node:
		_clear_skill_tooltip()


func _position_active_tooltip() -> void:
	if active_tooltip == null or active_tooltip_node == null:
		return

	var node_rect: Rect2 = active_tooltip_node.get_global_rect()
	var tooltip_size: Vector2 = active_tooltip.size
	if tooltip_size.x <= 0.0 or tooltip_size.y <= 0.0:
		tooltip_size = active_tooltip.get_combined_minimum_size()

	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_x: float = node_rect.position.x + node_rect.size.x + 12.0
	if tooltip_x + tooltip_size.x > viewport_size.x:
		tooltip_x = node_rect.position.x - tooltip_size.x - 12.0
	var max_y: float = maxf(8.0, viewport_size.y - tooltip_size.y - 8.0)
	var tooltip_y: float = clampf(node_rect.position.y, 8.0, max_y)
	active_tooltip.global_position = Vector2(tooltip_x, tooltip_y)


func _clear_skill_tooltip() -> void:
	if active_tooltip != null and is_instance_valid(active_tooltip):
		active_tooltip.queue_free()
	active_tooltip = null
	active_tooltip_node = null


func _connect_buttons() -> void:
	all_type_button.pressed.connect(_on_type_filter_pressed.bind(TYPE_ALL))
	active_type_button.pressed.connect(_on_type_filter_pressed.bind(TYPE_ACTIVE))
	passive_type_button.pressed.connect(_on_type_filter_pressed.bind(TYPE_PASSIVE))
	all_stage_button.pressed.connect(_on_stage_filter_pressed.bind(STAGE_ALL))
	initial_stage_button.pressed.connect(_on_stage_filter_pressed.bind(STAGE_INITIAL))
	upgrade_stage_button.pressed.connect(_on_stage_filter_pressed.bind(STAGE_UPGRADE))
	all_ownership_button.pressed.connect(_on_ownership_filter_pressed.bind(OWNERSHIP_ALL))
	warrior_ownership_button.pressed.connect(_on_ownership_filter_pressed.bind(OWNERSHIP_WARRIOR))
	scount_ownership_button.pressed.connect(_on_ownership_filter_pressed.bind(OWNERSHIP_SCOUNT))
	exit_button.pressed.connect(close_panel)


func _on_type_filter_pressed(new_filter: int) -> void:
	current_type_filter = new_filter
	skill_tree_graph.set_filters(current_type_filter, current_stage_filter, current_ownership_filter)
	_refresh_filter_buttons()


func _on_stage_filter_pressed(new_filter: int) -> void:
	current_stage_filter = new_filter
	skill_tree_graph.set_filters(current_type_filter, current_stage_filter, current_ownership_filter)
	_refresh_filter_buttons()


func _on_ownership_filter_pressed(new_filter: int) -> void:
	current_ownership_filter = new_filter
	skill_tree_graph.set_filters(current_type_filter, current_stage_filter, current_ownership_filter)
	_refresh_filter_buttons()


func _refresh_filter_buttons() -> void:
	all_type_button.button_pressed = current_type_filter == TYPE_ALL
	active_type_button.button_pressed = current_type_filter == TYPE_ACTIVE
	passive_type_button.button_pressed = current_type_filter == TYPE_PASSIVE
	all_stage_button.button_pressed = current_stage_filter == STAGE_ALL
	initial_stage_button.button_pressed = current_stage_filter == STAGE_INITIAL
	upgrade_stage_button.button_pressed = current_stage_filter == STAGE_UPGRADE
	all_ownership_button.button_pressed = current_ownership_filter == OWNERSHIP_ALL
	warrior_ownership_button.button_pressed = current_ownership_filter == OWNERSHIP_WARRIOR
	scount_ownership_button.button_pressed = current_ownership_filter == OWNERSHIP_SCOUNT
