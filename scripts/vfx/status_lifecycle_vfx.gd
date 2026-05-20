## 状态生命周期特效。
## 适合冻结、燃烧、恢复光环这类有 start / active / end 三段动画的状态表现。
class_name StatusLifecycleVFX
extends Node2D

@export var start_animation: StringName = &"start"
@export var active_animation: StringName = &"active"
@export var end_animation: StringName = &"end"
@export var queue_free_after_end: bool = true

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

var is_finishing: bool = false


func _ready() -> void:
	if animated_sprite == null:
		return
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_animation(start_animation if _has_animation(start_animation) else active_animation)


func _exit_tree() -> void:
	if animated_sprite != null and animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_animation_finished)


# 外部系统在状态快结束或被移除时调用，让特效先播收尾动画再释放。
func finish_vfx() -> void:
	if is_finishing:
		return
	is_finishing = true

	if animated_sprite == null or not _has_animation(end_animation):
		queue_free()
		return

	_play_animation(end_animation)


func _on_animation_finished() -> void:
	if animated_sprite == null:
		return

	if animated_sprite.animation == start_animation:
		_play_animation(active_animation)
		return

	if animated_sprite.animation == active_animation:
		# active 不循环时停在最后一帧，表现为“冻结持续存在”。
		_hold_last_frame(active_animation)
		return

	if animated_sprite.animation == end_animation and queue_free_after_end:
		queue_free()


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite == null or not _has_animation(animation_name):
		return

	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0
	animated_sprite.play(animation_name)


func _hold_last_frame(animation_name: StringName) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	var frame_count := animated_sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 0:
		return

	animated_sprite.stop()
	animated_sprite.animation = animation_name
	animated_sprite.frame = frame_count - 1
	animated_sprite.frame_progress = 1.0


func _has_animation(animation_name: StringName) -> bool:
	return animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name)
