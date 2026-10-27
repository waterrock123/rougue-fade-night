## 路线地图左上角的天气/环境摘要，绘制在常驻面板和调试界面下方。
class_name WorldConditionDisplay
extends PanelContainer

const SUNNY_WEATHER := preload("res://world_conditions/weather/sunny.tres")
const MONEY_RAIN_WEATHER := preload("res://world_conditions/weather/money_rain.tres")
const NORMAL_ENVIRONMENT := preload("res://world_conditions/environment/normal.tres")
const DARKNESS_ENVIRONMENT := preload("res://world_conditions/environment/darkness.tres")

@onready var weather_label: Label = %WeatherLabel
@onready var environment_label: Label = %EnvironmentLabel

var run_stats: RunStats


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	if not EventBus.world_condition_changed.is_connected(refresh):
		EventBus.world_condition_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if EventBus.world_condition_changed.is_connected(refresh):
		EventBus.world_condition_changed.disconnect(refresh)


func bind_run_stats(new_run_stats: RunStats) -> void:
	run_stats = new_run_stats
	refresh()


func refresh() -> void:
	var weather := _resolve_weather()
	var environment := _resolve_environment()
	_update_label(weather_label, "天气", weather, run_stats.weather_remaining_rooms if run_stats != null else 0)
	_update_label(environment_label, "环境", environment, run_stats.environment_remaining_rooms if run_stats != null else 0)


func _update_label(label: Label, prefix: String, data: WorldConditionData, remaining_rooms: int) -> void:
	if label == null or data == null:
		return
	var duration_text := "默认" if remaining_rooms <= 0 else "剩余 %d 个房间" % remaining_rooms
	label.text = "%s：%s  ·  %s" % [prefix, data.display_name, duration_text]
	label.tooltip_text = data.description


func _resolve_weather() -> WorldConditionData:
	if run_stats != null and run_stats.active_weather_id == MONEY_RAIN_WEATHER.condition_id:
		return MONEY_RAIN_WEATHER
	return SUNNY_WEATHER


func _resolve_environment() -> WorldConditionData:
	if run_stats != null and run_stats.active_environment_id == DARKNESS_ENVIRONMENT.condition_id:
		return DARKNESS_ENVIRONMENT
	return NORMAL_ENVIRONMENT
