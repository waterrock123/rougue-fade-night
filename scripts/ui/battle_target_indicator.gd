class_name BattleTargetIndicator
extends Control

## 单个屏幕边缘目标指示器。箭头由代码绘制，因此暂时不依赖额外美术资源。

const NORMAL_COLOR := Color(0.95, 0.16, 0.12, 0.95)
const BOUNTY_COLOR := Color(1.0, 0.72, 0.16, 0.98)
const POSITION_SMOOTH_SPEED := 18.0
const ROTATION_SMOOTH_SPEED := 22.0
const SNAP_DISTANCE := 420.0

var direction_angle: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var target_direction_angle: float = 0.0
var indicator_color: Color = NORMAL_COLOR
var pulse_time: float = 0.0
var count_label: Label
var active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label = Label.new()
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.position = Vector2(-34.0, 18.0)
	count_label.size = Vector2(68.0, 30.0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 20)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.02, 0.95))
	count_label.add_theme_constant_override("outline_size", 5)
	add_child(count_label)
	set_process(false)
	hide()


func _process(delta: float) -> void:
	var position_weight: float = 1.0 - exp(-POSITION_SMOOTH_SPEED * delta)
	var rotation_weight: float = 1.0 - exp(-ROTATION_SMOOTH_SPEED * delta)
	if position.distance_squared_to(target_position) > SNAP_DISTANCE * SNAP_DISTANCE:
		position = target_position
	else:
		position = position.lerp(target_position, position_weight)
	direction_angle = lerp_angle(direction_angle, target_direction_angle, rotation_weight)
	pulse_time += delta
	queue_redraw()


func configure(screen_position: Vector2, direction: Vector2, count: int, is_bounty: bool) -> void:
	target_position = screen_position
	target_direction_angle = direction.angle()
	# 新出现的箭头直接落在正确位置；后续刷新才使用逐帧平滑，避免从旧位置横穿屏幕。
	if not active:
		position = target_position
		direction_angle = target_direction_angle
	active = true
	indicator_color = BOUNTY_COLOR if is_bounty else NORMAL_COLOR
	count_label.text = "悬赏" if is_bounty else ("×%d" % count if count > 1 else "")
	count_label.visible = is_bounty or count > 1
	show()
	set_process(true)
	queue_redraw()


func deactivate() -> void:
	active = false
	set_process(false)
	hide()


func _draw() -> void:
	var pulse: float = 1.0 + sin(pulse_time * 4.0) * 0.08
	draw_circle(Vector2.ZERO, 25.0 * pulse, Color(indicator_color, 0.16))
	draw_set_transform(Vector2.ZERO, direction_angle, Vector2.ONE * pulse)
	var arrow_points := PackedVector2Array([
		Vector2(29.0, 0.0),
		Vector2(-13.0, -16.0),
		Vector2(-5.0, 0.0),
		Vector2(-13.0, 16.0),
	])
	draw_colored_polygon(arrow_points, indicator_color)
	arrow_points.append(arrow_points[0])
	draw_polyline(arrow_points, Color(0.18, 0.03, 0.02, 0.95), 3.0, true)
	draw_set_transform(Vector2.ZERO)
