## 指定地图物体被拥有者击破，或指定投射物首次命中/飞行结束时，概率生成后续 Manifest。
## 通过标签筛选类型，基础与升级概率独立配置，不依赖装备名称；适合碎石、分裂弹等效果。
class_name ResolvedObjectSpawnManifestEffect
extends RelicEffect

@export var manifest_scene: PackedScene
@export var map_feature_tag: StringName = &"rock"
@export var projectile_tag: String = "stone"
@export_range(0.0, 1.0, 0.01) var chance: float = 0.3
@export_range(0.0, 1.0, 0.01) var upgraded_chance: float = 0.5

var entries: Dictionary = {}
var serial: int = 0


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not (context.owner is Entity):
		return
	serial += 1
	entries[_key(context, effect_key)] = {"context": context, "generation": serial}
	if not EventBus.map_object_destroyed.is_connected(_on_object_destroyed):
		EventBus.map_object_destroyed.connect(_on_object_destroyed)
	if not EventBus.projectile_resolved.is_connected(_on_projectile_resolved):
		EventBus.projectile_resolved.connect(_on_projectile_resolved)


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context != null and is_instance_valid(context.owner):
		entries.erase(_key(context, effect_key))
	if not entries.is_empty():
		return
	if EventBus.map_object_destroyed.is_connected(_on_object_destroyed):
		EventBus.map_object_destroyed.disconnect(_on_object_destroyed)
	if EventBus.projectile_resolved.is_connected(_on_projectile_resolved):
		EventBus.projectile_resolved.disconnect(_on_projectile_resolved)


func _key(context: RelicContext, effect_key: Variant) -> String:
	return "%s:%s" % [context.owner.get_instance_id(), effect_key]


func _on_object_destroyed(object: Node, killer: Entity) -> void:
	if map_feature_tag == &"" or not is_instance_valid(object) or not (object is MapObject):
		return
	var map_object: MapObject = object as MapObject
	if not map_object.has_feature_tag(map_feature_tag):
		return
	_trigger(killer, map_object.global_position, map_object.last_impact_direction)


func _on_projectile_resolved(projectile: ProjectileManifest, _reason: StringName) -> void:
	if projectile_tag.is_empty() or not is_instance_valid(projectile):
		return
	if not projectile.tags.has(projectile_tag):
		return
	_trigger(projectile.source, projectile.global_position, projectile.current_dir)


func _trigger(source: Entity, origin: Vector2, direction: Vector2) -> void:
	if manifest_scene == null or not is_instance_valid(source) or source.is_dead:
		return
	for key: Variant in entries.keys():
		var entry: Dictionary = entries[key]
		var context: RelicContext = entry["context"] as RelicContext
		if not is_instance_valid(context.owner) or context.owner != source:
			continue
		var probability: float = upgraded_chance if context.own_relic.leveltip == Relic.LevelTip.LEVELUP else chance
		if randf() < probability:
			# 在同步信号中复制位置与方向，延迟生成时不再访问已销毁的石头。
			_spawn.call_deferred(str(key), int(entry["generation"]), origin, direction)


func _spawn(key: String, generation: int, origin: Vector2, direction: Vector2) -> void:
	if not entries.has(key) or int(entries[key]["generation"]) != generation:
		return
	var context: RelicContext = entries[key]["context"] as RelicContext
	if not is_instance_valid(context.owner) or not (context.owner is Entity):
		return
	var entity: Entity = context.owner as Entity
	if entity.is_dead or not entity.is_inside_tree() or not EventBus.is_battle_active:
		return
	var root: Node = entity.get_tree().current_scene
	if root == null:
		return
	var manifest: AbilityManifest = manifest_scene.instantiate() as AbilityManifest
	if manifest == null:
		return
	var forward: Vector2 = direction.normalized()
	if forward == Vector2.ZERO:
		forward = (origin - entity.global_position).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var ability_context: AbilityContext = AbilityContext.new(entity, null)
	ability_context.locked_direction = forward
	ability_context.targets = [origin + forward * 400.0]
	root.add_child(manifest)
	manifest.global_position = origin
	manifest.global_rotation = forward.angle()
	manifest.activate(ability_context)
