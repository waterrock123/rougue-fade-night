## 敌人变体：复用已有场景的动画/碰撞，替换技能配置，并提供可锁定的二维朝向。
## 不重写寻路、死亡、属性、硬直与韧性逻辑，这些仍由 Enemy 管理。
class_name ConfiguredEnemy
extends Enemy

@export var combat_abilities: Array[PackedScene] = []
@export var initial_ability_delay: float = 0.6
## 弧度/秒；背冰兽可调低，让绕背有意义。零表示立即转向。
@export var facing_turn_speed: float = 8.0
@export var guarded_status_id: StringName = &""
## 远程怪的最小舒适距离；零表示不后撤，施法和控制期间不会后撤。
@export var retreat_distance: float = 0.0

var combat_direction: Vector2 = Vector2.RIGHT
var facing_lock_remaining: float = 0.0


func _ready() -> void:
	_prepare_visuals()
	_replace_combat_abilities()
	super._ready()
	hit_reaction_controller.hit_stun_started.connect(_on_action_interrupted)


func _process(delta: float) -> void:
	facing_lock_remaining = maxf(facing_lock_remaining - delta, 0.0)
	if animated_sprite != null:
		var guarding: bool = status_controller != null and status_controller.has_status(guarded_status_id)
		animated_sprite.self_modulate = Color(0.6, 0.9, 1.0) if guarding else Color.WHITE
	if not _try_retreat(delta):
		super._process(delta)


func _replace_combat_abilities() -> void:
	if combat_abilities.is_empty():
		return
	for child: Node in ability_controller.get_children():
		if child is Ability:
			ability_controller.remove_child(child)
			child.queue_free()
	ability_controller.abilities.clear()
	ability_controller.cooldowns.clear()
	for index: int in range(combat_abilities.size()):
		var ability: Ability = ability_controller.register_runtime_ability(combat_abilities[index], "variant_%d" % index)
		if ability != null:
			ability.id = StringName(combat_abilities[index].resource_path.get_file().get_basename())
			ability_controller.cooldowns[ability] = initial_ability_delay


func _prepare_visuals() -> void:
	# 避免占位素材里的循环死亡/攻击动画锁住角色，且不修改原怪物的共享 SpriteFrames。
	var frames: SpriteFrames = animated_sprite.sprite_frames.duplicate(true) as SpriteFrames
	animated_sprite.sprite_frames = frames
	for animation: StringName in [&"die", &"attack", &"slash"]:
		if frames.has_animation(animation):
			frames.set_animation_loop(animation, false)
	if not frames.has_animation(&"walk") and frames.has_animation(&"move"):
		frames.add_animation(&"walk")
		frames.set_animation_speed(&"walk", frames.get_animation_speed(&"move"))
		for index: int in range(frames.get_frame_count(&"move")):
			frames.add_frame(&"walk", frames.get_frame_texture(&"move", index), frames.get_frame_duration(&"move", index))
	animated_sprite.play(&"idle")


func _face_target(direction: Vector2) -> void:
	if direction == Vector2.ZERO or facing_lock_remaining > 0.0:
		return
	var target_angle: float = direction.angle()
	var angle: float = target_angle if facing_turn_speed <= 0.0 else rotate_toward(combat_direction.angle(), target_angle, facing_turn_speed * get_process_delta_time())
	combat_direction = Vector2.RIGHT.rotated(angle)
	super._face_target(combat_direction)


func get_facing_direction() -> Vector2:
	return combat_direction


func lock_combat_facing(direction: Vector2, duration: float) -> void:
	if direction != Vector2.ZERO:
		combat_direction = direction.normalized()
		super._face_target(combat_direction)
	facing_lock_remaining = maxf(facing_lock_remaining, duration)


func _on_action_interrupted(_duration: float) -> void:
	# 让已排队的延迟伤害和冲刺失效；破韧使用同一个硬直信号，也会中断防御。
	cancel_active_actions()
	if status_controller != null and guarded_status_id != &"":
		status_controller.remove_status(guarded_status_id)
	facing_lock_remaining = 0.0
	current_anim = null


func _try_retreat(delta: float) -> bool:
	if retreat_distance <= 0.0 or is_dead or not can_act() or is_movement_locked():
		return false
	current_target = _find_nearest_player_side_target()
	if not is_instance_valid(current_target) or global_position.distance_to(current_target.global_position) >= retreat_distance:
		return false
	var direction: Vector2 = current_target.global_position.direction_to(global_position)
	var destination: Vector2 = global_position + direction * retreat_distance
	if pathfinding != null:
		direction = pathfinding.find_path(destination).normalized()
	move_with_physics(direction * speed * delta)
	_face_target(direction)
	_update_motion_cache(delta)
	_handle_animations()
	return true
