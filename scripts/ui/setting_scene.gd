class_name SettingScene
extends Control

signal closed

const KEYBOARD_PANEL_SCENE := preload("res://scenes/single_keyboard_panel.tscn")
const WHEEL_SCROLL_STEP := 72.0

@onready var keyboard_button: Button = get_node_or_null("Panel/Panel/HBoxContainer/KeyBoardButton") as Button
@onready var vision_button: Button = get_node_or_null("Panel/Panel/HBoxContainer/VisionButton") as Button
@onready var sound_button: Button = get_node_or_null("Panel/Panel/HBoxContainer/SoundButton") as Button
@onready var other_button: Button = get_node_or_null("Panel/Panel/HBoxContainer/OtherButton") as Button
@onready var keyboard_setting_view: Control = get_node_or_null("Panel/Panel/Panel/KeyboardSetting") as Control
@onready var keyboard_container: VBoxContainer = get_node_or_null("Panel/Panel/Panel/KeyboardSetting/VBoxContainer") as VBoxContainer
@onready var keyboard_scroll_bar: VScrollBar = get_node_or_null("Panel/Panel/Panel/VScrollBar") as VScrollBar
@onready var back_button: Button = _find_back_button()

var keyboard_scroll_value := 0.0
var keyboard_content_base_top := 0.0


func _ready() -> void:
	if keyboard_container != null:
		keyboard_content_base_top = keyboard_container.position.y

	if keyboard_button != null and not keyboard_button.pressed.is_connected(_on_keyboard_button_pressed):
		keyboard_button.pressed.connect(_on_keyboard_button_pressed)
	if vision_button != null and not vision_button.pressed.is_connected(_on_other_tab_pressed):
		vision_button.pressed.connect(_on_other_tab_pressed.bind(vision_button))
	if sound_button != null and not sound_button.pressed.is_connected(_on_other_tab_pressed):
		sound_button.pressed.connect(_on_other_tab_pressed.bind(sound_button))
	if other_button != null and not other_button.pressed.is_connected(_on_other_tab_pressed):
		other_button.pressed.connect(_on_other_tab_pressed.bind(other_button))
	if back_button != null and not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)
	if keyboard_scroll_bar != null and not keyboard_scroll_bar.value_changed.is_connected(_on_keyboard_scroll_value_changed):
		keyboard_scroll_bar.value_changed.connect(_on_keyboard_scroll_value_changed)
	_show_keyboard_panel()

	# 默认打开键盘页，避免设置界面进来后内容区还是编辑器里的占位行。
	_show_keyboard_panel()


func _on_keyboard_button_pressed() -> void:
	_show_keyboard_panel()


func _on_other_tab_pressed(active_button: Button) -> void:
	_set_tab_pressed(active_button)
	_clear_keyboard_rows()


func _on_back_button_pressed() -> void:
	closed.emit()
	queue_free()


func _show_keyboard_panel() -> void:
	_set_tab_pressed(keyboard_button)
	_clear_keyboard_rows()
	keyboard_scroll_value = 0.0
	if keyboard_container == null:
		return

	for action_info in InputSettingsManager.get_action_infos():
		var action_name := StringName(str(action_info.get("action", "")))
		var display_name := str(action_info.get("display_name", action_name))
		if action_name == &"":
			continue

		var row := KEYBOARD_PANEL_SCENE.instantiate() as SingleKeyboardPanel
		if row == null:
			continue

		keyboard_container.add_child(row)
		row.setup(action_name, display_name)

	call_deferred("_refresh_keyboard_scroll")


func _clear_keyboard_rows() -> void:
	if keyboard_container == null:
		return

	for child in keyboard_container.get_children():
		child.queue_free()
	keyboard_scroll_value = 0.0
	_apply_keyboard_scroll_position()
	call_deferred("_refresh_keyboard_scroll")


func _gui_input(event: InputEvent) -> void:
	if _handle_keyboard_wheel_event(event):
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _handle_keyboard_wheel_event(event):
		get_viewport().set_input_as_handled()


func _handle_keyboard_wheel_event(event: InputEvent) -> bool:
	if not _is_keyboard_tab_active():
		return false
	if not _is_mouse_over_keyboard_view():
		return false

	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return false

	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_keyboard_by(-WHEEL_SCROLL_STEP)
		return true
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_keyboard_by(WHEEL_SCROLL_STEP)
		return true

	return false


func _on_keyboard_scroll_value_changed(value: float) -> void:
	_set_keyboard_scroll(value)


func _scroll_keyboard_by(delta: float) -> void:
	_set_keyboard_scroll(keyboard_scroll_value + delta)


func _set_keyboard_scroll(value: float) -> void:
	var max_scroll := _get_keyboard_max_scroll()
	keyboard_scroll_value = clamp(value, 0.0, max_scroll)

	if keyboard_scroll_bar != null and not is_equal_approx(keyboard_scroll_bar.value, keyboard_scroll_value):
		keyboard_scroll_bar.value = keyboard_scroll_value

	_apply_keyboard_scroll_position()


func _refresh_keyboard_scroll() -> void:
	var max_scroll := _get_keyboard_max_scroll()
	if keyboard_scroll_bar != null:
		var view_height: float = _get_keyboard_view_height()
		keyboard_scroll_bar.min_value = 0.0
		keyboard_scroll_bar.max_value = max_scroll + view_height
		keyboard_scroll_bar.page = view_height
		keyboard_scroll_bar.step = 1.0
		keyboard_scroll_bar.visible = max_scroll > 0.0

	_set_keyboard_scroll(clamp(keyboard_scroll_value, 0.0, max_scroll))


func _apply_keyboard_scroll_position() -> void:
	if keyboard_container == null:
		return

	keyboard_container.position.y = _get_keyboard_content_top() - keyboard_scroll_value


func _get_keyboard_max_scroll() -> float:
	if keyboard_container == null or keyboard_setting_view == null:
		return 0.0

	var content_height: float = max(keyboard_container.size.y, keyboard_container.get_combined_minimum_size().y)
	var content_bottom: float = _get_keyboard_content_top() + content_height
	var view_bottom: float = _get_keyboard_view_height()
	return max(content_bottom - view_bottom, 0.0)


func _get_keyboard_content_top() -> float:
	return keyboard_content_base_top


func _get_keyboard_view_height() -> float:
	if keyboard_setting_view == null:
		return 0.0
	var current_height: float = keyboard_setting_view.size.y
	var minimum_height: float = keyboard_setting_view.custom_minimum_size.y
	return max(current_height, minimum_height)


func _is_keyboard_tab_active() -> bool:
	return keyboard_button == null or keyboard_button.button_pressed


func _is_mouse_over_keyboard_view() -> bool:
	if keyboard_setting_view == null:
		return false

	return keyboard_setting_view.get_global_rect().has_point(get_viewport().get_mouse_position())


func _set_tab_pressed(active_button: Button) -> void:
	for button in [keyboard_button, vision_button, sound_button, other_button]:
		if button == null:
			continue
		button.button_pressed = button == active_button


func _find_back_button() -> Button:
	var by_path := get_node_or_null("BackButton") as Button
	if by_path != null:
		return by_path

	return find_child("BackButton", true, false) as Button
