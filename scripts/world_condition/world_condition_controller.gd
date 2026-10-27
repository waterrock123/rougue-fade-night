## 本局天气/环境控制器。
## 两类状态独立抽取、独立倒计时；有效状态不会在离开修整期时被提前覆盖。
class_name WorldConditionController
extends Node

const SUNNY_WEATHER := preload("res://world_conditions/weather/sunny.tres")
const MONEY_RAIN_WEATHER := preload("res://world_conditions/weather/money_rain.tres")
const NORMAL_ENVIRONMENT := preload("res://world_conditions/environment/normal.tres")
const DARKNESS_ENVIRONMENT := preload("res://world_conditions/environment/darkness.tres")

var run_stats: RunStats
var weather_pool: Array[WorldConditionData] = [SUNNY_WEATHER, MONEY_RAIN_WEATHER]
var environment_pool: Array[WorldConditionData] = [NORMAL_ENVIRONMENT, DARKNESS_ENVIRONMENT]


func bind_run_stats(new_run_stats: RunStats) -> void:
	run_stats = new_run_stats
	_normalize_saved_conditions()
	_notify_changed()


# 离开修整期时，仅为空缺的类型抽取新状态。
func roll_conditions_after_rest() -> void:
	if run_stats == null:
		return

	if run_stats.weather_remaining_rooms <= 0:
		var weather := _pick_weighted_condition(weather_pool)
		_set_weather(weather)
	if run_stats.environment_remaining_rooms <= 0:
		var environment := _pick_weighted_condition(environment_pool)
		_set_environment(environment)

	_notify_changed()


## 装备/事件强制触发一项非默认状态，使用本局种子和已有资源权重，覆盖同类状态。
func trigger_random_condition(include_weather: bool = true, include_environment: bool = true) -> WorldConditionData:
	if run_stats == null:
		return null
	var candidates: Array[WorldConditionData] = []
	if include_weather:
		_collect_special_conditions(weather_pool, SUNNY_WEATHER.condition_id, candidates)
	if include_environment:
		_collect_special_conditions(environment_pool, NORMAL_ENVIRONMENT.condition_id, candidates)
	var selected: WorldConditionData = _pick_weighted_condition(candidates)
	if selected == null:
		return null
	if selected.condition_type == WorldConditionData.ConditionType.WEATHER:
		_set_weather(selected)
	else:
		_set_environment(selected)
	_notify_changed()
	return selected


func _collect_special_conditions(pool: Array[WorldConditionData], default_id: StringName, result: Array[WorldConditionData]) -> void:
	for condition: WorldConditionData in pool:
		if condition != null and condition.condition_id != default_id and condition.roll_weight > 0.0:
			result.append(condition)


# 完成一个房间进入修整期时，先结算效果，再消耗持续房间数。
func settle_completed_room() -> void:
	if run_stats == null:
		return

	var weather := get_active_weather()
	if weather != null and run_stats.weather_remaining_rooms > 0:
		weather.apply_rest_period_effects(run_stats)
		run_stats.weather_remaining_rooms = max(run_stats.weather_remaining_rooms - 1, 0)
		if run_stats.weather_remaining_rooms == 0:
			run_stats.active_weather_id = SUNNY_WEATHER.condition_id

	var environment := get_active_environment()
	if environment != null and run_stats.environment_remaining_rooms > 0:
		environment.apply_rest_period_effects(run_stats)
		run_stats.environment_remaining_rooms = max(run_stats.environment_remaining_rooms - 1, 0)
		if run_stats.environment_remaining_rooms == 0:
			run_stats.active_environment_id = NORMAL_ENVIRONMENT.condition_id

	_notify_changed()


func apply_to_battle(battle_scene: Node) -> void:
	if run_stats == null or battle_scene == null:
		return
	if battle_scene.has_method("clear_darkness_environment"):
		battle_scene.call("clear_darkness_environment")

	var weather := get_active_weather()
	if weather != null:
		weather.apply_battle_effects(battle_scene, run_stats)
	var environment := get_active_environment()
	if environment != null:
		environment.apply_battle_effects(battle_scene, run_stats)


func get_active_weather() -> WorldConditionData:
	if run_stats == null:
		return SUNNY_WEATHER
	return _find_condition(weather_pool, run_stats.active_weather_id, SUNNY_WEATHER)


func get_active_environment() -> WorldConditionData:
	if run_stats == null:
		return NORMAL_ENVIRONMENT
	return _find_condition(environment_pool, run_stats.active_environment_id, NORMAL_ENVIRONMENT)


## 调试台直接指定两类状态与剩余房间数；不会消耗随机种子。
func set_debug_conditions(weather: WorldConditionData, weather_rooms: int, environment: WorldConditionData, environment_rooms: int) -> bool:
	if run_stats == null or weather == null or environment == null:
		return false
	if _find_condition(weather_pool, weather.condition_id, null) == null:
		return false
	if _find_condition(environment_pool, environment.condition_id, null) == null:
		return false
	run_stats.weather_remaining_rooms = clampi(weather_rooms, 0, 99)
	run_stats.environment_remaining_rooms = clampi(environment_rooms, 0, 99)
	run_stats.active_weather_id = weather.condition_id if run_stats.weather_remaining_rooms > 0 else SUNNY_WEATHER.condition_id
	run_stats.active_environment_id = environment.condition_id if run_stats.environment_remaining_rooms > 0 else NORMAL_ENVIRONMENT.condition_id
	_notify_changed()
	return true


func _set_weather(weather: WorldConditionData) -> void:
	if run_stats == null:
		return
	var selected := weather if weather != null else SUNNY_WEATHER
	run_stats.active_weather_id = selected.condition_id
	run_stats.weather_remaining_rooms = selected.roll_duration_rooms()


func _set_environment(environment: WorldConditionData) -> void:
	if run_stats == null:
		return
	var selected := environment if environment != null else NORMAL_ENVIRONMENT
	run_stats.active_environment_id = selected.condition_id
	run_stats.environment_remaining_rooms = selected.roll_duration_rooms()


func _pick_weighted_condition(pool: Array[WorldConditionData]) -> WorldConditionData:
	var total_weight: float = 0.0
	for condition: WorldConditionData in pool:
		if condition != null:
			total_weight += max(condition.roll_weight, 0.0)

	if total_weight <= 0.0:
		return null

	var roll: float = RunRng.randf_range(0.0, total_weight)
	var accumulated_weight: float = 0.0
	for condition: WorldConditionData in pool:
		if condition == null:
			continue
		accumulated_weight += max(condition.roll_weight, 0.0)
		if roll <= accumulated_weight:
			return condition

	return pool.back() if not pool.is_empty() else null


func _find_condition(
	pool: Array[WorldConditionData],
	condition_id: StringName,
	fallback: WorldConditionData
) -> WorldConditionData:
	for condition: WorldConditionData in pool:
		if condition != null and condition.condition_id == condition_id:
			return condition
	return fallback


func _normalize_saved_conditions() -> void:
	if run_stats == null:
		return
	if _find_condition(weather_pool, run_stats.active_weather_id, null) == null:
		run_stats.active_weather_id = SUNNY_WEATHER.condition_id
		run_stats.weather_remaining_rooms = 0
	if _find_condition(environment_pool, run_stats.active_environment_id, null) == null:
		run_stats.active_environment_id = NORMAL_ENVIRONMENT.condition_id
		run_stats.environment_remaining_rooms = 0


func _notify_changed() -> void:
	if EventBus != null:
		EventBus.world_condition_changed.emit()
