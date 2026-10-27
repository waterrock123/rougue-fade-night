class_name AntiqueShopRoom
extends EventRoom

const EVENT_BUTTON_GROUP := "antique_shop_event_buttons"

@onready var browse_button: EventRoomButton = $DrinkButton
@onready var leave_choice_button: EventRoomButton = $NotdrinkButton
@onready var invite_button: EventRoomButton = $NotdrinkButton2
@onready var desc_label: Label = $DescLabel


func setup() -> void:
	_setup_button(browse_button, _choose_browse)
	_setup_button(leave_choice_button, _choose_leave)
	_setup_button(invite_button, _choose_invite)
	if ProfileManager.has_completed_event(&"invited_xiaole"):
		invite_button.disabled = true
		invite_button.detail_text = "小乐已经在大厅经营她的古董生意。"
		invite_button.refresh_display()


func _setup_button(button: EventRoomButton, callback: Callable) -> void:
	button.add_to_group(EVENT_BUTTON_GROUP)
	button.setup_button(callback)


func _choose_browse() -> void:
	_resolve(browse_button)


func _choose_leave() -> void:
	_resolve(leave_choice_button)


func _choose_invite() -> void:
	ProfileManager.try_complete_event(&"invited_xiaole")
	_resolve(invite_button)


func _resolve(button: EventRoomButton) -> void:
	if desc_label != null:
		desc_label.text = button.get_pressed_desc(0)
	for node: Node in get_tree().get_nodes_in_group(EVENT_BUTTON_GROUP):
		if node is EventRoomButton and is_ancestor_of(node):
			node.queue_free()


func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
