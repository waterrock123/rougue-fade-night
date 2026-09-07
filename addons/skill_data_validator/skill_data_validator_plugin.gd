@tool
extends EditorPlugin

const VALIDATOR_SCRIPT: Script = preload("res://addons/skill_data_validator/skill_data_validator.gd")

var report_dialog: AcceptDialog
var report_text: TextEdit


func _enter_tree() -> void:
	_create_report_dialog()
	add_tool_menu_item("校验技能与奖励数据", Callable(self, "_run_validator"))


func _exit_tree() -> void:
	remove_tool_menu_item("校验技能与奖励数据")
	if is_instance_valid(report_dialog):
		report_dialog.queue_free()


func _create_report_dialog() -> void:
	report_dialog = AcceptDialog.new()
	report_dialog.title = "编辑器数据校验"
	report_dialog.min_size = Vector2i(980, 680)

	report_text = TextEdit.new()
	report_text.editable = false
	report_text.custom_minimum_size = Vector2(920, 600)
	report_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_dialog.add_child(report_text)

	var base_control: Control = get_editor_interface().get_base_control()
	base_control.add_child(report_dialog)


func _run_validator() -> void:
	var validator: SkillDataValidator = VALIDATOR_SCRIPT.new()
	var result: Dictionary = validator.validate_project()
	var report: String = String(result.get("report", "没有生成校验报告。"))
	var has_errors: bool = bool(result.get("has_errors", false))

	print(report)
	report_text.text = report
	report_dialog.title = "编辑器数据校验 - " + ("发现错误" if has_errors else "通过")
	report_dialog.popup_centered(Vector2i(980, 680))
