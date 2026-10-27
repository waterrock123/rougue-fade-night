## 纯视觉圆形脉冲，不承担伤害和目标搜索，可复用为光环/冲击波提示。
class_name RadialPulseVisualManifest
extends AbilityManifest

@export var radius: float = 80.0
@export var duration: float = 0.45
@export var pulse_color: Color = Color(0.75, 0.4, 1.0, 0.45)
@export var line_width: float = 1.5
var progress: float = 0.0


func _activate(_context: AbilityContext) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(_update_pulse, 0.0, 1.0, maxf(duration, 0.01))
	tween.tween_callback(queue_free)


func _update_pulse(value: float) -> void:
	progress = value
	queue_redraw()


func _draw() -> void:
	var color: Color = pulse_color
	color.a *= 1.0 - progress
	draw_arc(Vector2.ZERO, radius * progress, 0.0, TAU, 64, color, line_width, true)
	color.a *= 0.3
	draw_circle(Vector2.ZERO, radius * progress, color)
