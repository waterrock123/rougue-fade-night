## 遗物效果：装备期间在拥有者脚下周期生成 Manifest。
## 适合雪暴瓶的冰霜残迹，也可复用给火焰足迹、毒雾路径、治疗路径等装备。
class_name SpawnOwnerTrailManifestEffect
extends RelicEffect

@export var manifest_scene: PackedScene
@export var spawn_interval: float = 0.25
@export var min_spawn_distance: float = 12.0
@export var spawn_only_while_moving: bool = true
@export var initial_spawn: bool = true
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var manifest_property_overrides: Dictionary = {}
@export var levelup_manifest_property_overrides: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or manifest_scene == null:
		return
	if not (relic_context.owner is Entity):
		return

	var owner := relic_context.owner as Entity
	var spawner := OwnerManifestTrailSpawner.new()
	spawner.name = "RelicTrailSpawner_%s" % String(effect_key)
	spawner.spawn_interval = spawn_interval
	spawner.min_spawn_distance = min_spawn_distance
	spawner.spawn_only_while_moving = spawn_only_while_moving
	spawner.initial_spawn = initial_spawn
	spawner.spawn_offset = spawn_offset

	var overrides := manifest_property_overrides.duplicate(true)
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		for property_name in levelup_manifest_property_overrides.keys():
			overrides[property_name] = levelup_manifest_property_overrides[property_name]

	owner.add_child(spawner)
	spawner.setup(owner, manifest_scene, overrides)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or relic_context.owner == null:
		return

	var spawner := relic_context.owner.get_node_or_null("RelicTrailSpawner_%s" % String(effect_key))
	if spawner != null:
		spawner.queue_free()
