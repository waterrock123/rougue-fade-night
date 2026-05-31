## 每场战斗第一次受到有效伤害时给自己添加状态。
## 适合“刺激录像带”这类受击后短暂爆发的装备。
class_name FirstDamageTakenStatusEffect
extends RelicEffect

@export var status_data: StatusData
@export var stacks: int = 1
@export var duration_override: float = INF
@export var require_positive_damage: bool = true

var active_connections: Dictionary = {}
var triggered_keys: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null or status_data == null:
		return

	var key := str(effect_key)
	if active_connections.has(key):
		return

	var callback := Callable(self, "_on_damage_taken").bind(owner, key)
	owner.damage_taken.connect(callback)
	active_connections[key] = {
		"owner": owner,
		"callback": callback,
	}
	triggered_keys.erase(key)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if not active_connections.has(key):
		return

	var entry := active_connections[key] as Dictionary
	var owner := entry.get("owner") as Entity
	var callback := entry.get("callback") as Callable
	if owner != null and is_instance_valid(owner) and owner.damage_taken.is_connected(callback):
		owner.damage_taken.disconnect(callback)

	active_connections.erase(key)
	triggered_keys.erase(key)


func _on_damage_taken(damage_data: DamageData, owner: Entity, effect_key: String) -> void:
	if triggered_keys.has(effect_key):
		return
	if damage_data == null:
		return
	if require_positive_damage and damage_data.final_damage <= 0.0:
		return
	if owner == null or not is_instance_valid(owner):
		return

	var status_controller := owner.get_status_controller()
	if status_controller == null:
		return

	triggered_keys[effect_key] = true
	status_controller.add_status(status_data, owner, effect_key, stacks, duration_override)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
