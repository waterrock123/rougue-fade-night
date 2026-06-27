## 遗物效果：战斗开始时按概率生成一只悬赏精英怪。
## 适合“升级后有概率出现悬赏怪”“诅咒物品引来强敌”这类战斗开场事件。
class_name BattleStartBountyEnemyChanceEffect
extends RelicEffect

const DEFAULT_BOUNTY_ENEMY_POOL := preload("res://custom_resource/default_bounty_enemy_pool.tres")

@export_range(0.0, 1.0, 0.01) var chance: float = 0.5
@export var bounty_enemy_pool: BountyEnemyPool = DEFAULT_BOUNTY_ENEMY_POOL
## 大于 0 时覆盖悬赏金币；小于等于 0 时使用悬赏池条目自己的金币。
@export var bounty_gold_override: int = 0
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var use_owner_position: bool = false

var active_callbacks: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner(relic_context)
	if owner == null:
		return

	var key: String = str(effect_key)
	if active_callbacks.has(key):
		return

	if EventBus.is_battle_active:
		_on_battle_started(relic_context, key)
		return

	var callback: Callable = Callable(self, "_on_battle_started").bind(relic_context, key)
	EventBus.battle_started.connect(callback, CONNECT_ONE_SHOT)
	active_callbacks[key] = callback


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	if not active_callbacks.has(key):
		return

	var callback: Callable = active_callbacks[key] as Callable
	if EventBus.battle_started.is_connected(callback):
		EventBus.battle_started.disconnect(callback)
	active_callbacks.erase(key)


func _on_battle_started(relic_context: RelicContext, effect_key: String) -> void:
	active_callbacks.erase(effect_key)
	if randf() > chance:
		return

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

	var use_custom_position: bool = use_owner_position
	var spawn_position: Vector2 = owner.global_position + spawn_offset
	var enemy: Enemy = spawner.spawn_bounty_enemy(entry, spawn_position, use_custom_position)
	if enemy != null and bounty_gold_override > 0:
		enemy.bounty_gold = bounty_gold_override


func _get_random_entry() -> BountyEnemyEntry:
	var pool: BountyEnemyPool = bounty_enemy_pool
	if pool == null:
		pool = DEFAULT_BOUNTY_ENEMY_POOL
	return pool.get_random_entry()


func _get_owner(relic_context: RelicContext) -> Entity:
	if relic_context == null:
		return null
	if not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
