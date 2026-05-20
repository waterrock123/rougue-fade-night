## 拥有者脚下 Manifest 轨迹生成器。
## 装备效果会把它挂到实体身上，它负责按间隔/移动距离在脚底生成地面残迹。
class_name OwnerManifestTrailSpawner
extends Node

@export var manifest_scene: PackedScene
@export var spawn_interval: float = 0.25
@export var min_spawn_distance: float = 12.0
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var spawn_only_while_moving: bool = true
@export var initial_spawn: bool = true
@export var manifest_property_overrides: Dictionary = {}

var owner_entity: Entity
var spawn_timer: float = 0.0
var last_spawn_position: Vector2 = Vector2.INF


func setup(new_owner: Entity, new_manifest_scene: PackedScene, overrides: Dictionary = {}) -> void:
	owner_entity = new_owner
	manifest_scene = new_manifest_scene
	manifest_property_overrides = overrides.duplicate(true)
	if owner_entity != null:
		last_spawn_position = owner_entity.global_position


func _ready() -> void:
	if owner_entity == null and get_parent() is Entity:
		owner_entity = get_parent() as Entity
	if initial_spawn:
		call_deferred("_try_spawn_manifest", true)


func _process(delta: float) -> void:
	if owner_entity == null or not is_instance_valid(owner_entity) or owner_entity.is_dead:
		queue_free()
		return
	if manifest_scene == null:
		return

	spawn_timer += delta
	if spawn_timer < spawn_interval:
		return

	spawn_timer = 0.0
	_try_spawn_manifest(false)


func _try_spawn_manifest(force_spawn: bool) -> void:
	if owner_entity == null or manifest_scene == null:
		return

	var current_position := owner_entity.global_position
	var moved_distance := current_position.distance_to(last_spawn_position)
	if not force_spawn:
		if spawn_only_while_moving and moved_distance < min_spawn_distance:
			return
		if moved_distance < min_spawn_distance:
			return

	_spawn_manifest(current_position + spawn_offset)
	last_spawn_position = current_position


func _spawn_manifest(spawn_position: Vector2) -> void:
	var manifest := manifest_scene.instantiate() as AbilityManifest
	if manifest == null:
		return

	var root := owner_entity.get_tree().current_scene
	if root == null:
		root = owner_entity.get_tree().root
	root.add_child(manifest)
	manifest.global_position = spawn_position

	for property_name in manifest_property_overrides.keys():
		manifest.set(StringName(property_name), manifest_property_overrides[property_name])

	var context := AbilityContext.new(owner_entity, null)
	manifest.activate(context)
