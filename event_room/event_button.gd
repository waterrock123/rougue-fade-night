class_name EventRoomButton
extends Button

const POSITIVE_COLOR := Color(1.0, 0.82, 0.25, 1.0)
const NEGATIVE_COLOR := Color(1.0, 0.28, 0.24, 1.0)
const NEUTRAL_COLOR := Color(0.92, 0.88, 0.78, 1.0)

var event_button_callback: Callable

#按下后会使event房间内的述用label变为的内容
@export_multiline() var pressed_desc:Array[String]

#简要描述标签即DescLabel的text内容
@export_multiline() var desc_text:String
#详细解释标签即DetailLabel的text内容
@export_multiline() var detail_text:String
@onready var detail_label: RichTextLabel = %DetailLabel
@onready var desc_label: Label = %DescLabel


func _ready() -> void:
	refresh_display()


# 事件房间进入时调用：绑定按钮效果，并把导出的描述数据写入 UI。
func setup_button(callback: Callable) -> void:
	event_button_callback = callback
	refresh_display()


# 刷新按钮文字。DetailLabel 使用 RichTextLabel，方便对正面/负面效果做颜色区分。
func refresh_display() -> void:
	if desc_label != null:
		desc_label.text = desc_text
	if detail_label != null:
		detail_label.clear()
		detail_label.append_text(_format_detail_text(detail_text))


func get_pressed_desc(result_index: int = 0) -> String:
	if pressed_desc.is_empty():
		return ""

	var safe_index = clamp(result_index, 0, pressed_desc.size() - 1)
	return pressed_desc[safe_index]


func _on_pressed() -> void:
	if event_button_callback:
		event_button_callback.call()


# 轻量规则：包含“失去/损失/减少”等词的片段视为负面，包含“获得/回复/提升”等词的片段视为正面。
func _format_detail_text(raw_text: String) -> String:
	if raw_text.is_empty():
		return ""

	var parts := raw_text.split("，", false)
	var result := ""
	for index in range(parts.size()):
		var part := String(parts[index])
		result += _wrap_color(part, _get_segment_color(part))
		if index < parts.size() - 1:
			result += "，"

	return result


func _get_segment_color(segment: String) -> Color:
	var negative_words := ["失去", "损失", "减少", "受到", "扣除", "降低"]
	for word in negative_words:
		if segment.contains(word):
			return NEGATIVE_COLOR

	var positive_words := ["获得", "回复", "恢复", "提升", "增加", "免费"]
	for word in positive_words:
		if segment.contains(word):
			return POSITIVE_COLOR

	return NEUTRAL_COLOR


func _wrap_color(text: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), _escape_bbcode(text)]


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")
