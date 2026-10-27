extends Node2D

## 红眼的定位沿用场景中的 RedEyes 节点；只在节点内生成视觉元素，不修改敌人的动画。
const GLOW_SHADER: Shader = preload("res://shaders/big_dog_eye_glow.gdshader")

@export_group("红光")
@export var glow_color: Color = Color(1.0, 0.08, 0.045, 0.9)
@export_range(8.0, 32.0, 1.0) var glow_size: float = 18.0
@export_range(0.1, 8.0, 0.1) var pulse_speed: float = 2.2
@export_group("移动光迹")
@export_range(0.05, 0.8, 0.01) var trail_lifetime: float = 0.25
@export_range(1.0, 12.0, 0.5) var trail_width: float = 4.0
@export_range(0.5, 8.0, 0.5) var sample_spacing: float = 2.0
@export_range(0.0, 100.0, 1.0) var min_move_speed: float = 9.0

var parent_enemy: Enemy
var glow_rect: ColorRect
var trail_line: Line2D
var samples: Array[Dictionary] = []
var base_position: Vector2
var previous_world_position: Vector2
var last_motion_time: float = -100.0
var was_flipped: bool = false


func _ready() -> void:
	parent_enemy = get_parent() as Enemy
	base_position = position
	_create_glow()
	_create_trail()
	previous_world_position = global_position
	if parent_enemy != null and parent_enemy.animated_sprite != null:
		was_flipped = parent_enemy.animated_sprite.flip_h


func _process(delta: float) -> void:
	if parent_enemy == null or parent_enemy.is_dead or parent_enemy.animated_sprite == null:
		visible = false
		trail_line.clear_points()
		return

	# 狗左右翻转时，眼睛在角色中心的另一侧出现。
	var flipped: bool = parent_enemy.animated_sprite.flip_h
	position.x = -base_position.x if flipped else base_position.x
	var now: float = float(Time.get_ticks_msec()) * 0.001
	var world_position: Vector2 = global_position
	if flipped != was_flipped:
		samples.clear()
		trail_line.clear_points()
		previous_world_position = world_position
		was_flipped = flipped
	var moving: bool = delta > 0.0 and world_position.distance_to(previous_world_position) / delta >= min_move_speed
	if moving:
		last_motion_time = now
		if samples.is_empty() or (samples.back()["position"] as Vector2).distance_to(world_position) >= sample_spacing:
			samples.append({"position": world_position, "time": now})
	previous_world_position = world_position
	_update_trail(now, world_position, moving)


func _create_glow() -> void:
	glow_rect = ColorRect.new()
	glow_rect.name = "SoftEyeGlow"
	glow_rect.color = Color.WHITE
	glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_rect.position = Vector2.ONE * (-glow_size * 0.5)
	glow_rect.size = Vector2.ONE * glow_size
	var material := ShaderMaterial.new()
	material.shader = GLOW_SHADER
	material.set_shader_parameter("glow_color", glow_color)
	material.set_shader_parameter("pulse_speed", pulse_speed)
	glow_rect.material = material
	add_child(glow_rect)


func _create_trail() -> void:
	trail_line = Line2D.new()
	trail_line.name = "EyeLightTrail"
	trail_line.top_level = true
	trail_line.z_index = -1
	trail_line.width = trail_width
	trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	var fade := Gradient.new()
	fade.set_color(0, Color(glow_color.r, glow_color.g, glow_color.b, 0.0))
	fade.set_color(1, Color(glow_color.r, glow_color.g, glow_color.b, 0.65))
	trail_line.gradient = fade
	add_child(trail_line)
	trail_line.global_position = Vector2.ZERO


func _update_trail(now: float, world_position: Vector2, moving: bool) -> void:
	while not samples.is_empty() and now - float(samples[0]["time"]) > trail_lifetime:
		samples.remove_at(0)
	trail_line.clear_points()
	if samples.is_empty():
		return
	for sample: Dictionary in samples:
		trail_line.add_point(sample["position"] as Vector2)
	if moving and trail_line.get_point_count() > 0:
		trail_line.add_point(world_position)
	# 停下后让整条光迹渐隐，而不是突然切断。
	trail_line.modulate.a = clamp((trail_lifetime - (now - last_motion_time)) / trail_lifetime, 0.0, 1.0)
