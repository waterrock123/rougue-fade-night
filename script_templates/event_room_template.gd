class_name EventRoom
extends Control


@export var run_stats: RunStats


func setup() -> void:
	pass


func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
