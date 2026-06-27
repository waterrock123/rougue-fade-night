## 消耗品使用时按最大生命值百分比治疗。
## 和“已损生命百分比治疗”分开，方便药水、料理等效果复用。
class_name UseHealMaxHealthPercentEffect
extends RelicEffect

@export_range(0.0, 1.0, 0.01) var heal_percent: float = 0.25


func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if heal_percent <= 0.0:
		return

	var owner := relic_context.owner as Entity
	var heal_amount := owner.get_runtime_max_health() * heal_percent
	owner.apply_heal(heal_amount)
