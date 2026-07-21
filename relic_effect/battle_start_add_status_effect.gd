@tool
class_name BattleStartAddStatusEffect
extends RelicEffect

## 战斗开始时为拥有者添加一个 status。
## 适合装备/被动在进入战斗时获得固定层数的状态，例如电涌核心升级后的电力。

@export var status_data: StatusData
@export var stacks: int = 1
@export var duration_override: float = INF

var _applied_records: Dictionary = {}
var _pending_contexts: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	var owner_entity: Entity = _get_owner_entity(context)
	if owner_entity == null or status_data == null or stacks <= 0:
		return

	var key: String = _make_key(context, effect_key)
	if _applied_records.has(key) or _pending_contexts.has(key):
		return

	if EventBus.is_battle_active:
		_apply_status(owner_entity, key)
		return

	# 装备效果可能在修整期就被激活，这里等待下一次战斗真正开始再添加状态。
	_pending_contexts[key] = owner_entity
	if not EventBus.battle_started.is_connected(_on_battle_started):
		EventBus.battle_started.connect(_on_battle_started)


func on_deactivate(context: RelicContext, effect_key) -> void:
	var key: String = _make_key(context, effect_key)
	_pending_contexts.erase(key)
	_remove_status_source(key)

	if _pending_contexts.is_empty() and EventBus.battle_started.is_connected(_on_battle_started):
		EventBus.battle_started.disconnect(_on_battle_started)


func _on_battle_started(_payload: Variant = null) -> void:
	var pending_keys: Array = _pending_contexts.keys()
	for key_variant: Variant in pending_keys:
		var key: String = str(key_variant)
		var owner_candidate = _pending_contexts.get(key, null)
		if owner_candidate != null and is_instance_valid(owner_candidate) and owner_candidate is Entity:
			var owner_entity: Entity = owner_candidate as Entity
			_apply_status(owner_entity, key)
		_pending_contexts.erase(key)

	if EventBus.battle_started.is_connected(_on_battle_started):
		EventBus.battle_started.disconnect(_on_battle_started)


func _apply_status(owner_entity: Entity, key: String) -> void:
	if owner_entity == null or not is_instance_valid(owner_entity) or owner_entity.is_dead:
		return

	var status_controller: StatusController = owner_entity.get_status_controller()
	if status_controller == null:
		return

	status_controller.add_status(status_data, owner_entity, key, stacks, duration_override)
	_applied_records[key] = owner_entity


func _remove_status_source(key: String) -> void:
	if not _applied_records.has(key):
		return

	var owner_candidate = _applied_records.get(key, null)
	if owner_candidate != null and is_instance_valid(owner_candidate) and owner_candidate is Entity:
		var owner_entity: Entity = owner_candidate as Entity
		var status_controller: StatusController = owner_entity.get_status_controller()
		if status_controller != null and status_data != null:
			status_controller.remove_status_source(status_data.id, key)

	_applied_records.erase(key)


func _get_owner_entity(context: RelicContext) -> Entity:
	if context == null:
		return null
	if context.owner is Entity:
		return context.owner as Entity
	return null


func _make_key(context: RelicContext, effect_key) -> String:
	var key_text: String = str(effect_key)
	if not key_text.is_empty():
		return key_text
	if context == null:
		return str(get_instance_id())
	return "%s:%s" % [str(context.relic_key), str(get_instance_id())]
