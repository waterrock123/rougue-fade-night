## 随机范围生成 Manifest 组件。
## 适合火雨、陨石雨、毒雾落点这类“围绕目标随机生成多个地面效果”的技能。
class_name AbilitySpawnManifestRandomAroundTarget
extends AbilityComponent

@export var manifest_scene: PackedScene
@export_range(1, 64, 1) var spawn_count: int = 6
@export var min_radius: float = 0.0
@export var max_radius: float = 160.0
@export var initial_delay: float = 0.0
@export var spawn_interval: float = 0.12
@export var include_center_spawn: bool = false
@export var manifest_property_overrides: Dictionary = {}

@export_group("Target")
## 没有显式目标时，优先从这些 group 里找最近目标作为落点中心。
@export var fallback_target_groups: Array[StringName] = [&"player", &"player_ally", &"summon_pet"]


func _activate(context: AbilityContext) -> void:
	if manifest_scene == null or context == null or context.caster == null:
		return

	if initial_delay > 0.0:
		await get_tree().create_timer(initial_delay, false).timeout
	if context == null or not context.is_caster_action_valid():
		return

	var center_position: Vector2 = _get_center_position(context)
	for index in range(spawn_count):
		if not context.is_caster_action_valid():
			return

		var spawn_position: Vector2 = center_position
		if not (include_center_spawn and index == 0):
			spawn_position += _get_random_offset()

		_spawn_manifest(context, spawn_position)

		if spawn_interval > 0.0 and index < spawn_count - 1:
			await get_tree().create_timer(spawn_interval, false).timeout


func _spawn_manifest(context: AbilityContext, spawn_position: Vector2) -> void:
	var manifest: AbilityManifest = manifest_scene.instantiate() as AbilityManifest
	if manifest == null:
		return

	var root: Node = context.caster.get_tree().current_scene
	if root == null:
		root = context.caster.get_tree().root
	root.add_child(manifest)
	manifest.global_position = spawn_position

	for property_name in manifest_property_overrides.keys():
		manifest.set(StringName(property_name), manifest_property_overrides[property_name])

	var child_context: AbilityContext = AbilityContext.new(context.caster, context.ability)
	child_context.caster_action_version = context.caster_action_version
	child_context.locked_direction = context.locked_direction
	child_context.targets = [spawn_position]
	manifest.activate(child_context)


func _get_center_position(context: AbilityContext) -> Vector2:
	if not context.targets.is_empty():
		var target = context.targets[0]
		if target is Entity:
			return (target as Entity).global_position
		if target is Node2D:
			return (target as Node2D).global_position
		if target is Vector2:
			return target

	var fallback_target: Entity = _find_nearest_fallback_target(context.caster)
	if fallback_target != null:
		return fallback_target.global_position

	return context.caster.global_position


func _find_nearest_fallback_target(caster: Entity) -> Entity:
	var nearest: Entity = null
	var nearest_distance: float = INF

	for group_name in fallback_target_groups:
		for node in get_tree().get_nodes_in_group(String(group_name)):
			if not (node is Entity):
				continue

			var candidate: Entity = node as Entity
			if candidate == caster:
				continue
			if candidate.has_method("can_be_targeted") and not candidate.can_be_targeted():
				continue

			var distance: float = caster.global_position.distance_to(candidate.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate

	return nearest


func _get_random_offset() -> Vector2:
	var safe_min_radius: float = max(min_radius, 0.0)
	var safe_max_radius: float = max(max_radius, safe_min_radius)
	var angle: float = randf() * TAU
	var distance: float = randf_range(safe_min_radius, safe_max_radius)
	return Vector2.RIGHT.rotated(angle) * distance
