## 在拥有指定状态时，为黑暗战场提供额外视野的通用遗物效果。
class_name DarknessVisionStatusEffect
extends RelicEffect

@export var required_status_id: StringName = &"power"
@export_range(1.0, 2000.0, 1.0) var vision_radius: float = 300.0
@export_range(1.0, 2000.0, 1.0) var levelup_vision_radius: float = 420.0

var active_battle_scenes: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not (context.owner is Entity):
		return
	var owner_entity: Entity = context.owner as Entity
	var battle_scene: Node = _find_battle_scene(owner_entity)
	if battle_scene == null or not battle_scene.has_method("register_darkness_vision_source"):
		return
	var radius: float = vision_radius
	if context.own_relic != null and context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		radius = levelup_vision_radius
	var key: String = str(effect_key)
	battle_scene.call("register_darkness_vision_source", key, owner_entity, required_status_id, radius)
	active_battle_scenes[key] = battle_scene


func on_deactivate(_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	var battle_scene: Node = active_battle_scenes.get(key) as Node
	if battle_scene != null and is_instance_valid(battle_scene) and battle_scene.has_method("unregister_darkness_vision_source"):
		battle_scene.call("unregister_darkness_vision_source", key)
	active_battle_scenes.erase(key)


func _find_battle_scene(owner_entity: Entity) -> Node:
	var current_node: Node = owner_entity
	while current_node != null:
		if current_node is PlayScene:
			return current_node
		current_node = current_node.get_parent()
	return null
