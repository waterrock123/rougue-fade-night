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
}

@export var radius = 30.0
@export var target_mode: TargetMode = TargetMode.AUTO_OPPONENT
@export var direction_mode: DirectionMode = DirectionMode.AUTO
@export var require_in_front: bool = true
@export_range(0.0, 360.0) var front_angle: float = 90.0
@export var include_self: bool = false


func _activate(context: AbilityContext):
	context.targets = check_colliders_around_position(context.caster, radius)


func check_colliders_around_position(caster: Entity, search_radius: float) -> Array[Entity]:
	var shape = CircleShape2D.new()
	shape.radius = search_radius

	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform.origin = caster.global_position
	query.collide_with_areas = true

	var space_state = caster.get_world_2d().direct_space_state
	var results = space_state.intersect_shape(query)
	var targets: Array[Entity] = []

	for result in results:
		var collider = result.collider
		var parent = collider.get_parent()
		if not (parent is Entity):
			continue

		var target := parent as Entity
		if not include_self and target == caster:
			continue
		if not _matches_target_mode(caster, target):
			continue
		if require_in_front and not _is_target_in_front(caster, target):
			continue
		if targets.has(target):
			continue

		targets.push_back(target)

	return targets


func _matches_target_mode(caster: Entity, target: Entity) -> bool:
	match target_mode:
		TargetMode.PLAYER:
			return target.is_in_group("player")
		TargetMode.ENEMY:
			return target.is_in_group("enemy")
		TargetMode.ENTITY:
			return true
		TargetMode.AUTO_OPPONENT:
			if caster.is_in_group("player"):
				return target.is_in_group("enemy")
			if caster.is_in_group("enemy"):
				return target.is_in_group("player")
			return target != caster

	return false


func _is_target_in_front(caster: Entity, target: Entity) -> bool:
	var reference_dir := _get_reference_direction(caster)
	if reference_dir == Vector2.ZERO:
		return true

	var to_target = (target.global_position - caster.global_position).normalized()
	var dot = reference_dir.dot(to_target)
	return dot >= cos(deg_to_rad(front_angle * 0.5))


func _get_reference_direction(caster: Entity) -> Vector2:
	match _resolve_direction_mode(caster):
		DirectionMode.CURSOR:
			var camera := get_viewport().get_camera_2d()
			if camera == null:
				return caster.get_facing_direction()
			var mouse_pos = camera.get_global_mouse_position()
			return (mouse_pos - caster.global_position).normalized()
		DirectionMode.FACING:
			return caster.get_facing_direction()

	return caster.get_facing_direction()


func _resolve_direction_mode(caster: Entity) -> DirectionMode:
	if direction_mode != DirectionMode.AUTO:
		return direction_mode

	if caster.is_in_group("player"):
		return DirectionMode.CURSOR

	return DirectionMode.FACING
