## 破韧触发类遗物效果的公共基类。
## 只负责监听全局破韧事件、确认破韧者归属并管理连接生命周期；具体收益由子类实现。
class_name PoiseBreakRelicEffect
extends RelicEffect


@export_group("触发条件")
## 开启后，只有装备持有者亲自造成的破韧才会触发效果。
@export var require_owner_as_breaker: bool = true

var _active_connections: Dictionary = {}


## 装备生效时开始监听破韧事件。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	var effect_owner: Entity = _get_owner_entity(relic_context)
	if effect_owner == null:
		return

	var key: String = str(effect_key)
	if _active_connections.has(key):
		return

	var is_levelup: bool = (
		relic_context.own_relic != null
		and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP
	)
	var callback: Callable = Callable(self, "_on_enemy_poise_broken").bind(effect_owner, key, is_levelup)
	EventBus.enemy_poise_broken.connect(callback)
	_active_connections[key] = {
		"owner": effect_owner,
		"callback": callback,
	}


## 遗物卸下或场景退出时断开监听，避免效果残留到下一场战斗。
func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	var entry: Dictionary = _active_connections.get(key, {}) as Dictionary
	if entry.is_empty():
		return

	var callback: Callable = entry.get("callback", Callable()) as Callable
	if callback.is_valid() and EventBus.enemy_poise_broken.is_connected(callback):
		EventBus.enemy_poise_broken.disconnect(callback)
	_active_connections.erase(key)


## 统一过滤无效目标与非持有者破韧，再把事件交给子类。
func _on_enemy_poise_broken(
	broken_enemy: Entity,
	breaker: Entity,
	damage_data: DamageData,
	effect_owner: Entity,
	effect_key: String,
	is_levelup: bool
) -> void:
	if effect_owner == null or not is_instance_valid(effect_owner) or effect_owner.is_dead:
		return
	if broken_enemy == null or not is_instance_valid(broken_enemy) or broken_enemy.is_dead:
		return
	if require_owner_as_breaker and breaker != effect_owner:
		return

	apply_poise_break_effect(effect_owner, broken_enemy, damage_data, effect_key, is_levelup)


## 子类覆写此方法，实现各自独立的破韧收益。
func apply_poise_break_effect(
	_owner: Entity,
	_broken_enemy: Entity,
	_damage_data: DamageData,
	_effect_key: String,
	_is_levelup: bool
) -> void:
	pass


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
