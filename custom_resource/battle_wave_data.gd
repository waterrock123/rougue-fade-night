class_name BattleWaveData
extends Resource

enum AdvanceMode {
	TIME,
	CLEAR_PREVIOUS,
}

# 这一波会按顺序执行的固定生成条目。
# Boss 战建议优先使用这里：例如 Boss x1、护卫 x2、远程小怪 x4。
@export_group("Fixed Spawns")
@export var fixed_spawns: Array[EnemySpawnEntry] = []

@export_group("Random Pool")
# 这一波允许随机生成的敌人池。
# 保留旧字段，普通战斗可以继续用；Boss 战可以把 max_enemies 设为 0，只用 fixed_spawns。
@export var packed_enemies: Array[PackedScene] = []
# 这一波从随机池中总共生成多少敌人。
@export var max_enemies: int = 0
# 两次生成之间的时间间隔。
@export var spawn_interval: float = 1.0
# 每次到点时一口气生成多少只敌人。
@export var spawn_batch_size: int = 1
# 当前波次结束后，进入下一波前的额外等待时间。
@export var next_wave_delay: float = 0.0
# 控制下一波的推进方式：
# TIME 表示按时间推进；
# CLEAR_PREVIOUS 表示必须清完当前波敌人后再推进。
@export var advance_mode: AdvanceMode = AdvanceMode.CLEAR_PREVIOUS


# 固定编排和随机池的总生成数量。
func get_total_spawn_count() -> int:
	var total = max(max_enemies, 0) if has_random_pool() else 0
	for entry in fixed_spawns:
		if entry != null and entry.is_valid_entry():
			total += max(entry.count, 0)
	return total


func has_random_pool() -> bool:
	return not packed_enemies.is_empty() and max_enemies > 0
