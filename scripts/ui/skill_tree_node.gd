class_name SkillTreeNode
extends Button

signal skill_selected(skill_data: SkillData)
signal hover_started(skill_data: SkillData, skill_node: SkillTreeNode)
signal hover_ended(skill_node: SkillTreeNode)

@onready var icon_texture: TextureRect = %IconTexture
@onready var name_label: Label = %NameLabel

var skill_data: SkillData


func _ready() -> void:
	# 卡片独占鼠标命中，确保每个技能都能稳定触发自己的 tooltip。
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 防止点击技能卡片后获得焦点，ScrollContainer 因焦点变化自动跳动。
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_set_child_mouse_filter_ignore(self)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return

	var graph: SkillTreeGraph = get_parent() as SkillTreeGraph
	if graph != null and graph.handle_wheel_event(mouse_event):
		# 卡片处理完滚轮后阻止 Button 和 ScrollContainer 再次处理。
		accept_event()


## 设置技能树中的一张横向技能卡片，并区分初始技能与升级技能的颜色。
func setup(new_skill_data: SkillData) -> void:
	skill_data = new_skill_data
	if skill_data == null:
		hide()
		return

	show()
	icon_texture.texture = skill_data.icon
	name_label.text = skill_data.skill_name
	# 技能树使用自己的 tooltip 管理器，避免内置 tooltip 被横向滚动视口裁剪。
	tooltip_text = ""
	_apply_visual_style(skill_data.is_upgrade_skill)


func _on_pressed() -> void:
	if skill_data != null:
		skill_selected.emit(skill_data)


func _on_mouse_entered() -> void:
	if skill_data != null:
		hover_started.emit(skill_data, self)


func _on_mouse_exited() -> void:
	hover_ended.emit(self)


func _apply_visual_style(is_upgrade_skill: bool) -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.2, 0.3, 0.98) if not is_upgrade_skill else Color(0.3, 0.22, 0.12, 0.98)
	normal_style.border_color = Color(0.42, 0.78, 1.0, 0.9) if not is_upgrade_skill else Color(1.0, 0.76, 0.32, 0.95)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	add_theme_stylebox_override("normal", normal_style)

	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.2, 0.38, 0.52, 1.0) if not is_upgrade_skill else Color(0.48, 0.34, 0.16, 1.0)
	hover_style.set_border_width_all(3)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", hover_style)


func _set_child_mouse_filter_ignore(root: Node) -> void:
	for child in root.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_child_mouse_filter_ignore(child)
