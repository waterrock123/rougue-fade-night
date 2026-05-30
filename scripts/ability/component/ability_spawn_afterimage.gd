## 残影生成组件。
## 复制施法者 AnimatedSprite2D 的当前帧，生成一个独立残影，并用 shader 做淡出/溶解。
## 适合瞬身、冲刺、闪现、影分身等需要“原地留影”的技能。
class_name AbilitySpawnAfterimage
extends AbilityComponent

const AFTERIMAGE_SHADER := preload("res://shaders/afterimage_dissolve.gdshader")

@export var animated_sprite_path: NodePath = ^"AnimatedSprite2D"
@export var lifetime: float = 0.32
@export var start_alpha: float = 0.72
@export var end_alpha: float = 0.0
@export var tint_color: Color = Color(0.48, 0.03, 0.08, 1.0)
@export var edge_color: Color = Color(1.0, 0.14, 0.08, 1.0)
@export var start_scale_multiplier: float = 1.0
@export var end_scale_multiplier: float = 1.08
@export var z_index_offset: int = -1


func _activate(context: AbilityContext) -> void:
	if context == null or context.caster == null or not context.is_caster_action_valid():
		return

	var animated_sprite := _get_animated_sprite(context.caster)
	if animated_sprite == null:
		return

	var frame_texture := _get_current_frame_texture(animated_sprite)
	if frame_texture == null:
		return

	var afterimage := _create_afterimage_sprite(context.caster, animated_sprite, frame_texture)
	_add_afterimage_to_scene(afterimage)
	_play_afterimage_tween(afterimage)


func _get_animated_sprite(caster: Entity) -> AnimatedSprite2D:
	return caster.get_node_or_null(animated_sprite_path) as AnimatedSprite2D


func _get_current_frame_texture(animated_sprite: AnimatedSprite2D) -> Texture2D:
	if animated_sprite.sprite_frames == null:
		return null
	if not animated_sprite.sprite_frames.has_animation(animated_sprite.animation):
		return null
	return animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)


func _create_afterimage_sprite(caster: Entity, animated_sprite: AnimatedSprite2D, frame_texture: Texture2D) -> Sprite2D:
	var afterimage := Sprite2D.new()
	afterimage.name = "AbilityAfterimage"
	afterimage.texture = frame_texture
	afterimage.centered = animated_sprite.centered
	afterimage.offset = animated_sprite.offset
	afterimage.flip_h = animated_sprite.flip_h
	afterimage.flip_v = animated_sprite.flip_v
	afterimage.global_transform = animated_sprite.global_transform
	afterimage.scale *= start_scale_multiplier
	afterimage.z_index = caster.z_index + z_index_offset
	afterimage.material = _create_afterimage_material()
	return afterimage


func _create_afterimage_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = AFTERIMAGE_SHADER
	material.set_shader_parameter("tint_color", tint_color)
	material.set_shader_parameter("edge_color", edge_color)
	material.set_shader_parameter("dissolve_amount", 0.0)
	material.set_shader_parameter("alpha_multiplier", start_alpha)
	return material


func _add_afterimage_to_scene(afterimage: Sprite2D) -> void:
	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	root.add_child(afterimage)


func _play_afterimage_tween(afterimage: Sprite2D) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(afterimage, "scale", afterimage.scale * end_scale_multiplier, lifetime)
	tween.tween_property(afterimage.material, "shader_parameter/dissolve_amount", 1.0, lifetime)
	tween.tween_property(afterimage.material, "shader_parameter/alpha_multiplier", end_alpha, lifetime)
	tween.chain().tween_callback(afterimage.queue_free)
