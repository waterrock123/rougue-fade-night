## 环绕飞剑 Manifest。
## 它不依赖具体技能，可以被地图物体、遗物效果、套装效果共同复用。
class_name OrbitingSwordManifest
extends AbilityManifest

@export_group("环绕")
## 留空时会根据施放者阵营自动决定目标；玩家侧默认攻击 enemy，敌人侧默认攻击 player。
@export var target_group: StringName = &""
@export var auto_target_group_from_source: bool = true
@export var orbit_radius: float = 54.0
@export var orbit_speed: float = 2.1
## 半径缓慢波动，让轨迹有“一圈大一圈小”的连续变化。
@export var radius_wave_amplitude: float = 7.0
@export var radius_wave_speed: float = 1.2
## 多把剑会获得轻微不同的半径，避免完全重叠成一把。
@export var slot_radius_variation: float = 4.0
## 越低越有阻尼感，越高越紧贴理论轨道。
@export var follow_smoothing: float = 18.0
## 小于等于 0 表示持续到场景结束或来源失效。
@export var lifetime: float = 0.0
@export var rotate_to_tangent: bool = true
@export var rotation_offset: float = PI * 0.5

@export_group("智能突刺")
## 开启后，飞剑在环绕时会寻找靠近持有者的敌人，并短暂加速穿过目标后回到轨道。
@export var enable_smart_dash: bool = true
## 以持有者为中心的索敌半径；敌人进入这个范围后，飞剑才会主动出击。
@export var dash_acquire_radius: float = 118.0
@export var dash_cooldown: float = 1.2
@export var dash_speed: float = 390.0
@export var dash_return_speed: float = 300.0
## 飞到目标点后额外穿过的距离，让表现更像“划过去”而不是停在敌人身上。
@export var dash_pass_distance: float = 42.0
@export var dash_return_arrive_distance: float = 6.0
## 线段扫掠判定半径，避免突刺速度太快时 Area2D 漏判。
@export var dash_swept_hit_radius: float = 13.0
## 生成后至少环绕一小段时间再突刺，避免刚出现就全部扎出去。
@export var dash_min_orbit_time: float = 0.25
@export var dash_rotate_to_direction: bool = true
## 开启后，突刺/回轨会让 Sprite2D 的视觉剑尖朝向运动方向。
## 这样你在场景里调过的 Sprite2D.rotation 会被保留为美术偏移，不会破坏环绕时已经调好的方向。
@export var dash_align_sprite_tip_to_direction: bool = true
## 如果后续换了“剑尖不是朝右”的贴图，可以用这个额外角度微调突刺朝向。
@export var dash_tip_extra_angle: float = 0.0

@export_group("拖尾")
@export var enable_trail: bool = true
@export var trail_color: Color = Color(0.72, 0.9, 1.0, 0.44)
@export var trail_max_points: int = 12
@export var trail_min_distance: float = 4.0
@export var trail_width: float = 4.0
## 突刺时拖尾会稍微更亮一点，突出飞剑冲出去的瞬间。
@export var trail_dash_alpha_multiplier: float = 1.45

@export_group("伤害")
@export var damage: float = 12.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var tags: Array[String] = ["manifest", "orbiting_sword", "melee_effect", "sword"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()
## 飞剑单次命中的固定削韧值；高频命中时建议配置为较小正数。
@export var poise_damage: float = 4.0
## 默认不攻击地图交互物体，避免飞剑把苹果树、弹药箱、剑座这类物体自动清掉。
@export var can_hit_map_objects: bool = false
## 同一把飞剑对同一目标的重复命中间隔，避免站在敌人身上时每帧造成伤害。
@export var hit_interval: float = 0.45
@export var hit_sound: AudiioConfig

@onready var sprite2d: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var hit_area: Area2D = get_node_or_null("Area2D") as Area2D

const MOTION_ORBIT: int = 0
const MOTION_DASH: int = 1
const MOTION_RETURN: int = 2

var source_entity: Entity
var source_key: StringName = &""
var source_ability_id: StringName = &""
var source_ability_slot_index: int = -1
var slot_index: int = 0
var slot_count: int = 1
var orbit_phase: float = 0.0
var radius_phase: float = 0.0
var secondary_radius_phase: float = 0.0
var life_timer: float = 0.0
var hit_cooldowns: Dictionary = {}
var is_paused: bool = false
var has_initialized_position: bool = false
var motion_state: int = MOTION_ORBIT
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_remaining_distance: float = 0.0
var trail_points: Array[Vector2] = []


func _ready() -> void:
	add_to_group("orbiting_sword_manifest")
	if not EventBus.game_paused.is_connected(_on_game_paused):
		EventBus.game_paused.connect(_on_game_paused)
	if not EventBus.scene_changed.is_connected(_on_scene_changed):
		EventBus.scene_changed.connect(_on_scene_changed)


func _exit_tree() -> void:
	if EventBus.game_paused.is_connected(_on_game_paused):
		EventBus.game_paused.disconnect(_on_game_paused)
	if EventBus.scene_changed.is_connected(_on_scene_changed):
		EventBus.scene_changed.disconnect(_on_scene_changed)


func activate(context: AbilityContext) -> void:
	if context == null:
		return

	source_entity = context.caster
	if context.ability != null:
		source_ability_id = context.ability.id
		source_ability_slot_index = context.ability.runtime_slot_index
	setup_orbit(source_entity, &"ability_orbiting_sword", slot_index, slot_count)


## 外部系统生成飞剑时调用：同一来源 key 方便后续统一清理。
func setup_orbit(new_source_entity: Entity, new_source_key: StringName, new_slot_index: int, new_slot_count: int) -> void:
	source_entity = new_source_entity
	source_key = new_source_key
	slot_index = max(new_slot_index, 0)
	slot_count = max(new_slot_count, 1)
	life_timer = 0.0
	hit_cooldowns.clear()
	trail_points.clear()
	has_initialized_position = false
	motion_state = MOTION_ORBIT
	dash_direction = Vector2.ZERO
	dash_remaining_distance = 0.0
	# 多把飞剑错开首次出击时间，视觉上不会像同一把剑复制粘贴。
	dash_cooldown_timer = randf_range(0.0, max(dash_cooldown, 0.0) * 0.4)
	_setup_orbit_phases()
	_resolve_target_group()
	_snap_to_current_orbit_position()


func matches_source(new_source_entity: Entity, new_source_key: StringName) -> bool:
	return source_entity == new_source_entity and source_key == new_source_key


func _process(delta: float) -> void:
	if is_paused:
		return
	if _should_free_for_source_state():
		queue_free()
		return

	life_timer += delta
	if lifetime > 0.0 and life_timer >= lifetime:
		queue_free()
		return

	_tick_hit_cooldowns(delta)
	_tick_dash_cooldown(delta)
	_process_motion(delta)
	_update_trail()
	queue_redraw()


func _draw() -> void:
	_draw_trail()


func _process_motion(delta: float) -> void:
	if motion_state == MOTION_DASH:
		_process_dash(delta)
		return

	if motion_state == MOTION_RETURN:
		_process_return(delta)
		_apply_overlap_damage()
		return

	_update_orbit_position(delta)
	_apply_overlap_damage()
	_try_begin_dash()


## 给每把剑一个稳定但不同的相位，轨迹会变化但不会每帧乱跳。
func _setup_orbit_phases() -> void:
	var slot_phase: float = TAU * float(slot_index) / float(max(slot_count, 1))
	orbit_phase = slot_phase + randf_range(-0.08, 0.08)
	radius_phase = randf() * TAU
	secondary_radius_phase = randf() * TAU


func _resolve_target_group() -> void:
	if not auto_target_group_from_source:
		return
	if source_entity == null or not is_instance_valid(source_entity):
		return
	if source_entity.is_player_side():
		target_group = &"enemy"
	elif source_entity.is_enemy_side():
		target_group = &"player"


func _snap_to_current_orbit_position() -> void:
	if source_entity == null or not is_instance_valid(source_entity):
		return

	global_position = _get_orbit_position()
	has_initialized_position = true
	if rotate_to_tangent:
		global_rotation = _get_orbit_angle() + rotation_offset


func _tick_dash_cooldown(delta: float) -> void:
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0.0)


func _try_begin_dash() -> void:
	if not enable_smart_dash:
		return
	if dash_cooldown_timer > 0.0:
		return
	if life_timer < dash_min_orbit_time:
		return

	var target: Entity = _find_dash_target()
	if target == null:
		return

	_begin_dash(target)


func _begin_dash(target: Entity) -> void:
	var target_position: Vector2 = target.global_position
	var direction: Vector2 = global_position.direction_to(target_position)
	if direction == Vector2.ZERO and source_entity != null and is_instance_valid(source_entity):
		direction = source_entity.global_position.direction_to(target_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(_get_orbit_angle())

	dash_direction = direction.normalized()
	dash_remaining_distance = global_position.distance_to(target_position) + max(dash_pass_distance, 0.0)
	dash_cooldown_timer = max(dash_cooldown, 0.0)
	motion_state = MOTION_DASH
	if dash_rotate_to_direction:
		_face_dash_direction(dash_direction)


func _process_dash(delta: float) -> void:
	if dash_direction == Vector2.ZERO:
		motion_state = MOTION_RETURN
		return

	var move_distance: float = min(max(dash_speed, 0.0) * delta, dash_remaining_distance)
	var previous_position: Vector2 = global_position
	global_position += dash_direction * move_distance
	dash_remaining_distance -= move_distance

	if dash_rotate_to_direction:
		_face_dash_direction(dash_direction)

	_apply_swept_dash_damage(previous_position, global_position)
	_apply_overlap_damage()

	if dash_remaining_distance <= 0.0:
		motion_state = MOTION_RETURN


func _process_return(delta: float) -> void:
	var target_position: Vector2 = _get_orbit_position()
	var to_orbit: Vector2 = target_position - global_position
	var distance: float = to_orbit.length()
	var move_distance: float = max(dash_return_speed, 0.0) * delta

	if distance <= dash_return_arrive_distance or move_distance >= distance:
		global_position = target_position
		motion_state = MOTION_ORBIT
		has_initialized_position = true
		if rotate_to_tangent:
			global_rotation = _get_orbit_angle() + rotation_offset
		return

	var return_direction: Vector2 = to_orbit.normalized()
	global_position += return_direction * move_distance
	if dash_rotate_to_direction:
		_face_dash_direction(return_direction)


func _find_dash_target() -> Entity:
	if target_group == &"":
		return null
	if source_entity == null or not is_instance_valid(source_entity):
		return null
	if not is_inside_tree():
		return null

	var nearest: Entity
	var nearest_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(String(target_group)):
		if not (node is Entity):
			continue

		var candidate: Entity = node as Entity
		if not _is_valid_target_entity(candidate):
			continue
		if candidate.has_method("is_neutral_bounty_elite") and candidate.is_neutral_bounty_elite():
			continue

		var distance_to_owner: float = source_entity.global_position.distance_to(candidate.global_position)
		if distance_to_owner > dash_acquire_radius:
			continue
		if distance_to_owner < nearest_distance:
			nearest_distance = distance_to_owner
			nearest = candidate

	return nearest


## 高速突刺时用线段扫过目标，补足 Area2D 可能因为速度太快而漏掉的命中。
func _apply_swept_dash_damage(start_position: Vector2, end_position: Vector2) -> void:
	if start_position == end_position or target_group == &"":
		return

	var valid_source: Entity = _get_valid_source()
	if source_entity != null and valid_source == null:
		queue_free()
		return

	var has_hit: bool = false
	for node: Node in get_tree().get_nodes_in_group(String(target_group)):
		if not (node is Entity):
			continue

		var target: Entity = node as Entity
		if not _is_valid_target_entity(target):
			continue

		var target_id: int = target.get_instance_id()
		if hit_cooldowns.has(target_id):
			continue

		var distance_to_dash: float = _distance_to_segment(target.global_position, start_position, end_position)
		if distance_to_dash > dash_swept_hit_radius:
			continue

		_damage_target(target, valid_source)
		hit_cooldowns[target_id] = hit_interval
		has_hit = true

	if has_hit and hit_sound != null:
		AudioController.play(hit_sound, global_position)


func _distance_to_segment(point: Vector2, start_position: Vector2, end_position: Vector2) -> float:
	var segment: Vector2 = end_position - start_position
	var segment_length_sq: float = segment.length_squared()
	if segment_length_sq <= 0.000001:
		return point.distance_to(start_position)

	var point_factor: float = clamp((point - start_position).dot(segment) / segment_length_sq, 0.0, 1.0)
	var closest_position: Vector2 = start_position + segment * point_factor
	return point.distance_to(closest_position)


func _update_trail() -> void:
	if not enable_trail:
		trail_points.clear()
		return

	if trail_points.is_empty():
		trail_points.append(global_position)
	elif trail_points[trail_points.size() - 1].distance_to(global_position) >= trail_min_distance:
		trail_points.append(global_position)

	while trail_points.size() > max(trail_max_points, 2):
		trail_points.remove_at(0)


func _draw_trail() -> void:
	if not enable_trail or trail_points.size() < 2:
		return

	var alpha_multiplier: float = trail_dash_alpha_multiplier if motion_state == MOTION_DASH else 1.0
	for index: int in range(trail_points.size() - 1):
		var start_point: Vector2 = to_local(trail_points[index])
		var end_point: Vector2 = to_local(trail_points[index + 1])
		var progress: float = float(index) / float(max(trail_points.size() - 1, 1))
		var width: float = lerp(1.0, trail_width, progress)
		var alpha: float = lerp(0.0, trail_color.a, progress) * alpha_multiplier
		draw_line(
			start_point,
			end_point,
			Color(trail_color.r, trail_color.g, trail_color.b, clamp(alpha, 0.0, 1.0)),
			width,
			true
		)


func _face_dash_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return

	if dash_align_sprite_tip_to_direction:
		global_rotation = direction.angle() - _get_sprite_tip_local_angle()
	else:
		global_rotation = direction.angle() + rotation_offset


func _get_sprite_tip_local_angle() -> float:
	var sprite_tip_angle: float = 0.0
	if sprite2d != null:
		# 默认约定：贴图剑尖朝 Sprite2D 本地 +X 方向。
		# 如果你为了贴图手感调整了 Sprite2D.rotation，这里会自动把它计入视觉剑尖方向。
		sprite_tip_angle = sprite2d.rotation

	return sprite_tip_angle + dash_tip_extra_angle


func _update_orbit_position(delta: float) -> void:
	var target_position: Vector2 = _get_orbit_position()
	var lerp_weight: float = clamp(follow_smoothing * delta, 0.0, 1.0)
	if not has_initialized_position:
		global_position = target_position
		has_initialized_position = true
	else:
		global_position = global_position.lerp(target_position, lerp_weight)

	if rotate_to_tangent:
		global_rotation = _get_orbit_angle() + rotation_offset


func _get_orbit_position() -> Vector2:
	if source_entity == null or not is_instance_valid(source_entity):
		return global_position

	return source_entity.global_position + Vector2.RIGHT.rotated(_get_orbit_angle()) * _get_current_radius()


func _get_orbit_angle() -> float:
	return orbit_phase + life_timer * orbit_speed


func _get_current_radius() -> float:
	var slot_offset: float = 0.0
	if slot_count > 1:
		slot_offset = (1.0 if slot_index % 2 == 0 else -1.0) * slot_radius_variation

	var wave_a: float = sin(life_timer * radius_wave_speed + radius_phase) * radius_wave_amplitude
	var wave_b: float = sin(life_timer * radius_wave_speed * 0.57 + secondary_radius_phase) * radius_wave_amplitude * 0.35
	return max(8.0, orbit_radius + slot_offset + wave_a + wave_b)


func _tick_hit_cooldowns(delta: float) -> void:
	for target_id in hit_cooldowns.keys().duplicate():
		var remaining: float = float(hit_cooldowns[target_id]) - delta
		if remaining <= 0.0:
			hit_cooldowns.erase(target_id)
		else:
			hit_cooldowns[target_id] = remaining


func _apply_overlap_damage() -> void:
	if hit_area == null:
		return

	var valid_source: Entity = _get_valid_source()
	if source_entity != null and valid_source == null:
		queue_free()
		return

	var has_hit: bool = false
	for area: Area2D in hit_area.get_overlapping_areas():
		var target: Entity = _get_entity_from_area(area)
		if target == null:
			continue

		var target_id: int = target.get_instance_id()
		if hit_cooldowns.has(target_id):
			continue

		_damage_target(target, valid_source)
		hit_cooldowns[target_id] = hit_interval
		has_hit = true

	if has_hit and hit_sound != null:
		AudioController.play(hit_sound, global_position)


func _damage_target(target: Entity, valid_source: Entity) -> void:
	var damage_data: DamageData = DamageData.create(
		damage,
		damage_types,
		tags,
		valid_source,
		target,
		can_crit,
		scaling_rule,
		source_ability_id,
		source_ability_slot_index,
		poise_damage
	)
	target.apply_damage(damage_data)


func _get_entity_from_area(area: Area2D) -> Entity:
	if area == null:
		return null

	var parent_node: Node = area.get_parent()
	if not (parent_node is Entity):
		return null

	var entity: Entity = parent_node as Entity
	if not _is_valid_target_entity(entity):
		return null

	return entity


func _is_valid_target_entity(entity: Entity) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	if not can_hit_map_objects and (entity is MapObject or entity.is_in_group("map_object")):
		return false
	if entity == source_entity:
		return false
	if entity.is_dead:
		return false
	if target_group != &"" and not entity.matches_target_group(target_group):
		return false
	if entity.has_method("can_be_targeted") and not entity.can_be_targeted():
		return false

	return true


func _get_valid_source() -> Entity:
	if source_entity == null:
		return null
	if not is_instance_valid(source_entity):
		return null
	return source_entity


func _should_free_for_source_state() -> bool:
	if source_entity == null:
		return false
	if not is_instance_valid(source_entity):
		return true
	return source_entity.is_dead


func _on_game_paused(paused: bool) -> void:
	is_paused = paused


func _on_scene_changed(scene: String) -> void:
	if scene == "home":
		queue_free()
