class_name RelicToolTip
extends PanelContainer

## 等级对应颜色：白、黄绿、青、粉、橙、红。
@export var LevelColor: Array[Color] = [
	Color.ANTIQUE_WHITE,
	Color.GREEN_YELLOW,
	Color.CYAN,
	Color.DEEP_PINK,
	Color.CHOCOLATE,
	Color.RED,
]
@export var keyword_database: KeywordDatabase = preload("res://custom_resource/default_keyword_database.tres")

const TAG_UI_SCENE := preload("res://scenes/tooltip/tag_ui.tscn")

var name_label: Label
var texture_rect: TextureRect
var tool_tip_label: RichTextLabel
var desc_label: RichTextLabel
var level_label: Label
var price_label: Label
var tag_parent: Control
var keyword_explain_panel: KeywordExplainPanel


func set_tool_tip(relic: Relic) -> void:
	_bind_nodes()
	_clear_display()
	if relic == null:
		return

	name_label.text = relic.relic_name
	texture_rect.texture = relic.icon
	texture_rect.visible = relic.icon != null
	price_label.text = str(relic.get_effective_sell_price())
	level_label.text = "LV %s" % str(relic.level)
	level_label.label_settings.font_color = LevelColor[clamp(relic.level - 1, 0, LevelColor.size() - 1)]
	_refresh_keyword_text(relic)
	_refresh_tags(relic)


func _bind_nodes() -> void:
	name_label = %NameLabel
	texture_rect = %TextureRect
	tool_tip_label = %TooltipLabel
	desc_label = %DescLabel
	level_label = %LevelLabel
	price_label = %PriceLabel
	tag_parent = get_node_or_null("HBoxContainer/VBoxContainer/HBoxContainer/VBoxContainer") as Control
	keyword_explain_panel = get_node_or_null("HBoxContainer/KeywordExplainPanel") as KeywordExplainPanel


func _clear_display() -> void:
	# 先清空场景自带的示例文本，避免空资源或未填写资源露出“占位符”内容。
	if name_label != null:
		name_label.text = ""
	if texture_rect != null:
		texture_rect.texture = null
		texture_rect.visible = false
	if level_label != null:
		level_label.text = ""
	if price_label != null:
		price_label.text = ""

	_set_rich_text(tool_tip_label, "")
	_set_rich_text(desc_label, "")
	_clear_old_tags()
	if keyword_explain_panel != null:
		var empty_keywords: Array[KeywordData] = []
		keyword_explain_panel.setup_keywords(empty_keywords)


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
	if tag_parent == null:
		return

	# 原场景里会放一个 TagUI 作为占位示例，这里统一清掉后再按遗物数据重建。
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
	label.text = ""
	if bbcode_text.is_empty():
		return

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
