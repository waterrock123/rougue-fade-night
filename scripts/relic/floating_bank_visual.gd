class_name FloatingBankVisual
extends Sprite2D

var owner_entity: Entity
var target_offset: Vector2 = Vector2.ZERO
var follow_strength: float = 18.0
var damping: float = 10.0
var sway_amplitude: float = 4.0
var sway_speed: float = 2.0
var rotation_sway: float = 0.08
var base_rotation: float = 0.0
var time_offset: float = 0.0

var _velocity: Vector2 = Vector2.ZERO
var _life_time: float = 0.0


func setup(
	new_owner: Entity,
	new_texture: Texture2D,
	new_scale: Vector2,
	new_target_offset: Vector2,
	new_base_rotation: float,
	new_time_offset: float,
	new_z_index: int,
	new_follow_strength: float,
	new_damping: float,
	new_sway_amplitude: float,
	new_sway_speed: float,
	new_rotation_sway: float
) -> void:
	owner_entity = new_owner
	texture = new_texture
	scale = new_scale
	target_offset = new_target_offset
	base_rotation = new_base_rotation
	time_offset = new_time_offset
	z_index = new_z_index
	follow_strength = new_follow_strength
	damping = new_damping
	sway_amplitude = new_sway_amplitude
	sway_speed = new_sway_speed
	rotation_sway = new_rotation_sway

	if owner_entity != null and is_instance_valid(owner_entity):
		global_position = owner_entity.global_position + target_offset
	global_rotation = base_rotation


func _process(delta: float) -> void:
	if owner_entity == null or not is_instance_valid(owner_entity) or owner_entity.is_dead:
		queue_free()
		return

	_life_time += delta

	# 让悬浮投斧先追向目标位置，再用速度阻尼慢慢停住，视觉上会有一点“空气感”。
	var sway_time: float = _life_time * sway_speed + time_offset
	var sway_offset: Vector2 = Vector2(sin(sway_time * 0.7), cos(sway_time)) * sway_amplitude
	var target_position: Vector2 = owner_entity.global_position + target_offset + sway_offset
	var acceleration: Vector2 = (target_position - global_position) * follow_strength
	_velocity += acceleration * delta
	_velocity = _velocity.lerp(Vector2.ZERO, clamp(damping * delta, 0.0, 1.0))
	global_position += _velocity * delta

	# 轻微摆动让叠在一起的投斧不会像静态图标一样僵住。
	var target_rotation: float = base_rotation + sin(sway_time) * rotation_sway
	global_rotation = lerp_angle(global_rotation, target_rotation, clamp(delta * 8.0, 0.0, 1.0))
