## Boss 召唤敌人组件。
## 挂在 Ability 场景下，用于在施法者附近一次性召唤多只小怪；召唤物可以自动登记进 EnemySpawner，
## 这样它们会参与战斗结束判断，避免“Boss 死了但召唤物还活着，战斗却提前结束”的问题。
class_name AbilitySummonEnemies
extends AbilityComponent

enum SpawnPattern {
	EVEN_CIRCLE,
	RANDOM_RING,
}

@export var enemy_scenes: Array[PackedScene] = []
@export_range(1, 32, 1) var summon_count: int = 4
@export var spawn_pattern: SpawnPattern = SpawnPattern.EVEN_CIRCLE
@export var min_spawn_distance: float = 48.0
@export var spawn_radius: float = 96.0
@export var random_angle_offset: bool = true
@export var randomize_enemy_scene: bool = false
@export var spawn_interval: float = 0.0
@export var start_aggressive: bool = true
@export var register_to_enemy_spawner: bool = true
@export var spawn_parent_path: NodePath


func _activate(context: AbilityContext) -> void:
	if context == null or context.caster == null or enemy_scenes.is_empty():
		return

	var parent := _resolve_spawn_parent(context.caster)
	if parent == null:
		return

	var enemy_spawner := _find_enemy_spawner(context.caster) if register_to_enemy_spawner else null
	var offsets := _build_spawn_offsets()
	for index in range(summon_count):
		if not context.is_caster_action_valid():
			return
		if spawn_interval > 0.0 and index > 0:
			await get_tree().create_timer(spawn_interval, false).timeout
			if not context.is_caster_action_valid():
				return

		var enemy := _spawn_one_enemy(parent, context.caster.global_position + offsets[index], index)
		if enemy != null and enemy_spawner != null:
			enemy_spawner.register_external_enemy(enemy)


func _spawn_one_enemy(parent: Node, spawn_position: Vector2, index: int) -> Enemy:
	var scene := _pick_enemy_scene(index)
	if scene == null:
		return null

	var node := scene.instantiate() as Node2D
	if node == null:
		return null

	var enemy := node as Enemy
	if enemy != null and start_aggressive:
		# 召唤物通常应该立刻参战；在 add_child 前设置，Enemy._ready 会据此进入追击状态。
		enemy.aggresive = true

	parent.add_child(node)
	node.global_position = spawn_position
	return enemy


func _pick_enemy_scene(index: int) -> PackedScene:
	if enemy_scenes.is_empty():
		return null

	if enemy_scenes.size() == 1:
		return enemy_scenes[0]

	return enemy_scenes.pick_random() if randomize_enemy_scene else enemy_scenes[index % enemy_scenes.size()]


func _build_spawn_offsets() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var safe_count = max(summon_count, 1)
	var safe_radius = max(spawn_radius, min_spawn_distance)
	var base_angle := randf() * TAU if random_angle_offset else 0.0

	for index in range(safe_count):
		var angle := base_angle
		var distance = safe_radius
		match spawn_pattern:
			SpawnPattern.EVEN_CIRCLE:
				angle += TAU * float(index) / float(safe_count)
			SpawnPattern.RANDOM_RING:
				angle += randf() * TAU
				distance = randf_range(min_spawn_distance, safe_radius)

		result.append(Vector2.RIGHT.rotated(angle) * distance)

	return result


func _resolve_spawn_parent(caster: Node) -> Node:
	if spawn_parent_path != NodePath():
		var from_caster := caster.get_node_or_null(spawn_parent_path)
		if from_caster != null:
			return from_caster

		var current_scene := get_tree().current_scene
		if current_scene != null:
			var from_scene := current_scene.get_node_or_null(spawn_parent_path)
			if from_scene != null:
				return from_scene

	if caster.get_parent() != null:
		return caster.get_parent()

	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root


func _find_enemy_spawner(caster: Node) -> EnemySpawner:
	var node := caster
	while node != null:
		var spawner := node.get_node_or_null("EnemySpawner") as EnemySpawner
		if spawner != null:
			return spawner
		node = node.get_parent()

	return get_tree().get_first_node_in_group("enemy_spawner") as EnemySpawner
