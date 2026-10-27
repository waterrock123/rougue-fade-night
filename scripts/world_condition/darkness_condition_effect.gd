## 环境效果：开启战斗黑暗遮罩，只保留玩家周围的可见区域。
class_name DarknessConditionEffect
extends WorldConditionEffect

@export_range(40.0, 1000.0, 1.0) var vision_radius: float = 190.0
@export_range(0.0, 500.0, 1.0) var edge_softness: float = 90.0
@export_range(0.0, 1.0, 0.01) var darkness_alpha: float = 0.9


func apply_to_battle(battle_scene: Node, _run_stats: RunStats) -> void:
	if battle_scene != null and battle_scene.has_method("setup_darkness_environment"):
		battle_scene.call("setup_darkness_environment", vision_radius, edge_softness, darkness_alpha)
