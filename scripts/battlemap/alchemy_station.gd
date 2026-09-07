class_name AlchemyStation
extends MapObject

## 炼金台：受击累计到阈值后，掉落一个随机地图拾取物；每次掉落后下次阈值翻倍。
## 它是可交互地图物件，适合后续用“加工品”等地图标签提高生成概率。

const TEMPORARY_HEALTH_PICKUP_SCENE: PackedScene = preload("res://scenes/battlemap/temporary_health_pickup.tscn")
const TEMPORARY_ENERGY_PICKUP_SCENE: PackedScene = preload("res://scenes/battlemap/temporary_energy_pickup.tscn")
const MYSTERY_OBJECT_PICKUP_SCENE: PackedScene = preload("res://scenes/battlemap/mystery_object_pickup.tscn")
const GOLDEN_FLASH_PICKUP_SCENE: PackedScene = preload("res://scenes/battlemap/golden_flash_pickup.tscn")
const DEFAULT_ALCHEMY_DROP_POOL: AlchemyDropPool = preload("res://custom_resource/default_alchemy_drop_pool.tres")

@export_group("炼金掉落")
@export var first_drop_damage_threshold: float = 20.0
@export var threshold_multiplier_after_drop: float = 2.0
@export var max_drop_count: int = 4
@export var drop_spawn_radius: float = 20.0
## 优先使用资源池决定掉落物；为空时才使用下方旧版 pickup_scenes + pickup_weights 兜底。
@export var alchemy_drop_pool: AlchemyDropPool = DEFAULT_ALCHEMY_DROP_POOL
@export var fallback_shop_level: int = 1

@export_group("旧版掉落兜底")
@export var pickup_scenes: Array[PackedScene] = [
	TEMPORARY_HEALTH_PICKUP_SCENE,
	TEMPORARY_ENERGY_PICKUP_SCENE,
	MYSTERY_OBJECT_PICKUP_SCENE,
	GOLDEN_FLASH_PICKUP_SCENE,
]
@export var pickup_weights: Array[float] = [1.2, 1.2, 0.8, 0.45]

@export_group("阈值UI")
@export var show_threshold_ui: bool = true
@export var threshold_ui_path: NodePath = NodePath("ThresholdUI")
@export var threshold_ui_offset: Vector2 = Vector2(-32.0, -38.0)
@export var threshold_ui_size: Vector2 = Vector2(64.0, 14.0)
@export var hide_threshold_ui_when_exhausted: bool = false

@export_group("抛出动画")
@export var enable_throw_animation: bool = true
@export var throw_start_offset: Vector2 = Vector2(0.0, -18.0)
@export var throw_arc_height: float = 46.0
@export var throw_duration: float = 0.45
@export var throw_start_scale: float = 0.65
@export var throw_pickup_delay_after_land: float = 0.06
@export var throw_spin_degrees: float = 240.0

@export_group("触发反馈")
@export var enable_threshold_trigger_feedback: bool = true
@export var trigger_flash_color: Color = Color(1.0, 0.74, 1.0, 1.0)
@export var trigger_flash_duration: float = 0.06
@export var trigger_flash_recover_duration: float = 0.16
@export var trigger_shake_offset: float = 5.0
@export var trigger_shake_duration: float = 0.12
@export var trigger_scale_multiplier: float = 1.18
@export var trigger_scale_duration: float = 0.22
@export var threshold_ui_pulse_scale: float = 1.28
@export var threshold_ui_pulse_duration: float = 0.22

@export_group("喷出特效")
@export var enable_spawn_burst: bool = true
@export var burst_ray_count: int = 8
@export var burst_ray_length: float = 18.0
@export var burst_ray_width: float = 2.0
@export var burst_duration: float = 0.24
@export var burst_color: Color = Color(1.0, 0.78, 0.38, 0.9)
@export var burst_spread_radians: float = 1.9

var damage_since_last_drop: float = 0.0
var next_drop_threshold: float = 0.0
var dropped_count: int = 0
var threshold_ui_root: Control
var threshold_progress_bar: ProgressBar
var threshold_label: Label
var run_stats: RunStats
var trigger_feedback_tween: Tween
var threshold_ui_tween: Tween
var trigger_feedback_base_scale: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	add_to_group("alchemy_station")
	next_drop_threshold = max(first_drop_damage_threshold, 1.0)
	_setup_threshold_ui()
	_update_threshold_ui()


func _handle_damage_callback(damage_data: DamageData) -> void:
	super._handle_damage_callback(damage_data)
	if damage_data == null or damage_data.final_damage <= 0.0:
		return

	damage_since_last_drop += damage_data.final_damage
	_try_spawn_threshold_rewards()
	_update_threshold_ui()


## ObjectSpawnerFromTileMap 生成地图物体后会调用这个入口。
## 炼金掉落池借此读取当前商店等级和已启用地图标签，后续可以做“地图标签影响掉落池”的玩法。
func bind_run_stats(new_run_stats: RunStats) -> void:
	run_stats = new_run_stats


func _try_spawn_threshold_rewards() -> void:
	while _can_spawn_more_rewards() and damage_since_last_drop >= next_drop_threshold:
		damage_since_last_drop -= next_drop_threshold
		_play_threshold_trigger_feedback()
		_spawn_random_alchemy_pickup()
		dropped_count += 1
		next_drop_threshold = max(next_drop_threshold * max(threshold_multiplier_after_drop, 1.0), 1.0)


func _can_spawn_more_rewards() -> bool:
	if max_drop_count < 0:
		return true
	return dropped_count < max_drop_count


func _spawn_random_alchemy_pickup() -> void:
	var pickup_scene: PackedScene = _pick_weighted_pickup_scene()
	if pickup_scene == null:
		return

	var start_position: Vector2 = to_global(throw_start_offset)
	var landing_position: Vector2 = global_position + _get_drop_offset(drop_spawn_radius, dropped_count)
	_play_spawn_burst(start_position, landing_position)
	_spawn_tossed_pickup.call_deferred(pickup_scene, start_position, landing_position)


func _spawn_tossed_pickup(pickup_scene: PackedScene, start_position: Vector2, landing_position: Vector2) -> void:
	var pickup: Node2D = pickup_scene.instantiate() as Node2D
	if pickup == null:
		return

	var parent_node: Node = _get_drop_parent()
	if parent_node == null or not is_instance_valid(parent_node):
		pickup.queue_free()
		return

	parent_node.add_child(pickup)
	pickup.global_position = start_position
	_lock_pickup_until_landed(pickup)

	if not enable_throw_animation or throw_duration <= 0.0:
		pickup.global_position = landing_position
		return

	_play_throw_animation(pickup, start_position, landing_position)


func _lock_pickup_until_landed(pickup: Node2D) -> void:
	var map_pickup: MapPickup = pickup as MapPickup
	if map_pickup == null:
		return

	# 拾取物从炼金台飞出并落地前不能被吸附或拾取，避免玩家贴脸攻击时奖励还在空中就被吃掉。
	var lock_duration: float = max(throw_pickup_delay_after_land, 0.0)
	if enable_throw_animation:
		lock_duration += max(throw_duration, 0.0)
	map_pickup.delay_collection_for(lock_duration)


func _play_throw_animation(pickup: Node2D, start_position: Vector2, landing_position: Vector2) -> void:
	var original_scale: Vector2 = pickup.scale
	var original_rotation: float = pickup.rotation
	pickup.scale = original_scale * max(throw_start_scale, 0.01)

	var tween: Tween = create_tween()
	tween.tween_method(
		Callable(self, "_set_tossed_pickup_position").bind(pickup, start_position, landing_position, throw_arc_height),
		0.0,
		1.0,
		throw_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(pickup, "scale", original_scale, throw_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pickup, "rotation", original_rotation + deg_to_rad(throw_spin_degrees), throw_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self, "_finish_tossed_pickup").bind(pickup, landing_position, original_scale, original_rotation))


func _set_tossed_pickup_position(progress: float, pickup: Node2D, start_position: Vector2, landing_position: Vector2, arc_height: float) -> void:
	if pickup == null or not is_instance_valid(pickup):
		return

	var base_position: Vector2 = start_position.lerp(landing_position, clamp(progress, 0.0, 1.0))
	var arc_offset: Vector2 = Vector2(0.0, -sin(progress * PI) * max(arc_height, 0.0))
	pickup.global_position = base_position + arc_offset


func _finish_tossed_pickup(pickup: Node2D, landing_position: Vector2, original_scale: Vector2, original_rotation: float) -> void:
	if pickup == null or not is_instance_valid(pickup):
		return

	pickup.global_position = landing_position
	pickup.scale = original_scale
	pickup.rotation = original_rotation


func _play_threshold_trigger_feedback() -> void:
	if not enable_threshold_trigger_feedback:
		return

	_play_threshold_body_feedback()
	_play_threshold_ui_feedback()


func _play_threshold_body_feedback() -> void:
	var visual: Node2D = _get_feedback_visual()
	if visual == null:
		return

	if trigger_feedback_base_scale == Vector2.ZERO:
		trigger_feedback_base_scale = visual.scale

	if hit_flash_tween != null and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
	if hit_shake_tween != null and hit_shake_tween.is_valid():
		hit_shake_tween.kill()
	if trigger_feedback_tween != null and trigger_feedback_tween.is_valid():
		trigger_feedback_tween.kill()

	visual.modulate = feedback_visual_base_modulate
	visual.position = feedback_visual_base_position
	visual.scale = trigger_feedback_base_scale

	var shake_direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
	var shake_target: Vector2 = feedback_visual_base_position + shake_direction * max(trigger_shake_offset, 0.0)
	var enlarged_scale: Vector2 = trigger_feedback_base_scale * max(trigger_scale_multiplier, 0.01)

	# 满阈值时覆盖普通受击反馈，让炼金台有一个“吐出奖励”的更强瞬间。
	trigger_feedback_tween = create_tween()
	trigger_feedback_tween.tween_property(visual, "modulate", trigger_flash_color, max(trigger_flash_duration, 0.01))
	trigger_feedback_tween.parallel().tween_property(visual, "scale", enlarged_scale, max(trigger_scale_duration * 0.45, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	trigger_feedback_tween.parallel().tween_property(visual, "position", shake_target, max(trigger_shake_duration * 0.5, 0.01))
	trigger_feedback_tween.tween_property(visual, "modulate", feedback_visual_base_modulate, max(trigger_flash_recover_duration, 0.01))
	trigger_feedback_tween.parallel().tween_property(visual, "scale", trigger_feedback_base_scale, max(trigger_scale_duration * 0.55, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	trigger_feedback_tween.parallel().tween_property(visual, "position", feedback_visual_base_position, max(trigger_shake_duration * 0.5, 0.01))


func _play_threshold_ui_feedback() -> void:
	if threshold_ui_root == null:
		return

	if threshold_progress_bar != null:
		threshold_progress_bar.value = threshold_progress_bar.max_value

	if threshold_ui_tween != null and threshold_ui_tween.is_valid():
		threshold_ui_tween.kill()

	threshold_ui_root.scale = Vector2.ONE
	threshold_ui_root.pivot_offset = threshold_ui_root.size * 0.5

	var pulse_scale: Vector2 = Vector2.ONE * max(threshold_ui_pulse_scale, 0.01)
	threshold_ui_tween = create_tween()
	threshold_ui_tween.tween_property(threshold_ui_root, "scale", pulse_scale, max(threshold_ui_pulse_duration * 0.4, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	threshold_ui_tween.tween_property(threshold_ui_root, "scale", Vector2.ONE, max(threshold_ui_pulse_duration * 0.6, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _play_spawn_burst(start_position: Vector2, landing_position: Vector2) -> void:
	if not enable_spawn_burst or burst_ray_count <= 0:
		return

	var parent_node: Node = _get_drop_parent()
	if parent_node == null or not is_instance_valid(parent_node):
		return

	var burst_root: Node2D = Node2D.new()
	burst_root.name = "AlchemyBurstVFX"
	burst_root.z_index = 80
	parent_node.add_child(burst_root)
	burst_root.global_position = start_position

	var throw_vector: Vector2 = landing_position - start_position
	var base_angle: float = throw_vector.angle() if throw_vector.length() > 0.01 else randf() * TAU
	var safe_spread: float = max(burst_spread_radians, 0.0)
	var safe_count: int = max(burst_ray_count, 1)

	for ray_index: int in range(safe_count):
		var ray_progress: float = 0.5
		if safe_count > 1:
			ray_progress = float(ray_index) / float(safe_count - 1)

		var ray_angle: float = base_angle - safe_spread * 0.5 + safe_spread * ray_progress + randf_range(-0.16, 0.16)
		var ray_length: float = randf_range(max(burst_ray_length * 0.55, 1.0), max(burst_ray_length, 1.0))
		burst_root.add_child(_create_burst_ray(ray_angle, ray_length))

	var tween: Tween = create_tween()
	tween.tween_property(burst_root, "scale", Vector2.ONE * 1.45, max(burst_duration, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(burst_root, "modulate:a", 0.0, max(burst_duration, 0.01))
	tween.tween_callback(Callable(burst_root, "queue_free"))


func _create_burst_ray(angle: float, length: float) -> Line2D:
	var ray: Line2D = Line2D.new()
	ray.width = max(burst_ray_width, 0.1)
	ray.default_color = burst_color
	ray.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2.RIGHT.rotated(angle) * max(length, 1.0),
	])
	return ray


func _setup_threshold_ui() -> void:
	if not show_threshold_ui:
		return

	threshold_ui_root = get_node_or_null(threshold_ui_path) as Control
	if threshold_ui_root == null:
		threshold_ui_root = _create_threshold_ui_root()

	if threshold_ui_root == null:
		return

	threshold_progress_bar = threshold_ui_root.get_node_or_null("ProgressBar") as ProgressBar
	if threshold_progress_bar == null:
		threshold_progress_bar = _create_threshold_progress_bar(threshold_ui_root)

	threshold_label = threshold_ui_root.get_node_or_null("Label") as Label
	if threshold_label == null:
		threshold_label = _create_threshold_label(threshold_ui_root)

	_configure_threshold_ui_nodes()


func _create_threshold_ui_root() -> Control:
	var root: Control = Control.new()
	root.name = "ThresholdUI"
	root.position = threshold_ui_offset
	root.size = threshold_ui_size
	root.custom_minimum_size = threshold_ui_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	return root


func _create_threshold_progress_bar(parent: Control) -> ProgressBar:
	var progress_bar: ProgressBar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.position = Vector2.ZERO
	progress_bar.size = threshold_ui_size
	progress_bar.custom_minimum_size = threshold_ui_size
	progress_bar.show_percentage = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_bar.add_theme_stylebox_override("background", _create_threshold_style(Color(0.05, 0.04, 0.08, 0.75), Color(0.9, 0.78, 1.0, 0.55)))
	progress_bar.add_theme_stylebox_override("fill", _create_threshold_style(Color(0.55, 0.28, 1.0, 0.85), Color(1.0, 0.85, 1.0, 0.0)))
	parent.add_child(progress_bar)
	return progress_bar


func _create_threshold_label(parent: Control) -> Label:
	var label: Label = Label.new()
	label.name = "Label"
	label.position = Vector2.ZERO
	label.size = threshold_ui_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.12, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	return label


func _configure_threshold_ui_nodes() -> void:
	if threshold_ui_root != null:
		threshold_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if threshold_ui_root.size == Vector2.ZERO:
			threshold_ui_root.size = threshold_ui_size
		if threshold_ui_root.custom_minimum_size == Vector2.ZERO:
			threshold_ui_root.custom_minimum_size = threshold_ui_size

	if threshold_progress_bar != null:
		threshold_progress_bar.position = Vector2.ZERO
		threshold_progress_bar.size = threshold_ui_size
		threshold_progress_bar.custom_minimum_size = threshold_ui_size
		threshold_progress_bar.show_percentage = false
		threshold_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		threshold_progress_bar.add_theme_stylebox_override("background", _create_threshold_style(Color(0.05, 0.04, 0.08, 0.75), Color(0.9, 0.78, 1.0, 0.55)))
		threshold_progress_bar.add_theme_stylebox_override("fill", _create_threshold_style(Color(0.55, 0.28, 1.0, 0.85), Color(1.0, 0.85, 1.0, 0.0)))

	if threshold_label != null:
		threshold_label.position = Vector2.ZERO
		threshold_label.size = threshold_ui_size
		threshold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		threshold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		threshold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		threshold_label.add_theme_font_size_override("font_size", 8)
		threshold_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))
		threshold_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.12, 1.0))
		threshold_label.add_theme_constant_override("outline_size", 2)


func _create_threshold_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _update_threshold_ui() -> void:
	if threshold_ui_root == null:
		return

	var exhausted: bool = not _can_spawn_more_rewards()
	threshold_ui_root.visible = show_threshold_ui and not (hide_threshold_ui_when_exhausted and exhausted)

	if threshold_progress_bar != null:
		threshold_progress_bar.min_value = 0.0
		threshold_progress_bar.max_value = max(next_drop_threshold, 1.0)
		threshold_progress_bar.value = threshold_progress_bar.max_value if exhausted else clamp(damage_since_last_drop, 0.0, threshold_progress_bar.max_value)

	if threshold_label == null:
		return
	if exhausted:
		threshold_label.text = "耗尽"
	else:
		threshold_label.text = "%s/%s" % [str(int(floor(damage_since_last_drop))), str(int(ceil(next_drop_threshold)))]


func _pick_weighted_pickup_scene() -> PackedScene:
	var pool_pickup_scene: PackedScene = _pick_pickup_scene_from_pool()
	if pool_pickup_scene != null:
		return pool_pickup_scene

	var valid_entries: Array[Dictionary] = []
	var total_weight: float = 0.0

	for index: int in range(pickup_scenes.size()):
		var pickup_scene: PackedScene = pickup_scenes[index]
		if pickup_scene == null:
			continue

		var weight: float = _get_pickup_weight(index)
		if weight <= 0.0:
			continue

		total_weight += weight
		valid_entries.append({
			"scene": pickup_scene,
			"accumulated_weight": total_weight,
		})

	if valid_entries.is_empty() or total_weight <= 0.0:
		return null

	var roll: float = randf_range(0.0, total_weight)
	for entry: Dictionary in valid_entries:
		if float(entry.get("accumulated_weight", 0.0)) >= roll:
			return entry.get("scene") as PackedScene

	return valid_entries[valid_entries.size() - 1].get("scene") as PackedScene


func _get_pickup_weight(index: int) -> float:
	if index >= 0 and index < pickup_weights.size():
		return max(pickup_weights[index], 0.0)
	return 1.0


func _pick_pickup_scene_from_pool() -> PackedScene:
	if alchemy_drop_pool == null:
		return null

	var stats: RunStats = _get_run_stats()
	var shop_level: int = _get_current_shop_level(stats)
	var enabled_map_tag_keys: Array[String] = _get_enabled_map_tag_keys(stats)
	return alchemy_drop_pool.pick_random_pickup_scene(shop_level, enabled_map_tag_keys)


func _get_current_shop_level(stats: RunStats) -> int:
	if stats != null and stats.shop != null:
		return max(stats.shop.level, 1)
	return max(fallback_shop_level, 1)


func _get_enabled_map_tag_keys(stats: RunStats) -> Array[String]:
	if stats == null:
		return []
	return stats.get_enabled_map_tag_keys()


func _get_run_stats() -> RunStats:
	if run_stats != null:
		return run_stats

	run_stats = _find_run_stats_from_ancestors()
	return run_stats


func _find_run_stats_from_ancestors() -> RunStats:
	var current_node: Node = self
	while current_node != null:
		var value: Variant = _get_node_property(current_node, "run_stats")
		if value is RunStats:
			return value as RunStats
		current_node = current_node.get_parent()

	return null


func _get_node_property(node: Node, property_name: String) -> Variant:
	if node == null:
		return null

	for property_info: Dictionary in node.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return node.get(property_name)

	return null
