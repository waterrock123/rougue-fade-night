class_name CampfireRoom
extends EventRoom






func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
