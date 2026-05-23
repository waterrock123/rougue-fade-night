class_name TagEffectTooltip
extends VBoxContainer

@export var keyword_database: KeywordDatabase = preload("res://custom_resource/default_keyword_database.tres")

@onready var tag_ui: TagUI = $HBoxContainer/TagUI
@onready var effect_name_label: Label = %TagEffectName
@onready var count_label: Label = $HBoxContainer/CountLabel
@onready var desc_label: RichTextLabel = $TagEffectDesc


func setup(snapshot: Dictionary) -> void:
	_resolve_nodes()

	var effect := snapshot.get("effect") as TagEffect
	var tag := snapshot.get("tag") as RelicTag
	var count := int(snapshot.get("count", 0))
	var required_count := int(snapshot.get("required_count", 0))
	var is_active := bool(snapshot.get("is_active", false))
	var is_completed := bool(snapshot.get("is_completed", false))

	if tag_ui != null:
		tag_ui.setup(tag)

	if effect_name_label != null:
		effect_name_label.text = str(snapshot.get("name", effect.get_display_name() if effect != null else ""))

	if count_label != null:
		if is_completed:
			count_label.text = "已完成"
		elif is_active:
			count_label.text = "已激活"
		else:
			count_label.text = "%s/%s" % [count, required_count]

	if desc_label != null:
		desc_label.bbcode_enabled = true
		var desc := str(snapshot.get("desc", ""))
		var result := KeywordTextFormatter.format_text(desc, keyword_database)
		desc_label.text = result.bbcode_text

	show()


func _resolve_nodes() -> void:
	if tag_ui == null:
		tag_ui = get_node_or_null("HBoxContainer/TagUI") as TagUI
	if effect_name_label == null:
		effect_name_label = get_node_or_null("%TagEffectName") as Label
	if count_label == null:
		count_label = get_node_or_null("HBoxContainer/CountLabel") as Label
	if desc_label == null:
		desc_label = get_node_or_null("TagEffectDesc") as RichTextLabel
