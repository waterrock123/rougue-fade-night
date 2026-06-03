class_name BountyEnemyEntry
extends Resource

## 悬赏精英怪池子中的一个条目。
## 装备、技能或 EnemySpawner 都可以从 BountyEnemyPool 中抽取这个条目来生成悬赏怪。
@export var enemy_scene: PackedScene
@export var bounty_gold: int = 8
@export var weight: float = 1.0
@export var starts_neutral: bool = true
@export var neutral_speed_multiplier: float = 0.45
@export var neutral_wander_radius: float = 120.0
@export var neutral_wander_repick_interval: float = 1.8


func is_valid_entry() -> bool:
	return enemy_scene != null and weight > 0.0


func apply_to_enemy(enemy: Enemy) -> void:
	if enemy == null:
		return

	enemy.configure_bounty_elite(
		bounty_gold,
		starts_neutral,
		neutral_speed_multiplier,
		neutral_wander_radius,
		neutral_wander_repick_interval
	)
