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

@export_group("安全落点")
## 开启后，瞬移只会落在玩家可达的地图区域内，避免 Boss 穿到边界外。
@export var use_battle_map_safe_placement: bool = true
## 理想背后位置不可用时，每次向左右偏转的角度。
@export_range(5.0, 90.0, 1.0) var fallback_angle_step_degrees: float = 30.0
## 向目标两侧各尝试多少个候选方向。
@export_range(0, 6, 1) var fallback_angle_steps: int = 3
## 最后的邻近格搜索范围。范围应保持较小，避免跨墙跳到不符合预期的位置。
@export_range(0, 4, 1) var safe_search_radius_cells: int = 2
## 大型施法者可设为 1，要求落点周围一圈格子也可行走。
@export_range(0, 3, 1) var teleport_clearance_cells: int = 0


func _activate(context: AbilityContext) -> void:
	if context == null or context.caster == null or not context.is_caster_action_valid():
		return

	var target := _get_target(context)
	if target == null:
		return

	_write_target_to_context(context, target)
	var caster := context.caster
	var teleport_position_value: Variant = _get_teleport_position(caster, target)
	if not (teleport_position_value is Vector2):
		return
	var teleport_position: Vector2 = teleport_position_value
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


func _get_teleport_position(caster: Entity, target: Entity) -> Variant:
	var approach_direction := caster.global_position.direction_to(target.global_position)
	if approach_direction == Vector2.ZERO:
		approach_direction = caster.get_facing_direction()
	if approach_direction == Vector2.ZERO:
		approach_direction = Vector2.RIGHT

	var battle_map := _find_battle_map(caster)
	if battle_map == null:
		var right := Vector2(-approach_direction.y, approach_direction.x)
		return target.global_position + approach_direction * behind_distance + right * side_offset

	var candidate_directions: Array[Vector2] = [approach_direction]
	var angle_step: float = deg_to_rad(fallback_angle_step_degrees)
	for step: int in range(1, fallback_angle_steps + 1):
		candidate_directions.append(approach_direction.rotated(angle_step * float(step)))
		candidate_directions.append(approach_direction.rotated(-angle_step * float(step)))

	for candidate_direction: Vector2 in candidate_directions:
		var right := Vector2(-candidate_direction.y, candidate_direction.x)
		var candidate_position: Vector2 = (
			target.global_position
			+ candidate_direction * behind_distance
			+ right * side_offset
		)
		if _is_safe_teleport_candidate(battle_map, target.global_position, candidate_position):
			return candidate_position

	# 最后只在理想点附近做小范围修正；仍需保证目标到落点之间没有边界墙。
	var ideal_right := Vector2(-approach_direction.y, approach_direction.x)
	var ideal_position: Vector2 = target.global_position + approach_direction * behind_distance + ideal_right * side_offset
	var nearby_value: Variant = battle_map.get_nearest_playable_position(
		ideal_position,
		safe_search_radius_cells,
		teleport_clearance_cells
	)
	if nearby_value is Vector2 and _is_safe_teleport_candidate(
		battle_map,
		target.global_position,
		nearby_value
	):
		return nearby_value

	# 所有候选都不安全时取消瞬移，让后续攻击也不会在场外生成。
	return null


func _find_battle_map(caster: Entity) -> BattleMap:
	if not use_battle_map_safe_placement or caster == null or caster.get_tree() == null:
		return null
	return caster.get_tree().get_first_node_in_group("battle_map") as BattleMap


func _is_safe_teleport_candidate(
	battle_map: BattleMap,
	target_position: Vector2,
	candidate_position: Vector2
) -> bool:
	if not battle_map.is_world_position_in_playable_region(candidate_position, teleport_clearance_cells):
		return false
	return battle_map.is_world_segment_in_playable_region(
		target_position,
		candidate_position,
		teleport_clearance_cells
	)


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
