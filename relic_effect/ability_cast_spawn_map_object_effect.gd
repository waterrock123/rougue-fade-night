## 主动技能成功释放时按概率在附近生成指定分类的地图物体；默认排除基础攻击。
class_name AbilityCastSpawnMapObjectEffect
extends RelicEffect

@export var feature_tag: StringName = &"beneficial_plant"
@export_range(0.0, 1.0, 0.01) var chance: float = 0.05
@export var spawn_radius: float = 120.0
@export var exclude_basic_attack: bool = true

var bindings: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not (context.owner is Entity):
		return
	var caster: Entity = context.owner as Entity
	var controller: AbilityController = caster.get_node_or_null("AbilityController") as AbilityController
	if controller == null:
		return
	var key: String = "%d:%s" % [caster.get_instance_id(), str(effect_key)]
	if bindings.has(key):
		return
	var callback: Callable = _on_cast.bind(key)
	bindings[key] = {"caster": caster, "controller": controller, "callback": callback}
	controller.ability_triggered.connect(callback)


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var key: String = "%d:%s" % [context.owner.get_instance_id(), str(effect_key)]
	if not bindings.has(key):
		return
	var record: Dictionary = bindings[key]
	var controller: Variant = record["controller"]
	if is_instance_valid(controller) and controller.ability_triggered.is_connected(record["callback"]):
		controller.ability_triggered.disconnect(record["callback"])
	bindings.erase(key)


func _on_cast(ability: Ability, caster: Entity, key: String) -> void:
	if not bindings.has(key) or not EventBus.is_battle_active or not is_instance_valid(caster):
		return
	var controller: AbilityController = bindings[key]["controller"]
	if exclude_basic_attack and controller.abilities.find(ability) == 0:
		return
	if randf() < chance:
		# 可能在碰撞回调中施法，延迟实例化以避开物理查询锁。
		_spawn.call_deferred(key, caster.global_position)


func _spawn(key: String, position: Vector2) -> void:
	if not bindings.has(key) or not EventBus.is_battle_active:
		return
	var caster: Variant = bindings[key]["caster"]
	if not is_instance_valid(caster) or caster.is_dead or not caster.is_inside_tree():
		return
	var node: Node = caster
	while node != null:
		if node is PlayScene:
			var scene: PlayScene = node as PlayScene
			if is_instance_valid(scene.object_spawner):
				scene.object_spawner.spawn_feature_near(feature_tag, position, spawn_radius)
			return
		node = node.get_parent()
