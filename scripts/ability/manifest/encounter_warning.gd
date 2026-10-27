## 世界坐标预警：圆形、扇形或带安全缺口的环形；只显示范围，不结算伤害。
## 绑定动作上下文，施法被取消、死亡或离开场景时立即清理。
class_name EncounterWarning
extends Node2D

enum Shape { CIRCLE, SECTOR, GAP_RING }
var context: AbilityContext
var shape: Shape = Shape.CIRCLE
var radius: float = 40.0
var inner_radius: float = 0.0
var angle_degrees: float = 110.0
var gap_degrees: float = 65.0
var duration: float = 1.0
var elapsed: float = 0.0
var persist_after_action: bool = false
var color: Color = Color(1.0, 0.12, 0.05, 0.22)


static func spawn(action: AbilityContext, location: Vector2, size: float, lifetime: float) -> EncounterWarning:
	var warning: EncounterWarning = EncounterWarning.new()
	warning.context = action
	warning.radius = size
	warning.duration = maxf(lifetime, 0.01)
	# 地面之上、角色与山丘之下，避免范围填色盖住角色。
	warning.z_index = -20
	var parent: Node = action.caster.get_parent()
	parent.add_child(warning)
	warning.global_position = location
	return warning


func _process(delta: float) -> void:
	if context == null or not is_instance_valid(context.caster) or context.caster.is_dead:
		queue_free()
		return
	if not persist_after_action and not context.is_caster_action_valid():
		queue_free()
		return
	elapsed += delta
	if elapsed >= duration:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var tint: Color = color
	tint.a *= lerpf(0.65, 1.0, clampf(elapsed / duration, 0.0, 1.0))
	if shape == Shape.CIRCLE:
		draw_circle(Vector2.ZERO, radius, tint)
		return
	var start: float = -deg_to_rad(angle_degrees) * 0.5
	var span: float = deg_to_rad(angle_degrees)
	if shape == Shape.GAP_RING:
		start = deg_to_rad(gap_degrees) * 0.5
		span = TAU - deg_to_rad(gap_degrees)
	for index: int in range(64):
		var first: Vector2 = Vector2.RIGHT.rotated(start + span * float(index) / 64.0)
		var second: Vector2 = Vector2.RIGHT.rotated(start + span * float(index + 1) / 64.0)
		var points: PackedVector2Array = PackedVector2Array([first * inner_radius, first * radius, second * radius])
		if inner_radius > 0.0:
			points.append(second * inner_radius)
		draw_colored_polygon(points, tint)
