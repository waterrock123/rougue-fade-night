class_name RelicToolTip
extends PanelContainer


var name_label: Label 
var texture_rect: TextureRect 
var tool_tip_label: Label 
var desc_label:Label


func set_tool_tip(relic_name:String,desc:String,tool_tip:String,texture) -> void:
	name_label = %NameLabel
	texture_rect = %TextureRect
	tool_tip_label = %TooltipLabel
	desc_label = %DescLabel
	name_label.text = relic_name
	desc_label.text = desc
	tool_tip_label.text = tool_tip
	texture_rect.texture = texture
