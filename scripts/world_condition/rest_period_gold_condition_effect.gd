## 天气效果：进入修整期时获得额外金币。
## 可复用于钞票雨、丰收季等所有修整期金币类规则。
class_name RestPeriodGoldConditionEffect
extends WorldConditionEffect

@export var gold_amount: int = 3


func on_rest_period_entered(run_stats: RunStats) -> void:
	if run_stats == null or gold_amount == 0:
		return
	run_stats.set_gold(run_stats.gold + gold_amount)
