## 范围技能的独立表现层：只读取父级半径与脉冲计数，不造成伤害、不修改计时。
## 同时支持静态符文与一次性帧动画，按美术的实际可见半径匹配判定范围。
class_name RadialSkillVisual
extends Node2D

@export var art_radius: float = 16.0
@export var animation_name: StringName = &"frost_burst"
@export var playback_seconds: float = 0.28
@export_range(0.0, 1.0) var idle_opacity: float = 0.4
@export_range(0.0, 1.0) var pulse_opacity: float = 0.35
@export var rotation_speed: float = 0.08
var area: TimedRadialAreaManifest
var sprite: Node2D
var seen_pulses: int = 0
var pulse_remaining: float = 0.0


func _ready() -> void:
	area = get_parent() as TimedRadialAreaManifest
	sprite = get_node_or_null("Sprite2D") as Node2D
	visible = false
	if area == null or sprite == null:
		set_process(false)
		return
	_fit_radius()
	if sprite is AnimatedSprite2D:
		_configure_animation(sprite as AnimatedSprite2D)


func _fit_radius() -> void:
	var factor: float = maxf(area.radius, 0.0) / maxf(art_radius, 1.0)
	sprite.scale = Vector2.ONE * factor


func _configure_animation(animated: AnimatedSprite2D) -> void:
	var frames: SpriteFrames = animated.sprite_frames
	if frames == null or not frames.has_animation(animation_name):
		return
	var units: float = 0.0
	for index: int in range(frames.get_frame_count(animation_name)):
		units += frames.get_frame_duration(animation_name, index)
	var duration: float = units / maxf(frames.get_animation_speed(animation_name), 0.001)
	animated.speed_scale = duration / maxf(playback_seconds, 0.01)


func _process(delta: float) -> void:
	if not is_instance_valid(area) or not is_instance_valid(sprite) or not area.active:
		visible = false
		return
	visible = true
	if area.emitted != seen_pulses:
		seen_pulses = area.emitted
		pulse_remaining = 1.0
		if sprite is AnimatedSprite2D:
			(sprite as AnimatedSprite2D).stop()
			(sprite as AnimatedSprite2D).play(animation_name)
	else:
		pulse_remaining = maxf(pulse_remaining - maxf(delta, 0.0) * 4.0, 0.0)
	_update_opacity()
	if not sprite is AnimatedSprite2D:
		rotation += rotation_speed * delta


func _update_opacity() -> void:
	# 与父级已有的0.3秒视觉尾声一致；这里只淡出贴图，不延长技能伤害与状态。
	var last_pulse: float = maxf(area.initial_delay, 0.0) + (maxi(area.pulse_count, 1) - 1) * maxf(area.pulse_interval, 0.05)
	var fade: float = clampf((last_pulse + 0.3 - area.elapsed) / 0.2, 0.0, 1.0)
	var opacity: float = clampf(idle_opacity + pulse_remaining * pulse_opacity, 0.0, 1.0)
	sprite.modulate.a = opacity * fade
