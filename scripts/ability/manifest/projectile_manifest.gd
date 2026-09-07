class_name ProjectileManifest
extends AbilityManifest

@export_group("Projectile")
@export var speed: float = 10.0
@export var target_group: String
@export var max_distance: float = 1000.0
@export var is_rotate: bool = false
@export var hit_sound: AudiioConfig
@export var rotate_speed: float = 10.0

@export_group("World Collision")
## 是否会被墙体、石头、柱子等 World 层物理碰撞挡住。
@export var blocked_by_world: bool = true
## 默认检测物理层 1，也就是 project.godot 里命名的 World 层。
@export_flags_2d_physics var world_collision_mask: int = 1

@export_group("Return")
@export var return_to_source_after_max_distance: bool = false
@export var return_speed_multiplier: float = 1.0
@export var return_arrive_distance: float = 18.0
@export var return_max_distance_multiplier: float = 1.0

@export_group("Homing")
## 投射物自身的追踪转向速度；0 表示默认不追踪。装备也可以通过运行时属性追加此数值。
@export var homing_turn_speed: float = 0.0
@export var homing_acquire_radius: float = 500.0
@export var homing_retarget_interval: float = 0.12

@export_group("Damage")
@export var damage: float = 10.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.RANGED]
@export var tags: Array[String] = ["manifest", "projectile", "ranged"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()
## 普通投射物默认造成 6 点削韧；高速连射弹可在具体场景中继续调低。
@export var poise_damage: float = 6.0
@export var is_penetrate: bool = false

@onready var sprite2d: Sprite2D = $Sprite2D

var source: Entity
var source_ability_id: StringName = &""
var source_ability_slot_index: int = -1
var current_dir: Vector2 = Vector2.ZERO
var current_distance: float = 0.0
var return_distance: float = 0.0
var is_returning: bool = false
var runtime_homing_turn_speed: float = 0.0
var homing_controller: ProjectileHomingController = ProjectileHomingController.new()


# 初始化投射物飞行方向、来源和距离修正。
func activate(context: AbilityContext) -> void:
	source = context.caster
	source_ability_id = context.ability.id if context.ability != null else &""
	source_ability_slot_index = context.ability.runtime_slot_index if context.ability != null else -1
	_apply_projectile_range_bonus()
	_configure_homing()
	if not EventBus.game_paused.is_connected(_handle_game_pause):
		EventBus.game_paused.connect(_handle_game_pause)
	if not EventBus.scene_changed.is_connected(_handle_scene_changed):
		EventBus.scene_changed.connect(_handle_scene_changed)

	if context.targets.size() > 0:
		var target_pos: Vector2 = context.get_target_positon(0)
		if target_pos != global_position:
			current_dir = (target_pos - global_position).normalized()
			look_at(target_pos)
	elif context.locked_direction != Vector2.ZERO:
		current_dir = context.locked_direction.normalized()


func _exit_tree() -> void:
	if EventBus.game_paused.is_connected(_handle_game_pause):
		EventBus.game_paused.disconnect(_handle_game_pause)
	if EventBus.scene_changed.is_connected(_handle_scene_changed):
		EventBus.scene_changed.disconnect(_handle_scene_changed)


# 推进投射物。可选回旋逻辑会在达到最远距离后沿直线追向施法者。
func _process(delta: float) -> void:
	if source != null and not is_instance_valid(source):
		queue_free()
		return
	if source != null and source.is_dead:
		queue_free()
		return

	if is_returning:
		_process_returning(delta)
	else:
		_process_forward(delta)

	if is_rotate:
		global_rotation += delta * rotate_speed


func _process_forward(delta: float) -> void:
	if current_dir == Vector2.ZERO:
		queue_free()
		return

	_update_homing_direction(delta)
	var movement: Vector2 = current_dir * delta * speed
	current_distance += movement.length()
	if not _move_or_free_on_world_hit(movement):
		return

	if current_distance >= max_distance:
		if return_to_source_after_max_distance:
			_begin_returning()
		else:
			queue_free()


func _process_returning(delta: float) -> void:
	var valid_source: Entity = _get_valid_source()
	if valid_source == null:
		queue_free()
		return

	var to_source: Vector2 = valid_source.global_position - global_position
	var distance_to_source: float = to_source.length()
	if distance_to_source <= return_arrive_distance:
		queue_free()
		return

	current_dir = to_source.normalized()
	var movement_length: float = delta * speed * max(return_speed_multiplier, 0.01)
	if movement_length >= distance_to_source:
		queue_free()
		return

	var movement: Vector2 = current_dir * movement_length
	return_distance += movement.length()
	if not _move_or_free_on_world_hit(movement):
		return

	# 如果玩家移动太快，投斧不会无限追踪；回旋路程用完后直接消失。
	var allowed_return_distance: float = max_distance * max(return_max_distance_multiplier, 0.01)
	if return_distance >= allowed_return_distance:
		queue_free()


func _begin_returning() -> void:
	is_returning = true
	return_distance = 0.0
	current_distance = max_distance


# 普通投射物使用轻量射线检测墙体，撞到 World 层后直接消失。
func _move_or_free_on_world_hit(movement: Vector2) -> bool:
	if movement == Vector2.ZERO:
		return true

	var collision: Dictionary = _get_world_collision(movement)
	if not collision.is_empty():
		var hit_position: Variant = collision.get("position")
		if hit_position is Vector2:
			global_position = hit_position
		queue_free()
		return false

	global_position += movement
	return true


func _get_world_collision(movement: Vector2) -> Dictionary:
	if not blocked_by_world or movement == Vector2.ZERO or not is_inside_tree():
		return {}

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + movement,
		world_collision_mask
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_ray(query)


# 跟随全局暂停状态处理贴图动画暂停。
func _handle_game_pause(pause: bool) -> void:
	if sprite2d != null and sprite2d.texture is AnimatedTexture:
		(sprite2d.texture as AnimatedTexture).pause = pause


# 切回 home 场景时清理残留投射物。
func _handle_scene_changed(scene: String) -> void:
	if scene == "home":
		queue_free()


# 命中目标时创建 DamageData，并交给实体统一受伤链路处理。
func _on_area_2d_area_entered(area: Area2D) -> void:
	var parent: Node = area.get_parent()
	if parent == null or not _matches_target_group(parent):
		return

	if parent is Entity:
		if parent.has_method("can_be_targeted") and not parent.can_be_targeted():
			return

		var valid_source: Entity = _get_valid_source()
		if source != null and valid_source == null:
			queue_free()
			return

		var damage_data: DamageData = DamageData.create(
			damage,
			damage_types,
			tags,
			valid_source,
			parent,
			can_crit,
			scaling_rule,
			source_ability_id,
			source_ability_slot_index,
			poise_damage
		)
		parent.apply_damage(damage_data)

		if hit_sound != null:
			AudioController.play(hit_sound, global_position)

		if is_penetrate:
			return

		queue_free()


func _get_valid_source() -> Entity:
	# 投射物可能比施法者活得更久；旧引用失效时不能再传给 DamageData。
	if source == null:
		return null
	if not is_instance_valid(source):
		return null
	return source


func _matches_target_group(node: Node) -> bool:
	if target_group.is_empty():
		return true
	if node is Entity:
		return (node as Entity).matches_target_group(StringName(target_group))
	return node.is_in_group(target_group)


func _apply_projectile_range_bonus() -> void:
	if source == null or source.stats_controller == null:
		return

	var bonus_rate: float = max(source.stats_controller.get_stat(&"projectile_range_bonus_rate"), 0.0)
	if bonus_rate <= 0.0:
		return
	if not tags.has("projectile"):
		return

	# 只对 projectile 标签的 manifest 生效，抛射物、近战特效等不会被投射物增程误影响。
	max_distance *= 1.0 + bonus_rate


## 追踪由来源实体的运行时属性驱动，因此临时装备也会在装备刷新后立即生效。
func _configure_homing() -> void:
	runtime_homing_turn_speed = maxf(homing_turn_speed, 0.0)
	homing_controller.reset()
	if source == null or source.stats_controller == null or not tags.has("projectile"):
		return
	runtime_homing_turn_speed += maxf(
		source.stats_controller.get_stat(&"projectile_homing_turn_speed", 0.0),
		0.0
	)


func _update_homing_direction(delta: float) -> void:
	if runtime_homing_turn_speed <= 0.0:
		return
	current_dir = homing_controller.steer(
		self,
		source,
		StringName(target_group),
		current_dir,
		runtime_homing_turn_speed,
		homing_acquire_radius,
		homing_retarget_interval,
		delta
	)
	if not is_rotate and current_dir != Vector2.ZERO:
		global_rotation = current_dir.angle()
