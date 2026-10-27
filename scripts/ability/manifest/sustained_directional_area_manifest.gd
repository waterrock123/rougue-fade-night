## 跟随施法者与鼠标方向的持续扇形领域：定时查询真实碰撞区域，统一结算伤害与命中状态。
## 不生成真实投射物，视觉粒子只负责展示；可复用于火焰吐息、持续毒雾等技能。
class_name SustainedDirectionalAreaManifest
extends AbilityManifest

@export_group("范围与持续")
@export var lifetime: float = 5.0
@export var max_range: float = 120.0
@export_range(1.0, 179.0, 1.0) var angle_degrees: float = 40.0
@export var tick_interval: float = 0.2
@export var follow_mouse: bool = true
@export var target_group: StringName = &"enemy"
@export_flags_2d_physics var target_mask: int = 4294967295
@export_flags_2d_physics var obstacle_mask: int = 1

@export_group("伤害与状态")
@export var damage: float = 10.0
## 可选成长规则；为空时保持原有固定伤害，光束等领域也能复用属性公式。
@export var scaling_rule: DamageScalingRule
@export var damage_types: Array[int] = [DamageData.DamageType.FIRE]
@export var tags: Array[String] = ["manifest", "area", "periodic", "active_skill", "fire"]
@export var can_crit: bool = false
@export var poise_damage: float = 0.0
@export var hit_status: StatusData
@export var hit_status_stacks: int = 1
## INF 沿用状态默认持续时间；不修改共享资源。
@export var hit_status_duration: float = INF
## 施法限制交给状态效果实现，领域仅负责施加与结束时按来源移除。
@export var caster_status: StatusData

var cast_context: AbilityContext
var source_ability_id: StringName = &""
var source_slot: int = -1
var source_key: String = ""
var elapsed: float = 0.0
var tick_timer: float = 0.0
var hit_shape: ConvexPolygonShape2D
var finished: bool = false
var caster_status_removed: bool = false
@onready var particles: CPUParticles2D = get_node_or_null("Flames") as CPUParticles2D


func _activate(context: AbilityContext) -> void:
	if context == null or not context.is_caster_action_valid():
		queue_free()
		return
	cast_context = context
	if is_instance_valid(context.ability):
		source_ability_id = context.ability.id
		source_slot = context.ability.runtime_slot_index
	source_key = "sustained_area_%d" % get_instance_id()
	hit_shape = _build_sector_shape()
	var controller: StatusController = context.caster.get_status_controller()
	if caster_status != null and controller != null:
		controller.add_status(caster_status, context.caster, source_key, 1, lifetime)
	_update_aim()
	if particles != null:
		particles.emitting = true


func _physics_process(delta: float) -> void:
	if finished or cast_context == null:
		return
	if not _can_continue():
		_finish()
		return
	_update_aim()
	# 只累计生命周期内的时间，避免低帧率在5秒结束后继续补伤害。
	var active_delta: float = minf(delta, maxf(lifetime - elapsed, 0.0))
	elapsed += active_delta
	tick_timer += active_delta
	var interval: float = maxf(tick_interval, 0.02)
	while tick_timer + 0.00001 >= interval and not finished:
		tick_timer -= interval
		_apply_tick()
		if not _can_continue():
			_finish()
	if elapsed + 0.00001 >= lifetime:
		_finish()


func _can_continue() -> bool:
	if not EventBus.is_battle_active or not cast_context.is_caster_action_valid():
		return false
	var caster: Entity = cast_context.caster
	if not caster.is_inside_tree() or caster.is_queued_for_deletion() or not caster.can_act():
		return false
	# 技能栏重建时允许同id技能继续喷射；真正卸下提供技能的装备则中断。
	var controller: AbilityController = caster.get_node_or_null("AbilityController") as AbilityController
	if source_ability_id == &"" or controller == null:
		return true
	for ability: Ability in controller.abilities:
		if is_instance_valid(ability) and ability.id == source_ability_id:
			return true
	return false


func _update_aim() -> void:
	var caster: Entity = cast_context.caster
	global_position = caster.global_position
	var direction: Vector2 = caster.get_facing_direction()
	if follow_mouse:
		direction = caster.get_global_mouse_position() - caster.global_position
	if direction.length_squared() > 0.0001:
		global_rotation = direction.angle()


## 凸多边形查询在本帧使用最新瞄准方向，避免Area2D旋转后等一帧才更新重叠结果。
func _build_sector_shape() -> ConvexPolygonShape2D:
	var result: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	var points: PackedVector2Array = [Vector2.ZERO]
	var half_angle: float = deg_to_rad(clampf(angle_degrees, 1.0, 179.0) * 0.5)
	for index: int in range(13):
		var angle: float = lerpf(-half_angle, half_angle, float(index) / 12.0)
		points.append(Vector2.RIGHT.rotated(angle) * maxf(max_range, 1.0))
	result.points = points
	return result


func _apply_tick() -> void:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = hit_shape
	query.transform = Transform2D(global_rotation, global_position)
	query.collision_mask = target_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query, 512)
	var seen: Dictionary = {}
	for hit: Dictionary in hits:
		var area: Area2D = hit.get("collider") as Area2D
		if not is_instance_valid(area):
			continue
		var target: Entity = area.get_parent() as Entity
		if not _valid_target(target) or seen.has(target.get_instance_id()):
			continue
		seen[target.get_instance_id()] = true
		_hit_target(target)
		if not _can_continue():
			return


func _valid_target(target: Entity) -> bool:
	if not is_instance_valid(target) or target == cast_context.caster or target.is_queued_for_deletion():
		return false
	if not target.can_be_targeted() or not target.matches_target_group(target_group):
		return false
	# 每个目标独立检测墙体，扇形边缘也不能绕过墙命中墙后单位。
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position, target.global_position, obstacle_mask
	)
	ray.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _hit_target(target: Entity) -> void:
	var caster: Entity = cast_context.caster
	var data: DamageData = DamageData.create(
		damage, damage_types, tags, caster, target, can_crit, scaling_rule,
		source_ability_id, source_slot, poise_damage
	)
	data.impact_direction = Vector2.RIGHT.rotated(global_rotation)
	stamp_damage_elements(data)
	target.apply_damage(data)
	# 闪避、无敌、零实际伤害和致死命中不再给目标附加燃烧。
	if not is_instance_valid(target) or target.is_dead or data.is_miss or data.final_damage <= 0.0:
		return
	var controller: StatusController = target.get_status_controller()
	if hit_status != null and controller != null:
		controller.add_status(hit_status, caster, source_key, hit_status_stacks, hit_status_duration)


func _finish() -> void:
	if finished:
		return
	finished = true
	_remove_caster_status()
	queue_free()


func _exit_tree() -> void:
	_remove_caster_status()


func _remove_caster_status() -> void:
	if caster_status_removed:
		return
	caster_status_removed = true
	if caster_status == null or cast_context == null or not is_instance_valid(cast_context.caster):
		return
	var controller: StatusController = cast_context.caster.get_status_controller()
	if is_instance_valid(controller):
		controller.remove_status_source(caster_status.id, source_key)
