class_name HubPortal
extends Area2D

## 大厅入口的通用交互组件。
## 当前只发送入口信号，由 MainHomeMap 统一决定进入单人、等候室或训练场，
## 后续联网时不需要把房间创建逻辑分散到每一个入口场景中。

signal portal_activated(portal_id: StringName)

@export_group("入口信息")
@export var portal_id: StringName
@export var portal_title: String = "未命名入口"
@export_multiline var portal_description: String
@export var interact_action: StringName = &"ui_accept"

@onready var prompt_label: Label = $PromptCanvas/PromptLabel

var player_inside := false
var prompts_enabled: bool = true


func _ready() -> void:
	add_to_group("hub_portal")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh_prompt()
	_update_prompt_screen_position()


func _process(_delta: float) -> void:
	# 提示文字位于 CanvasLayer 中，不再受相机缩放影响；位置每帧跟随传送门。
	_update_prompt_screen_position()


func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or portal_id == &"":
		return
	if event.is_action_pressed(interact_action):
		get_viewport().set_input_as_handled()
		portal_activated.emit(portal_id)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = true
	_refresh_prompt()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = false
	_refresh_prompt()


func _refresh_prompt() -> void:
	if prompt_label == null:
		return

	prompt_label.text = portal_title
	if player_inside:
		prompt_label.text += "\n[空格] 交互"
	elif not portal_description.is_empty():
		prompt_label.text += "\n" + portal_description
	prompt_label.visible = prompts_enabled


## 大厅打开图鉴、NPC 对话等全屏面板时，由 MainHomeMap 统一隐藏入口提示。
func set_prompts_enabled(enabled: bool) -> void:
	prompts_enabled = enabled
	_refresh_prompt()


## 将世界坐标转换为屏幕坐标并取整，避免像素风文字被相机缩放采样得模糊。
func _update_prompt_screen_position() -> void:
	if prompt_label == null:
		return
	var screen_position := get_viewport().get_canvas_transform() * global_position
	# Label 的 position 是左上角，因此同时减去半宽以保持文字居中在传送门上方。
	prompt_label.position = (screen_position + Vector2(-70.0, -58.0)).round()
