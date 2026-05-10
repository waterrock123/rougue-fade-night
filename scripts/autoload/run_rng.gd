extends Node

const DEFAULT_SEED_MIN := 100000
const DEFAULT_SEED_MAX := 999999999

var rng := RandomNumberGenerator.new()
var seed_value: int = 0


# 开始一局新游戏时初始化“本局随机流”。
# 这条随机流只给地图、商店、事件等局外/非战斗内容使用，战斗内随机不要接入这里。
func start_new_run(custom_seed: int = 0) -> void:
	if custom_seed == 0:
		rng.randomize()
		seed_value = rng.randi_range(DEFAULT_SEED_MIN, DEFAULT_SEED_MAX)
	else:
		seed_value = custom_seed

	rng.seed = seed_value


# 读档时恢复随机数状态，保证商店/地图后续随机继续沿着同一条序列推进。
func restore_from_save(saved_seed: int, saved_state: int) -> void:
	seed_value = saved_seed
	rng.seed = seed_value
	rng.state = saved_state


func get_save_data() -> Dictionary:
	return {
		"seed": seed_value,
		"state": rng.state,
	}


func randf() -> float:
	return rng.randf()


func randf_range(from: float, to: float) -> float:
	return rng.randf_range(from, to)


func randi_range(from: int, to: int) -> int:
	return rng.randi_range(from, to)


func pick(array: Array):
	if array.is_empty():
		return null

	return array[rng.randi_range(0, array.size() - 1)]


# 使用 Fisher-Yates 洗牌，避免调用数组自带 shuffle 时跑到全局随机流。
func shuffle_array(array: Array) -> void:
	for index in range(array.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp = array[index]
		array[index] = array[swap_index]
		array[swap_index] = temp
