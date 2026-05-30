class_name AllyPeriodicFieldManifest
extends AbilityManifest

@export_group("领域生命周期")
@export var duration: float = 5.0
@export var tick_interval: float = 1.5
@export var tick_on_spawn: bool = true
@export var fade_duration: float = 0.6

@export_group("领域范围")
@export var radius: float = 82.0
@export var target_groups: Array[StringName] = [&"player", &"player_ally", &"summon_pet"]

@export_group("治疗")
@export var heal_amount: float = 5.0
@export var show_heal_text: bool = true
@export var heal_text_color: Color = Color(0.55, 1.0, 0.62, 1.0)

@export_group("附加状态")
@export var status_data: StatusData
@export var status_stacks: int = 1
@export var status_duration_override: float = INF

@export_group("视觉")
@export var fill_color: Color = Color(0.28, 0.95, 0.58, 0.22)
@export var outline_color: Color = Color(0.7, 1.0, 0.82, 0.75)
@export var outline_width: float = 3.0
@export var pulse_speed: float = 2.0
@export var pulse_radius: float = 6.0

var source: Entity
var elapsed_time: float = 0.0
var tick_timer: float = 0.0
var visual_time: float = 0.0
var fade_started: bool = false


func _ready() -> void:
	z_index = min(z_index, -1)
	queue_redraw()


func _activate(context: AbilityContext) -> void:
	if context != null:
		source = context.caster

	tick_timer = tick_interval
	if tick_on_spawn:
		call_deferred("_apply_tick")


func _process(delta: float) -> void:
	elapsed_time += delta
	visual_time += delta
	tick_timer -= delta

	if _should_cancel_because_source_gone():
		queue_free()
		return

	if tick_timer <= 0.0:
		_apply_tick()
		tick_timer = max(tick_interval, 0.05)

	if not fade_started and elapsed_time >= max(duration - fade_duration, 0.0):
		_start_fade()

	if elapsed_time >= duration:
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	var pulse = (sin(visual_time * pulse_speed) + 1.0) * 0.5
	var current_radius = radius + pulse * pulse_radius
	var current_fill = fill_color
	current_fill.a *= lerp(0.72, 1.0, pulse)
	var current_outline = outline_color
	current_outline.a *= lerp(0.55, 1.0, pulse)

	draw_circle(Vector2.ZERO, current_radius, current_fill)
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 96, current_outline, outline_width, true)


func _apply_tick() -> void:
	for target in _collect_targets():
		_heal_target(target)
		_apply_status_to_target(target)


func _collect_targets() -> Array[Entity]:
	var result: Array[Entity] = []
	var tree = get_tree()
	if tree == null:
		return result

	for group_name in target_groups:
		for node in tree.get_nodes_in_group(String(group_name)):
			if not (node is Entity):
				continue

			var entity = node as Entity
			if result.has(entity):
				continue
			if not _is_valid_ally(entity):
				continue

			result.append(entity)

	return result


func _is_valid_ally(entity: Entity) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	if entity.is_dead:
		return false
	if entity.global_position.distance_to(global_position) > radius:
		return false

	# 如果有施法者，就按阵营判断盟友；否则退回到 target_groups 的显式筛选。
	if source != null and is_instance_valid(source):
		if source.is_player_side():
			return entity.is_player_side()
		if source.is_enemy_side():
			return entity.is_enemy_side()

	return true


func _heal_target(target: Entity) -> void:
	if heal_amount <= 0.0:
		return

	var max_health_value = target.max_health
	if target.stats_controller != null:
		max_health_value = target.stats_controller.get_stat(&"max_health", target.max_health)

	var previous_health = target.current_health
	target.current_health = min(target.current_health + heal_amount, max_health_value)
	if target.stats_controller != null:
		target.stats_controller.current_health = target.current_health
		target.stats_controller.sync_runtime_resources()

	if target.is_in_group("player"):
		EventBus.player_health_changed.emit(target.current_health, max_health_value)

	if show_heal_text and target.current_health > previous_health:
		FloatText.show_damage_text("+%s" % int(target.current_health - previous_health), _get_float_text_position(target), heal_text_color)


func _apply_status_to_target(target: Entity) -> void:
	if status_data == null:
		return

	var status_controller = target.get_status_controller()
	if status_controller == null:
		return

	var source_key = "%s_%s" % [String(status_data.id), get_instance_id()]
	status_controller.add_status(status_data, source, source_key, status_stacks, status_duration_override)


func _get_float_text_position(target: Entity) -> Vector2:
	var height = target.get_height() if target.has_method("get_height") else 32.0
	return Vector2(target.global_position.x, target.global_position.y - height * 0.5)


func _should_cancel_because_source_gone() -> bool:
	if source == null:
		return false
	return not is_instance_valid(source) or source.is_dead


func _start_fade() -> void:
	fade_started = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, max(fade_duration, 0.01))
