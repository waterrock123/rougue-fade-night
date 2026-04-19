class_name UIProgressBar
extends TextureProgressBar

@export var label: Label
var _max_value = 100.0


func update_value(ui_current_value:float,ui_max_value:float):
	var value_proportion = _max_value / ui_max_value
	value = clamp(ui_current_value * value_proportion, 0,_max_value)

	label.text = "%s/%s" % [int(ui_current_value), int(ui_max_value)]
