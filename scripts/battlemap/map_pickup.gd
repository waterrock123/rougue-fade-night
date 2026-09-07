class_name MapPickup
extends Area2D

signal collected(pickup: MapPickup, collector: Entity)

## 地图拾取物基类。
## 它只负责“谁能捡、何时消失、捡到后调用效果”，具体效果由子类重写 _apply_pickup。

@export var collect_groups: Array[StringName] = [&"player"]
@export var pickup_delay: float = 0.15
@export var lifetime: float = 12.0
@export var remove_on_collect: bool = true

@export_group("提示")
@export var pickup_display_name: String = ""
@export var show_pickup_tip: bool = true

@export_group("视觉动态")
## 拾取物的视觉根节点。为空时会自动寻找 VisualRoot / Sprite2D / AnimatedSprite2D。
@export var visual_root_path: NodePath
@export var enable_float_motion: bool = true
@export var float_amplitude: float = 3.0
@export var float_speed: float = 2.4
@export var enable_sway_motion: bool = true
@export var sway_angle_degrees: float = 5.0
@export var sway_speed: float = 2.0
@export var enable_spawn_bounce: bool = true
@export var spawn_bounce_height: float = 10.0
@export var spawn_bounce_duration: float = 0.28
@export var enable_expire_blink: bool = true
@export var expire_blink_time: float = 2.0
@export var expire_blink_speed: float = 12.0

@export_group("吸附")
## 开启后，玩家靠近时拾取物会飞向玩家。普通掉落物建议开启，钥匙/剧情物可以关闭。
@export var enable_magnet: bool = true
@export var magnet_radius: float = 42.0
@export var magnet_speed: float = 150.0
@export var magnet_acceleration: float = 420.0
@export var collect_distance: float = 10.0

var age: float = 0.0
var collected_once: bool = false
var visual_root: Node2D
var visual_base_position: Vector2 = Vector2.ZERO
var visual_base_rotation: float = 0.0
var motion_seed: float = 0.0
var current_magnet_speed: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	visual_root = _resolve_visual_root()
	if visual_root != null:
		visual_base_position = visual_root.position
		visual_base_rotation = visual_root.rotation
	motion_seed = randf() * TAU
	_play_spawn_bounce()


func _process(delta: float) -> void:
	age += delta
	if lifetime > 0.0 and age >= lifetime:
		queue_free()
		return

	if not collected_once and age >= pickup_delay:
		_try_collect_current_overlaps()
		_process_magnet(delta)

	_update_visual_motion()


func _on_body_entered(body: Node2D) -> void:
	if body is Entity:
		_try_collect(body as Entity)


func _on_area_entered(area: Area2D) -> void:
	var parent: Node = area.get_parent()
	if parent is Entity:
		_try_collect(parent as Entity)


func _try_collect(collector: Entity) -> void:
	if collected_once or collector == null or collector.is_dead:
		return
	if age < pickup_delay:
		return
	if not _can_collect(collector):
		return

	collected_once = true
	_apply_pickup(collector)
	collected.emit(self, collector)
	if EventBus != null:
		EventBus.map_pickup_collected.emit(self, collector)
	if remove_on_collect:
		queue_free()


func _process_magnet(delta: float) -> void:
	if not enable_magnet:
		return

	var collector: Entity = _find_nearest_collector(magnet_radius)
	if collector == null:
		current_magnet_speed = 0.0
		return

	current_magnet_speed = min(current_magnet_speed + magnet_acceleration * delta, magnet_speed)
	global_position = global_position.move_toward(collector.global_position, current_magnet_speed * delta)
	if global_position.distance_to(collector.global_position) <= collect_distance:
		_try_collect(collector)


func _try_collect_current_overlaps() -> void:
	for body: Node2D in get_overlapping_bodies():
		if collected_once:
			return
		if body is Entity:
			_try_collect(body as Entity)

	for area: Area2D in get_overlapping_areas():
		if collected_once:
			return

		var parent: Node = area.get_parent()
		if parent is Entity:
			_try_collect(parent as Entity)


func _can_collect(collector: Entity) -> bool:
	for group_name: StringName in collect_groups:
		if collector.is_in_group(String(group_name)):
			return true
		if group_name == &"player" and collector.is_player_side():
			return true
	return false


func _find_nearest_collector(radius: float) -> Entity:
	var nearest: Entity
	var nearest_distance: float = INF

	for group_name: StringName in collect_groups:
		for node in get_tree().get_nodes_in_group(String(group_name)):
			if not (node is Entity):
				continue

			var entity: Entity = node as Entity
			if entity.is_dead:
				continue

			var distance: float = global_position.distance_to(entity.global_position)
			if distance > radius or distance >= nearest_distance:
				continue

			nearest = entity
			nearest_distance = distance

	return nearest


func _update_visual_motion() -> void:
	if visual_root == null:
		return

	var float_offset: float = 0.0
	if enable_float_motion:
		float_offset = sin(age * float_speed + motion_seed) * float_amplitude

	visual_root.position = visual_base_position + Vector2(0.0, float_offset)

	if enable_sway_motion:
		var sway_angle: float = deg_to_rad(sway_angle_degrees)
		visual_root.rotation = visual_base_rotation + sin(age * sway_speed + motion_seed) * sway_angle
	else:
		visual_root.rotation = visual_base_rotation

	if enable_expire_blink and lifetime > 0.0 and lifetime - age <= expire_blink_time:
		visual_root.modulate.a = 0.35 + 0.65 * absf(sin(age * expire_blink_speed))
	else:
		visual_root.modulate.a = 1.0


func _play_spawn_bounce() -> void:
	if not enable_spawn_bounce or visual_root == null:
		return

	visual_root.position = visual_base_position + Vector2(0.0, -spawn_bounce_height)
	var tween: Tween = create_tween()
	tween.tween_property(visual_root, "position", visual_base_position, spawn_bounce_duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _resolve_visual_root() -> Node2D:
	if visual_root_path != NodePath():
		var explicit_node: Node2D = get_node_or_null(visual_root_path) as Node2D
		if explicit_node != null:
			return explicit_node

	var visual_node: Node2D = get_node_or_null("VisualRoot") as Node2D
	if visual_node != null:
		return visual_node

	for child: Node in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child as Node2D
		if child.name == &"VisualRoot" and child is Node2D:
			return child as Node2D

	return null


func _apply_pickup(_collector: Entity) -> void:
	# 子类在这里写具体效果，例如回血、加金币、给状态。
	pass


## 让拾取物在接下来一小段时间内不能被捡起。
## 炼金台“把物品抛到地上”的动画会用到它，避免物品还在空中就被玩家吸走。
func delay_collection_for(duration: float) -> void:
	if duration <= 0.0:
		return

	pickup_delay = max(pickup_delay, age + duration)


## 子类调用这个函数统一弹出“玩家拾取了 X，触发了 Y”的地图提示。
func show_collected_tip(effect_text: String) -> void:
	if not show_pickup_tip:
		return
	if FloatText == null or not FloatText.has_method("show_screen_tip"):
		return

	var item_name: String = get_pickup_display_name()
	var detail: String = effect_text.strip_edges()
	if detail.is_empty():
		FloatText.show_screen_tip("玩家拾取了%s。" % item_name)
		return

	FloatText.show_screen_tip("玩家拾取了%s，触发了%s。" % [item_name, detail])


func get_pickup_display_name() -> String:
	var display_name: String = pickup_display_name.strip_edges()
	if not display_name.is_empty():
		return display_name
	return name
