## 接触后结算一次并消失的投射物。半径为0时只命中接触目标，大于0时改为圆形爆炸。
## 可概率附加状态；伤害、成长、暴击、削韧仍统一交给DamageData与Entity。
class_name ImpactProjectileManifest
extends ProjectileManifest

@export_group("接触效果")
@export var impact_radius: float = 0.0
@export_flags_2d_physics var impact_target_mask: int = 4294967295
@export var impact_visual_scene: PackedScene
@export var hit_status: StatusData
@export_range(0.0, 1.0, 0.01) var hit_status_chance: float = 0.0
@export var hit_status_stacks: int = 1
@export var hit_status_duration: float = INF
var impact_pending: bool = false


func _on_area_2d_area_entered(area: Area2D) -> void:
	if impact_pending or try_intercept_projectile_movement(Vector2.ZERO):
		return
	var candidate: Node = area.get_parent()
	if not candidate is Entity or not _is_impact_target(candidate as Entity):
		return
	# 同帧多个受击区域只接受第一次接触；实际查询和生成视觉延后到物理信号之外。
	impact_pending = true
	set_process(false)
	var hit_area: Area2D = get_node_or_null("Area2D") as Area2D
	if hit_area != null:
		hit_area.set_deferred("monitoring", false)
	_resolve_impact.call_deferred(candidate, global_position)


func _resolve_impact(contact: Variant, position_at_hit: Vector2) -> void:
	var valid_source: Entity = _get_valid_source()
	if not is_inside_tree() or valid_source == null or valid_source.is_dead:
		queue_free()
		return
	global_position = position_at_hit
	var targets: Array[Entity] = _collect_impact_targets(contact)
	_spawn_impact_visual(valid_source)
	for candidate: Variant in targets:
		if not is_instance_valid(valid_source) or valid_source.is_dead:
			break
		if not _is_impact_target(candidate):
			continue
		var target: Entity = candidate as Entity
		var data: DamageData = _create_hit_damage(target, valid_source)
		target.apply_damage(data)
		if is_instance_valid(target) and is_instance_valid(valid_source):
			_try_apply_status(target, valid_source, data)
	_notify_resolution(&"hit")
	if hit_sound != null:
		AudioController.play(hit_sound, global_position)
	queue_free()


## 直接接触的目标只计一次，爆炸中多个Area2D也按实体去重。
func _collect_impact_targets(contact: Variant) -> Array[Entity]:
	var result: Array[Entity] = []
	if is_instance_valid(contact) and contact is Entity and _is_impact_target(contact as Entity):
		result.append(contact as Entity)
	if impact_radius <= 0.0:
		return result
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = impact_radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = impact_target_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query, 512):
		var area: Area2D = hit.get("collider") as Area2D
		if not is_instance_valid(area):
			continue
		var target: Entity = area.get_parent() as Entity
		if _is_impact_target(target) and not result.has(target) and _has_impact_sight(target):
			result.append(target)
	return result


func _is_impact_target(target: Variant) -> bool:
	if not is_instance_valid(target) or not target is Entity:
		return false
	return not target.is_queued_for_deletion() and target != source and target.can_be_targeted() and _matches_target_group(target)


func _has_impact_sight(target: Entity) -> bool:
	if not blocked_by_world:
		return true
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, target.global_position, world_collision_mask)
	ray.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _try_apply_status(target: Entity, valid_source: Entity, data: DamageData) -> void:
	if hit_status == null or hit_status_chance <= 0.0 or data.is_miss or data.final_damage <= 0.0:
		return
	if not is_instance_valid(valid_source) or not _is_impact_target(target):
		return
	if randf() >= hit_status_chance or not is_instance_valid(target.status_controller):
		return
	var key: String = "%s_%s" % [source_ability_id, hit_status.id]
	target.status_controller.add_status(hit_status, valid_source, key, hit_status_stacks, hit_status_duration)


func _spawn_impact_visual(valid_source: Entity) -> void:
	if impact_visual_scene == null:
		return
	var visual: AbilityManifest = impact_visual_scene.instantiate() as AbilityManifest
	if visual == null:
		return
	get_parent().add_child(visual)
	visual.global_position = global_position
	visual.activate(AbilityContext.new(valid_source, null))
