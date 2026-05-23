class_name TagEffectShowButton
extends Button

signal tag_pressed(tag: RelicTag)

@onready var tag_label: Label = $HBoxContainer/TagLabel
@onready var effect_icon: TextureRect = $HBoxContainer/TagEffectIcon
@onready var effect_name_label: Label = $HBoxContainer/TagEffectName
@onready var count_label: Label = $HBoxContainer/CountLabel

var tag: RelicTag
var selected_effect: TagEffect


func _ready() -> void:
	toggle_mode = true
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)


func setup(new_tag: RelicTag, effect: TagEffect) -> void:
	_resolve_nodes()
	tag = new_tag
	selected_effect = effect

	if tag_label != null:
		tag_label.text = "%s：" % (tag.tag_name if tag != null else "未知")
		_apply_tag_label_color(tag.color if tag != null else Color.WHITE)

	if effect_icon != null:
		effect_icon.texture = effect.icon if effect != null else null
		effect_icon.visible = effect_icon.texture != null

	if effect_name_label != null:
		effect_name_label.text = effect.get_display_name() if effect != null else "未选择"

	if count_label != null:
		count_label.text = str(effect.required_count) if effect != null else "-"


func set_selected(selected: bool) -> void:
	button_pressed = selected


func _on_pressed() -> void:
	tag_pressed.emit(tag)


func _apply_tag_label_color(color: Color) -> void:
	if tag_label == null:
		return

	var style_box := tag_label.get_theme_stylebox("normal")
	if style_box is StyleBoxFlat:
		var copied_style := (style_box as StyleBoxFlat).duplicate() as StyleBoxFlat
		copied_style.bg_color = color
		tag_label.add_theme_stylebox_override("normal", copied_style)


func _resolve_nodes() -> void:
	if tag_label == null:
		tag_label = get_node_or_null("HBoxContainer/TagLabel") as Label
	if effect_icon == null:
		effect_icon = get_node_or_null("HBoxContainer/TagEffectIcon") as TextureRect
	if effect_name_label == null:
		effect_name_label = get_node_or_null("HBoxContainer/TagEffectName") as Label
	if count_label == null:
		count_label = get_node_or_null("HBoxContainer/CountLabel") as Label
