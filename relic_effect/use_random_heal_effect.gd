## 消耗品使用时随机治疗一定生命值。
## 适合“恢复 2 至 8 点生命”这类带波动的治疗效果。
class_name UseRandomHealEffect
extends RelicEffect

@export var min_heal_amount: int = 1
@export var max_heal_amount: int = 1


func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return

	var from_amount = min(min_heal_amount, max_heal_amount)
	var to_amount = max(min_heal_amount, max_heal_amount)
	var heal_amount := float(randi_range(from_amount, to_amount))
	_heal_owner(relic_context.owner as Entity, heal_amount)


func _heal_owner(owner: Entity, heal_amount: float) -> void:
	if owner == null or heal_amount <= 0.0:
		return

	owner.apply_heal(heal_amount)
