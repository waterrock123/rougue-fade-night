class_name EnemyPoiseFeedbackController
extends Node

var body_glow_enabled: bool = true
var body_glow_color: Color = Color(1.0, 0.95, 0.72, 1.0)
var body_glow_size: float = 1.0
var body_glow_alpha: float = 0.75
var body_glow_pulse_strength: float = 0.25
var body_glow_pulse_speed: float = 3.0
var break_flash_color: Color = Color.WHITE
var break_flash_in_duration: float = 0.05
var break_flash_out_duration: float = 0.2
var break_sound: AudiioConfig
var camera_shake_strength: float = 1.2
var camera_shake_duration: float = 0.16

var target: Entity
var poise_controller: EnemyPoiseController
var visual_material: ShaderMaterial
var break_flash_tween: Tween


func _exit_tree() -> void:
	_unbind_target()


## 反馈组件只监听韧性事件，不参与削韧计算和状态切换。
func bind_target(new_target: Entity, new_poise_controller: EnemyPoiseController) -> void:
	_unbind_target()
	target = new_target
	poise_controller = new_poise_controller
	visual_material = _resolve_compatible_material()
	_configure_material()

	if poise_controller != null:
		if not poise_controller.poise_state_changed.is_connected(_on_poise_state_changed):
			poise_controller.poise_state_changed.connect(_on_poise_state_changed)
		if not poise_controller.poise_broken.is_connected(_on_poise_broken):
			poise_controller.poise_broken.connect(_on_poise_broken)
	if target != null and not target.died.is_connected(_on_target_died):
		target.died.connect(_on_target_died)


func _on_poise_state_changed(is_active: bool) -> void:
	_set_body_glow_enabled(is_active and body_glow_enabled)


func _on_poise_broken(_duration: float) -> void:
	_set_body_glow_enabled(false)
	_play_break_flash()
	_play_break_sound()
	_request_camera_shake()


func _configure_material() -> void:
	if visual_material == null:
		return
	visual_material.set_shader_parameter("poise_glow_enabled", false)
	visual_material.set_shader_parameter("poise_glow_color", body_glow_color)
	visual_material.set_shader_parameter("poise_glow_size", maxf(body_glow_size, 0.0))
	visual_material.set_shader_parameter("poise_glow_alpha", clampf(body_glow_alpha, 0.0, 1.0))
	visual_material.set_shader_parameter("poise_glow_pulse_strength", clampf(body_glow_pulse_strength, 0.0, 1.0))
	visual_material.set_shader_parameter("poise_glow_pulse_speed", maxf(body_glow_pulse_speed, 0.0))
	visual_material.set_shader_parameter("poise_break_flash_color", break_flash_color)
	visual_material.set_shader_parameter("poise_break_flash_strength", 0.0)


func _set_body_glow_enabled(enabled: bool) -> void:
	if visual_material != null:
		visual_material.set_shader_parameter("poise_glow_enabled", enabled)


func _play_break_flash() -> void:
	if visual_material == null:
		return
	if break_flash_tween != null and break_flash_tween.is_valid():
		break_flash_tween.kill()

	visual_material.set_shader_parameter("poise_break_flash_strength", 0.0)
	break_flash_tween = create_tween()
	break_flash_tween.tween_property(
		visual_material,
		"shader_parameter/poise_break_flash_strength",
		1.0,
		maxf(break_flash_in_duration, 0.0)
	)
	break_flash_tween.tween_property(
		visual_material,
		"shader_parameter/poise_break_flash_strength",
		0.0,
		maxf(break_flash_out_duration, 0.0)
	)


func _play_break_sound() -> void:
	if break_sound == null or target == null or not is_instance_valid(target):
		return
	AudioController.play(break_sound, target.global_position)


func _request_camera_shake() -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var camera: Camera2D = target.get_viewport().get_camera_2d()
	if camera != null and camera.has_method("request_shake"):
		camera.request_shake(camera_shake_strength, camera_shake_duration)


func _resolve_compatible_material() -> ShaderMaterial:
	if target == null or target.animated_sprite == null:
		return null
	var material := target.animated_sprite.material as ShaderMaterial
	if material == null or material.shader == null:
		return null

	# 自定义敌人材质若没有这些参数则保持原样，避免运行时强行覆盖其 Shader。
	var shader_code: String = material.shader.code
	if not shader_code.contains("poise_glow_enabled"):
		return null
	return material


func _on_target_died(_entity: Entity) -> void:
	_reset_material()


func _reset_material() -> void:
	if break_flash_tween != null and break_flash_tween.is_valid():
		break_flash_tween.kill()
	break_flash_tween = null
	if visual_material != null:
		visual_material.set_shader_parameter("poise_glow_enabled", false)
		visual_material.set_shader_parameter("poise_break_flash_strength", 0.0)


func _unbind_target() -> void:
	_reset_material()
	if poise_controller != null and is_instance_valid(poise_controller):
		if poise_controller.poise_state_changed.is_connected(_on_poise_state_changed):
			poise_controller.poise_state_changed.disconnect(_on_poise_state_changed)
		if poise_controller.poise_broken.is_connected(_on_poise_broken):
			poise_controller.poise_broken.disconnect(_on_poise_broken)
	if target != null and is_instance_valid(target) and target.died.is_connected(_on_target_died):
		target.died.disconnect(_on_target_died)
	target = null
	poise_controller = null
	visual_material = null
