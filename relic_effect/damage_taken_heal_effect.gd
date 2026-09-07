## 受到实际伤害后立即治疗自身的通用遗物效果。
## 仅监听最终伤害大于零的事件，闪避、无敌帧和零伤害不会触发治疗。
class_name DamageTakenHealEffect
extends RelicEffect

@export var heal_amount: float = 1.0

var active_connections: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or heal_amount <= 0.0:
		return

	var key: String = str(effect_key)
	if active_connections.has(key):
		return

	var callback: Callable = Callable(self, "_on_owner_damaged").bind(owner)
	owner.damage_taken.connect(callback)
	active_connections[key] = {
		"owner": owner,
		"callback": callback,
	}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	var entry: Dictionary = active_connections.get(key, {}) as Dictionary
	var owner: Entity = entry.get("owner") as Entity
	var callback: Callable = entry.get("callback") as Callable
	if owner != null and is_instance_valid(owner) and owner.damage_taken.is_connected(callback):
		owner.damage_taken.disconnect(callback)
	active_connections.erase(key)


func _on_owner_damaged(damage_data: DamageData, owner: Entity) -> void:
	if owner == null or not is_instance_valid(owner) or owner.is_dead:
		return
	if damage_data == null or damage_data.final_damage <= 0.0:
		return
	owner.apply_heal(heal_amount)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
