## 摧毁指定类型地图物体后，为拥有者添加状态的通用遗物效果。
## 适合伐木斧、挖矿工具等“破坏特定地图物体获得临时增益”的装备。
class_name MapObjectDestroyedAddStatusEffect
extends RelicEffect

@export var required_feature_tag: StringName = &""
@export var status_data: StatusData
@export_range(1, 999, 1) var stacks: int = 1
@export var duration_override: float = INF
## 开启时只计算装备者本人的最后一击，避免召唤物误触发“你摧毁”类描述。
@export var require_direct_owner_kill: bool = true

var active_contexts: Dictionary = {}
var active_callbacks: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not (context.owner is Entity) or status_data == null:
		return
	var key: String = str(effect_key)
	if active_contexts.has(key):
		return
	var callback: Callable = _on_map_object_destroyed.bind(key)
	active_contexts[key] = context
	active_callbacks[key] = callback
	EventBus.map_object_destroyed.connect(callback)


func on_deactivate(_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	var callback: Callable = active_callbacks.get(key, Callable()) as Callable
	if EventBus.map_object_destroyed.is_connected(callback):
		EventBus.map_object_destroyed.disconnect(callback)
	active_callbacks.erase(key)
	active_contexts.erase(key)


func _on_map_object_destroyed(map_object: Node, killer: Entity, key: String) -> void:
	var context: RelicContext = active_contexts.get(key) as RelicContext
	if context == null or not (context.owner is Entity):
		return
	var owner_entity: Entity = context.owner as Entity
	if owner_entity == null or not is_instance_valid(owner_entity) or owner_entity.is_dead:
		return
	if require_direct_owner_kill and killer != owner_entity:
		return
	if not require_direct_owner_kill and (killer == null or not killer.is_player_side()):
		return
	if required_feature_tag != &"" and not _map_object_has_tag(map_object, required_feature_tag):
		return
	var controller: StatusController = owner_entity.get_status_controller()
	if controller != null:
		controller.add_status(status_data, owner_entity, key, stacks, duration_override)


func _map_object_has_tag(map_object: Node, feature_tag: StringName) -> bool:
	if map_object == null or not is_instance_valid(map_object):
		return false
	if map_object.has_method("has_feature_tag"):
		return bool(map_object.call("has_feature_tag", feature_tag))
	return map_object.is_in_group(String(feature_tag))
