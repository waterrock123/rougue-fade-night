class_name SkillToolTipPanel
extends PanelContainer

@export var keyword_database: KeywordDatabase = preload("res://custom_resource/default_keyword_database.tres")

@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var desc_label: RichTextLabel = %DescLabel
@onready var icon_texture: TextureRect = %TextureRect
@onready var keyword_explain_panel: KeywordExplainPanel = %KeywordExplainPanel


# 显示技能名称、等级、图标和说明。
func set_skill(skill_entry: SkillEntry) -> void:
	if skill_entry == null or skill_entry.skill_data == null:
		return

	_ensure_node_refs()
	if name_label == null or level_label == null or desc_label == null or icon_texture == null:
		return

	var skill_data := skill_entry.skill_data
	name_label.text = skill_data.skill_name
	level_label.text = "Lv.%s / %s" % [skill_entry.level, skill_data.max_level]
	_refresh_keyword_text(skill_data.desc)
	icon_texture.texture = skill_data.icon


# Tooltip 可能在刚 instantiate、还没进入场景树时就被灌入数据。
# 这里手动查找一次节点，避免 @onready 尚未执行导致空引用。
func _ensure_node_refs() -> void:
	if name_label == null:
		name_label = get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/NameLabel") as Label
	if level_label == null:
		level_label = get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/LevelLabel") as Label
	if desc_label == null:
		desc_label = get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/DescLabel") as RichTextLabel
	if icon_texture == null:
		icon_texture = get_node_or_null("MarginContainer/HBoxContainer/TextureRect") as TextureRect
	if keyword_explain_panel == null:
		keyword_explain_panel = get_node_or_null("MarginContainer/HBoxContainer/VBoxContainer/KeywordExplainPanel") as KeywordExplainPanel


func _refresh_keyword_text(raw_desc: String) -> void:
	var result := KeywordTextFormatter.format_text(raw_desc, keyword_database)
	if desc_label != null:
		desc_label.clear()
		desc_label.append_text(result.bbcode_text)
	if keyword_explain_panel != null:
		keyword_explain_panel.setup_keywords(result.keywords)
