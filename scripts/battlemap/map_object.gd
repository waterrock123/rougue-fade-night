class_name MapObject
extends Entity

signal object_hit(map_object: MapObject, damage_data: DamageData)
signal object_destroyed(map_object: MapObject, killer: Entity)

const INTERACTABLE_HIGHLIGHT_SHADER: Shader = preload("res://shaders/map_object_highlight.gdshader")

## 可被攻击的战斗地图物件基类。
## 注意：它不会加入 enemy 组，因此不会污染 EnemySpawner 的胜利统计或敌人击杀奖励。

@export_group("交互高亮")
## 开启后，地图物件的视觉节点外轮廓会出现轻微呼吸高亮，提醒玩家它是可交互物体。
@export var enable_interactable_highlight: bool = false
## 留空时会自动查找 VisualRoot 下的 Sprite2D / AnimatedSprite2D；没有 VisualRoot 时再找直接子节点。
@export var highlight_visual_path: NodePath
@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 8.0, 0.25) var highlight_outline_size: float = 1.0
@export_range(0.0, 1.0, 0.01) var highlight_outline_alpha: float = 0.72
@export_range(0.0, 1.0, 0.01) var highlight_inner_glow_strength: float = 0.06
@export_range(0.0, 1.0, 0.01) var highlight_pulse_strength: float = 0.14
@export_range(0.0, 8.0, 0.1) var highlight_pulse_speed: float = 2.0

@export_group("目标判定")
## 开启后，玩家侧技能把 target_group 写成 enemy 时也能命中这个物件。
@export var targetable_by_player_side: bool = true
## 开启后，敌人侧技能可以把这个物件视为玩家侧目标。默认关闭，避免怪物乱砍树。
@export var targetable_by_enemy_side: bool = false

@export_group("导航阻挡")
## 开启后，这个地图物件会把自己所在格子注册为 AStar 阻挡。苹果树可关，石头/宝箱/柱子建议开。
@export var blocks_navigation: bool = false
## 额外阻挡范围，0 表示只阻挡脚下 1 格，1 表示阻挡 3x3。
@export_range(0, 4, 1) var navigation_block_radius_cells: int = 0

@export_group("掉落")
## 受击后按概率掉落，适合苹果树“打一下有概率掉苹果”。
@export var drops_on_damage: Array[MapDropEntry] = []
## 被摧毁时按概率掉落。
@export var drops_on_destroy: Array[MapDropEntry] = []
@export var drop_to_runtime_effect_container: bool = true

@export_group("受击反馈")
## 留空时会自动使用 AnimatedSprite2D / Sprite2D 作为反馈节点。
@export var feedback_visual_path: NodePath
@export var enable_hit_flash: bool = true
@export var hit_flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var hit_flash_duration: float = 0.04
@export var hit_flash_recover_duration: float = 0.08
@export var enable_hit_shake: bool = true
@export var hit_shake_offset: float = 2.0
@export var hit_shake_duration: float = 0.08
@export var hit_sound: AudiioConfig

@export_group("销毁")
@export var destroy_sound: AudiioConfig
## 会按顺序寻找这些动画；找到后播放。没有动画时走 destroy_free_delay。
@export var destroy_animation_names: Array[StringName] = [&"destroy", &"break", &"die", &"death"]
## 只有非循环动画会等待 animation_finished，避免循环动画让节点永远不释放。
@export var wait_destroy_animation_finished: bool = true
## 地图物件死亡后立刻延迟关闭碰撞/可命中区域，避免“已碎掉但还挡路/还能挨打”。
@export var disable_collision_on_destroy: bool = true
## 没有专门死亡动画时，延迟一小段时间释放节点，让受击反馈有时间显示。
@export var destroy_free_delay: float = 0.2

var last_damage_source: Entity
var feedback_visual: Node2D
var feedback_visual_base_modulate: Color = Color.WHITE
var feedback_visual_base_position: Vector2 = Vector2.ZERO
var feedback_visual_cached: bool = false
var hit_flash_tween: Tween
var hit_shake_tween: Tween
var registered_navigation_battle_map: BattleMap
var has_registered_navigation_blocker: bool = false
var highlight_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	super._ready()
	add_to_group("map_object")
	_cache_feedback_visual()
	_setup_interactable_highlight()
	call_deferred("_register_navigation_blocker")


func _exit_tree() -> void:
	_unregister_navigation_blocker()
	super._exit_tree()


func is_enemy_side() -> bool:
	return targetable_by_player_side


func is_player_side() -> bool:
	return targetable_by_enemy_side


## 地图物体的最后一道阵营保护，避免玩家的范围伤害绕过目标筛选误伤动物。
## 普通地图物体默认允许玩家攻击；只有把 targetable_by_player_side 设为 false 的物体会被拦截。
func apply_damage(damage_event):
	if not targetable_by_player_side and damage_event is DamageData:
		var damage_data: DamageData = damage_event as DamageData
		if damage_data.source != null and damage_data.source.is_player_side():
			return damage_data

	return super.apply_damage(damage_event)


func _handle_damage_callback(damage_data: DamageData):
	if damage_data == null:
		return
	if damage_data.final_damage <= 0.0:
		return

	if damage_data.source != null and is_instance_valid(damage_data.source):
		last_damage_source = damage_data.source
	object_hit.emit(self, damage_data)
	_play_hit_sound()
	if current_health > 0.0:
		_spawn_drop_table(drops_on_damage)


func _die() -> void:
	if is_dead:
		return

	var killer: Entity = last_damage_source if last_damage_source != null and is_instance_valid(last_damage_source) else null
	super._die()
	_unregister_navigation_blocker()
	_disable_collision_for_destroy()
	_play_destroy_sound()
	_spawn_drop_table(drops_on_destroy)
	object_destroyed.emit(self, killer)
	if EventBus != null:
		EventBus.map_object_destroyed.emit(self, killer)
	_finish_destroy_later()


func _show_damage_taken_effect() -> void:
	_play_hit_flash()
	_play_hit_shake()


## 物件被脚本移动后可以手动调用它，刷新自己在 AStarGrid2D 上占用的格子。
func refresh_navigation_blocker() -> void:
	_unregister_navigation_blocker()
	_register_navigation_blocker()


func _spawn_drop_table(drop_table: Array[MapDropEntry]) -> void:
	for entry: MapDropEntry in drop_table:
		if entry == null:
			continue

		var count: int = entry.roll_count()
		spawn_pickup_scene(entry.pickup_scene, count, entry.spawn_radius)


func spawn_pickup_scene(pickup_scene: PackedScene, count: int = 1, spawn_radius: float = 14.0) -> void:
	if pickup_scene == null:
		return

	for index: int in range(max(count, 0)):
		_spawn_one_pickup_deferred(pickup_scene, spawn_radius, index)


func _spawn_one_pickup_deferred(pickup_scene: PackedScene, spawn_radius: float, index: int) -> void:
	var spawn_position: Vector2 = global_position + _get_drop_offset(spawn_radius, index)
	# 掉落经常发生在命中/死亡的物理回调里，延迟 add_child 可以避免 Godot 正在刷新碰撞查询时注册新的 Area2D。
	_spawn_one_pickup.call_deferred(pickup_scene, spawn_position)


func _spawn_one_pickup(pickup_scene: PackedScene, spawn_position: Vector2) -> void:
	var pickup: Node2D = pickup_scene.instantiate() as Node2D
	if pickup == null:
		return

	var parent_node: Node = _get_drop_parent()
	if parent_node == null or not is_instance_valid(parent_node):
		pickup.queue_free()
		return

	parent_node.add_child(pickup)
	pickup.global_position = spawn_position


func _get_drop_parent() -> Node:
	var battle_map: BattleMap = get_tree().get_first_node_in_group("battle_map") as BattleMap
	if battle_map != null and drop_to_runtime_effect_container:
		var runtime_container: Node = battle_map.get_runtime_effect_container()
		if runtime_container != null:
			return runtime_container

	if get_parent() != null:
		return get_parent()
	return get_tree().current_scene


func _get_drop_offset(spawn_radius: float, index: int) -> Vector2:
	var radius: float = max(spawn_radius, 0.0)
	if radius <= 0.0:
		return Vector2.ZERO

	var angle: float = randf() * TAU + float(index) * 0.9
	var distance: float = randf_range(radius * 0.25, radius)
	return Vector2.RIGHT.rotated(angle) * distance


func _finish_destroy_later() -> void:
	var destroy_animation_name: StringName = _get_destroy_animation_name()
	if destroy_animation_name != &"":
		_play_destroy_animation(destroy_animation_name)
		if wait_destroy_animation_finished and _can_wait_destroy_animation(destroy_animation_name):
			await animated_sprite.animation_finished

	if destroy_free_delay <= 0.0:
		queue_free()
		return

	await get_tree().create_timer(destroy_free_delay, false).timeout
	if is_instance_valid(self):
		queue_free()


func _cache_feedback_visual() -> void:
	feedback_visual = _resolve_feedback_visual()
	if feedback_visual == null:
		feedback_visual = self

	feedback_visual_base_modulate = feedback_visual.modulate
	feedback_visual_base_position = feedback_visual.position
	feedback_visual_cached = true


func _resolve_feedback_visual() -> Node2D:
	if feedback_visual_path != NodePath():
		var explicit_visual: Node2D = get_node_or_null(feedback_visual_path) as Node2D
		if explicit_visual != null:
			return explicit_visual

	if animated_sprite != null:
		return animated_sprite

	var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		return sprite

	return null


## 运行时刷新高亮参数。编辑场景时调 export 即可；脚本中动态改颜色也可以调用它重套材质。
func refresh_interactable_highlight() -> void:
	_setup_interactable_highlight()


func _setup_interactable_highlight() -> void:
	highlight_materials.clear()
	if not enable_interactable_highlight:
		return

	var highlight_visuals: Array[CanvasItem] = _get_highlight_visuals()
	for visual: CanvasItem in highlight_visuals:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = INTERACTABLE_HIGHLIGHT_SHADER
		_apply_highlight_material_params(material)
		visual.material = material
		highlight_materials.append(material)


func _apply_highlight_material_params(material: ShaderMaterial) -> void:
	if material == null:
		return

	material.set_shader_parameter("highlight_enabled", true)
	material.set_shader_parameter("outline_color", highlight_color)
	material.set_shader_parameter("outline_size", highlight_outline_size)
	material.set_shader_parameter("outline_alpha", highlight_outline_alpha)
	material.set_shader_parameter("inner_glow_strength", highlight_inner_glow_strength)
	material.set_shader_parameter("pulse_strength", highlight_pulse_strength)
	material.set_shader_parameter("pulse_speed", highlight_pulse_speed)


func _get_highlight_visuals() -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	var seen_ids: Dictionary = {}

	if highlight_visual_path != NodePath():
		var explicit_root: Node = get_node_or_null(highlight_visual_path)
		_collect_highlight_visuals(explicit_root, result, seen_ids)
		return result

	var visual_root: Node = get_node_or_null("VisualRoot")
	if visual_root != null:
		_collect_highlight_visuals(visual_root, result, seen_ids)

	if animated_sprite != null:
		_append_highlight_visual(animated_sprite, result, seen_ids)

	var direct_sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if direct_sprite != null:
		_append_highlight_visual(direct_sprite, result, seen_ids)

	return result


func _collect_highlight_visuals(node: Node, result: Array[CanvasItem], seen_ids: Dictionary) -> void:
	if node == null:
		return

	_append_highlight_visual(node, result, seen_ids)
	for child: Node in node.get_children():
		_collect_highlight_visuals(child, result, seen_ids)


func _append_highlight_visual(node: Node, result: Array[CanvasItem], seen_ids: Dictionary) -> void:
	if not _is_highlight_visual_node(node):
		return

	var canvas_item: CanvasItem = node as CanvasItem
	var instance_id: int = canvas_item.get_instance_id()
	if seen_ids.has(instance_id):
		return

	seen_ids[instance_id] = true
	result.append(canvas_item)


func _is_highlight_visual_node(node: Node) -> bool:
	return node is Sprite2D or node is AnimatedSprite2D or node is TextureRect


func _get_feedback_visual() -> Node2D:
	if not feedback_visual_cached or feedback_visual == null or not is_instance_valid(feedback_visual):
		_cache_feedback_visual()
	return feedback_visual


func _play_hit_flash() -> void:
	if not enable_hit_flash:
		return

	var visual: Node2D = _get_feedback_visual()
	if visual == null:
		return

	if hit_flash_tween != null and hit_flash_tween.is_valid():
		hit_flash_tween.kill()
		visual.modulate = feedback_visual_base_modulate

	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(visual, "modulate", hit_flash_color, hit_flash_duration)
	hit_flash_tween.tween_property(visual, "modulate", feedback_visual_base_modulate, hit_flash_recover_duration)


func _play_hit_shake() -> void:
	if not enable_hit_shake:
		return

	var visual: Node2D = _get_feedback_visual()
	if visual == null:
		return

	if hit_shake_tween != null and hit_shake_tween.is_valid():
		hit_shake_tween.kill()
		visual.position = feedback_visual_base_position

	var shake_x: float = randf_range(-hit_shake_offset, hit_shake_offset)
	hit_shake_tween = create_tween()
	hit_shake_tween.tween_property(visual, "position:x", feedback_visual_base_position.x + shake_x, hit_shake_duration * 0.5)
	hit_shake_tween.tween_property(visual, "position", feedback_visual_base_position, hit_shake_duration * 0.5)


func _play_hit_sound() -> void:
	if hit_sound == null:
		return
	AudioController.play(hit_sound, global_position)


func _play_destroy_sound() -> void:
	if destroy_sound == null:
		return
	AudioController.play(destroy_sound, global_position)


func _get_destroy_animation_name() -> StringName:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return &""

	for animation_name: StringName in destroy_animation_names:
		if animated_sprite.sprite_frames.has_animation(animation_name):
			return animation_name

	return &""


func _play_destroy_animation(animation_name: StringName) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	animated_sprite.play(animation_name)


func _can_wait_destroy_animation(animation_name: StringName) -> bool:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return false
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return false
	return not animated_sprite.sprite_frames.get_animation_loop(animation_name)


func _disable_collision_for_destroy() -> void:
	if not disable_collision_on_destroy:
		return

	# 这里常从物理命中回调进入，所以全部用 set_deferred，避免 flushing queries 报错。
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_disable_collision_recursive(self)


func _disable_collision_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", true)
		elif child is Area2D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)

		_disable_collision_recursive(child)


func _register_navigation_blocker() -> void:
	if not blocks_navigation:
		return
	if is_dead or not is_inside_tree():
		return

	var battle_map: BattleMap = get_tree().get_first_node_in_group("battle_map") as BattleMap
	if battle_map == null:
		return

	battle_map.register_runtime_navigation_blocker(self, global_position, navigation_block_radius_cells)
	registered_navigation_battle_map = battle_map
	has_registered_navigation_blocker = true


func _unregister_navigation_blocker() -> void:
	if not has_registered_navigation_blocker:
		return

	if registered_navigation_battle_map != null and is_instance_valid(registered_navigation_battle_map):
		registered_navigation_battle_map.unregister_runtime_navigation_blocker(self)

	registered_navigation_battle_map = null
	has_registered_navigation_blocker = false
