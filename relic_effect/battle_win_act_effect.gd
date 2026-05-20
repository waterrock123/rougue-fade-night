## 战斗胜利触发的遗物效果示例。
## 当前逻辑用于在战斗胜利时提高遗物自身出售价格。
class_name BattleWinActEffect
extends RelicEffect


## 获得遗物时注册战斗胜利监听。
func on_gain(relic_context: RelicContext, effect_key) -> void:
	EventBus.battle_win.connect(price_up(relic_context))


## 这类效果不需要装备激活时额外处理。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	pass


## 这类效果当前没有失效清理逻辑。
func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	pass


## 提高遗物自身出售价格。
func price_up(relic_context: RelicContext):
	var relic = relic_context.own_relic
	relic.sell_price += 1
