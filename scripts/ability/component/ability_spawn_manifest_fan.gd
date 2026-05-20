## 扇形多 Manifest 生成组件。
## 适合冰锥、散弹、扇形箭雨这类“同一时间生成多个投射物，并按扇形方向散开”的技能。
@tool
class_name AbilitySpawnManifestFan
extends AbilityComponent

enum DirectionMode {
	LOCKED_OR_FACING,
	CURSOR,
}

@export var manifest_scene: PackedScene
@export_range(1, 32, 1) var manifest_count: int = 5
@export_range(0.0, 360.0, 1.0) var spread_angle_degrees: float = 90.0
@export var target_distance: float = 300.0
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var set_as_child: bool = false
@export var rotate_to_direction: bool = true
@export var scale_multiplier: float = 1.0
@export var direction_mode: DirectionMode = DirectionMode.CURSOR


func _activate(context: AbilityContext) -> void:
	if manifest_scene == null or context == null or context.caster == null or not context.is_caster_action_valid():
		return

	var caster := context.caster
	var base_direction := _get_base_direction(context)
	var directions := _build_fan_directions(base_direction)

	for direction in directions:
		if not context.is_caster_action_valid():
			return
		_spawn_one_manifest(context, caster, direction)


func _spawn_one_manifest(context: AbilityContext, caster: Entity, direction: Vector2) -> void:
	var ability_manifest := manifest_scene.instantiate() as AbilityManifest
	if ability_manifest == null:
		return

	var final_offset := spawn_offset.rotated(direction.angle())
	var spawn_position := caster.global_position + final_offset

	if set_as_child:
		caster.add_child(ability_manifest)
	else:
		var root := get_tree().current_scene
		if root == null:
			root = get_tree().root
		root.add_child(ability_manifest)

	ability_manifest.global_position = spawn_position
	if rotate_to_direction and direction != Vector2.ZERO:
		ability_manifest.global_rotation = direction.angle()
	ability_manifest.scale *= scale_multiplier

	# 每个投射物使用独立上下文，避免多根冰锥共享同一个 target 数组导致方向互相覆盖。
	var child_context := AbilityContext.new(caster, context.ability)
	child_context.caster_action_version = context.caster_action_version
	child_context.locked_direction = direction
	child_context.targets = [spawn_position + direction * target_distance]

	ability_manifest.activate(child_context)


func _get_base_direction(context: AbilityContext) -> Vector2:
	if direction_mode == DirectionMode.CURSOR and context.caster.has_method("get_global_mouse_position"):
		var mouse_direction := context.caster.global_position.direction_to(context.caster.get_global_mouse_position())
		if mouse_direction != Vector2.ZERO:
			return mouse_direction.normalized()

	if context.locked_direction != Vector2.ZERO:
		return context.locked_direction.normalized()

	var facing := context.caster.get_facing_direction()
	return facing.normalized() if facing != Vector2.ZERO else Vector2.RIGHT


func _build_fan_directions(base_direction: Vector2) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	var safe_count: int = max(manifest_count, 1)
	var safe_base := base_direction.normalized() if base_direction != Vector2.ZERO else Vector2.RIGHT

	if safe_count == 1:
		directions.append(safe_base)
		return directions

	var half_angle := deg_to_rad(spread_angle_degrees * 0.5)
	for index in range(safe_count):
		var t := float(index) / float(safe_count - 1)
		var angle = lerp(-half_angle, half_angle, t)
		directions.append(safe_base.rotated(angle).normalized())

	return directions
