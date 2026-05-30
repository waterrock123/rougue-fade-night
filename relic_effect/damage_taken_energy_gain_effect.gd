## 受到伤害时恢复能量的通用遗物效果。
## 适合“染血画笔”这类把受伤转化为法力/能量收益的装备。
class_name DamageTakenEnergyGainEffect
extends RelicEffect

## 每次实际损失生命后恢复的能量值。
@export var energy_gain: float = 5.0
## 只有最终伤害大于 0 时才触发。
@export var require_positive_damage: bool = true

var active_connections: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null or energy_gain <= 0.0:
		return

	var key := str(effect_key)
	if active_connections.has(key):
		return

	var callback := Callable(self, "_on_owner_damage_taken").bind(key)
	owner.damage_taken.connect(callback)
	active_connections[key] = {
		"owner": owner,
		"callback": callback,
	}


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


func _on_owner_damage_taken(damage_data: DamageData, _effect_key: String) -> void:
	if damage_data == null:
		return
	if require_positive_damage and damage_data.final_damage <= 0.0:
		return
	if damage_data.target == null or not is_instance_valid(damage_data.target):
		return

	var owner := damage_data.target
	owner.current_energy = min(owner.current_energy + energy_gain, owner.max_energy)
	if owner.stats_controller != null:
		owner.stats_controller.current_energy = owner.current_energy
		owner.stats_controller.sync_runtime_resources()

	if owner.is_in_group("player"):
		EventBus.player_energy_changed.emit(owner.current_energy, owner.max_energy)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
