## 带明确安全缺口的环形弹幕：预警和真实弹幕共享同一组方向，不追踪。
## 二阶段可追加另一圈；后续圈重新预警，不在玩家脚下瞬间生成伤害。
class_name AbilityRadialGapVolley
extends AbilityComponent

@export var projectile_scene: PackedScene
@export var projectile_count: int = 24
@export var safe_gap_degrees: float = 65.0
@export var spawn_radius: float = 52.0
@export var warning_radius: float = 280.0
@export var windup: float = 1.0
@export var phase_two_second_ring: bool = true
@export var second_ring_pause: float = 0.35
@export var second_ring_windup: float = 0.65
@export var second_ring_gap_offset: float = 12.0


func _activate(context: AbilityContext) -> void:
	var gap_angle: float = randf() * TAU
	var second_ring: bool = phase_two_second_ring and context.caster.has_method("get_encounter_phase") and context.caster.call("get_encounter_phase") == 2
	_warn(context, gap_angle, windup)
	await get_tree().create_timer(windup, false).timeout
	if not is_inside_tree() or not context.is_caster_action_valid():
		return
	_fire(context, gap_angle)
	if not second_ring:
		return
	await get_tree().create_timer(second_ring_pause, false).timeout
	if not is_inside_tree() or not context.is_caster_action_valid():
		return
	gap_angle += deg_to_rad(second_ring_gap_offset)
	_warn(context, gap_angle, second_ring_windup)
	await get_tree().create_timer(second_ring_windup, false).timeout
	if is_inside_tree() and context.is_caster_action_valid():
		_fire(context, gap_angle)


func get_volley_directions(gap_angle: float) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	var gap: float = clampf(deg_to_rad(safe_gap_degrees), 0.1, TAU - 0.1)
	var total: int = maxi(projectile_count, 2)
	for index: int in range(total):
		var angle: float = gap_angle + gap * 0.5 + (TAU - gap) * float(index) / float(total - 1)
		directions.append(Vector2.RIGHT.rotated(angle))
	return directions


func _warn(context: AbilityContext, angle: float, duration: float) -> void:
	var warning: EncounterWarning = EncounterWarning.spawn(context, context.caster.global_position, warning_radius, duration)
	warning.shape = EncounterWarning.Shape.GAP_RING
	warning.inner_radius = spawn_radius
	warning.gap_degrees = safe_gap_degrees
	warning.global_rotation = angle


func _fire(context: AbilityContext, gap_angle: float) -> void:
	if projectile_scene == null:
		return
	for direction: Vector2 in get_volley_directions(gap_angle):
		var node: AbilityManifest = projectile_scene.instantiate() as AbilityManifest
		if node == null:
			continue
		context.caster.get_parent().add_child(node)
		node.global_position = context.caster.global_position + direction * spawn_radius
		var shot: AbilityContext = AbilityContext.new(context.caster, context.ability)
		shot.element_tags = context.element_tags.duplicate()
		shot.cast_record = context.cast_record
		shot.locked_direction = direction
		node.activate(shot)
