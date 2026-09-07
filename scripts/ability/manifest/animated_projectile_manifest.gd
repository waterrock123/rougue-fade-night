## 动画投射物 Manifest。
## 用于带 start / repeatable / hit 三段动画的投射物：生成后播放 start，飞行时循环 repeatable，命中后播放 hit 并释放。
class_name AnimatedProjectileManifest
extends AbilityManifest

@export_group("Projectile")
@export var speed: float = 260.0
@export var target_group: StringName = &"enemy"
@export var max_distance: float = 300.0
@export var rotate_while_flying: bool = false
@export var rotate_speed: float = 10.0
@export var is_penetrate: bool = false
@export var hit_sound: AudiioConfig

@export_group("World Collision")
## 是否会被墙体、石头、柱子等 World 层物理碰撞挡住。
@export var blocked_by_world: bool = true
## 默认检测物理层 1，也就是 project.godot 里命名的 World 层。
@export_flags_2d_physics var world_collision_mask: int = 1

@export_group("Homing")
## 投射物自身的追踪转向速度；0 表示默认不追踪。装备可以通过运行时属性追加此数值。
@export var homing_turn_speed: float = 0.0
@export var homing_acquire_radius: float = 500.0
@export var homing_retarget_interval: float = 0.12

@export_group("Animation")
@export var start_animation: StringName = &"start"
@export var repeat_animation: StringName = &"repeatable"
@export var hit_animation: StringName = &"hit"

@export_group("Damage")
@export var damage: float = 10.0
@export var can_crit: bool = true
@export var damage_types: Array[int] = [DamageData.DamageType.RANGED]
@export var tags: Array[String] = ["manifest", "projectile", "animated_projectile", "ranged"]
@export var scaling_rule: DamageScalingRule = DamageScalingRule.new()
## 普通动画投射物默认造成 6 点削韧，多发齐射可在具体场景中调低。
@export var poise_damage: float = 6.0

@export_group("On Hit Status")
## 命中后概率附加的状态；为空则不附加。适合冰锥概率冻结、火球概率燃烧等。
@export var on_hit_status: StatusData
@export_range(0.0, 1.0, 0.01) var on_hit_status_chance: float = 0.0
## 每点幸运提高多少触发概率，例如 0.01 表示每点幸运 +1%。
@export var luck_chance_bonus_per_point: float = 0.0
@export var on_hit_status_stacks: int = 1
## 本次施加状态的持续时间覆盖。INF 表示使用 StatusData 资源里的默认 duration。
@export var on_hit_status_duration_override: float = INF

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var hit_area: Area2D = get_node_or_null("Area2D") as Area2D

var source: Entity
var source_ability_id: StringName = &""
var source_ability_slot_index: int = -1
var current_dir: Vector2 = Vector2.ZERO
var current_distance: float = 0.0
var is_hit_finishing: bool = false
var runtime_homing_turn_speed: float = 0.0
var homing_controller: ProjectileHomingController = ProjectileHomingController.new()


func _ready() -> void:
	if animated_sprite != null and not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	if hit_area != null and not hit_area.area_entered.is_connected(_on_area_2d_area_entered):
		hit_area.area_entered.connect(_on_area_2d_area_entered)


func _exit_tree() -> void:
	if animated_sprite != null and animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_animation_finished)
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
	_configure_homing()

	if not EventBus.game_paused.is_connected(_handle_game_pause):
		EventBus.game_paused.connect(_handle_game_pause)
	if not EventBus.scene_changed.is_connected(_handle_scene_changed):
		EventBus.scene_changed.connect(_handle_scene_changed)

	current_dir = _get_projectile_direction(context)
	if current_dir != Vector2.ZERO:
		global_rotation = current_dir.angle()

	if animated_sprite == null:
		return

	# start 负责起手表现；没有 start 动画时直接进入持续飞行动画。
	_play_animation(start_animation if _has_animation(start_animation) else repeat_animation)


func _process(delta: float) -> void:
	if _should_free_for_source_state():
		queue_free()
		return
	if is_hit_finishing:
		return

	_update_homing_direction(delta)
	var movement: Vector2 = current_dir * speed * delta
	current_distance += movement.length()
	if not _move_or_finish_on_world_hit(movement):
		return

	if rotate_while_flying:
		global_rotation += rotate_speed * delta

	# 没击中目标但已经飞到最远距离时，直接释放，不播放 hit 动画。
	if current_distance >= max_distance:
		queue_free()


func _get_projectile_direction(context: AbilityContext) -> Vector2:
	if context.locked_direction != Vector2.ZERO:
		return context.locked_direction.normalized()
	if context.targets.size() > 0:
		var target_pos := context.get_target_positon(0)
		var target_direction := global_position.direction_to(target_pos)
		if target_direction != Vector2.ZERO:
			return target_direction.normalized()
	if source != null:
		var facing := source.get_facing_direction()
		if facing != Vector2.ZERO:
			return facing.normalized()
	return Vector2.RIGHT


## 读取来源实体由装备、状态等系统提供的投射物追踪属性。
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
		target_group,
		current_dir,
		runtime_homing_turn_speed,
		homing_acquire_radius,
		homing_retarget_interval,
		delta
	)
	if not rotate_while_flying and current_dir != Vector2.ZERO:
		global_rotation = current_dir.angle()


func _on_area_2d_area_entered(area: Area2D) -> void:
	if is_hit_finishing:
		return

	var target := _get_entity_from_area(area)
	if target == null:
		return

	var valid_source := _get_valid_source()
	if source != null and valid_source == null:
		queue_free()
		return

	_damage_target(target, valid_source)
	_try_apply_on_hit_status(target, valid_source)

	if hit_sound != null:
		AudioController.play(hit_sound, global_position)

	if is_penetrate:
		return

	_finish_by_hit()


func _damage_target(target: Entity, valid_source: Entity) -> void:
	var damage_data := DamageData.create(
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


func _try_apply_on_hit_status(target: Entity, valid_source: Entity) -> void:
	if on_hit_status == null or on_hit_status_chance <= 0.0:
		return

	var status_controller := target.get_status_controller()
	if status_controller == null:
		return

	var final_chance = clamp(on_hit_status_chance + _get_luck_status_bonus(valid_source), 0.0, 1.0)
	if randf() > final_chance:
		return

	var source_key := "%s_%s" % [source_ability_id, on_hit_status.id]
	status_controller.add_status(on_hit_status, valid_source, source_key, on_hit_status_stacks, on_hit_status_duration_override)


func _get_luck_status_bonus(valid_source: Entity) -> float:
	if valid_source == null or valid_source.stats_controller == null:
		return 0.0
	return valid_source.stats_controller.get_stat(&"luck") * luck_chance_bonus_per_point


func _finish_by_hit() -> void:
	is_hit_finishing = true
	_disable_hit_area()
	if _has_animation(hit_animation):
		_play_animation(hit_animation)
	else:
		queue_free()


# 动画投射物撞到 World 层时不造成额外伤害，只播放命中收尾动画并释放。
func _move_or_finish_on_world_hit(movement: Vector2) -> bool:
	if movement == Vector2.ZERO:
		return true

	var collision: Dictionary = _get_world_collision(movement)
	if not collision.is_empty():
		var hit_position: Variant = collision.get("position")
		if hit_position is Vector2:
			global_position = hit_position
		_finish_by_hit()
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


func _on_animation_finished() -> void:
	if animated_sprite == null:
		return

	if animated_sprite.animation == start_animation:
		_play_animation(repeat_animation)
		return

	if animated_sprite.animation == repeat_animation:
		# 有些 SpriteFrames 没有勾 loop，这里兜底重播，让持续飞行动画保持循环。
		_play_animation(repeat_animation)
		return

	if animated_sprite.animation == hit_animation:
		queue_free()


func _get_entity_from_area(area: Area2D) -> Entity:
	if area == null:
		return null

	var parent := area.get_parent()
	if not (parent is Entity):
		return null

	var entity := parent as Entity
	if not entity.matches_target_group(target_group):
		return null
	if source != null and is_instance_valid(source) and entity == source:
		return null
	if entity.has_method("can_be_targeted") and not entity.can_be_targeted():
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
	# area_entered 信号仍在物理回调中时，不能立刻切 monitoring，否则 Godot 会报 locked。
	hit_area.set_deferred("monitoring", false)
	hit_area.set_deferred("monitorable", false)
	


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite == null:
		return
	if not _has_animation(animation_name):
		return
	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0
	animated_sprite.play(animation_name)


func _has_animation(animation_name: StringName) -> bool:
	return animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name)


func _handle_game_pause(pause: bool) -> void:
	if animated_sprite != null:
		animated_sprite.speed_scale = 0.0 if pause else 1.0


func _handle_scene_changed(scene: String) -> void:
	if scene == "home":
		queue_free()


func _apply_projectile_range_bonus() -> void:
	if source == null or source.stats_controller == null:
		return

	var bonus_rate = max(source.stats_controller.get_stat(&"projectile_range_bonus_rate"), 0.0)
	if bonus_rate <= 0.0:
		return
	if not tags.has("projectile"):
		return

	# 动画投射物同样吃“投射物增程”，但抛射类 manifest 不会走到这里。
	max_distance *= 1.0 + bonus_rate
