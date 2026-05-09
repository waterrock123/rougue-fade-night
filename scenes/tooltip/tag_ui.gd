class_name TagUI
extends HBoxContainer

@onready var label: Label = $Label


func setup(tag: RelicTag) -> void:
	if tag == null:
		hide()
		return

	_resolve_nodes()
	if label == null:
		return

	show()
	label.text = tag.tag_name
	_apply_tag_color(tag.color)


func _resolve_nodes() -> void:
	# Tooltip 会在 instantiate 后立刻 setup，此时 @onready 可能还没跑，所以这里做一次兜底获取。
	if label == null:
		label = get_node_or_null("Label") as Label


func _apply_tag_color(color: Color) -> void:
	_resolve_nodes()
	if label == null:
		return

	# 每个标签都复制一份 StyleBox，避免改一个标签时把所有标签的背景一起改掉。
	var style_box := label.get_theme_stylebox("normal")
	if style_box is StyleBoxFlat:
		var copied_style := (style_box as StyleBoxFlat).duplicate() as StyleBoxFlat
		copied_style.bg_color = color
		label.add_theme_stylebox_override("normal", copied_style)
