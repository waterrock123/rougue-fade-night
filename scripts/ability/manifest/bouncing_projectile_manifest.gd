## 物理飞行的跳弹：命中后寻找附近未命中的敌人，保留施法归属和元素快照。
## 接触结算延后到物理回调之外，每跳对完整伤害（含属性成长）衰减，不重复生成发射事件。
class_name BouncingProjectileManifest
extends ProjectileManifest

@export var max_targets: int = 4
@export var bounce_radius: float = 140.0
@export_range(0.0, 1.0, 0.01) var damage_retention: float = 0.8
@export var arrival_radius: float = 5.0
var hits_used: int = 0
var contact_pending: bool = false
var bounce_target: WeakRef


func _on_area_2d_area_entered(area: Area2D) -> void:
	if contact_pending or is_queued_for_deletion() or try_intercept_projectile_movement(Vector2.ZERO):
		return
	var candidate: Node = area.get_parent()
	if candidate is Entity and _valid_contact(candidate as Entity):
		_queue_contact(candidate as Entity)


func _valid_contact(target: Entity) -> bool:
	if not is_instance_valid(target) or target == source or target.is_queued_for_deletion():
		return false
	if target.is_in_group("map_object") or hit_target_ids.has(target.get_instance_id()):
		return false
	return target.can_be_targeted() and _matches_target_group(target)


func _queue_contact(target: Entity) -> void:
	contact_pending = true
	_resolve_contact.call_deferred(weakref(target))


func _resolve_contact(target_ref: WeakRef) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var valid_source: Entity = _get_valid_source()
	if valid_source == null or valid_source.is_dead or not EventBus.is_battle_active:
		queue_free()
		return
	var candidate: Variant = target_ref.get_ref()
	if is_instance_valid(candidate) and candidate is Entity and _valid_contact(candidate as Entity):
		var target: Entity = candidate as Entity
		# 必须先登记，避免伤害信号引起重入时重复结算同一目标。
		hit_target_ids[target.get_instance_id()] = true
		var data: DamageData = _create_hit_damage(target, valid_source)
		hits_used += 1
		target.apply_damage(data)
		_notify_resolution(&"hit")
		if hit_sound != null:
			AudioController.play(hit_sound, global_position)
	contact_pending = false
	if not is_instance_valid(valid_source) or valid_source.is_dead or not EventBus.is_battle_active:
		queue_free()
		return
	if hits_used >= maxi(max_targets, 1):
		queue_free()
		return
	_select_next_target()


func _create_hit_damage(target: Entity, valid_source: Entity) -> DamageData:
	var data: DamageData = super._create_hit_damage(target, valid_source)
	data.skill_damage_multiplier *= pow(clampf(damage_retention, 0.0, 1.0), hits_used)
	return data


func _find_bounce_target() -> Entity:
	var valid_source: Entity = _get_valid_source()
	var excluded: Array[int] = []
	excluded.assign(hit_target_ids.keys())
	for target: Entity in SkillCombatQuery.enemies_within(valid_source, global_position, bounce_radius, excluded):
		if not _valid_contact(target):
			continue
		# 自动跳弹不主动招惹尚未激活的中立悬赏怪，直射命中仍正常生效。
		if target.has_method("is_neutral_bounty_elite") and target.is_neutral_bounty_elite():
			continue
		return target
	return null


func _select_next_target() -> void:
	var target: Entity = _find_bounce_target()
	if target == null:
		queue_free()
		return
	bounce_target = weakref(target)
	current_distance = 0.0
	# 每一跳有独立路程预算，初次直射接近最大距离也能继续弹跳。
	max_distance = maxf(bounce_radius, 1.0) + arrival_radius
	_aim_at(target)


func _aim_at(target: Entity) -> void:
	var direction: Vector2 = global_position.direction_to(target.global_position)
	if not direction.is_zero_approx():
		current_dir = direction
		global_rotation = direction.angle()


func _process_forward(delta: float) -> void:
	if contact_pending or is_queued_for_deletion():
		return
	if not EventBus.is_battle_active:
		queue_free()
		return
	if bounce_target != null:
		var candidate: Variant = bounce_target.get_ref()
		if not is_instance_valid(candidate) or not _valid_contact(candidate as Entity):
			_select_next_target()
			return
		var target: Entity = candidate as Entity
		var valid_source: Entity = _get_valid_source()
		if valid_source == null or not SkillCombatQuery.has_sight(valid_source, global_position, target.global_position):
			_select_next_target()
			return
		_aim_at(target)
		# 目标与弹体重叠或高速接近时不依赖第二次area_entered，仍走同一去重结算入口。
		if global_position.distance_to(target.global_position) <= maxf(arrival_radius, speed * delta):
			_queue_contact(target)
			return
		super._process_forward(delta)
	else:
		super._process_forward(delta)


func _update_homing_direction(delta: float) -> void:
	# 首次直射可以接受装备追踪加成；弹跳阶段由锁定目标引导，不能被普通追踪改回旧目标。
	if bounce_target == null:
		super._update_homing_direction(delta)
