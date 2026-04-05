class_name PlayerEnergyBar
extends UIProgressBar


func _enter_tree() -> void:
	EventBus.player_energy_changed.connect(update_value)
