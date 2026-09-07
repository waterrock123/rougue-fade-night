## 闪避成功后给自身附加一个状态的通用遗物效果。
## 例如斗笠可借此在闪避后短暂提高暴击率。
class_name DodgeApplyStatusEffect
extends RelicEffect

@export var status_data: StatusData
@export var stacks: int = 1
@export var duration_override: float = INF

var active_connections: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or status_data == null:
		return

	var key: String = str(effect_key)
	if active_connections.has(key):
		return

	var callback: Callable = Callable(self, "_on_owner_evaded").bind(relic_context, key)
	owner.damage_evaded.connect(callback)
	active_connections[key] = {
		"owner": owner,
		"callback": callback,
	}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	var entry: Dictionary = active_connections.get(key, {}) as Dictionary
	var owner: Entity = entry.get("owner") as Entity
	var callback: Callable = entry.get("callback") as Callable
	if owner != null and is_instance_valid(owner) and owner.damage_evaded.is_connected(callback):
		owner.damage_evaded.disconnect(callback)
	active_connections.erase(key)


func _on_owner_evaded(_damage_data: DamageData, relic_context: RelicContext, effect_key: String) -> void:
	var status_controller: StatusController = _get_status_controller(relic_context)
	if status_controller == null or status_data == null:
		return

	status_controller.add_status(status_data, relic_context.owner, effect_key, stacks, duration_override)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity


func _get_status_controller(relic_context: RelicContext) -> StatusController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_status_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).get_status_controller()
	return null
