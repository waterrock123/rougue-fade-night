## 战斗胜利后提升遗物自身出售价格的通用效果。
## 目前用于“猪猪存钱罐”的升级态：携带并打赢一场战斗后，出售价值永久 +1。
class_name BattleWinActEffect
extends RelicEffect


## 每次战斗胜利后提升的出售价格。
@export var sell_price_bonus_per_win: int = 1

var active_contexts: Dictionary = {}


## 只让战斗中的实体注册胜利结算，避免 Run 里的 PlayerBuildProxy 和战斗 Player 重复结算。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	if _get_owner_entity(relic_context) == null:
		return
	if sell_price_bonus_per_win <= 0:
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
		_increase_relic_sell_price(context_value as RelicContext)


func _increase_relic_sell_price(relic_context: RelicContext) -> void:
	if relic_context == null or relic_context.own_relic == null:
		return

	relic_context.own_relic.sell_price += sell_price_bonus_per_win


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null

	return relic_context.owner as Entity


func _disconnect_if_idle() -> void:
	if active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)
