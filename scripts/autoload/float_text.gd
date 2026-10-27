extends Node
@onready var damage_font = preload("res://resource/damage_font.tres")
const RELIC_TOOL_TIP_PANEL = preload("res://scenes/tooltip/relic_tool_tip_panel.tscn")
const SKILL_TOOL_TIP_PANEL = preload("res://scenes/tooltip/skill_tool_tip_panel.tscn")
var action_tip_limiter: ActionTipLimiter = ActionTipLimiter.new()
var screen_tip_layer: CanvasLayer
var screen_tip_label: Label
var screen_tip_tween: Tween


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


## 操作失败不挤进战斗历史日志，使用单条即时提示；限频不影响实际操作执行。
func show_action_tip(message: String, key: String = "", duration: float = 1.2) -> void:
	if message.is_empty():
		return
	var stable_key: String = key if not key.is_empty() else message
	if action_tip_limiter.acquire(stable_key, Time.get_ticks_msec()):
		_show_floating_screen_tip(message, duration)


func _show_floating_screen_tip(message: String, duration: float = 1.2) -> void:
	if message.is_empty():
		return
	_ensure_screen_tip()
	if screen_tip_tween != null and screen_tip_tween.is_valid():
		screen_tip_tween.kill()
	screen_tip_label.text = message
	screen_tip_label.modulate.a = 0.0
	screen_tip_label.show()
	screen_tip_tween = create_tween()
	screen_tip_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	screen_tip_tween.tween_property(screen_tip_label, "modulate:a", 1.0, 0.1)
	screen_tip_tween.tween_interval(maxf(duration, 0.1))
	screen_tip_tween.tween_property(screen_tip_label, "modulate:a", 0.0, 0.18)
	screen_tip_tween.tween_callback(screen_tip_label.hide)


func _ensure_screen_tip() -> void:
	if is_instance_valid(screen_tip_label):
		return
	screen_tip_layer = CanvasLayer.new()
	screen_tip_layer.layer = 100
	screen_tip_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(screen_tip_layer)
	screen_tip_label = Label.new()
	screen_tip_layer.add_child(screen_tip_label)
	screen_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	screen_tip_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	screen_tip_label.offset_left = -420.0
	screen_tip_label.offset_right = 420.0
	screen_tip_label.offset_top = 70.0
	screen_tip_label.offset_bottom = 154.0
	screen_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_tip_label.label_settings = LabelSettings.new()
	screen_tip_label.label_settings.font_size = 28
	screen_tip_label.label_settings.font_color = Color(1.0, 0.92, 0.65)
	screen_tip_label.label_settings.outline_color = Color(0.1, 0.06, 0.02, 1.0)
	screen_tip_label.label_settings.outline_size = 5









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
	
	
	
	
