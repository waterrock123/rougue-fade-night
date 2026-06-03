## 径向生成多个 Manifest 的技能组件。
## 适合“朝四面八方散射多个投射物，然后投射物自己寻敌”的技能。
@tool
class_name AbilitySpawnManifestRadial
extends AbilityComponent

@export var manifest_scene: PackedScene
@export_range(1, 48, 1) var manifest_count: int = 8
@export var target_distance: float = 260.0
@export var spawn_radius: float = 8.0
@export var start_angle_degrees: float = 0.0
@export var randomize_start_angle: bool = true
@export_range(0.0, 45.0, 0.5) var angle_jitter_degrees: float = 6.0
@export var set_as_child: bool = false
@export var rotate_to_direction: bool = true
@export var scale_multiplier: float = 1.0


func _activate(context: AbilityContext) -> void:
	if manifest_scene == null or context == null or context.caster == null or not context.is_caster_action_valid():
		return

	var caster: Entity = context.caster
	var directions: Array[Vector2] = _build_radial_directions()
	for direction in directions:
		if not context.is_caster_action_valid():
			return
		_spawn_one_manifest(context, caster, direction)


func _spawn_one_manifest(context: AbilityContext, caster: Entity, direction: Vector2) -> void:
	var ability_manifest: AbilityManifest = manifest_scene.instantiate() as AbilityManifest
	if ability_manifest == null:
		return

	var spawn_position: Vector2 = caster.global_position + direction * spawn_radius
	if set_as_child:
		caster.add_child(ability_manifest)
	else:
		var root: Node = get_tree().current_scene
		if root == null:
			root = get_tree().root
		root.add_child(ability_manifest)

	ability_manifest.global_position = spawn_position
	if rotate_to_direction and direction != Vector2.ZERO:
		ability_manifest.global_rotation = direction.angle()
	ability_manifest.scale *= scale_multiplier

	var child_context: AbilityContext = AbilityContext.new(caster, context.ability)
	child_context.caster_action_version = context.caster_action_version
	child_context.locked_direction = direction
	child_context.targets = [spawn_position + direction * target_distance]
	ability_manifest.activate(child_context)


func _build_radial_directions() -> Array[Vector2]:
	var directions: Array[Vector2] = []
	var safe_count: int = max(manifest_count, 1)
	var start_angle: float = deg_to_rad(start_angle_degrees)
	if randomize_start_angle:
		start_angle += randf() * TAU

	for index in range(safe_count):
		var angle: float = start_angle + TAU * float(index) / float(safe_count)
		if angle_jitter_degrees > 0.0:
			angle += deg_to_rad(randf_range(-angle_jitter_degrees, angle_jitter_degrees))
		directions.append(Vector2.RIGHT.rotated(angle).normalized())

	return directions
