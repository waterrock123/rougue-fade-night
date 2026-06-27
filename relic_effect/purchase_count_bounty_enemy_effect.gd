## 遗物效果：修整期购买达到指定次数后，登记下一场战斗生成悬赏精英怪。
## 适合“购物太显眼，引来强敌围猎”的运营型装备效果；每个修整期可限制触发次数。
class_name PurchaseCountBountyEnemyEffect
extends RelicEffect

const DEFAULT_BOUNTY_ENEMY_POOL := preload("res://custom_resource/default_bounty_enemy_pool.tres")

@export var purchase_threshold: int = 5
@export var max_triggers_per_rest_period: int = 1
@export var bounty_enemy_pool: BountyEnemyPool = DEFAULT_BOUNTY_ENEMY_POOL
## 大于 0 时覆盖悬赏金币；小于等于 0 时使用悬赏池条目自己的金币。
@export var bounty_gold_override: int = 0
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var use_owner_position: bool = false

var active_contexts: Dictionary = {}
var purchases_since_trigger: int = 0
var triggers_this_rest_period: int = 0
var pending_bounty_spawns: int = 0
var battle_callbacks: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	active_contexts[key] = relic_context

	if not EventBus.relic_purchased.is_connected(_on_relic_purchased):
		EventBus.relic_purchased.connect(_on_relic_purchased)
	if not EventBus.rest_period_started.is_connected(_on_rest_period_started):
		EventBus.rest_period_started.connect(_on_rest_period_started)

	_connect_battle_start_if_needed(key, relic_context)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	active_contexts.erase(key)
	_disconnect_battle_callback(key)

	if active_contexts.is_empty():
		if EventBus.relic_purchased.is_connected(_on_relic_purchased):
			EventBus.relic_purchased.disconnect(_on_relic_purchased)
		if EventBus.rest_period_started.is_connected(_on_rest_period_started):
			EventBus.rest_period_started.disconnect(_on_rest_period_started)


func _on_rest_period_started() -> void:
	# 每个修整期重新允许触发，但保留未进入战斗的待刷怪次数。
	purchases_since_trigger = 0
	triggers_this_rest_period = 0


func _on_relic_purchased(_relic: Relic) -> void:
	if active_contexts.is_empty():
		return
	if _has_reached_rest_period_limit():
		return

	purchases_since_trigger += 1
	if purchases_since_trigger < max(purchase_threshold, 1):
		return

	purchases_since_trigger = 0
	triggers_this_rest_period += 1
	pending_bounty_spawns += 1
	_connect_all_battle_start_callbacks()


func _connect_all_battle_start_callbacks() -> void:
	for key in active_contexts.keys():
		var relic_context: RelicContext = active_contexts[key] as RelicContext
		_connect_battle_start_if_needed(String(key), relic_context)


func _connect_battle_start_if_needed(key: String, relic_context: RelicContext) -> void:
	if pending_bounty_spawns <= 0:
		return
	if battle_callbacks.has(key):
		return
	if relic_context == null:
		return

	if EventBus.is_battle_active:
		_on_battle_started(relic_context, key)
		return

	var callback: Callable = Callable(self, "_on_battle_started").bind(relic_context, key)
	EventBus.battle_started.connect(callback, CONNECT_ONE_SHOT)
	battle_callbacks[key] = callback


func _disconnect_battle_callback(key: String) -> void:
	if not battle_callbacks.has(key):
		return

	var callback: Callable = battle_callbacks[key] as Callable
	if EventBus.battle_started.is_connected(callback):
		EventBus.battle_started.disconnect(callback)
	battle_callbacks.erase(key)


func _on_battle_started(relic_context: RelicContext, effect_key: String) -> void:
	battle_callbacks.erase(effect_key)
	if pending_bounty_spawns <= 0:
		return

	var spawn_count: int = pending_bounty_spawns
	pending_bounty_spawns = 0
	for _index in range(spawn_count):
		_spawn_bounty_enemy(relic_context)


func _spawn_bounty_enemy(relic_context: RelicContext) -> void:
	var owner: Entity = _get_owner(relic_context)
	if owner == null:
		return

	var spawner: EnemySpawner = owner.get_tree().get_first_node_in_group("enemy_spawner") as EnemySpawner
	if spawner == null:
		return

	var entry: BountyEnemyEntry = _get_random_entry()
	if entry == null:
		return

	var spawn_position: Vector2 = owner.global_position + spawn_offset
	var enemy: Enemy = spawner.spawn_bounty_enemy(entry, spawn_position, use_owner_position)
	if enemy != null and bounty_gold_override > 0:
		enemy.bounty_gold = bounty_gold_override


func _get_random_entry() -> BountyEnemyEntry:
	var pool: BountyEnemyPool = bounty_enemy_pool
	if pool == null:
		pool = DEFAULT_BOUNTY_ENEMY_POOL
	return pool.get_random_entry()


func _has_reached_rest_period_limit() -> bool:
	if max_triggers_per_rest_period <= 0:
		return false
	return triggers_this_rest_period >= max_triggers_per_rest_period


func _get_owner(relic_context: RelicContext) -> Entity:
	if relic_context == null:
		return null
	if not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
