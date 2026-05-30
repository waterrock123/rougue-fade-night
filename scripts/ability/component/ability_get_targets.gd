## 目标搜索组件。
## 可按施法者或锁定位置为中心搜索玩家、敌人或所有实体，支持圆形范围与扇形范围。
## 常用于近战斩击、扇形攻击、冲击波等“先找目标，再造成伤害”的技能。
class_name AbilityGetTarget
extends AbilityComponent

enum TargetMode {
	AUTO_OPPONENT,
	PLAYER,
	ENEMY,
	ENTITY,
}

enum DirectionMode {
	AUTO,
	CURSOR,
	FACING,
	PLAYER,
	LOCKED_CONTEXT,
}

enum SearchShape {
	## 只按 radius 搜索范围，不限制方向。
	CIRCLE,
	## 先用 radius 搜索候选目标，再按 direction_mode 与 sector_angle 过滤成扇形。
	SECTOR,
}

enum OriginMode {
	## 以施法者为中心搜索，保留旧技能的默认行为。
	CASTER,
	## 以 AbilityContext.targets[0] 的位置为中心搜索，适合先锁定落点再结算范围伤害/控制。
	FIRST_TARGET,
}

## 搜索形状。SECTOR 适合扇形技能，CIRCLE 适合圆形光环/AOE。
@export var search_shape: SearchShape = SearchShape.CIRCLE
## 搜索半径。扇形模式下就是扇形半径。
@export var radius: float = 30.0
## 搜索圆心来源。默认以施法者为圆心；定点 AOE 可以改成 FIRST_TARGET。
@export var origin_mode: OriginMode = OriginMode.CASTER
## 要搜索的目标阵营。
@export var target_mode: TargetMode = TargetMode.AUTO_OPPONENT
## 扇形/前方判断使用的方向来源。
@export var direction_mode: DirectionMode = DirectionMode.AUTO
## 旧配置兼容项。开启后即使 search_shape 是 CIRCLE，也会按 front_angle 过滤前方目标。
@export var require_in_front: bool = false
## 旧配置兼容项。建议新技能使用 sector_angle。
@export_range(0.0, 360.0) var front_angle: float = 90.0
## 扇形角度。search_shape 为 SECTOR 时生效。
@export_range(1.0, 360.0, 1.0) var sector_angle: float = 90.0
@export var include_self: bool = false


func _activate(context: AbilityContext) -> void:
	context.targets = check_colliders_around_position(context, radius)


func check_colliders_around_position(context: AbilityContext, search_radius: float) -> Array[Entity]:
	if context == null or context.caster == null:
		return []

	var caster := context.caster
	var search_origin := _get_search_origin(context)
	var shape := CircleShape2D.new()
	shape.radius = search_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform.origin = search_origin
	query.collide_with_areas = true

	var space_state := caster.get_world_2d().direct_space_state
	var results := space_state.intersect_shape(query)
	var targets: Array[Entity] = []

	for result in results:
		var collider = result.collider
		var parent = collider.get_parent()
		if not (parent is Entity):
			continue

		var target := parent as Entity
		if not include_self and target == caster:
			continue
		if target.has_method("can_be_targeted") and not target.can_be_targeted():
			continue
		if not _matches_target_mode(caster, target):
			continue
		if _should_filter_by_sector() and not _is_target_in_sector(context, target, search_origin):
			continue
		if targets.has(target):
			continue

		targets.push_back(target)

	return targets


func _matches_target_mode(caster: Entity, target: Entity) -> bool:
	match target_mode:
		TargetMode.PLAYER:
			return target.is_player_side()
		TargetMode.ENEMY:
			return target.is_enemy_side()
		TargetMode.ENTITY:
			return true
		TargetMode.AUTO_OPPONENT:
			if caster.is_player_side():
				return target.is_enemy_side()
			if caster.is_enemy_side():
				return target.is_player_side()
			return target != caster

	return false


func _should_filter_by_sector() -> bool:
	return search_shape == SearchShape.SECTOR or require_in_front


func _is_target_in_sector(context: AbilityContext, target: Entity, search_origin: Vector2) -> bool:
	var reference_dir := _get_reference_direction(context, target)
	if reference_dir == Vector2.ZERO:
		return true

	var to_target := (target.global_position - search_origin).normalized()
	if to_target == Vector2.ZERO:
		return true

	var angle := sector_angle if search_shape == SearchShape.SECTOR else front_angle
	var dot := reference_dir.dot(to_target)
	return dot >= cos(deg_to_rad(angle * 0.5))


func _get_reference_direction(context: AbilityContext, current_target: Entity = null) -> Vector2:
	var caster := context.caster
	match _resolve_direction_mode(caster):
		DirectionMode.CURSOR:
			var camera := get_viewport().get_camera_2d()
			if camera == null:
				return caster.get_facing_direction()
			var mouse_pos := camera.get_global_mouse_position()
			return (mouse_pos - caster.global_position).normalized()
		DirectionMode.FACING:
			return caster.get_facing_direction()
		DirectionMode.PLAYER:
			return _get_direction_to_player(caster)
		DirectionMode.LOCKED_CONTEXT:
			if context.locked_direction != Vector2.ZERO:
				return context.locked_direction.normalized()
			if current_target != null:
				return caster.global_position.direction_to(current_target.global_position)

	return caster.get_facing_direction()


func _resolve_direction_mode(caster: Entity) -> DirectionMode:
	if direction_mode != DirectionMode.AUTO:
		return direction_mode

	if caster.is_in_group("player"):
		return DirectionMode.CURSOR

	return DirectionMode.FACING


## 给敌人/Boss 技能使用：扇形搜索方向朝向玩家，而不是只按左右朝向判断。
func _get_direction_to_player(caster: Entity) -> Vector2:
	var player_side_target := _find_nearest_player_side_target(caster)
	if player_side_target == null:
		return caster.get_facing_direction()

	var direction := caster.global_position.direction_to(player_side_target.global_position)
	return direction if direction != Vector2.ZERO else caster.get_facing_direction()


func _find_nearest_player_side_target(caster: Entity) -> Entity:
	var nearest: Entity
	var nearest_distance := INF

	for group_name in [&"player", &"player_ally", &"summon_pet"]:
		for node in get_tree().get_nodes_in_group(String(group_name)):
			if not (node is Entity):
				continue

			var candidate := node as Entity
			if not candidate.is_player_side():
				continue
			if candidate.has_method("can_be_targeted") and not candidate.can_be_targeted():
				continue

			var distance := caster.global_position.distance_to(candidate.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate

	return nearest


func _get_search_origin(context: AbilityContext) -> Vector2:
	if origin_mode == OriginMode.FIRST_TARGET and not context.targets.is_empty():
		var target = context.targets[0]
		if target is Node2D:
			return (target as Node2D).global_position
		if target is Vector2:
			return target

	return context.caster.global_position
