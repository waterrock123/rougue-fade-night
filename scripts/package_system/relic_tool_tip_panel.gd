class_name RelicToolTip
extends PanelContainer
#123456等级对应的颜色是白，黄绿，蓝，紫，橙，红
@export var LevelColor:Array[Color] = [Color.ANTIQUE_WHITE,Color.GREEN_YELLOW,Color.CYAN,Color.DEEP_PINK,Color.CHOCOLATE,Color.RED]


var name_label: Label 
var texture_rect: TextureRect 
var tool_tip_label: Label 
var desc_label:Label
var level_label:Label

func set_tool_tip(relic:Relic) -> void:
	name_label = %NameLabel
	texture_rect = %TextureRect
	tool_tip_label = %TooltipLabel
	desc_label = %DescLabel
	level_label = %LevelLabel
	name_label.text = relic.relic_name
	desc_label.text = relic.desc
	tool_tip_label.text = relic.tooltip
	texture_rect.texture = relic.icon
	level_label.text = level_label.text.format([relic.level])
	level_label.label_settings.font_color = LevelColor[(relic.level)-1]
