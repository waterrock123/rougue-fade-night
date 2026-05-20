## 技能范围指示器。
## 按住技能键时显示预览范围，松开释放后隐藏；本组件只负责视觉提示，不造成实际效果。
@tool
class_name AbilityAreaIndicator
extends AbilityComponent

enum IndicatorShape {
	LINE_RECT,
	CIRCLE,
	SECTOR,
	FAN_LINE_RECTS,
}

@export var shape: IndicatorShape = IndicatorShape.LINE_RECT
@export var length: float = 520.0
@export var width: float = 80.0
@export var radius: float = 160.0
@export var circle_segments: int = 48

@export_group("Sector")
## shape 为 SECTOR 时生效，length 表示扇形半径。
@export_range(1.0, 360.0, 1.0) var angle_degrees: float = 90.0
## 扇形边缘分段数，数值越高越圆滑。
@export var sector_segments: int = 16

@export_group("Fan Lines")
## shape 为 FAN_LINE_RECTS 时生效，用多条矩形指示线组合成散射范围。
@export_range(1, 32, 1) var fan_line_count: int = 5
@export_range(0.0, 360.0, 1.0) var fan_spread_angle_degrees: float = 90.0

@export_group("Style")
@export var fill_color: Color = Color(0.2, 0.75, 1.0, 0.22)
@export var border_color: Color = Color(0.7, 0.95, 1.0, 0.85)
@export var border_width: float = 3.0
## 指示区域应该像画在地面上一样，默认放在角色和投射物下面，避免挡住人物。
@export var indicator_z_index: int = -2

var preview_context: AbilityContext
var polygon: Polygon2D
var border: Line2D
var fan_polygons: Array[Polygon2D] = []
var fan_borders: Array[Line2D] = []


func _ready() -> void:
	# 指示器由 AbilityController 的按住预览逻辑手动控制，不参与普通技能组件自动链。
	auto_activate = false
	set_process(false)


func begin_preview(context: AbilityContext) -> void:
	preview_context = context
	_ensure_nodes()
	_set_indicator_visible(true)
	set_process(true)
	_update_indicator()


func end_preview() -> void:
	set_process(false)
	_set_indicator_visible(false)
	preview_context = null


func _process(_delta: float) -> void:
	_update_indicator()


func _exit_tree() -> void:
	_free_single_nodes()
	_free_fan_nodes()


func _ensure_nodes() -> void:
	if polygon == null or not is_instance_valid(polygon):
		polygon = Polygon2D.new()
		polygon.color = fill_color
		polygon.z_index = indicator_z_index

	if border == null or not is_instance_valid(border):
		border = Line2D.new()
		border.default_color = border_color
		border.width = border_width
		border.closed = true
		border.z_index = indicator_z_index + 1

	var root := _get_visual_root()
	if polygon.get_parent() == null:
		root.add_child(polygon)
	if border.get_parent() == null:
		root.add_child(border)

	_ensure_fan_nodes(fan_line_count)


func _set_indicator_visible(visible: bool) -> void:
	var single_visible := visible and shape != IndicatorShape.FAN_LINE_RECTS
	if polygon != null:
		polygon.visible = single_visible
	if border != null:
		border.visible = single_visible

	var fan_visible := visible and shape == IndicatorShape.FAN_LINE_RECTS
	for node in fan_polygons:
		if node != null and is_instance_valid(node):
			node.visible = fan_visible
	for node in fan_borders:
		if node != null and is_instance_valid(node):
			node.visible = fan_visible


func _update_indicator() -> void:
	if preview_context == null or preview_context.caster == null:
		return

	_set_indicator_visible(true)
	match shape:
		IndicatorShape.LINE_RECT:
			_update_line_rect()
		IndicatorShape.CIRCLE:
			_update_circle()
		IndicatorShape.SECTOR:
			_update_sector()
		IndicatorShape.FAN_LINE_RECTS:
			_update_fan_line_rects()


func _update_line_rect() -> void:
	var caster := preview_context.caster
	var direction := _get_preview_direction()
	var points := _build_line_rect_points()

	polygon.polygon = points
	polygon.global_position = caster.global_position
	polygon.global_rotation = direction.angle()

	border.points = points
	border.global_position = caster.global_position
	border.global_rotation = direction.angle()


func _update_circle() -> void:
	var caster := preview_context.caster
	var points := PackedVector2Array()
	var safe_segments: int = max(circle_segments, 12)

	# 用多边形近似圆形，既能画半透明填充，也能画边框。
	for index in range(safe_segments):
		var angle := TAU * float(index) / float(safe_segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	polygon.polygon = points
	polygon.global_position = caster.global_position
	polygon.global_rotation = 0.0

	border.points = points
	border.global_position = caster.global_position
	border.global_rotation = 0.0


func _update_sector() -> void:
	var caster := preview_context.caster
	var direction := _get_preview_direction()
	var points := _build_sector_points()

	polygon.polygon = points
	polygon.global_position = caster.global_position
	polygon.global_rotation = direction.angle()

	border.points = points
	border.global_position = caster.global_position
	border.global_rotation = direction.angle()


func _update_fan_line_rects() -> void:
	var caster := preview_context.caster
	var directions := _build_fan_directions(_get_preview_direction())
	var points := _build_line_rect_points()
	_ensure_fan_nodes(directions.size())

	for index in range(fan_polygons.size()):
		var is_used := index < directions.size()
		fan_polygons[index].visible = is_used
		fan_borders[index].visible = is_used
		if not is_used:
			continue

		var direction := directions[index]
		fan_polygons[index].polygon = points
		fan_polygons[index].global_position = caster.global_position
		fan_polygons[index].global_rotation = direction.angle()

		fan_borders[index].points = points
		fan_borders[index].global_position = caster.global_position
		fan_borders[index].global_rotation = direction.angle()


func _build_line_rect_points() -> PackedVector2Array:
	var half_width := width * 0.5
	return PackedVector2Array([
		Vector2(0.0, -half_width),
		Vector2(length, -half_width),
		Vector2(length, half_width),
		Vector2(0.0, half_width),
	])


## 扇形从施法者位置向前展开，适合冰冻波、喷吐、扇形斩击等技能预览。
func _build_sector_points() -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var safe_segments: int = max(max(sector_segments, int(ceil(angle_degrees / 8.0))), 3)
	var half_angle := deg_to_rad(angle_degrees * 0.5)
	var safe_radius: float = max(length, 0.0)

	for index in range(safe_segments + 1):
		var t := float(index) / float(safe_segments)
		var angle = lerp(-half_angle, half_angle, t)
		points.append(Vector2(cos(angle), sin(angle)) * safe_radius)

	points.append(Vector2.ZERO)
	return points


func _build_fan_directions(base_direction: Vector2) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	var safe_count: int = max(fan_line_count, 1)
	var safe_base := base_direction.normalized() if base_direction != Vector2.ZERO else Vector2.RIGHT

	if safe_count == 1:
		directions.append(safe_base)
		return directions

	var half_angle := deg_to_rad(fan_spread_angle_degrees * 0.5)
	for index in range(safe_count):
		var t := float(index) / float(safe_count - 1)
		var angle = lerp(-half_angle, half_angle, t)
		directions.append(safe_base.rotated(angle).normalized())

	return directions


func _get_preview_direction() -> Vector2:
	if preview_context == null or preview_context.caster == null:
		return Vector2.RIGHT

	var caster := preview_context.caster
	var direction := caster.global_position.direction_to(caster.get_global_mouse_position())
	if direction == Vector2.ZERO:
		direction = caster.get_facing_direction()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	return direction.normalized()


func _ensure_fan_nodes(count: int) -> void:
	var root := _get_visual_root()
	while fan_polygons.size() < count:
		var fan_polygon := Polygon2D.new()
		fan_polygon.color = fill_color
		fan_polygon.z_index = indicator_z_index
		fan_polygon.visible = false
		root.add_child(fan_polygon)
		fan_polygons.append(fan_polygon)

		var fan_border := Line2D.new()
		fan_border.default_color = border_color
		fan_border.width = border_width
		fan_border.closed = true
		fan_border.z_index = indicator_z_index + 1
		fan_border.visible = false
		root.add_child(fan_border)
		fan_borders.append(fan_border)


func _get_visual_root() -> Node:
	var root := get_tree().current_scene
	return root if root != null else get_tree().root


func _free_single_nodes() -> void:
	if polygon != null and is_instance_valid(polygon):
		polygon.queue_free()
	if border != null and is_instance_valid(border):
		border.queue_free()


func _free_fan_nodes() -> void:
	for node in fan_polygons:
		if node != null and is_instance_valid(node):
			node.queue_free()
	for node in fan_borders:
		if node != null and is_instance_valid(node):
			node.queue_free()
	fan_polygons.clear()
	fan_borders.clear()
