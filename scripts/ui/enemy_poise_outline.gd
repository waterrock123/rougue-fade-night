class_name EnemyPoiseOutline
extends Control

var poise_ratio: float = 1.0
var outline_color: Color = Color.WHITE
var outline_width: float = 1.0
var break_feedback_active: bool = false
var break_feedback_progress: float = 0.0
var break_feedback_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 10
	visible = false


## 根据剩余韧性更新血条外圈；韧性越低，白色描边的周长越短。
func set_poise(current_poise: float, max_poise: float, is_active: bool) -> void:
	_cancel_break_feedback()
	poise_ratio = clampf(current_poise / maxf(max_poise, 0.001), 0.0, 1.0)
	visible = is_active and poise_ratio > 0.0
	queue_redraw()


## 韧性归零时让完整外圈向外扩散并淡出，作为没有额外美术资源时的破韧反馈。
func play_break_feedback(duration: float) -> void:
	_cancel_break_feedback()
	break_feedback_active = true
	break_feedback_progress = 0.0
	visible = true
	queue_redraw()

	if duration <= 0.0:
		_finish_break_feedback()
		return

	break_feedback_tween = create_tween()
	break_feedback_tween.tween_method(_set_break_feedback_progress, 0.0, 1.0, duration)
	break_feedback_tween.finished.connect(_finish_break_feedback)


func _draw() -> void:
	if break_feedback_active:
		_draw_break_feedback()
		return
	if not visible or poise_ratio <= 0.0:
		return

	var inset: float = maxf(outline_width * 0.5, 0.5)
	var left: float = inset
	var top: float = inset
	var right: float = size.x - inset
	var bottom: float = size.y - inset
	if right <= left or bottom <= top:
		return

	# 从血条顶部中央开始顺时针绘制，形成类似环形韧性条的消耗效果。
	var path: PackedVector2Array = PackedVector2Array([
		Vector2((left + right) * 0.5, top),
		Vector2(right, top),
		Vector2(right, bottom),
		Vector2(left, bottom),
		Vector2(left, top),
		Vector2((left + right) * 0.5, top),
	])
	var perimeter: float = (right - left) * 2.0 + (bottom - top) * 2.0
	var remaining_length: float = perimeter * poise_ratio

	for index: int in range(path.size() - 1):
		if remaining_length <= 0.0:
			break
		var from_point: Vector2 = path[index]
		var to_point: Vector2 = path[index + 1]
		var segment_length: float = from_point.distance_to(to_point)
		if segment_length <= 0.0:
			continue

		var drawn_length: float = minf(remaining_length, segment_length)
		var segment_end: Vector2 = from_point.lerp(to_point, drawn_length / segment_length)
		draw_line(from_point, segment_end, outline_color, outline_width, true)
		remaining_length -= drawn_length


func _draw_break_feedback() -> void:
	var expansion: float = break_feedback_progress * 5.0
	var alpha: float = 1.0 - break_feedback_progress
	var color := Color(outline_color.r, outline_color.g, outline_color.b, outline_color.a * alpha)
	var rect := Rect2(Vector2(-expansion, -expansion), size + Vector2.ONE * expansion * 2.0)
	draw_rect(rect, color, false, outline_width + break_feedback_progress * 2.0, true)


func _set_break_feedback_progress(value: float) -> void:
	break_feedback_progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _finish_break_feedback() -> void:
	break_feedback_active = false
	break_feedback_progress = 0.0
	break_feedback_tween = null
	visible = false
	queue_redraw()


func _cancel_break_feedback() -> void:
	if break_feedback_tween != null and break_feedback_tween.is_valid():
		break_feedback_tween.kill()
	break_feedback_tween = null
	break_feedback_active = false
	break_feedback_progress = 0.0
