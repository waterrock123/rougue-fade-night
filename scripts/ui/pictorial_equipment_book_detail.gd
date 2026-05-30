class_name PictorialEquipmentBookDetail
extends VBoxContainer

const TAG_UI_SCENE := preload("res://scenes/tooltip/tag_ui.tscn")
const LEVEL_COLORS: Array[Color] = [Color.ANTIQUE_WHITE, Color.GREEN_YELLOW, Color.CYAN, Color.DEEP_PINK, Color.CHOCOLATE, Color.RED]

@export var keyword_database: KeywordDatabase = preload("res://custom_resource/default_keyword_database.tres")

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var tag_list: Control = %TagList
@onready var tooltip_label: Label = %TooltipLabel
@onready var desc_label: Label = %DescLabel


# 右侧装备详情面板，只负责把 Relic 的静态信息填进 UI。
func setup(relic: Relic) -> void:
	_resolve_nodes()
	if relic == null:
		hide()
		return

	show()
	if icon_rect != null:
		icon_rect.texture = relic.icon
	if name_label != null:
		name_label.text = relic.relic_name
	_refresh_level(relic)
	_refresh_tags(relic)
	if tooltip_label != null:
		tooltip_label.text = KeywordTextFormatter.format_text_plain(relic.tooltip, keyword_database)
	if desc_label != null:
		desc_label.text = KeywordTextFormatter.format_text_plain(relic.desc, keyword_database)


func _refresh_level(relic: Relic) -> void:
	if level_label == null:
		return

	level_label.text = "Lv.%s" % str(relic.level)
	_apply_level_color(level_label, relic.level)


func _apply_level_color(label: Label, relic_level: int) -> void:
	var level_color := LEVEL_COLORS[clamp(relic_level - 1, 0, LEVEL_COLORS.size() - 1)]

	# 与 RelicToolTip 使用同一套颜色，并确保详情面板拥有独立的 LabelSettings。
	if label.label_settings == null:
		label.label_settings = LabelSettings.new()
	else:
		label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = level_color
	label.add_theme_color_override("font_color", level_color)


func _refresh_tags(relic: Relic) -> void:
	if tag_list == null:
		return

	for child in tag_list.get_children():
		tag_list.remove_child(child)
		child.queue_free()

	for tag in relic.tags:
		if tag == null:
			continue
		var tag_ui := TAG_UI_SCENE.instantiate() as TagUI
		tag_list.add_child(tag_ui)
		tag_ui.setup(tag)


func _resolve_nodes() -> void:
	if icon_rect == null:
		icon_rect = get_node_or_null("%Icon") as TextureRect
	if name_label == null:
		name_label = get_node_or_null("%NameLabel") as Label
	if level_label == null:
		level_label = get_node_or_null("%LevelLabel") as Label
	if tag_list == null:
		tag_list = get_node_or_null("%TagList") as Control
	if tooltip_label == null:
		tooltip_label = get_node_or_null("%TooltipLabel") as Label
	if desc_label == null:
		desc_label = get_node_or_null("%DescLabel") as Label
