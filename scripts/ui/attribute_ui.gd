class_name AttributeUI
extends Control


enum ValueFormat {
	NUMBER,
	PERCENTAGE,
}

@export_group("显示")
@export var icon: Texture2D
@export var display_name: String = "属性"
@export var attribute: StringName
@export var value_format: ValueFormat = ValueFormat.NUMBER
@export_range(0, 2, 1) var decimal_places: int = 0

var stats_controller: StatsController

@onready var icon_rect: TextureRect = $Panel/MarginContainer/HBoxContainer/Icon
@onready var name_label: Label = $Panel/MarginContainer/HBoxContainer/NameLabel
@onready var value_label: Label = $Panel/MarginContainer/HBoxContainer/DataLabel


## 绑定属性控制器并初始化图标、名称和当前值。
func setup(new_stats_controller: StatsController) -> void:
	stats_controller = new_stats_controller
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	name_label.text = display_name
	update_value()


## 属性变化时刷新显示；百分比属性统一转换为玩家容易理解的百分数。
func update_value() -> void:
	if stats_controller == null:
		value_label.text = "--"
		return

	var current_value: float = stats_controller.get_stat(attribute)
	if value_format == ValueFormat.PERCENTAGE:
		value_label.text = _format_value(current_value * 100.0) + "%"
	else:
		value_label.text = _format_value(current_value)


func _format_value(value: float) -> String:
	if decimal_places <= 0:
		return str(roundi(value))

	var step: float = 1.0 / pow(10.0, float(decimal_places))
	return str(snappedf(value, step)).pad_decimals(decimal_places)
