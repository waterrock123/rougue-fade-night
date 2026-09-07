class_name BattleMessageLog
extends PanelContainer

## 战斗内左侧提示列表。
## 地图物件、掉落物、悬赏精英怪等提示都走这里，玩家可以通过滚动条回看本场战斗内的消息。

@export var max_messages: int = 80
@export var auto_scroll_to_latest: bool = true
@export var message_width: float = 300.0
@export var message_font_size: int = 14
@export var message_color: Color = Color(1.0, 0.94, 0.72, 1.0)
@export var message_outline_color: Color = Color(0.08, 0.05, 0.02, 0.95)
@export var message_outline_size: int = 3

@onready var scroll_container: ScrollContainer = $MarginContainer/ScrollContainer
@onready var message_list: VBoxContainer = $MarginContainer/ScrollContainer/MessageList


func _ready() -> void:
	add_to_group("battle_message_log")
	mouse_filter = Control.MOUSE_FILTER_PASS
	if scroll_container != null:
		scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	if message_list != null:
		message_list.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 添加一条新的战斗消息。消息会自动换行，并在数量过多时丢弃最旧记录。
func add_message(message: String) -> void:
	var text: String = message.strip_edges()
	if text.is_empty() or message_list == null:
		return

	var row: PanelContainer = _create_message_row(text)
	message_list.add_child(row)
	_trim_old_messages()

	if auto_scroll_to_latest:
		call_deferred("_scroll_to_latest")


func clear_messages() -> void:
	if message_list == null:
		return

	for child: Node in message_list.get_children():
		child.queue_free()


func _create_message_row(message: String) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(message_width, 0.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", _create_row_style())

	var label: Label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(message_width - 16.0, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", message_font_size)
	label.add_theme_color_override("font_color", message_color)
	label.add_theme_color_override("font_outline_color", message_outline_color)
	label.add_theme_constant_override("outline_size", message_outline_size)
	row.add_child(label)
	return row


func _create_row_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.07, 0.52)
	style.border_color = Color(1.0, 0.78, 0.22, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


func _trim_old_messages() -> void:
	if message_list == null:
		return

	while message_list.get_child_count() > max(max_messages, 1):
		var first_child: Node = message_list.get_child(0)
		message_list.remove_child(first_child)
		first_child.queue_free()


func _scroll_to_latest() -> void:
	if scroll_container == null:
		return

	var vertical_bar: VScrollBar = scroll_container.get_v_scroll_bar()
	if vertical_bar == null:
		return

	vertical_bar.value = vertical_bar.max_value
