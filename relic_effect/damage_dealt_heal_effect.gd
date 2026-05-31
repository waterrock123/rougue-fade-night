## 造成伤害后按冷却治疗自己。
## 适合“战车”这种持续进攻带来的回血效果。
class_name DamageDealtHealEffect
extends RelicEffect

@export var heal_amount: float = 1.0
@export var cooldown: float = 2.0
@export var require_positive_damage: bool = true

var active_connections: Dictionary = {}
var last_trigger_msec: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null:
		return

	var key := str(effect_key)
	if active_connections.has(key):
		return

	var callback := Callable(self, "_on_damage_dealt").bind(owner, key)
	owner.damage_dealt.connect(callback)
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
	if owner != null and is_instance_valid(owner) and owner.damage_dealt.is_connected(callback):
		owner.damage_dealt.disconnect(callback)

	active_connections.erase(key)
	last_trigger_msec.erase(key)


func _on_damage_dealt(damage_data: DamageData, owner: Entity, effect_key: String) -> void:
	if owner == null or not is_instance_valid(owner) or owner.is_dead:
		return
	if damage_data == null:
		return
	if require_positive_damage and damage_data.final_damage <= 0.0:
		return
	if not _cooldown_ready(effect_key):
		return

	last_trigger_msec[effect_key] = Time.get_ticks_msec()
	owner.current_health = min(owner.current_health + heal_amount, owner.max_health)
	if owner.stats_controller != null:
		owner.stats_controller.current_health = owner.current_health
		owner.stats_controller.sync_runtime_resources()

	if owner.is_in_group("player"):
		EventBus.player_health_changed.emit(owner.current_health, owner.max_health)


func _cooldown_ready(effect_key: String) -> bool:
	var now := Time.get_ticks_msec()
	var last_time := int(last_trigger_msec.get(effect_key, -1000000))
	return now - last_time >= int(max(cooldown, 0.0) * 1000.0)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
