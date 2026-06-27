extends Node

signal bindings_changed(action_name: StringName)

const CONFIG_PATH := "user://key_bindings.cfg"
const CONFIG_SECTION := "bindings"
const MAX_BINDINGS_PER_ACTION := 2

const ACTION_INFOS := [
	{"action": "upmove", "display_name": "向上移动"},
	{"action": "downmove", "display_name": "向下移动"},
	{"action": "leftmove", "display_name": "向左移动"},
	{"action": "rightmove", "display_name": "向右移动"},
	{"action": "ability_1", "display_name": "技能1（基础攻击）"},
	{"action": "ability_2", "display_name": "技能2"},
	{"action": "ability_3", "display_name": "技能3"},
	{"action": "ability_4", "display_name": "技能4"},
	{"action": "ability_5", "display_name": "技能5"},
	{"action": "use_consumable", "display_name": "使用消耗品"},
]

var default_events_by_action: Dictionary = {}


func _ready() -> void:
	_capture_default_bindings()
	load_bindings()


func get_action_infos() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for info_value in ACTION_INFOS:
		var info: Dictionary = info_value as Dictionary
		result.append(info.duplicate(true))
	return result


func get_action_events(action_name: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if not InputMap.has_action(action_name):
		return result

	for event in InputMap.action_get_events(action_name):
		var input_event := event as InputEvent
		if input_event == null:
			continue
		if not _is_supported_event(input_event):
			continue
		result.append(input_event.duplicate(true) as InputEvent)
		if result.size() >= MAX_BINDINGS_PER_ACTION:
			break

	return result


func set_binding_event(action_name: StringName, binding_index: int, event: InputEvent) -> void:
	if binding_index < 0 or binding_index >= MAX_BINDINGS_PER_ACTION:
		return
	if event == null or not _is_supported_event(event):
		return

	var events: Array[InputEvent] = get_action_events(action_name)
	var new_event := _normalize_event(event)
	if new_event == null:
		return

	if binding_index < events.size():
		events[binding_index] = new_event
	else:
		events.append(new_event)

	_apply_events(action_name, events)
	save_bindings()
	bindings_changed.emit(action_name)


func clear_binding_event(action_name: StringName, binding_index: int) -> void:
	if binding_index < 0 or binding_index >= MAX_BINDINGS_PER_ACTION:
		return

	var events: Array[InputEvent] = get_action_events(action_name)
	if binding_index >= events.size():
		return

	events.remove_at(binding_index)
	_apply_events(action_name, events)
	save_bindings()
	bindings_changed.emit(action_name)


func reset_action(action_name: StringName) -> void:
	var default_events: Array[InputEvent] = _get_default_events(action_name)
	_apply_events(action_name, default_events)
	save_bindings()
	bindings_changed.emit(action_name)


func get_event_display_text(event: InputEvent) -> String:
	if event == null:
		return "空"

	if event is InputEventKey:
		return _get_key_event_text(event as InputEventKey)
	if event is InputEventMouseButton:
		return _get_mouse_event_text(event as InputEventMouseButton)

	return event.as_text()


func load_bindings() -> void:
	var config := ConfigFile.new()
	var error := config.load(CONFIG_PATH)
	if error != OK:
		return

	for info_value in ACTION_INFOS:
		var info: Dictionary = info_value as Dictionary
		var action_name := StringName(str(info.get("action", "")))
		if action_name == &"":
			continue
		if not config.has_section_key(CONFIG_SECTION, String(action_name)):
			continue

		var raw_events: Variant = config.get_value(CONFIG_SECTION, String(action_name), [])
		var events: Array[InputEvent] = _deserialize_events(raw_events)
		_apply_events(action_name, events)


func save_bindings() -> void:
	var config := ConfigFile.new()
	for info_value in ACTION_INFOS:
		var info: Dictionary = info_value as Dictionary
		var action_name := StringName(str(info.get("action", "")))
		if action_name == &"":
			continue

		var serialized_events: Array[Dictionary] = []
		for event in get_action_events(action_name):
			serialized_events.append(_event_to_dictionary(event))
		config.set_value(CONFIG_SECTION, String(action_name), serialized_events)

	var error := config.save(CONFIG_PATH)
	if error != OK:
		push_warning("无法保存按键配置：%s" % CONFIG_PATH)


func _capture_default_bindings() -> void:
	default_events_by_action.clear()
	for info_value in ACTION_INFOS:
		var info: Dictionary = info_value as Dictionary
		var action_name := StringName(str(info.get("action", "")))
		if action_name == &"":
			continue
		default_events_by_action[action_name] = get_action_events(action_name)


func _get_default_events(action_name: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	var stored_events: Array = default_events_by_action.get(action_name, []) as Array
	for event_value in stored_events:
		var event := event_value as InputEvent
		if event != null:
			result.append(event.duplicate(true) as InputEvent)
	return result


func _apply_events(action_name: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)
	for event in events:
		if event == null:
			continue
		InputMap.action_add_event(action_name, event.duplicate(true) as InputEvent)


func _deserialize_events(raw_events: Variant) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if not (raw_events is Array):
		return result

	var event_array: Array = raw_events as Array
	for event_data_value in event_array:
		var event_data := event_data_value as Dictionary
		if event_data == null:
			continue

		var event := _dictionary_to_event(event_data)
		if event == null:
			continue
		result.append(event)
		if result.size() >= MAX_BINDINGS_PER_ACTION:
			break

	return result


func _event_to_dictionary(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {
			"type": "key",
			"physical_keycode": key_event.physical_keycode,
			"keycode": key_event.keycode,
			"alt": key_event.alt_pressed,
			"shift": key_event.shift_pressed,
			"ctrl": key_event.ctrl_pressed,
			"meta": key_event.meta_pressed,
		}

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return {
			"type": "mouse_button",
			"button_index": mouse_event.button_index,
		}

	return {}


func _dictionary_to_event(data: Dictionary) -> InputEvent:
	var event_type := str(data.get("type", ""))
	if event_type == "key":
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(data.get("physical_keycode", 0))
		key_event.keycode = int(data.get("keycode", 0))
		key_event.alt_pressed = bool(data.get("alt", false))
		key_event.shift_pressed = bool(data.get("shift", false))
		key_event.ctrl_pressed = bool(data.get("ctrl", false))
		key_event.meta_pressed = bool(data.get("meta", false))
		return key_event

	if event_type == "mouse_button":
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = int(data.get("button_index", 0))
		return mouse_event

	return null


func _normalize_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var source_key := event as InputEventKey
		var key_event := InputEventKey.new()
		key_event.physical_keycode = source_key.physical_keycode
		key_event.keycode = source_key.keycode
		key_event.alt_pressed = source_key.alt_pressed
		key_event.shift_pressed = source_key.shift_pressed
		key_event.ctrl_pressed = source_key.ctrl_pressed
		key_event.meta_pressed = source_key.meta_pressed
		return key_event

	if event is InputEventMouseButton:
		var source_mouse := event as InputEventMouseButton
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = source_mouse.button_index
		return mouse_event

	return null


func _is_supported_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.physical_keycode != 0 or key_event.keycode != 0
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return mouse_event.button_index > 0
	return false


func _get_key_event_text(event: InputEventKey) -> String:
	var parts: Array[String] = []
	if event.ctrl_pressed:
		parts.append("Ctrl")
	if event.shift_pressed:
		parts.append("Shift")
	if event.alt_pressed:
		parts.append("Alt")
	if event.meta_pressed:
		parts.append("Meta")

	var keycode := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var key_text := OS.get_keycode_string(keycode)
	if key_text.is_empty():
		key_text = event.as_text()
	parts.append(key_text)
	return "+".join(parts)


func _get_mouse_event_text(event: InputEventMouseButton) -> String:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			return "鼠标左键"
		MOUSE_BUTTON_RIGHT:
			return "鼠标右键"
		MOUSE_BUTTON_MIDDLE:
			return "鼠标中键"
		MOUSE_BUTTON_WHEEL_UP:
			return "滚轮上"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "滚轮下"
		_:
			return "鼠标键%s" % event.button_index
