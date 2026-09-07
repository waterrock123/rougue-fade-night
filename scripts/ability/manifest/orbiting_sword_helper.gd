## 环绕飞剑生成工具。
## 地图物体、套装效果、遗物效果都可以调用这里，保持飞剑生成和清理逻辑统一。
class_name OrbitingSwordHelper
extends RefCounted

const DEFAULT_SWORD_SCENE: PackedScene = preload("res://scenes/ability/manifest/orbiting_sword_manifest.tscn")


static func spawn_swords(
	source_entity: Entity,
	count: int,
	source_key: StringName,
	sword_scene: PackedScene = null,
	damage: float = 12.0,
	lifetime: float = 0.0,
	orbit_radius: float = 54.0,
	orbit_speed: float = 2.1,
	radius_wave_amplitude: float = 7.0,
	slot_radius_variation: float = 4.0,
	target_group: StringName = &""
) -> Array[OrbitingSwordManifest]:
	var result: Array[OrbitingSwordManifest] = []
	if source_entity == null or not is_instance_valid(source_entity):
		return result
	if count <= 0:
		return result

	var parent_node: Node = _get_spawn_parent(source_entity)
	if parent_node == null:
		return result

	var packed_scene: PackedScene = sword_scene if sword_scene != null else DEFAULT_SWORD_SCENE
	for index: int in range(count):
		var sword: OrbitingSwordManifest = packed_scene.instantiate() as OrbitingSwordManifest
		if sword == null:
			continue

		sword.damage = damage
		sword.lifetime = lifetime
		sword.orbit_radius = orbit_radius
		sword.orbit_speed = orbit_speed
		sword.radius_wave_amplitude = radius_wave_amplitude
		sword.slot_radius_variation = slot_radius_variation
		if target_group != &"":
			sword.target_group = target_group
			sword.auto_target_group_from_source = false

		parent_node.add_child(sword)
		sword.global_position = source_entity.global_position
		sword.setup_orbit(source_entity, source_key, index, count)
		result.append(sword)

	return result


static func clear_swords_for_source(source_entity: Entity, source_key: StringName) -> void:
	if source_entity == null or not is_instance_valid(source_entity):
		return
	if not source_entity.is_inside_tree():
		return

	for node: Node in source_entity.get_tree().get_nodes_in_group("orbiting_sword_manifest"):
		if not is_instance_valid(node):
			continue
		var sword: OrbitingSwordManifest = node as OrbitingSwordManifest
		if sword == null:
			continue
		if sword.matches_source(source_entity, source_key):
			sword.queue_free()


static func _get_spawn_parent(source_entity: Entity) -> Node:
	if source_entity == null or not source_entity.is_inside_tree():
		return null

	var battle_map: BattleMap = source_entity.get_tree().get_first_node_in_group("battle_map") as BattleMap
	if battle_map != null:
		var runtime_container: Node = battle_map.get_runtime_effect_container()
		if runtime_container != null:
			return runtime_container

	if source_entity.get_parent() != null:
		return source_entity.get_parent()

	return source_entity.get_tree().current_scene
