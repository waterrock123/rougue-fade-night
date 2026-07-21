## 遗物效果：战斗开始时给予状态，并在受到指定类型伤害后追加状态层数。
## 适合“蓄能电池”：开场给予电力，受到闪电伤害后继续充能。
class_name BattleStartStatusChargeOnDamageTakenEffect
extends RelicEffect

## 战斗开始时给予的状态资源。
@export var status_data: StatusData
## 战斗开始时给予的基础层数。
@export var initial_stacks: int = 3
## 每次符合条件的受伤事件额外给予多少层。
@export var extra_stacks_per_damage: int = 1
## 未升级时，额外可获得的最大层数。
@export var max_extra_stacks: int = 3
## 升级时，额外可获得的最大层数。
@export var levelup_max_extra_stacks: int = 6
## 需要匹配的伤害类型。留空则任意伤害类型都能触发。
@export var required_damage_types: Array[int] = [DamageData.DamageType.LIGHTNING]
## 是否要求最终伤害大于 0。开启后闪避、无敌或 0 伤害不会触发。
@export var require_positive_damage: bool = true
## 状态持续时间覆盖。INF 表示使用 StatusData 自己的 duration。
@export var duration_override: float = INF

var active_records: Dictionary = {}
var pending_battle_callbacks: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or status_data == null:
		return

	var key: String = str(effect_key)
	if active_records.has(key) or pending_battle_callbacks.has(key):
		return

	if EventBus.is_battle_active:
		_start_battle_effect(relic_context, key)
		return

	var callback: Callable = Callable(self, "_start_battle_effect").bind(relic_context, key)
	pending_battle_callbacks[key] = callback
	EventBus.battle_started.connect(callback, CONNECT_ONE_SHOT)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	_disconnect_pending_battle_callback(key)
	_stop_battle_effect(key)


func _start_battle_effect(relic_context: RelicContext, key: String) -> void:
	pending_battle_callbacks.erase(key)

	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or not is_instance_valid(owner) or owner.is_dead:
		return

	var status_controller: StatusController = owner.get_status_controller()
	if status_controller == null:
		return

	# 同一 effect_key 作为来源，确保“这件装备提供的电力”可以被统一消耗或清理。
	status_controller.add_status(status_data, owner, key, max(initial_stacks, 0), duration_override)

	var damage_callback: Callable = Callable(self, "_on_owner_damage_taken").bind(key)
	if not owner.damage_taken.is_connected(damage_callback):
		owner.damage_taken.connect(damage_callback)

	active_records[key] = {
		"owner": owner,
		"callback": damage_callback,
		"extra_stacks": 0,
		"max_extra_stacks": _get_max_extra_stacks(relic_context),
	}


func _stop_battle_effect(key: String) -> void:
	if not active_records.has(key):
		return

	var record: Dictionary = active_records[key] as Dictionary
	var owner: Entity = record.get("owner") as Entity
	var callback: Callable = record.get("callback") as Callable
	if owner != null and is_instance_valid(owner):
		if owner.damage_taken.is_connected(callback):
			owner.damage_taken.disconnect(callback)
		var status_controller: StatusController = owner.get_status_controller()
		if status_controller != null and status_data != null:
			status_controller.remove_status_source(status_data.id, key)

	active_records.erase(key)


func _on_owner_damage_taken(damage_data: DamageData, key: String) -> void:
	if not active_records.has(key):
		return
	if not _damage_matches(damage_data):
		return

	var record: Dictionary = active_records[key] as Dictionary
	var owner: Entity = record.get("owner") as Entity
	if owner == null or not is_instance_valid(owner) or owner.is_dead:
		active_records.erase(key)
		return

	var current_extra_stacks: int = int(record.get("extra_stacks", 0))
	var extra_stack_limit: int = int(record.get("max_extra_stacks", 0))
	if current_extra_stacks >= extra_stack_limit:
		return

	var add_amount: int = min(max(extra_stacks_per_damage, 0), extra_stack_limit - current_extra_stacks)
	if add_amount <= 0:
		return

	var status_controller: StatusController = owner.get_status_controller()
	if status_controller == null:
		return

	status_controller.add_status(status_data, owner, key, add_amount, duration_override)
	record["extra_stacks"] = current_extra_stacks + add_amount
	active_records[key] = record


func _damage_matches(damage_data: DamageData) -> bool:
	if damage_data == null:
		return false
	if require_positive_damage and damage_data.final_damage <= 0.0:
		return false
	for required_damage_type: int in required_damage_types:
		if not damage_data.damage_types.has(required_damage_type):
			return false
	return true


func _get_max_extra_stacks(relic_context: RelicContext) -> int:
	if relic_context != null and relic_context.own_relic != null:
		if relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
			return max(levelup_max_extra_stacks, 0)
	return max(max_extra_stacks, 0)


func _disconnect_pending_battle_callback(key: String) -> void:
	if not pending_battle_callbacks.has(key):
		return

	var callback: Callable = pending_battle_callbacks[key] as Callable
	if EventBus.battle_started.is_connected(callback):
		EventBus.battle_started.disconnect(callback)
	pending_battle_callbacks.erase(key)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
