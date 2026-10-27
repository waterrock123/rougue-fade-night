## 天气/环境效果基类。
## 每个效果只负责一个触发时机，避免把金币、战斗视觉等逻辑写死在状态数据中。
class_name WorldConditionEffect
extends Resource


func on_rest_period_entered(_run_stats: RunStats) -> void:
	pass


func apply_to_battle(_battle_scene: Node, _run_stats: RunStats) -> void:
	pass
