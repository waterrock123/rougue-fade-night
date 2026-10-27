class_name TutorialInputLabels
extends RefCounted


## 从实际 InputMap 读取两个备选键位，不把鼠标左键、右键或 WASD 写死在教程里。
static func action_text(action: StringName) -> String:
	var text: String = InputBindingDisplay.action_text(action)
	return "未绑定，请先在设置中绑定" if text == "未绑定" else text


static func movement_text() -> String:
	return "上 %s   下 %s\n左 %s   右 %s" % [action_text(&"upmove"), action_text(&"downmove"), action_text(&"leftmove"), action_text(&"rightmove")]
