## 战斗胜利结算时按已损失生命值治疗的通用遗物效果。
## 适合“水桶”这类升级后根据战后损血量回复的装备。
class_name BattleWinMissingHealthHealEffect
extends RelicEffect


## 回复比例。0.2 表示回复已损失生命值的 20%。
@export_range(0.0, 1.0, 0.01) var missing_health_percent: float = 0.2

var active_contexts: Dictionary = {}


## 只在战斗实体身上注册，避免常驻的 PlayerBuildProxy 和战斗 Player 重复触发。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	if _get_owner_entity(relic_context) == null:
		return

	active_contexts[str(effect_key)] = relic_context
	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	_disconnect_if_idle()


func _on_battle_rewards_resolving() -> void:
	var contexts := active_contexts.duplicate()
	active_contexts.clear()
	_disconnect_if_idle()

	for context_value in contexts.values():
		_heal_missing_health(context_value as RelicContext)


func _heal_missing_health(relic_context: RelicContext) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null or missing_health_percent <= 0.0:
		return

	var missing_health = max(owner.get_runtime_max_health() - owner.current_health, 0.0)
	var heal_amount = missing_health * missing_health_percent
	if heal_amount <= 0.0:
		return

	owner.apply_heal(heal_amount)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null

	return relic_context.owner as Entity


func _disconnect_if_idle() -> void:
	if active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)
