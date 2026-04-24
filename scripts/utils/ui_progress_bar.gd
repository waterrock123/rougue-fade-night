class_name UIProgressBar
extends TextureProgressBar

@export var label: Label


func update_value(ui_current_value:float,ui_max_value:float):
	if ui_max_value <= 0.0:
		value = min_value
		if label != null:
			label.text = "0/0"
		return

	var range_size := max_value - min_value
	var fill_ratio :float = clamp(ui_current_value / ui_max_value, 0.0, 1.0)
	value = min_value + range_size * fill_ratio

	if label != null:
		label.text = "%s/%s" % [int(ui_current_value), int(ui_max_value)]
