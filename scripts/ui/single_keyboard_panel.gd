class_name SingleKeyboardPanel
extends Panel

const EMPTY_TEXT := "空"
const LISTENING_TEXT := "按下新按键..."

var action_name: StringName = &""
var binding_slot_index: int = -1

@onready var name_label: Label = $HBoxContainer/NameLabel
@onready var first_binding_button: Button = $HBoxContainer/FirstBindingButton
@onready var second_binding_button: Button = $HBoxContainer/SecondBindingButton
@onready var reset_button: Button = $HBoxContainer/ResetButton


func _ready() -> void:
	set_process_input(false)
	if not first_binding_button.pressed.is_connected(_on_first_binding_button_pressed):
		first_binding_button.pressed.connect(_on_first_binding_button_pressed)
	if not second_binding_button.pressed.is_connected(_on_second_binding_button_pressed):
		second_binding_button.pressed.connect(_on_second_binding_button_pressed)
	if not reset_button.pressed.is_connected(_on_reset_button_pressed):
		reset_button.pressed.connect(_on_reset_button_pressed)
	if not InputSettingsManager.bindings_changed.is_connected(_on_bindings_changed):
		InputSettingsManager.bindings_changed.connect(_on_bindings_changed)


func _exit_tree() -> void:
	if InputSettingsManager.bindings_changed.is_connected(_on_bindings_changed):
		InputSettingsManager.bindings_changed.disconnect(_on_bindings_changed)


func setup(new_action_name: StringName, display_name: String) -> void:
	action_name = new_action_name
	if name_label != null:
		name_label.text = display_name
	_refresh_buttons()


func _input(event: InputEvent) -> void:
	if binding_slot_index < 0:
		return

	if event is InputEventKey:
		_handle_key_input(event as InputEventKey)
		return

	if event is InputEventMouseButton:
		_handle_mouse_input(event as InputEventMouseButton)


func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return

	var keycode := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if keycode == KEY_ESCAPE:
		_cancel_listening()
		get_viewport().set_input_as_handled()
		return
	if keycode == KEY_BACKSPACE or keycode == KEY_DELETE:
		InputSettingsManager.clear_binding_event(action_name, binding_slot_index)
		_finish_listening()
		get_viewport().set_input_as_handled()
		return

	InputSettingsManager.set_binding_event(action_name, binding_slot_index, event)
	_finish_listening()
	get_viewport().set_input_as_handled()


func _handle_mouse_input(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return

	InputSettingsManager.set_binding_event(action_name, binding_slot_index, event)
	_finish_listening()
	get_viewport().set_input_as_handled()


func _on_first_binding_button_pressed() -> void:
	_begin_listening(0)


func _on_second_binding_button_pressed() -> void:
	_begin_listening(1)


func _on_reset_button_pressed() -> void:
	_cancel_listening()
	InputSettingsManager.reset_action(action_name)
	_refresh_buttons()


func _on_bindings_changed(changed_action_name: StringName) -> void:
	if changed_action_name == action_name:
		_refresh_buttons()


func _begin_listening(slot_index: int) -> void:
	binding_slot_index = slot_index
	set_process_input(true)
	_refresh_buttons()
	_get_binding_button(slot_index).text = LISTENING_TEXT


func _finish_listening() -> void:
	binding_slot_index = -1
	set_process_input(false)
	_refresh_buttons()


func _cancel_listening() -> void:
	if binding_slot_index < 0:
		return

	binding_slot_index = -1
	set_process_input(false)
	_refresh_buttons()


func _refresh_buttons() -> void:
	if action_name == &"":
		return

	var events: Array[InputEvent] = InputSettingsManager.get_action_events(action_name)
	first_binding_button.text = _get_event_text(events, 0)
	second_binding_button.text = _get_event_text(events, 1)


func _get_event_text(events: Array[InputEvent], index: int) -> String:
	if index < 0 or index >= events.size():
		return EMPTY_TEXT

	return InputSettingsManager.get_event_display_text(events[index])


func _get_binding_button(slot_index: int) -> Button:
	if slot_index == 0:
		return first_binding_button
	return second_binding_button
