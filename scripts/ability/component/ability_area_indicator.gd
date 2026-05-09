class_name AbilityAreaIndicator
extends AbilityComponent

enum IndicatorShape {
	LINE_RECT,
}

@export var shape: IndicatorShape = IndicatorShape.LINE_RECT
@export var length: float = 520.0
@export var width: float = 80.0
@export var fill_color: Color = Color(0.2, 0.75, 1.0, 0.22)
@export var border_color: Color = Color(0.7, 0.95, 1.0, 0.85)
@export var border_width: float = 3.0

var preview_context: AbilityContext
var polygon: Polygon2D
var border: Line2D


func _ready() -> void:
	# 指示器只在按住技能键时显示，不参与正式释放链。
	auto_activate = false
	set_process(false)


func begin_preview(context: AbilityContext) -> void:
	preview_context = context
	_ensure_nodes()
	_show_nodes(true)
	set_process(true)
	_update_indicator()


func end_preview() -> void:
	set_process(false)
	_show_nodes(false)
	preview_context = null


func _process(_delta: float) -> void:
	_update_indicator()


func _exit_tree() -> void:
	# 技能被移除或切换场景时，顺手清理预览节点，避免隐藏节点残留在当前场景里。
	if polygon != null and is_instance_valid(polygon):
		polygon.queue_free()
	if border != null and is_instance_valid(border):
		border.queue_free()


func _ensure_nodes() -> void:
	if polygon != null and is_instance_valid(polygon):
		return

	polygon = Polygon2D.new()
	polygon.color = fill_color
	polygon.z_index = 1000

	border = Line2D.new()
	border.default_color = border_color
	border.width = border_width
	border.closed = true
	border.z_index = 1001

	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(polygon)
	root.add_child(border)


func _show_nodes(visible: bool) -> void:
	if polygon != null:
		polygon.visible = visible
	if border != null:
		border.visible = visible


func _update_indicator() -> void:
	if preview_context == null or preview_context.caster == null:
		return

	match shape:
		IndicatorShape.LINE_RECT:
			_update_line_rect()


func _update_line_rect() -> void:
	var caster := preview_context.caster
	var mouse_pos := caster.get_global_mouse_position()
	var direction := caster.global_position.direction_to(mouse_pos)
	if direction == Vector2.ZERO:
		direction = caster.get_facing_direction()

	var half_width := width * 0.5
	var points := PackedVector2Array([
		Vector2(0.0, -half_width),
		Vector2(length, -half_width),
		Vector2(length, half_width),
		Vector2(0.0, half_width),
	])

	polygon.polygon = points
	polygon.global_position = caster.global_position
	polygon.global_rotation = direction.angle()

	border.points = points
	border.global_position = caster.global_position
	border.global_rotation = direction.angle()
