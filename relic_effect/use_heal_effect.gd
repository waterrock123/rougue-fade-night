## 消耗品使用时治疗拥有者的效果。
## 治疗量会被限制在最大生命值以内，并同步玩家生命 UI。
class_name UseHealEffect
extends RelicEffect


## 使用时恢复的生命值。
@export var heal_amount: float = 1.0


## 使用消耗品时恢复生命值。
## 治疗会被限制在最大生命值以内，并同步 StatsController 与玩家生命 UI。
func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if heal_amount <= 0.0:
		return

	var owner := relic_context.owner as Entity
	owner.apply_heal(heal_amount)
