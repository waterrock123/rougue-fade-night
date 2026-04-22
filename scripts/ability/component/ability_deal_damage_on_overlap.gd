class_name AbilityDealDamageOnOverlap
extends AbilityComponent

# Active window for overlap-based damage.
@export var active_duration: float = 0.2
@export var hit_once_per_activation: bool = true
@export var collision_area_path: NodePath = ^"Area2D"

# Damage settings.
@export var damage: float = 10.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var tags: Array[String] = ["skill", "charge"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()


func _activate(context: AbilityContext):
	var caster := context.caster
	if caster == null:
		return

	var hit_cache := {}
	var elapsed := 0.0

	while elapsed < active_duration:
		var targets := _collect_overlap_targets(caster)
		context.targets = targets

		for target in targets:
			if hit_once_per_activation and hit_cache.has(target):
				continue

			var damage_data := DamageData.create(
				damage,
				damage_types,
				tags,
				caster,
				target,
				can_crit,
				scaling_rule
			)
			target.apply_damage(damage_data)
			hit_cache[target] = true

		await get_tree().physics_frame
		elapsed += 1.0 / float(Engine.physics_ticks_per_second)


func _collect_overlap_targets(caster: Entity) -> Array[Entity]:
	var area := caster.get_node_or_null(collision_area_path) as Area2D
	if area == null:
		return []

	var hit_targets: Array[Entity] = []

	for shape_node in area.get_children():
		if not (shape_node is CollisionShape2D):
			continue

		var collision_shape := shape_node as CollisionShape2D
		if collision_shape.disabled or collision_shape.shape == null:
			continue

		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collision_shape.shape
		query.transform = collision_shape.global_transform
		query.collide_with_areas = true

		var results := caster.get_world_2d().direct_space_state.intersect_shape(query)
		for result in results:
			var collider = result.collider
			if collider == null or collider == area:
				continue

			var parent = collider.get_parent()
			if not (parent is Entity):
				continue

			var target := parent as Entity
			if target == caster:
				continue
			if not _is_valid_target(caster, target):
				continue
			if hit_targets.has(target):
				continue

			hit_targets.push_back(target)

	return hit_targets


func _is_valid_target(caster: Entity, target: Entity) -> bool:
	if caster.is_in_group("enemy"):
		return target.is_in_group("player")
	if caster.is_in_group("player"):
		return target.is_in_group("enemy")
	return target != caster
