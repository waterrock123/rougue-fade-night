extends Node
@onready var damage_font = preload("res://resource/damage_font.tres")
const RELIC_TOOL_TIP_PANEL = preload("res://scenes/tooltip/relic_tool_tip_panel.tscn")
const SKILL_TOOL_TIP_PANEL = preload("res://scenes/tooltip/skill_tool_tip_panel.tscn")


func show_screen_tip(message: String, duration: float = 1.2) -> void:
	if message.is_empty():
		return

	var battle_message_log: BattleMessageLog = _get_battle_message_log()
	if battle_message_log != null:
		battle_message_log.add_message(message)
		return

	_show_floating_screen_tip(message, duration)


func _get_battle_message_log() -> BattleMessageLog:
	if not is_inside_tree():
		return null

	return get_tree().get_first_node_in_group("battle_message_log") as BattleMessageLog


func _show_floating_screen_tip(message: String, duration: float = 1.2) -> void:
	if message.is_empty():
		return

	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.offset_left = -360.0
	label.offset_right = 360.0
	label.offset_top = 70.0
	label.offset_bottom = 120.0
	label.modulate = Color(1.0, 0.92, 0.65, 0.0)
	label.label_settings = LabelSettings.new()
	label.label_settings.font_size = 32
	label.label_settings.font_color = Color(1.0, 0.92, 0.65, 1.0)
	label.label_settings.outline_color = Color(0.1, 0.06, 0.02, 1.0)
	label.label_settings.outline_size = 6
	layer.add_child(label)

	# 屏幕提示统一走这里，方便背包、商店、战斗等系统复用同一种反馈。
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, 0.18)
	await tween.finished
	layer.queue_free()









func show_damage_text(damage: String, spw_position: Vector2, color: Color):
	var label = Label.new()
	label.text = damage
	label.z_index = 1000
	label.scale = Vector2(0.15,0.15)
	label.label_settings = LabelSettings.new()
	label.label_settings.font = damage_font
	label.label_settings.font_color = color
	label.label_settings.font_size = 100
	label.label_settings.outline_color = Color.BLACK
	label.label_settings.outline_size = 2
	

	add_child(label)
	
	#偏移与生成位置
	var x_offset = randf_range(-10.0,10.0)
	var spawn_offset = label.size / 2
	label.position = spw_position - spawn_offset
	label.position.x += x_offset
	label.pivot_offset = label.size/2
	
	var tween = create_tween()
	
	tween.tween_property(label,"position:x",label.position.x+x_offset,0.3)
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel()
	tween.tween_property(label,"position:y",label.position.y-10,0.3)
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel()
	tween.tween_property(label,"scale",Vector2.ZERO,0.4).set_ease(Tween.EASE_IN)
	
	await tween.finished
	label.queue_free()
	
	
	
	
