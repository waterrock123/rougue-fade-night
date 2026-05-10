class_name KeywordExplainEntry
extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var desc_label: Label = %DescLabel


func setup(keyword: KeywordData) -> void:
	_ensure_node_refs()
	if keyword == null or name_label == null or desc_label == null:
		hide()
		return

	show()
	name_label.text = keyword.display_name
	desc_label.text = keyword.desc
	_apply_keyword_color(keyword.color)


func _ensure_node_refs() -> void:
	if name_label == null:
		name_label = get_node_or_null("VBoxContainer/MarginContainer/NameLabel") as Label
	if desc_label == null:
		desc_label = get_node_or_null("VBoxContainer/DescLabel") as Label


func _apply_keyword_color(color: Color) -> void:
	if name_label == null:
		return

	var style_box := name_label.get_theme_stylebox("normal")
	if style_box is StyleBoxFlat:
		var copied_style := (style_box as StyleBoxFlat).duplicate() as StyleBoxFlat
		copied_style.bg_color = color
		name_label.add_theme_stylebox_override("normal", copied_style)
