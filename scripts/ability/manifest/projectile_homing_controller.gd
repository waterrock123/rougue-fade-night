## 投射物追踪转向辅助器。
## 只负责寻找目标与计算新方向，不负责移动、伤害或生命周期，可供不同投射物 Manifest 复用。
class_name ProjectileHomingController
extends RefCounted

var current_target: Entity
var retarget_timer: float = 0.0


## 根据附近目标修正当前飞行方向；turn_speed 使用弧度/秒。
func steer(
	projectile: Node2D,
	source: Entity,
	target_group: StringName,
	current_direction: Vector2,
	turn_speed: float,
	acquire_radius: float,
	retarget_interval: float,
	delta: float
) -> Vector2:
	if projectile == null or not projectile.is_inside_tree() or target_group == &"" or turn_speed <= 0.0:
		return current_direction

	if not _is_valid_target(projectile, source, current_target, target_group, acquire_radius, false):
		current_target = null
		retarget_timer = maxf(retarget_timer - delta, 0.0)
		if retarget_timer <= 0.0:
			current_target = _find_nearest_target(projectile, source, target_group, acquire_radius)
			retarget_timer = maxf(retarget_interval, 0.01)

	if current_target == null:
		return current_direction

	var desired_direction: Vector2 = projectile.global_position.direction_to(current_target.global_position)
	if desired_direction == Vector2.ZERO:
		return current_direction
	if current_direction == Vector2.ZERO:
		return desired_direction

	var max_turn: float = turn_speed * delta
	var angle_delta: float = wrapf(desired_direction.angle() - current_direction.angle(), -PI, PI)
	return current_direction.rotated(clampf(angle_delta, -max_turn, max_turn)).normalized()


func reset() -> void:
	current_target = null
	retarget_timer = 0.0


func _find_nearest_target(
	projectile: Node2D,
	source: Entity,
	target_group: StringName,
	acquire_radius: float
) -> Entity:
	var nearest: Entity
	var nearest_distance: float = INF
	for node: Node in projectile.get_tree().get_nodes_in_group(String(target_group)):
		if not (node is Entity):
			continue
		var candidate: Entity = node as Entity
		if not _is_valid_target(projectile, source, candidate, target_group, acquire_radius, true):
			continue

		var distance: float = projectile.global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest


func _is_valid_target(
	projectile: Node2D,
	source: Entity,
	candidate: Entity,
	target_group: StringName,
	acquire_radius: float,
	check_radius: bool
) -> bool:
	if candidate == null or not is_instance_valid(candidate) or candidate == source or candidate.is_dead:
		return false
	if candidate.has_method("can_be_targeted") and not candidate.can_be_targeted():
		return false
	if candidate.has_method("is_neutral_bounty_elite") and candidate.is_neutral_bounty_elite():
		return false
	if not candidate.matches_target_group(target_group):
		return false
	if check_radius and acquire_radius > 0.0:
		return projectile.global_position.distance_to(candidate.global_position) <= acquire_radius
	return true
