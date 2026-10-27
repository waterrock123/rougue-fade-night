class_name BasicTutorialPanel
extends CanvasLayer

signal return_requested()
signal restart_requested()
signal confirmation_requested()
@export var chapter_title: String = "基础操作"
@onready var character_label: Label = $Root/Panel/Margin/Content/CharacterLabel
@onready var step_label: Label = $Root/Panel/Margin/Content/StepLabel
@onready var title_label: Label = $Root/Panel/Margin/Content/TitleLabel
@onready var instruction_label: Label = $Root/Panel/Margin/Content/InstructionLabel
@onready var key_label: Label = $Root/Panel/Margin/Content/KeyLabel
@onready var progress_label: Label = $Root/Panel/Margin/Content/ProgressLabel
@onready var return_button: Button = $Root/Panel/Margin/Content/Buttons/ReturnButton
@onready var confirm_button: Button = $Root/Panel/Margin/Content/ConfirmButton
@onready var focus_frame: Panel = $Root/FocusFrame
var focus_target: Control


func _ready() -> void:
	return_button.pressed.connect(func() -> void: return_requested.emit())
	$Root/Panel/Margin/Content/Buttons/RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	confirm_button.pressed.connect(func() -> void: confirmation_requested.emit())


func show_step(character_name: String, stage: int, title: String, instruction: String, keys: String) -> void:
	character_label.text = "%s / %s" % [chapter_title, character_name]
	step_label.text = "本章已完成" if stage >= 4 else "步骤 %d / 4" % (stage + 1)
	title_label.text = title
	instruction_label.text = instruction
	key_label.text = keys
	return_button.text = "完成，返回大厅" if stage >= 4 else "退出教学"
	progress_label.text = ""
	confirm_button.hide()


func set_progress(text: String) -> void:
	progress_label.text = text


func set_confirmation(text: String, enabled: bool) -> void:
	confirm_button.text = text
	confirm_button.disabled = not enabled
	confirm_button.show()


func set_focus_target(target: Control) -> void:
	focus_target = target
	_update_focus_frame()


func _process(_delta: float) -> void:
	_update_focus_frame()


## 框选真实交互区域，不接管其鼠标事件，也不修改原控件样式。
func _update_focus_frame() -> void:
	if not is_instance_valid(focus_target) or not focus_target.is_visible_in_tree():
		focus_frame.hide()
		return
	var rect: Rect2 = focus_target.get_global_rect().grow(5.0)
	focus_frame.position = rect.position
	focus_frame.size = rect.size
	focus_frame.show()
