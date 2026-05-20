## 生成技能实体组件。
## 实例化投射物、斩击、冲击波等 AbilityManifest 场景，并把当前 AbilityContext 传给它。
class_name AbilitySpawnManifest
extends AbilityComponent

@export var manifest_scene: PackedScene
@export var set_as_child: bool = false
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var scale_multiplier: float = 1.0

@export_group("Directional Spawn")
@export var use_directional_offset: bool = false
@export var forward_offset: float = 0.0
@export var side_offset: float = 0.0
@export var rotate_to_direction: bool = true


func _activate(context: AbilityContext) -> void:
	if manifest_scene == null or context == null or context.caster == null or not context.is_caster_action_valid():
		return

	var ability_manifest := manifest_scene.instantiate() as AbilityManifest
	if ability_manifest == null:
		return

	var caster := context.caster
	if ability_manifest is ProjectileManifest:
		ability_manifest.source = caster

	var direction := _get_spawn_direction(context)
	var final_offset := spawn_offset
	if use_directional_offset:
		final_offset += _get_directional_offset(direction)

	if set_as_child:
		caster.add_child(ability_manifest)
		if use_directional_offset:
			ability_manifest.global_position = caster.global_position + final_offset
		else:
			ability_manifest.position = spawn_offset
	else:
		var root := get_tree().current_scene
		if root == null:
			root = get_tree().root
		root.add_child(ability_manifest)
		ability_manifest.global_position = caster.global_position + final_offset

	if rotate_to_direction and direction != Vector2.ZERO:
		ability_manifest.global_rotation = direction.angle()

	ability_manifest.scale *= scale_multiplier
	if not context.is_caster_action_valid():
		ability_manifest.queue_free()
		return
	ability_manifest.activate(context)


# 优先使用预警组件锁定的方向，保证“红区在哪，Manifest 就生成在哪”。
func _get_spawn_direction(context: AbilityContext) -> Vector2:
	if context.locked_direction != Vector2.ZERO:
		return context.locked_direction.normalized()

	var facing := context.caster.get_facing_direction()
	return facing.normalized() if facing != Vector2.ZERO else Vector2.RIGHT


func _get_directional_offset(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.ZERO

	var right := Vector2(-direction.y, direction.x)
	return direction * forward_offset + right * side_offset
