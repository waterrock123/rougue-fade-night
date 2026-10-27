## 真实发射投射物时概率追加一个 Manifest；按每颗投射物独立判定，支持升级概率。
## 延迟到物理回调结束后生成，追加实体带保护标记，不会递归触发追加发射。
class_name ProjectileLaunchSpawnManifestEffect
extends RelicEffect

@export var manifest_scene: PackedScene
@export_range(0.0, 1.0, 0.01) var chance: float = 0.05
@export_range(0.0, 1.0, 0.01) var upgraded_chance: float = 0.1

var contexts: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not (context.owner is Entity):
		return
	contexts["%s:%s" % [context.owner.get_instance_id(), effect_key]] = context
	if not EventBus.projectile_launched.is_connected(_on_launched):
		EventBus.projectile_launched.connect(_on_launched)


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context != null and is_instance_valid(context.owner):
		contexts.erase("%s:%s" % [context.owner.get_instance_id(), effect_key])
	if contexts.is_empty() and EventBus.projectile_launched.is_connected(_on_launched):
		EventBus.projectile_launched.disconnect(_on_launched)


func _on_launched(projectile: Node2D, context: AbilityContext, direction: Vector2) -> void:
	if manifest_scene == null or context == null or not is_instance_valid(projectile):
		return
	if projectile.get_meta(&"extra_projectile", false):
		return
	for key: Variant in contexts.keys():
		var entry: RelicContext = contexts[key] as RelicContext
		if not is_instance_valid(entry.owner) or entry.owner != context.caster:
			continue
		var probability: float = upgraded_chance if entry.own_relic.leveltip == Relic.LevelTip.LEVELUP else chance
		if randf() < probability:
			_spawn.call_deferred(str(key), context, projectile.global_position, direction)


func _spawn(key: String, original: AbilityContext, origin: Vector2, direction: Vector2) -> void:
	if not contexts.has(key) or not original.is_caster_action_valid():
		return
	if original.ability != null and not is_instance_valid(original.ability):
		return
	var caster: Entity = original.caster
	if not caster.is_inside_tree():
		return
	var manifest: AbilityManifest = manifest_scene.instantiate() as AbilityManifest
	if manifest == null:
		return
	var context: AbilityContext = AbilityContext.new(caster, original.ability)
	context.locked_direction = direction
	context.targets = [origin + direction * 600.0]
	manifest.set_meta(&"extra_projectile", true)
	var scene: Node = caster.get_tree().current_scene
	if scene == null:
		manifest.free()
		return
	scene.add_child(manifest)
	manifest.global_position = origin
	manifest.global_rotation = direction.angle()
	manifest.activate(context)
