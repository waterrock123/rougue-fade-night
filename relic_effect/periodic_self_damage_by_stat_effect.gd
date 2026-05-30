## 遗物效果：战斗中每隔一段时间按自身属性对自己造成伤害。
## 适合“诅咒装置”“代价型光环”等周期性负面效果。
class_name PeriodicSelfDamageByStatEffect
extends RelicEffect

@export var stat_name: StringName = &"charm"
@export var stat_multiplier: float = 1.0
@export var interval: float = 15.0
@export var min_damage: float = 0.0
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var tags: Array[String] = ["relic", "periodic_self_damage"]

var active_entries: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null:
		return

	var key := str(effect_key)
	if active_entries.has(key):
		return

	var callback := Callable(self, "_on_battle_started").bind(key)
	active_entries[key] = {
		"owner": owner,
		"callback": callback,
		"active": true,
		"loop_running": false,
	}

	if not EventBus.battle_started.is_connected(callback):
		EventBus.battle_started.connect(callback)
	if EventBus.is_battle_active:
		_start_loop(key)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if not active_entries.has(key):
		return

	var entry := active_entries[key] as Dictionary
	entry["active"] = false
	var callback := entry.get("callback") as Callable
	if EventBus.battle_started.is_connected(callback):
		EventBus.battle_started.disconnect(callback)

	active_entries.erase(key)


func _on_battle_started(key: String) -> void:
	_start_loop(key)


func _start_loop(key: String) -> void:
	if not active_entries.has(key):
		return

	var entry := active_entries[key] as Dictionary
	if bool(entry.get("loop_running", false)):
		return

	entry["loop_running"] = true
	active_entries[key] = entry
	_damage_loop.call_deferred(key)


func _damage_loop(key: String) -> void:
	while active_entries.has(key):
		var entry := active_entries[key] as Dictionary
		if not bool(entry.get("active", false)):
			break

		var owner := entry.get("owner") as Entity
		if owner == null or not is_instance_valid(owner) or owner.is_dead or not owner.is_inside_tree():
			break

		await owner.get_tree().create_timer(max(interval, 0.05)).timeout

		if not active_entries.has(key):
			break
		if not EventBus.is_battle_active:
			continue
		if owner == null or not is_instance_valid(owner) or owner.is_dead:
			break

		_apply_periodic_damage(owner)

	if active_entries.has(key):
		var latest_entry := active_entries[key] as Dictionary
		latest_entry["loop_running"] = false
		active_entries[key] = latest_entry


func _apply_periodic_damage(owner: Entity) -> void:
	var amount := min_damage
	if owner.stats_controller != null:
		amount = max(amount, owner.stats_controller.get_stat(stat_name) * stat_multiplier)
	if amount <= 0.0:
		return

	var damage_data := DamageData.create(
		amount,
		damage_types,
		tags,
		null,
		owner,
		false
	)
	owner.apply_damage(damage_data)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
