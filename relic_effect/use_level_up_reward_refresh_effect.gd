## 消耗品使用时获得升级奖励刷新次数。
## 刷新次数储存在 RunStats 中，因此可以跨场景保存。
class_name UseLevelUpRewardRefreshEffect
extends RelicEffect

@export var refresh_count: int = 1


func on_use(relic_context: RelicContext, _effect_key) -> void:
	if refresh_count <= 0:
		return

	var run_stats := _resolve_run_stats(relic_context.owner if relic_context != null else null)
	if run_stats == null:
		return

	run_stats.add_level_up_reward_refresh_count(refresh_count)


func _resolve_run_stats(owner: Node) -> RunStats:
	var node := owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()

	return null
