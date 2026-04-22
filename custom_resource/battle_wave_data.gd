class_name BattleWaveData
extends Resource

enum AdvanceMode {
	TIME,
	CLEAR_PREVIOUS,
}

# 这一波允许生成的敌人池。
@export var packed_enemies: Array[PackedScene] = []
# 这一波总共要生成多少敌人。
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
