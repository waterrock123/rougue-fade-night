class_name PictorialEquipmentUI
extends CenterContainer

signal selected(ui: PictorialEquipmentUI, relic: Relic)

const TAG_UI_SCENE := preload("res://scenes/tooltip/tag_ui.tscn")
const LEVEL_COLORS: Array[Color] = [Color.ANTIQUE_WHITE, Color.GREEN_YELLOW, Color.CYAN, Color.DEEP_PINK, Color.CHOCOLATE, Color.RED]

var relic: Relic

@onready var button: Button = $Button
@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var tag_list: Control = %TagList
@onready var unique_icon: TextureRect = %UniqueIcon


func _ready() -> void:
	if button != null and not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


# 用装备资源刷新左侧图鉴格子的简要展示。
func setup(new_relic: Relic) -> void:
	relic = new_relic
	_resolve_nodes()
	if relic == null:
		hide()
		return

	show()
	icon_rect.texture = relic.icon if icon_rect != null else null
	name_label.text = relic.relic_name if name_label != null else ""
	_refresh_level()
	_refresh_tags()
	if unique_icon != null:
		unique_icon.visible = relic.relic_type == Relic.RelicType.UNIQUE


func set_selected(value: bool) -> void:
	_resolve_nodes()
	if button != null:
		button.button_pressed = value


func _on_button_pressed() -> void:
	selected.emit(self, relic)


func _refresh_level() -> void:
	if level_label == null:
		return

	level_label.text = "Lv.%s" % str(relic.level)
	_apply_level_color(level_label, relic.level)


func _apply_level_color(label: Label, relic_level: int) -> void:
	var level_color := LEVEL_COLORS[clamp(relic_level - 1, 0, LEVEL_COLORS.size() - 1)]

	# 每个格子复制一份 LabelSettings，避免多个等阶 Label 共用资源时互相覆盖颜色。
	if label.label_settings == null:
		label.label_settings = LabelSettings.new()
	else:
		label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = level_color
	label.add_theme_color_override("font_color", level_color)


func _refresh_tags() -> void:
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
	if button == null:
		button = get_node_or_null("Button") as Button
	if icon_rect == null:
		icon_rect = get_node_or_null("%Icon") as TextureRect
	if name_label == null:
		name_label = get_node_or_null("%NameLabel") as Label
	if level_label == null:
		level_label = get_node_or_null("%LevelLabel") as Label
	if tag_list == null:
		tag_list = get_node_or_null("%TagList") as Control
	if unique_icon == null:
		unique_icon = get_node_or_null("%UniqueIcon") as TextureRect
