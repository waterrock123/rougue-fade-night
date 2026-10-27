class_name BigDogEnemy
extends Enemy

## 特殊悬赏“大狗”复用友方猎犬的完整动画资源，避免复制两份逐帧动画后难以维护。
const DOG_VISUAL_SCENE: PackedScene = preload("res://entity/summon_pet/dog_summon_pet.tscn")


func _ready() -> void:
	_apply_dog_visuals()
	super._ready()


func _apply_dog_visuals() -> void:
	if animated_sprite == null or DOG_VISUAL_SCENE == null:
		return

	var visual_source: Node = DOG_VISUAL_SCENE.instantiate()
	if visual_source == null:
		return

	var source_sprite := visual_source.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if source_sprite != null:
		animated_sprite.sprite_frames = source_sprite.sprite_frames
		if source_sprite.material != null:
			animated_sprite.material = source_sprite.material.duplicate()
		animated_sprite.play(&"idle")

	visual_source.free()

