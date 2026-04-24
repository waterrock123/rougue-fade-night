class_name PlayerHealthBar
extends UIProgressBar

var stats_controller: StatsController


func _enter_tree() -> void:
	if not EventBus.player_health_changed.is_connected(update_value):
		EventBus.player_health_changed.connect(update_value)
	if not EventBus.attribute_update.is_connected(_refresh_from_stats_controller):
		EventBus.attribute_update.connect(_refresh_from_stats_controller)


func _exit_tree() -> void:
	if EventBus.player_health_changed.is_connected(update_value):
		EventBus.player_health_changed.disconnect(update_value)
	if EventBus.attribute_update.is_connected(_refresh_from_stats_controller):
		EventBus.attribute_update.disconnect(_refresh_from_stats_controller)


func setup(new_stats_controller: StatsController) -> void:
	stats_controller = new_stats_controller
	_refresh_from_stats_controller()


func _refresh_from_stats_controller() -> void:
	if stats_controller == null:
		return

	update_value(stats_controller.current_health, stats_controller.get_stat("max_health"))
