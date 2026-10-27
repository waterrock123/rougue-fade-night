class_name SpeakUi
extends Control

## 大厅 NPC 的功能对话框：负责展示头像、对白，并按 NPC 配置生成服务按钮。
signal action_selected(action_data: HubNpcActionData)
signal closed()

@onready var panel: Panel = $Panel
@onready var portrait: TextureRect = $Panel/MarginContainer/VBoxContainer/HBoxContainer/Texture
@onready var name_label: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/Name
@onready var content_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/MarginContainer/NpcSays
@onready var action_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/HBoxContainer2
@onready var button_template: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer2/Button
@onready var leave_button: Button = $Panel/MarginContainer/VBoxContainer/HBoxContainer2/LeaveButton

var dialogue_lines: Array[String] = []
var dialogue_index: int = 0
var available_actions: Array[HubNpcActionData] = []


func _ready() -> void:
	button_template.hide()
	leave_button.pressed.connect(_on_leave_button_pressed)
	hide()


## 打开面板时居中显示，并从交互资源读取本次问候和可用功能。
func open_for_npc(interaction_data: HubNpcInteractionData) -> void:
	if interaction_data == null:
		return
	name_label.text = interaction_data.display_name
	portrait.texture = interaction_data.portrait
	portrait.visible = interaction_data.portrait != null
	dialogue_lines = interaction_data.get_dialogue_lines_for_interaction()
	dialogue_index = 0
	available_actions = interaction_data.get_available_actions()
	_show_current_dialogue()
	show()
	panel.size = panel.custom_minimum_size
	position = ((get_viewport_rect().size - panel.size) * 0.5).round()


func _show_current_dialogue() -> void:
	if dialogue_lines.is_empty():
		content_label.text = "……"
	else:
		content_label.text = dialogue_lines[dialogue_index]
	_rebuild_action_buttons()


## 只有所有问候展示完成后，才显示 NPC 提供的功能按钮。
func _rebuild_action_buttons() -> void:
	for child: Node in action_container.get_children():
		if child != button_template and child != leave_button:
			action_container.remove_child(child)
			child.queue_free()
	if dialogue_index < dialogue_lines.size() - 1:
		var next_button: Button = _create_button("继续")
		next_button.pressed.connect(_on_next_button_pressed)
		return
	for action_data: HubNpcActionData in available_actions:
		if action_data == null:
			continue
		var action_button: Button = _create_button(action_data.display_name)
		action_button.tooltip_text = action_data.description
		action_button.pressed.connect(_on_action_button_pressed.bind(action_data))


func _create_button(button_text: String) -> Button:
	var new_button: Button = button_template.duplicate() as Button
	new_button.text = button_text
	new_button.show()
	action_container.add_child(new_button)
	return new_button


func _on_next_button_pressed() -> void:
	if dialogue_index >= dialogue_lines.size() - 1:
		return
	dialogue_index += 1
	_show_current_dialogue()


func _on_action_button_pressed(action_data: HubNpcActionData) -> void:
	action_selected.emit(action_data)


func _on_leave_button_pressed() -> void:
	closed.emit()


## 最后一句展示后离开才算完成；提前离开保留原阶段，不发奖励。
func is_dialogue_complete() -> bool:
	return not dialogue_lines.is_empty() and dialogue_index >= dialogue_lines.size() - 1
