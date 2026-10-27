## 单个天气或环境的数据资源。
class_name WorldConditionData
extends Resource

enum ConditionType {
	WEATHER,
	ENVIRONMENT,
}

@export var condition_id: StringName
@export var condition_type: ConditionType = ConditionType.WEATHER
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export_range(0.0, 1000.0, 0.1) var roll_weight: float = 1.0
@export_range(1, 99, 1) var min_duration_rooms: int = 1
@export_range(1, 99, 1) var max_duration_rooms: int = 1
@export var effects: Array[WorldConditionEffect] = []


func roll_duration_rooms() -> int:
	var safe_min: int = max(min_duration_rooms, 1)
	var safe_max: int = max(max_duration_rooms, safe_min)
	return RunRng.randi_range(safe_min, safe_max)


func apply_rest_period_effects(run_stats: RunStats) -> void:
	for effect: WorldConditionEffect in effects:
		if effect != null:
			effect.on_rest_period_entered(run_stats)


func apply_battle_effects(battle_scene: Node, run_stats: RunStats) -> void:
	for effect: WorldConditionEffect in effects:
		if effect != null:
			effect.apply_to_battle(battle_scene, run_stats)
