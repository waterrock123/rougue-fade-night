## 消耗品使用时按“已损失生命值”的比例治疗。
## 例如 0.3 表示恢复当前已损生命的 30%。
class_name UseHealMissingHealthPercentEffect
extends RelicEffect

@export_range(0.0, 1.0, 0.01) var heal_missing_percent: float = 0.3
@export var min_heal_amount: float = 0.0
@export var ignore_when_relic_levelup: bool = false


func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if ignore_when_relic_levelup and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return

	var owner := relic_context.owner as Entity
	var missing_health = max(owner.get_runtime_max_health() - owner.current_health, 0.0)
	var heal_amount = max(missing_health * heal_missing_percent, min_heal_amount)
	if heal_amount <= 0.0:
		return

	owner.apply_heal(heal_amount)
