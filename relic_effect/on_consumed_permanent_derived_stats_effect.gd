class_name OnConsumedPermanentDerivedStatsEffect
extends RelicEffect

## 装备被“消耗”时永久增加派生属性，例如永久增加 2% 减伤率。
@export var add_derived_stats: Dictionary = {}


func on_consumed(relic_context: RelicContext, effect_key) -> void:
	if add_derived_stats.is_empty():
		return

	# 复用已有的永久派生属性实现，避免“使用消耗品”和“被工具消耗”各写一套逻辑。
	var permanent_effect: UsePermanentDerivedStatsEffect = UsePermanentDerivedStatsEffect.new()
	permanent_effect.add_derived_stats = add_derived_stats
	permanent_effect.on_use(relic_context, effect_key)

