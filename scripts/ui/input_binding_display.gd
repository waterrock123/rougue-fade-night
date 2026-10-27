class_name InputBindingDisplay
extends RefCounted


## 设置、技能栏和教学共用键名格式，不改变InputMap或重绑按键。
static func action_text(action: StringName, multiline: bool = false) -> String:
	var labels: Array[String] = []
	if InputMap.has_action(action):
		for event: InputEvent in InputMap.action_get_events(action):
			var label: String = InputSettingsManager.get_event_display_text(event)
			if not label.is_empty() and not labels.has(label):
				labels.append(label)
	return ("\n" if multiline else " / ").join(labels) if not labels.is_empty() else "未绑定"
