## 消耗品使用时获得金币。
## 适合药剂、宝箱、幸运袋等一次性金币收益。
class_name UseGoldEffect
extends RelicEffect

@export var gold_amount: int = 1


func on_use(relic_context: RelicContext, _effect_key) -> void:
	if gold_amount == 0:
		return

	var run_stats := _resolve_run_stats(relic_context.owner if relic_context != null else null)
	if run_stats == null:
		return

	run_stats.set_gold(run_stats.gold + gold_amount)


func _resolve_run_stats(owner: Node) -> RunStats:
	var node := owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()

	return null
