## 带轻微自动追踪与拖尾的小光点 Manifest。
## 默认朝初始方向飞出，飞行中会定期寻找附近敌人并缓慢转向；找不到敌人则到时/到距离后消失。
class_name HomingFireflyManifest
extends AbilityManifest

@export_group("Movement")
@export var speed: float = 170.0
@export var max_distance: float = 260.0
@export var lifetime: float = 2.2
@export var target_group: StringName = &"enemy"
@export var acquire_radius: float = 190.0
@export var retarget_interval: float = 0.16
@export var homing_turn_speed: float = 4.2
@export var wander_angle_speed: float = 1.5
@export var wander_angle_amount: float = 0.32

@export_group("Visual")
@export var glow_colors: Array[Color] = [
	Color(0.55, 0.95, 1.0, 1.0),
	Color(0.52, 1.0, 0.72, 1.0),
]
@export var core_radius: float = 3.0
@export var glow_radius: float = 10.0
@export var trail_max_points: int = 12
@export var trail_min_distance: float = 5.0
@export var burst_duration: float = 0.18
@export var burst_radius: float = 22.0

@export_group("Damage")
@export var damage: float = 8.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.ICE, DamageData.DamageType.RANGED]
@export var tags: Array[String] = ["manifest", "summon_pet", "firefly", "projectile", "ranged", "magic"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()
@export var is_penetrate: bool = false
@export var hit_sound: AudiioConfig

@onready var hit_area: Area2D = get_node_or_null("Area2D") as Area2D

var source: Entity
var source_ability_id: StringName = &""
var source_ability_slot_index: int = -1
var current_dir: Vector2 = Vector2.RIGHT
var current_distance: float = 0.0
var life_timer: float = 0.0
var retarget_timer: float = 0.0
var trail_points: Array[Vector2] = []
var current_target: Entity
var glow_color: Color = Color(0.55, 0.95, 1.0, 1.0)
var is_bursting: bool = false
var burst_timer: float = 0.0
var is_paused: bool = false
var wander_seed: float = 0.0


func _ready() -> void:
	if hit_area != null and not hit_area.area_entered.is_connected(_on_area_2d_area_entered):
		hit_area.area_entered.connect(_on_area_2d_area_entered)


func _exit_tree() -> void:
	if hit_area != null and hit_area.area_entered.is_connected(_on_area_2d_area_entered):
		hit_area.area_entered.disconnect(_on_area_2d_area_entered)
	if EventBus.game_paused.is_connected(_handle_game_pause):
		EventBus.game_paused.disconnect(_handle_game_pause)
	if EventBus.scene_changed.is_connected(_handle_scene_changed):
		EventBus.scene_changed.disconnect(_handle_scene_changed)


func activate(context: AbilityContext) -> void:
	source = context.caster
	source_ability_id = context.ability.id if context.ability != null else &""
	source_ability_slot_index = context.ability.runtime_slot_index if context.ability != null else -1
	_apply_projectile_range_bonus()

	if not EventBus.game_paused.is_connected(_handle_game_pause):
		EventBus.game_paused.connect(_handle_game_pause)
	if not EventBus.scene_changed.is_connected(_handle_scene_changed):
		EventBus.scene_changed.connect(_handle_scene_changed)

	current_dir = _get_initial_direction(context)
	if current_dir == Vector2.ZERO:
		current_dir = Vector2.RIGHT.rotated(randf() * TAU)
	global_rotation = current_dir.angle()
	wander_seed = randf() * TAU
	glow_color = _pick_glow_color()
	trail_points = [global_position]


func _process(delta: float) -> void:
	if is_paused:
		return
	if _should_free_for_source_state():
		queue_free()
		return
	if is_bursting:
		_process_burst(delta)
		return

	life_timer += delta
	if life_timer >= lifetime:
		queue_free()
		return

	_update_target(delta)
	_update_direction(delta)
	_move_forward(delta)
	_update_trail()
	queue_redraw()


func _draw() -> void:
	_draw_trail()

	if is_bursting:
		var progress: float = clamp(burst_timer / max(burst_duration, 0.001), 0.0, 1.0)
		var alpha: float = 1.0 - progress
		draw_circle(Vector2.ZERO, lerp(glow_radius, burst_radius, progress), Color(glow_color.r, glow_color.g, glow_color.b, 0.22 * alpha))
		draw_circle(Vector2.ZERO, lerp(core_radius, burst_radius * 0.42, progress), Color(1.0, 1.0, 0.92, 0.6 * alpha))
		return

	draw_circle(Vector2.ZERO, glow_radius, Color(glow_color.r, glow_color.g, glow_color.b, 0.22))
	draw_circle(Vector2.ZERO, core_radius, Color(0.92, 1.0, 0.95, 0.96))


func _draw_trail() -> void:
	if trail_points.size() < 2:
		return

	for index in range(trail_points.size() - 1):
		var start_point: Vector2 = to_local(trail_points[index])
		var end_point: Vector2 = to_local(trail_points[index + 1])
		var progress: float = float(index) / float(max(trail_points.size() - 1, 1))
		var width: float = lerp(1.0, core_radius * 1.5, progress)
		var alpha: float = lerp(0.0, 0.36, progress)
		draw_line(start_point, end_point, Color(glow_color.r, glow_color.g, glow_color.b, alpha), width, true)


func _update_target(delta: float) -> void:
	retarget_timer -= delta
	if retarget_timer > 0.0 and _is_valid_target(current_target):
		return

	retarget_timer = retarget_interval
	current_target = _find_nearest_target()


func _update_direction(delta: float) -> void:
	var desired_dir: Vector2 = Vector2.ZERO
	if _is_valid_target(current_target):
		desired_dir = global_position.direction_to(current_target.global_position)
	else:
		var wander_angle: float = sin(life_timer * wander_angle_speed + wander_seed) * wander_angle_amount
		desired_dir = current_dir.rotated(wander_angle * delta).normalized()

	if desired_dir == Vector2.ZERO:
		return

	var max_turn: float = max(homing_turn_speed, 0.0) * delta
	var angle_delta: float = wrapf(desired_dir.angle() - current_dir.angle(), -PI, PI)
	current_dir = current_dir.rotated(clamp(angle_delta, -max_turn, max_turn)).normalized()
	global_rotation = current_dir.angle()


func _move_forward(delta: float) -> void:
	var movement: Vector2 = current_dir * speed * delta
	current_distance += movement.length()
	global_position += movement

	if current_distance >= max_distance:
		queue_free()


func _update_trail() -> void:
	if trail_points.is_empty():
		trail_points.append(global_position)
	elif trail_points[trail_points.size() - 1].distance_to(global_position) >= trail_min_distance:
		trail_points.append(global_position)

	while trail_points.size() > max(trail_max_points, 2):
		trail_points.remove_at(0)


func _on_area_2d_area_entered(area: Area2D) -> void:
	if is_bursting:
		return

	var target: Entity = _get_entity_from_area(area)
	if target == null:
		return

	var valid_source: Entity = _get_valid_source()
	if source != null and valid_source == null:
		queue_free()
		return

	_damage_target(target, valid_source)

	if hit_sound != null:
		AudioController.play(hit_sound, global_position)

	if is_penetrate:
		return

	_begin_burst()


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
		source_ability_slot_index
	)
	target.apply_damage(damage_data)


func _begin_burst() -> void:
	is_bursting = true
	burst_timer = 0.0
	_disable_hit_area()
	trail_points.clear()
	queue_redraw()


func _process_burst(delta: float) -> void:
	burst_timer += delta
	queue_redraw()
	if burst_timer >= burst_duration:
		queue_free()


func _get_initial_direction(context: AbilityContext) -> Vector2:
	if context.locked_direction != Vector2.ZERO:
		return context.locked_direction.normalized()
	if context.targets.size() > 0:
		var target_pos: Vector2 = context.get_target_positon(0)
		var direction: Vector2 = global_position.direction_to(target_pos)
		if direction != Vector2.ZERO:
			return direction.normalized()
	if source != null:
		var facing: Vector2 = source.get_facing_direction()
		if facing != Vector2.ZERO:
			return facing.normalized()
	return Vector2.RIGHT


func _find_nearest_target() -> Entity:
	var nearest: Entity
	var nearest_distance: float = INF

	for node in get_tree().get_nodes_in_group(String(target_group)):
		if not (node is Entity):
			continue

		var candidate: Entity = node as Entity
		if not _is_valid_target(candidate):
			continue

		var distance: float = global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate

	return nearest


func _is_valid_target(candidate: Entity) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if candidate == source or candidate.is_dead:
		return false
	if candidate.has_method("is_neutral_bounty_elite") and candidate.is_neutral_bounty_elite():
		return false
	if global_position.distance_to(candidate.global_position) > acquire_radius:
		return false
	if candidate.has_method("can_be_targeted") and not candidate.can_be_targeted():
		return false
	return candidate.matches_target_group(target_group)


func _get_entity_from_area(area: Area2D) -> Entity:
	if area == null:
		return null

	var parent: Node = area.get_parent()
	if not (parent is Entity):
		return null

	var entity: Entity = parent as Entity
	if not _is_valid_target(entity):
		return null
	return entity


func _get_valid_source() -> Entity:
	if source == null:
		return null
	if not is_instance_valid(source):
		return null
	return source


func _should_free_for_source_state() -> bool:
	if source == null:
		return false
	if not is_instance_valid(source):
		return true
	return source.is_dead


func _disable_hit_area() -> void:
	if hit_area == null:
		return
	hit_area.set_deferred("monitoring", false)
	hit_area.set_deferred("monitorable", false)


func _pick_glow_color() -> Color:
	if glow_colors.is_empty():
		return Color(0.55, 0.95, 1.0, 1.0)
	return glow_colors.pick_random()


func _handle_game_pause(pause: bool) -> void:
	is_paused = pause


func _handle_scene_changed(scene: String) -> void:
	if scene == "home":
		queue_free()


func _apply_projectile_range_bonus() -> void:
	if source == null or source.stats_controller == null:
		return

	var bonus_rate: float = max(source.stats_controller.get_stat(&"projectile_range_bonus_rate"), 0.0)
	if bonus_rate <= 0.0:
		return
	if not tags.has("projectile"):
		return

	max_distance *= 1.0 + bonus_rate
