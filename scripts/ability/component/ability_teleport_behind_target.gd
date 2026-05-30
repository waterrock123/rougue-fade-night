## 瞬移到目标背后组件。
## 只负责把施法者移动到目标背后并面向目标，不负责伤害或残影。
## “背后”默认按施法者到目标的方向继续穿过去，适合瞬身斩、背刺、闪现突袭。
class_name AbilityTeleportBehindTarget
extends AbilityComponent

@export var target_index: int = 0
@export var behind_distance: float = 34.0
@export var side_offset: float = 0.0
@export var fallback_search_radius: float = 360.0
@export var face_target_after_teleport: bool = true
@export var write_direction_to_context: bool = true


func _activate(context: AbilityContext) -> void:
	if context == null or context.caster == null or not context.is_caster_action_valid():
		return

	var target := _get_target(context)
	if target == null:
		return

	_write_target_to_context(context, target)
	var caster := context.caster
	var teleport_position := _get_teleport_position(caster, target)
	caster.global_position = teleport_position

	var direction_to_target := caster.global_position.direction_to(target.global_position)
	if direction_to_target == Vector2.ZERO:
		direction_to_target = caster.get_facing_direction()
	if write_direction_to_context:
		context.locked_direction = direction_to_target
	if face_target_after_teleport:
		caster.turn_to_position(target.global_position)


func _get_target(context: AbilityContext) -> Entity:
	if target_index >= 0 and target_index < context.targets.size():
		var target = context.targets[target_index]
		if target is Entity and _is_valid_target(context.caster, target):
			return target

	return _find_nearest_opponent(context.caster)


func _write_target_to_context(context: AbilityContext, target: Entity) -> void:
	if target_index >= 0 and target_index < context.targets.size():
		context.targets[target_index] = target
		return

	context.targets.clear()
	context.targets.append(target)


func _get_teleport_position(caster: Entity, target: Entity) -> Vector2:
	var approach_direction := caster.global_position.direction_to(target.global_position)
	if approach_direction == Vector2.ZERO:
		approach_direction = caster.get_facing_direction()
	if approach_direction == Vector2.ZERO:
		approach_direction = Vector2.RIGHT

	var right := Vector2(-approach_direction.y, approach_direction.x)
	return target.global_position + approach_direction * behind_distance + right * side_offset


func _find_nearest_opponent(caster: Entity) -> Entity:
	var nearest: Entity
	var nearest_distance := INF
	var groups := _get_opponent_groups(caster)

	for group_name in groups:
		for node in caster.get_tree().get_nodes_in_group(String(group_name)):
			if not (node is Entity):
				continue

			var candidate := node as Entity
			if not _is_valid_target(caster, candidate):
				continue

			var distance := caster.global_position.distance_to(candidate.global_position)
			if distance > fallback_search_radius:
				continue
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate

	return nearest


func _get_opponent_groups(caster: Entity) -> Array[StringName]:
	var groups: Array[StringName] = []
	if caster.is_enemy_side():
		groups.append(&"player")
		groups.append(&"player_ally")
		groups.append(&"summon_pet")
	else:
		groups.append(&"enemy")
	return groups


func _is_valid_target(caster: Entity, target: Entity) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target == caster or target.is_dead:
		return false
	if target.has_method("can_be_targeted") and not target.can_be_targeted():
		return false
	if caster.is_enemy_side():
		return target.is_player_side()
	if caster.is_player_side():
		return target.is_enemy_side()
	return true
