## 持续直线光束：复用领域的定时碰撞与伤害，只负责矩形形状、缓慢转向和光束显示。
class_name SustainedBeamManifest
extends SustainedDirectionalAreaManifest

@export var beam_width: float = 10.0
@export var turn_speed_degrees: float = 90.0
var aim_initialized: bool = false


func _build_sector_shape() -> ConvexPolygonShape2D:
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	var half_width: float = maxf(beam_width, 1.0) * 0.5
	shape.points = PackedVector2Array([
		Vector2(0, -half_width), Vector2(max_range, -half_width),
		Vector2(max_range, half_width), Vector2(0, half_width),
	])
	return shape


func _update_aim() -> void:
	var caster: Entity = cast_context.caster
	global_position = caster.global_position
	var direction: Vector2 = caster.get_global_mouse_position() - global_position
	if direction.is_zero_approx():
		direction = caster.get_facing_direction()
	var desired: float = direction.angle()
	if not aim_initialized:
		global_rotation = desired
		aim_initialized = true
	else:
		global_rotation = rotate_toward(global_rotation, desired, deg_to_rad(turn_speed_degrees) * get_physics_process_delta_time())
	_update_lines()


## 显示和伤害都受墙体限制，不把激光画到墙后；不生成每帧临时节点。
func _update_lines() -> void:
	var end: Vector2 = Vector2.RIGHT.rotated(global_rotation) * max_range
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + end, obstacle_mask)
	ray.collide_with_areas = false
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		end = (hit["position"] as Vector2) - global_position
	var local_end: Vector2 = end.rotated(-global_rotation)
	for child: Node in get_children():
		if child is Line2D:
			(child as Line2D).points = PackedVector2Array([Vector2.ZERO, local_end])
