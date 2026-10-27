class_name AnimatedAbilityManifest
extends AbilityManifest

@export var animation_name: StringName = &"default"
@export var free_when_finished: bool = true
## 仅适配视觉播放时长。零表示沿用原始帧时长，不改变已有Manifest行为或伤害时间轴。
@export var playback_seconds: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if animated_sprite == null:
		return

	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)


func _activate(_context: AbilityContext):
	if animated_sprite == null:
		return

	# 这个 Manifest 只负责视觉表现：生成后播放动画，动画结束自动清理。
	if playback_seconds > 0.0:
		animated_sprite.speed_scale = _animation_seconds() / playback_seconds
	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0
	animated_sprite.play(animation_name)


func _animation_seconds() -> float:
	var frames: SpriteFrames = animated_sprite.sprite_frames
	if frames == null or not frames.has_animation(animation_name):
		return 0.0
	var units: float = 0.0
	for index: int in range(frames.get_frame_count(animation_name)):
		units += frames.get_frame_duration(animation_name, index)
	return units / maxf(frames.get_animation_speed(animation_name), 0.001)


func _on_animation_finished() -> void:
	if free_when_finished:
		queue_free()
