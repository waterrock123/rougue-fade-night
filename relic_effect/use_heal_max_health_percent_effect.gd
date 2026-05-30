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
	var heal_amount := owner.max_health * heal_percent
	owner.current_health = min(owner.current_health + heal_amount, owner.max_health)

	if owner.stats_controller != null:
		owner.stats_controller.current_health = owner.current_health
		owner.stats_controller.sync_runtime_resources()

	if owner.is_in_group("player"):
		EventBus.player_health_changed.emit(owner.current_health, owner.max_health)
