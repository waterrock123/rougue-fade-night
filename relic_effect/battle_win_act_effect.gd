class_name  BattleWinActEffect
extends RelicEffect

#随战斗胜利时触发遗物本身价格+1的效果


# 获得遗物时触发。
# 适合做一次性的注册、监听或初始化逻辑。
func on_gain(relic_context:RelicContext,effect_key) -> void:
	EventBus.battle_win.connect(price_up(relic_context))


# 遗物处于“已装备/已激活”状态时触发。
# 大多数常驻装备效果都会在这里生效。
func on_activate(relic_context:RelicContext,effect_key) -> void:
	pass


# 遗物失效或卸下时触发。
# 这里负责清理 on_activate 时创建的效果。
func on_deactivate(relic_context:RelicContext,effect_key) -> void:
	pass


func price_up(relic_context:RelicContext):
	var relic = relic_context.own_relic
	relic.sell_price += 1
	
