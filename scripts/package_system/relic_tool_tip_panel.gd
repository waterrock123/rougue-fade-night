class_name RelicToolTip
extends PanelContainer
#123456等级对应的颜色是白，黄绿，蓝，紫，橙，红
@export var LevelColor:Array[Color] = [Color.ANTIQUE_WHITE,Color.GREEN_YELLOW,Color.CYAN,Color.DEEP_PINK,Color.CHOCOLATE,Color.RED]
@export var keyword_database: KeywordDatabase = preload("res://custom_resource/default_keyword_database.tres")

const TAG_UI_SCENE := preload("res://scenes/tooltip/tag_ui.tscn")

var name_label: Label 
var texture_rect: TextureRect 
var tool_tip_label: RichTextLabel
var desc_label: RichTextLabel
var level_label:Label
var price_label:Label
var tag_parent: Control
var keyword_explain_panel: KeywordExplainPanel

func set_tool_tip(relic:Relic) -> void:
	if relic == null:
		return

	name_label = %NameLabel
	texture_rect = %TextureRect
	tool_tip_label = %TooltipLabel
	desc_label = %DescLabel
	level_label = %LevelLabel
	price_label = %PriceLabel
	tag_parent = get_node_or_null("HBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer") as Control
	keyword_explain_panel = get_node_or_null("HBoxContainer/KeywordExplainPanel") as KeywordExplainPanel

	name_label.text = relic.relic_name
	price_label.text = price_label.text.format([relic.get_effective_sell_price()])
	texture_rect.texture = relic.icon
	level_label.text = level_label.text.format([relic.level])
	level_label.label_settings.font_color = LevelColor[clamp((relic.level)-1, 0, LevelColor.size() - 1)]
	_refresh_keyword_text(relic)
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


func _refresh_keyword_text(relic: Relic) -> void:
	var tooltip_result := KeywordTextFormatter.format_text(relic.tooltip, keyword_database)
	var desc_result := KeywordTextFormatter.format_text(relic.desc, keyword_database)

	_set_rich_text(tool_tip_label, tooltip_result.bbcode_text)
	_set_rich_text(desc_label, desc_result.bbcode_text)

	var keywords := _merge_keywords(tooltip_result.keywords, desc_result.keywords)
	if keyword_explain_panel != null:
		keyword_explain_panel.setup_keywords(keywords)


func _set_rich_text(label: RichTextLabel, bbcode_text: String) -> void:
	if label == null:
		return

	label.clear()
	label.append_text(bbcode_text)


func _merge_keywords(first_list: Array[KeywordData], second_list: Array[KeywordData]) -> Array[KeywordData]:
	var result: Array[KeywordData] = []
	for keyword in first_list:
		if keyword != null and not result.has(keyword):
			result.append(keyword)
	for keyword in second_list:
		if keyword != null and not result.has(keyword):
			result.append(keyword)
	return result
