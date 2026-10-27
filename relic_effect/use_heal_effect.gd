## 消耗品使用时治疗拥有者的效果。
## 治疗量会被限制在最大生命值以内，并同步玩家生命 UI。
class_name UseHealEffect
extends RelicEffect


## 使用时恢复的生命值。
@export var heal_amount: float = 1.0
## 升级态的替换治疗量；-1 保持原值，避免在 great_effects 中叠加造成重复治疗反馈。
@export var upgraded_heal_amount: float = -1.0


## 使用消耗品时恢复生命值。
## 治疗会被限制在最大生命值以内，并同步 StatsController 与玩家生命 UI。
func on_use(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	var amount: float = heal_amount
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP and upgraded_heal_amount >= 0.0:
		amount = upgraded_heal_amount
	if amount <= 0.0:
		return

	var owner := relic_context.owner as Entity
	owner.apply_heal(amount)
