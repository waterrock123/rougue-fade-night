class_name BattleStats
extends Resource

# 这场战斗的层级信息，后面可以拿来做掉落、难度或奖励缩放。
@export var battle_tier: int
#战斗的权重
@export var weight:float
# 兼容旧版单波配置。
# 如果没有填写 waves，就会自动把下面这些字段包装成一波战斗来处理。
@export_group("Legacy")
@export var packed_enemies: Array[PackedScene] = []
@export var max_enemies: int = 0
@export var spawn_interval: float = 5.0
@export var spawn_batch_size: int = 1
@export var next_wave_delay: float = 0.0
@export var advance_mode: BattleWaveData.AdvanceMode = BattleWaveData.AdvanceMode.CLEAR_PREVIOUS

@export_group("Waves")
@export var waves: Array[BattleWaveData] = []


# 返回当前这场战斗总共有多少波。
func get_wave_count() -> int:
	if not waves.is_empty():
		return waves.size()

	if packed_enemies.is_empty() or max_enemies <= 0:
		return 0

	return 1


# 获取指定索引的波次数据。
# 如果没有显式配置 waves，就按旧字段动态构造第 0 波。
func get_wave_data(index: int) -> BattleWaveData:
	if not waves.is_empty():
		if index < 0 or index >= waves.size():
			return null
		return waves[index]

	if index != 0 or packed_enemies.is_empty() or max_enemies <= 0:
		return null

	var legacy_wave := BattleWaveData.new()
	legacy_wave.packed_enemies = packed_enemies.duplicate()
	legacy_wave.max_enemies = max_enemies
	legacy_wave.spawn_interval = spawn_interval
	legacy_wave.spawn_batch_size = spawn_batch_size
	legacy_wave.next_wave_delay = next_wave_delay
	legacy_wave.advance_mode = advance_mode
	return legacy_wave
