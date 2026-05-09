class_name Entity
extends Node2D

@export var max_health: float = 50.0
@export var max_energy: float = 50.0
@export var damage_text_color: Color = Color.WHITE
@export var crit_damage_text_color: Color = Color(1.0, 0.85, 0.2, 1.0)

@export var energy_region_freq = 0.5
@export var energy_region_tick_value = 3

var current_anim: AnimationWrapper
var current_health: float
var current_energy: float
var is_dead: bool = false
var turning_cooldown = 0.0
var movement_lock_timer = 0.0
var energy_timer = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var stats_controller: StatsController = get_node_or_null("StatsController") as StatsController
@onready var status_controller: StatusController = get_node_or_null("StatusController") as StatusController


func _ready() -> void:
	if stats_controller != null:
		current_health = stats_controller.current_health
		current_energy = stats_controller.current_energy
	else:
		current_health = max_health
		current_energy = max_energy

	animated_sprite.material = animated_sprite.material.duplicate()
	animated_sprite.animation_finished.connect(on_animation_finished)


func _exit_tree() -> void:
	animated_sprite.animation_finished.disconnect(on_animation_finished)


func apply_damage(damage_event):
	if is_dead:
		return null

	var damage_data := _normalize_damage_event(damage_event)
	if damage_data == null:
		return null

	damage_data.target = self

	if damage_data.source != null and damage_data.source.stats_controller != null:
		damage_data = damage_data.source.stats_controller.process_outgoing_damage(damage_data)

	if stats_controller != null:
		damage_data = stats_controller.process_incoming_damage(damage_data)

	var final_damage :float = max(damage_data.final_damage, 0.0)
	current_health -= final_damage
	current_health = max(0, current_health)

	if stats_controller != null:
		stats_controller.current_health = current_health
		stats_controller.sync_runtime_resources()

	if final_damage > 0.0:
		_show_damage_taken_effect()
		show_damage_popup(damage_data)

	_handle_damage_callback(damage_data)
	if current_health == 0:
		is_dead = true
		play_animation(AnimationWrapper.new("die", true))

	return damage_data


func spend_energy(energy: float):
	pass


func apply_runtime_stats(_final_stats: Dictionary) -> void:
	pass


func get_status_controller() -> StatusController:
	return status_controller


func lock_movement(duration: float) -> void:
	movement_lock_timer = max(movement_lock_timer, duration)


func is_movement_locked() -> bool:
	return movement_lock_timer > 0.0


func play_animation(anim: AnimationWrapper):
	if animated_sprite.animation == anim.name:
		return

	if current_anim != null and current_anim.is_high_priority and not anim.is_high_priority:
		return

	current_anim = anim
	animated_sprite.play(anim.name)


func turn_to_position(pos: Vector2):
	if position.x > pos.x and not animated_sprite.flip_h:
		animated_sprite.flip_h = true
	elif position.x < pos.x and animated_sprite.flip_h:
		animated_sprite.flip_h = false


func get_facing_direction() -> Vector2:
	if animated_sprite.flip_h:
		return Vector2.LEFT
	return Vector2.RIGHT


func on_animation_finished():
	current_anim = null


func get_height() -> float:
	var anim = animated_sprite.animation
	var frame_tex = animated_sprite.sprite_frames.get_frame_texture(anim, 0)
	var height = frame_tex.get_height()
	return height * self.scale.y


func get_current_texture() -> Texture2D:
	return animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)


func show_damage_popup(damage_data: DamageData):
	var height = get_height()
	var spawn_position = Vector2(position.x, position.y - (height * 0.5))
	var text_color := damage_text_color
	if damage_data != null and damage_data.is_crit:
		text_color = crit_damage_text_color

	FloatText.show_damage_text(str(int(damage_data.get_display_damage())), spawn_position, text_color)


func _handle_damage_callback(_damage_data: DamageData):
	pass


func _show_damage_taken_effect():
	if animated_sprite.material != null:
		for _i in 2:
			animated_sprite.material.set_shader_parameter("is_hurt", true)
			await get_tree().create_timer(0.05).timeout
			animated_sprite.material.set_shader_parameter("is_hurt", false)
			await get_tree().create_timer(0.05).timeout


func _normalize_damage_event(damage_event) -> DamageData:
	if damage_event is DamageData:
		var damage_data := damage_event as DamageData
		if damage_data.final_damage <= 0.0:
			damage_data.final_damage = damage_data.base_damage
		return damage_data

	if damage_event is float or damage_event is int:
		return DamageData.create(float(damage_event))

	return null
