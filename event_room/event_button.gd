class_name EventRoomButton
extends Button

var event_button_callback: Callable

#按下后会使event房间内的述用label变为的内容
@export_multiline() var pressed_desc:String


func _on_pressed() -> void:
	if event_button_callback:
		event_button_callback.call()

	
