class_name AnimatedAbilityManifest
extends AbilityManifest

@export var animation_name: StringName = &"default"
@export var free_when_finished: bool = true

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
	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0
	animated_sprite.play(animation_name)


func _on_animation_finished() -> void:
	if free_when_finished:
		queue_free()
