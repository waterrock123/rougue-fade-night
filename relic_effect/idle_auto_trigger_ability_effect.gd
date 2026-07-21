class_name IdleAutoTriggerAbilityEffect
extends RelicEffect

## 一段时间内满足“没有造成/受到伤害”等空闲条件后，自动触发一个 Ability 场景。
## 当前用于“狂兽骸骨”，但 ability_scene 可替换成任意技能，实现其他自动触发装备。

@export var ability_scene: PackedScene
@export var idle_seconds: float = 5.0
@export var check_interval: float = 0.2
@export var reset_on_damage_dealt: bool = true
@export var reset_on_damage_taken: bool = true
@export var only_in_battle: bool = true
## 自动技能实例保留多久再清理。需要覆盖技能内异步组件的最长持续时间。
@export var cleanup_delay: float = 2.0

var active_records: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or ability_scene == null:
		return

	var key: String = str(effect_key)
	if active_records.has(key):
		return

	var dealt_callback: Callable = Callable(self, "_mark_activity").bind(key)
	var taken_callback: Callable = Callable(self, "_mark_activity").bind(key)
	if reset_on_damage_dealt and not owner.damage_dealt.is_connected(dealt_callback):
		owner.damage_dealt.connect(dealt_callback)
	if reset_on_damage_taken and not owner.damage_taken.is_connected(taken_callback):
		owner.damage_taken.connect(taken_callback)

	active_records[key] = {
		"owner": owner,
		"dealt_callback": dealt_callback,
		"taken_callback": taken_callback,
		"last_activity_msec": Time.get_ticks_msec(),
	}
	call_deferred("_monitor_idle", key)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	if not active_records.has(key):
		return

	var record: Dictionary = active_records[key] as Dictionary
	var owner: Entity = record.get("owner") as Entity
	var dealt_callback: Callable = record.get("dealt_callback") as Callable
	var taken_callback: Callable = record.get("taken_callback") as Callable
	if owner != null and is_instance_valid(owner):
		if dealt_callback.is_valid() and owner.damage_dealt.is_connected(dealt_callback):
			owner.damage_dealt.disconnect(dealt_callback)
		if taken_callback.is_valid() and owner.damage_taken.is_connected(taken_callback):
			owner.damage_taken.disconnect(taken_callback)

	active_records.erase(key)


func _mark_activity(_damage_data: DamageData, key: String) -> void:
	if not active_records.has(key):
		return

	var record: Dictionary = active_records[key] as Dictionary
	record["last_activity_msec"] = Time.get_ticks_msec()
	active_records[key] = record


func _monitor_idle(key: String) -> void:
	while active_records.has(key):
		var record: Dictionary = active_records[key] as Dictionary
		var owner: Entity = record.get("owner") as Entity
		if owner == null or not is_instance_valid(owner) or owner.is_dead or not owner.is_inside_tree():
			active_records.erase(key)
			return

		await owner.get_tree().create_timer(max(check_interval, 0.05), false).timeout
		if not active_records.has(key):
			return
		if only_in_battle and not EventBus.is_battle_active:
			continue

		record = active_records[key] as Dictionary
		var last_activity_msec: int = int(record.get("last_activity_msec", Time.get_ticks_msec()))
		var idle_msec: int = int(max(idle_seconds, 0.0) * 1000.0)
		if Time.get_ticks_msec() - last_activity_msec < idle_msec:
			continue
		if owner.has_method("can_act") and not owner.can_act():
			_mark_activity(null, key)
			continue

		_trigger_ability(owner)
		_mark_activity(null, key)


func _trigger_ability(owner: Entity) -> void:
	if owner == null or ability_scene == null:
		return

	var ability: Ability = ability_scene.instantiate() as Ability
	if ability == null:
		return

	owner.add_child(ability)
	ability.activate(owner)
	_cleanup_ability_later(owner, ability)


func _cleanup_ability_later(owner: Entity, ability: Ability) -> void:
	if owner == null or ability == null or not is_instance_valid(owner):
		return

	await owner.get_tree().create_timer(max(cleanup_delay, 0.1), false).timeout
	if ability != null and is_instance_valid(ability):
		ability.queue_free()


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
