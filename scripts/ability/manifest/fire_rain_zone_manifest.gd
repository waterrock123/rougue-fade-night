## 火雨落点 Manifest。
## 每个实例代表一枚独立火雨：先显示小圆形预警，再播放落火动画，随后造成一次范围伤害并在自身区域内生成火焰地面。
class_name FireRainZoneManifest
extends AbilityManifest

@export_group("Warning")
@export var warning_radius: float = 42.0
@export var warning_duration: float = 0.75
@export var warning_linger_after_impact: float = 3.8
@export var warning_fill_color: Color = Color(1.0, 0.08, 0.02, 0.12)
@export var warning_border_color: Color = Color(1.0, 0.26, 0.04, 0.0)
## 设置为 0 就不绘制边框，避免火雨密集时遮挡视野。
@export var warning_border_width: float = 0.0
@export var warning_segments: int = 32

@export_group("Fall Visual")
@export var fall_start_offset: Vector2 = Vector2(0.0, -96.0)
@export var fall_scale_from: Vector2 = Vector2(0.55, 0.55)
@export var fall_scale_to: Vector2 = Vector2(1.25, 1.25)
@export var fall_fade_out_time: float = 0.18

@export_group("Damage")
@export var damage: float = 14.0
@export var can_crit: bool = false
@export var damage_types: Array[int] = [DamageData.DamageType.FIRE]
@export var tags: Array[String] = ["manifest", "fire", "fire_rain", "aoe"]
@export var target_groups: Array[StringName] = [&"player", &"enemy"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()

@export_group("Fire Ground")
@export var fire_ground_manifest_scene: PackedScene
@export_range(0, 8, 1) var fire_ground_count: int = 2
@export var fire_ground_spawn_radius: float = 30.0
@export var fire_ground_spawn_interval: float = 0.08
@export var fire_ground_scale: float = 0.75

@onready var impact_area: Area2D = get_node_or_null("ImpactArea") as Area2D
@onready var impact_shape: CollisionShape2D = get_node_or_null("ImpactArea/CollisionShape2D") as CollisionShape2D
@onready var fall_sprite: AnimatedSprite2D = get_node_or_null("FallSprite") as AnimatedSprite2D

var source: Entity
var source_ability_id: StringName = &""
var source_ability_slot_index: int = -1
var warning_polygon: Polygon2D
var warning_border: Line2D


func _ready() -> void:
	_configure_area_radius()
	_setup_warning_visual()
	_setup_fall_sprite()


func activate(context: AbilityContext) -> void:
	if context == null or context.caster == null:
		queue_free()
		return

	source = context.caster
	source_ability_id = context.ability.id if context.ability != null else &""
	source_ability_slot_index = context.ability.runtime_slot_index if context.ability != null else -1
	_run_fire_rain()


func _run_fire_rain() -> void:
	if warning_duration > 0.0:
		await get_tree().create_timer(warning_duration, false).timeout
	if _should_cancel_for_source_state():
		queue_free()
		return

	await _play_fall_and_impact()
	_spawn_fire_grounds()

	if warning_linger_after_impact > 0.0:
		await get_tree().create_timer(warning_linger_after_impact, false).timeout
	queue_free()


func _play_fall_and_impact() -> void:
	if fall_sprite != null:
		fall_sprite.visible = true
		fall_sprite.position = fall_start_offset
		fall_sprite.scale = fall_scale_from
		fall_sprite.modulate.a = 1.0
		if fall_sprite.sprite_frames != null:
			fall_sprite.play()

		var fall_tween := create_tween()
		fall_tween.set_parallel(true)
		fall_tween.tween_property(fall_sprite, "position", Vector2.ZERO, max(fall_fade_out_time, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall_tween.tween_property(fall_sprite, "scale", fall_scale_to, max(fall_fade_out_time, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await fall_tween.finished

	await get_tree().physics_frame
	_damage_targets_in_area()

	if fall_sprite != null:
		var fade_tween := create_tween()
		fade_tween.tween_property(fall_sprite, "modulate:a", 0.0, max(fall_fade_out_time, 0.01))
		await fade_tween.finished
		fall_sprite.visible = false


func _damage_targets_in_area() -> void:
	if impact_area == null:
		return

	var damaged_targets: Array[Entity] = []
	for area in impact_area.get_overlapping_areas():
		var target := _get_entity_from_area(area)
		if target == null or damaged_targets.has(target):
			continue

		damaged_targets.append(target)
		_damage_target(target)


func _damage_target(target: Entity) -> void:
	var damage_data := DamageData.create(
		damage,
		damage_types,
		tags,
		_get_valid_source(),
		target,
		can_crit,
		scaling_rule,
		source_ability_id,
		source_ability_slot_index
	)
	target.apply_damage(damage_data)


func _spawn_fire_grounds() -> void:
	if fire_ground_manifest_scene == null or fire_ground_count <= 0:
		return

	for index in range(fire_ground_count):
		if _should_cancel_for_source_state():
			return

		_spawn_one_fire_ground()
		if fire_ground_spawn_interval > 0.0 and index < fire_ground_count - 1:
			await get_tree().create_timer(fire_ground_spawn_interval, false).timeout


func _spawn_one_fire_ground() -> void:
	var manifest := fire_ground_manifest_scene.instantiate() as AbilityManifest
	if manifest == null:
		return

	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(manifest)
	manifest.global_position = global_position + _get_random_offset_inside(fire_ground_spawn_radius)
	manifest.scale *= fire_ground_scale
	manifest.activate(AbilityContext.new(_get_valid_source(), null))


func _get_entity_from_area(area: Area2D) -> Entity:
	if area == null:
		return null

	var parent := area.get_parent()
	if not (parent is Entity):
		return null

	var entity := parent as Entity
	if source != null and is_instance_valid(source) and entity == source:
		return null
	if not _matches_target_groups(entity):
		return null
	if entity.has_method("can_be_targeted") and not entity.can_be_targeted():
		return null

	return entity


func _matches_target_groups(entity: Entity) -> bool:
	for group_name in target_groups:
		if entity.matches_target_group(group_name):
			return true
	return false


func _configure_area_radius() -> void:
	if impact_shape == null:
		return

	if impact_shape.shape is CircleShape2D:
		(impact_shape.shape as CircleShape2D).radius = warning_radius


func _setup_warning_visual() -> void:
	var points := _build_circle_points(warning_radius, warning_segments)

	warning_polygon = Polygon2D.new()
	warning_polygon.name = "WarningFill"
	warning_polygon.polygon = points
	warning_polygon.color = warning_fill_color
	warning_polygon.z_index = -1
	add_child(warning_polygon)

	if warning_border_width <= 0.0:
		return

	warning_border = Line2D.new()
	warning_border.name = "WarningBorder"
	warning_border.points = points
	warning_border.closed = true
	warning_border.width = warning_border_width
	warning_border.default_color = warning_border_color
	warning_border.z_index = 0
	add_child(warning_border)


func _setup_fall_sprite() -> void:
	if fall_sprite == null:
		return

	fall_sprite.visible = false
	fall_sprite.modulate.a = 1.0


func _build_circle_points(radius: float, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments: int = max(segment_count, 12)

	for index in range(safe_segments):
		var angle: float = TAU * float(index) / float(safe_segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	return points


func _get_random_offset_inside(radius: float) -> Vector2:
	var safe_radius: float = max(radius, 0.0)
	var angle: float = randf() * TAU
	var distance: float = sqrt(randf()) * safe_radius
	return Vector2.RIGHT.rotated(angle) * distance


func _get_valid_source() -> Entity:
	if source == null:
		return null
	if not is_instance_valid(source):
		return null
	return source


func _should_cancel_for_source_state() -> bool:
	if source == null:
		return false
	if not is_instance_valid(source):
		return true
	return source.is_dead
