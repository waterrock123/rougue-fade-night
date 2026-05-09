class_name RelicToolTip
extends PanelContainer
#123456等级对应的颜色是白，黄绿，蓝，紫，橙，红
@export var LevelColor:Array[Color] = [Color.ANTIQUE_WHITE,Color.GREEN_YELLOW,Color.CYAN,Color.DEEP_PINK,Color.CHOCOLATE,Color.RED]

const TAG_UI_SCENE := preload("res://scenes/tooltip/tag_ui.tscn")

var name_label: Label 
var texture_rect: TextureRect 
var tool_tip_label: Label 
var desc_label:Label
var level_label:Label
var price_label:Label
var tag_parent: Control

func set_tool_tip(relic:Relic) -> void:
	name_label = %NameLabel
	texture_rect = %TextureRect
	tool_tip_label = %TooltipLabel
	desc_label = %DescLabel
	level_label = %LevelLabel
	price_label = %PriceLabel
	tag_parent = get_node_or_null("VBoxContainer/HBoxContainer/VBoxContainer") as Control

	name_label.text = relic.relic_name
	desc_label.text = relic.desc
	price_label.text = price_label.text.format([relic.sell_price])
	tool_tip_label.text = relic.tooltip
	texture_rect.texture = relic.icon
	level_label.text = level_label.text.format([relic.level])
	level_label.label_settings.font_color = LevelColor[clamp((relic.level)-1, 0, LevelColor.size() - 1)]
	_refresh_tags(relic)


func _refresh_tags(relic: Relic) -> void:
	if tag_parent == null:
		return

	_clear_old_tags()
	if relic == null:
		return

	for tag in relic.tags:
		if tag == null:
			continue

		var tag_ui := TAG_UI_SCENE.instantiate() as TagUI
		tag_parent.add_child(tag_ui)
		tag_ui.setup(tag)


func _clear_old_tags() -> void:
	# 原场景里放着一个 TagUI 作为占位/示例，这里统一清掉后再按遗物数据重建。
	for child in tag_parent.get_children():
		if child is TagUI:
			tag_parent.remove_child(child)
			child.queue_free()
