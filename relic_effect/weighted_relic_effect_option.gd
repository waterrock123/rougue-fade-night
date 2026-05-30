## 遗物随机效果选项。
## 它只负责描述“一个随机结果”的权重、是否只在升级态出现，以及命中后要执行哪些遗物效果。
class_name WeightedRelicEffectOption
extends Resource

@export var option_name: String = ""
@export var weight: float = 1.0
@export var require_levelup: bool = false
@export var effects: Array[RelicEffect] = []


func is_available(relic_context: RelicContext) -> bool:
	if weight <= 0.0:
		return false
	if require_levelup:
		return relic_context != null \
			and relic_context.own_relic != null \
			and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP
	return true


func apply_on_use(relic_context: RelicContext, option_key: String) -> void:
	for effect_index in range(effects.size()):
		var effect := effects[effect_index]
		if effect == null:
			continue

		var child_key := "%s_effect_%s" % [option_key, effect_index]
		effect.on_use(relic_context, child_key)
