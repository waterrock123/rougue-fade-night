class_name PlayerHealthBar
extends UIProgressBar


func _enter_tree() -> void:
	EventBus.player_health_changed.connect(update_value)
