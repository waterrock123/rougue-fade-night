class_name ConsumableContainer
extends BoxContainer

@onready var texture_rect: TextureRect = $PanelContainer/ConsumableTextureRect
@onready var panel: PanelContainer = $PanelContainer

var relic: Relic
var cooldown_label: Label
var displayed_cooldown_seconds: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture_rect != null:
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 覆盖在图标上，不参与容器排版，也不截获装备提示的鼠标事件。
	cooldown_label = Label.new()
	cooldown_label.name = "CooldownLabel"
	cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cooldown_label.add_theme_font_size_override("font_size", 22)
	cooldown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cooldown_label.add_theme_constant_override("outline_size", 4)
	texture_rect.add_child(cooldown_label)
	cooldown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_cooldown_remaining(0.0)
	set_relic(null)


# 战斗开始或消耗品变化时刷新左上角的消耗品显示。
func set_relic(new_relic: Relic) -> void:
	relic = new_relic
	if not is_node_ready():
		await ready

	if relic == null:
		set_cooldown_remaining(0.0)
		texture_rect.texture = null
		texture_rect.visible = false
		tooltip_text = ""
		return

	texture_rect.texture = relic.icon
	texture_rect.visible = true
	tooltip_text = " "


func set_cooldown_remaining(remaining: float) -> void:
	if cooldown_label == null:
		return
	var seconds: int = int(ceilf(maxf(remaining, 0.0)))
	if seconds == displayed_cooldown_seconds:
		return
	displayed_cooldown_seconds = seconds
	cooldown_label.visible = seconds > 0 and relic != null
	cooldown_label.text = "%ds" % seconds if seconds > 0 else ""
	if texture_rect != null:
		texture_rect.modulate = Color(0.55, 0.55, 0.55) if seconds > 0 else Color.WHITE


func _make_custom_tooltip(_for_text: String) -> Object:
	if relic == null:
		return null

	var tool_tip_panel: RelicToolTip = FloatText.RELIC_TOOL_TIP_PANEL.instantiate()
	tool_tip_panel.set_tool_tip(relic)
	return tool_tip_panel
