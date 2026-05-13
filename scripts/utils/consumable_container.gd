class_name ConsumableContainer
extends BoxContainer

@onready var texture_rect: TextureRect = $PanelContainer/ConsumableTextureRect
@onready var panel: PanelContainer = $PanelContainer

var relic: Relic


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture_rect != null:
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_relic(null)


# 战斗开始或消耗品变化时刷新左上角的消耗品显示。
func set_relic(new_relic: Relic) -> void:
	relic = new_relic
	if not is_node_ready():
		await ready

	if relic == null:
		texture_rect.texture = null
		texture_rect.visible = false
		tooltip_text = ""
		return

	texture_rect.texture = relic.icon
	texture_rect.visible = true
	tooltip_text = " "


func _make_custom_tooltip(_for_text: String) -> Object:
	if relic == null:
		return null

	var tool_tip_panel: RelicToolTip = FloatText.RELIC_TOOL_TIP_PANEL.instantiate()
	tool_tip_panel.set_tool_tip(relic)
	return tool_tip_panel
