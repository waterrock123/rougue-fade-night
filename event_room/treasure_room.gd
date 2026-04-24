class_name TreasureRoom
extends EventRoom


@onready var gold_button: EventRoomButton = $GoldButton
@onready var equip_button: EventRoomButton = $EquipButton
@onready var all_button: EventRoomButton = $AllButton
@onready var label: Label = $Label



func setup() -> void:
	pass
	

func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
