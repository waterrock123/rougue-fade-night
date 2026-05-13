class_name ShopEquipButton
extends Button

signal purchase_requested(slot_index: int)

const NORMAL_MODULATE := Color(1, 1, 1, 1)
const FROZEN_MODULATE := Color(0.6, 0.8, 1.0, 1.0)
const MATCH_GLOW_SHADER := preload("res://shaders/shop_slot_match_glow.gdshader")
const TAG_UI_SCENE := preload("res://scenes/tooltip/tag_ui.tscn")
const LEVEL_COLORS: Array[Color] = [Color.ANTIQUE_WHITE, Color.GREEN_YELLOW, Color.CYAN, Color.DEEP_PINK, Color.CHOCOLATE, Color.RED]

@onready var slot_background: ColorRect = $SlotBackground
@onready var center_container: CenterContainer = $SlotBackground/CenterContainer
@onready var clear_label: Label = %ClearLabel
@onready var number_label: Label = %NumberLabel
@onready var gold_icon: TextureRect = $SlotBackground/Glod
@onready var slot_button_slot_relic: RelicUI = $SlotBackground/CenterContainer/RelicUI
@onready var name_label: Label = $SlotBackground/NameLabel
@onready var tag_container: VBoxContainer = $SlotBackground/VBoxContainer
@onready var level_label: Label = _resolve_level_label()

var slot_: Slot
var slot_index: int = -1
var is_frozen: bool = false
var match_glow_material: ShaderMaterial
var level_label_template := "LV {0}"
var runtime_level_label_settings: LabelSettings


func _ready() -> void:
	button_mask = MOUSE_BUTTON_MASK_LEFT
	if level_label != null:
		level_label_template = level_label.text if not level_label.text.is_empty() else level_label_template
	_setup_match_glow_material()
	update_button()


# 用一个 slot 数据刷新当前按钮的商品显示。
func set_slot(new_slot: Slot) -> void:
	slot_ = new_slot
	slot_button_slot_relic.slot_ = slot_
	slot_button_slot_relic.slot_relic_update()
	tooltip_text = " " if not is_empty() else ""
	update_button()


# 设置冻结状态并同步显示。
func set_frozen(frozen: bool) -> void:
	is_frozen = frozen
	modulate = FROZEN_MODULATE if is_frozen else NORMAL_MODULATE


# 当玩家背包/装备栏里已经有同 id 遗物时，开启格子边缘的金色闪光提示。
func set_owned_match_highlight(enabled: bool) -> void:
	_setup_match_glow_material()
	if match_glow_material == null:
		return

	match_glow_material.set_shader_parameter("glow_enabled", enabled)


# 清空当前格子的商品。
func clear_relic() -> void:
	if slot_ == null:
		slot_ = Slot.new()

	slot_.item = null
	slot_button_slot_relic.slot_ = slot_
	slot_button_slot_relic.slot_relic_update()
	tooltip_text = ""
	update_button()


# 刷新价格、空位提示和图标显示。
func update_button() -> void:
	var relic_data := _get_slot_relic_data()
	if relic_data != null:
		number_label.text = str(relic_data.price)
		number_label.visible = true
		gold_icon.visible = true
		clear_label.visible = false
		_update_name_label(relic_data)
		_update_level_label(relic_data)
		_refresh_tags(relic_data)
	else:
		number_label.visible = false
		gold_icon.visible = false
		clear_label.visible = true
		_update_name_label(null)
		_update_level_label(null)
		_refresh_tags(null)
		set_owned_match_highlight(false)


func _make_custom_tooltip(_for_text: String) -> Object:
	var relic_data := _get_slot_relic_data()
	if relic_data == null:
		return null

	var tool_tip_panel: RelicToolTip = FloatText.RELIC_TOOL_TIP_PANEL.instantiate()
	tool_tip_panel.set_tool_tip(relic_data)
	return tool_tip_panel


func _get_slot_relic_data() -> Relic:
	if slot_button_slot_relic == null:
		return null
	if slot_button_slot_relic.slot_ == null:
		return null
	return slot_button_slot_relic.slot_.item


func _setup_match_glow_material() -> void:
	if match_glow_material != null or slot_background == null:
		return

	match_glow_material = ShaderMaterial.new()
	match_glow_material.shader = MATCH_GLOW_SHADER
	match_glow_material.set_shader_parameter("glow_enabled", false)
	slot_background.material = match_glow_material


func _update_name_label(relic_data: Relic) -> void:
	if name_label == null:
		return

	if relic_data == null:
		name_label.hide()
		name_label.text = ""
		return

	name_label.show()
	name_label.text = relic_data.relic_name


func _update_level_label(relic_data: Relic) -> void:
	if level_label == null:
		return

	if relic_data == null:
		level_label.hide()
		level_label.text = ""
		return

	level_label.show()
	level_label.text = level_label_template.format([relic_data.level])
	var color_index = clamp(relic_data.level - 1, 0, LEVEL_COLORS.size() - 1)
	_set_level_label_color(LEVEL_COLORS[color_index])


func _refresh_tags(relic_data: Relic) -> void:
	if tag_container == null:
		return

	_clear_tag_container()
	if relic_data == null:
		return

	for tag in relic_data.tags:
		if tag == null:
			continue

		var tag_ui := TAG_UI_SCENE.instantiate() as TagUI
		tag_container.add_child(tag_ui)
		tag_ui.setup(tag)


func _clear_tag_container() -> void:
	for child in tag_container.get_children():
		if child is TagUI:
			tag_container.remove_child(child)
			child.queue_free()


func _resolve_level_label() -> Label:
	var resolved := get_node_or_null("SlotBackground/LevelLabel") as Label
	if resolved != null:
		return resolved

	return get_node_or_null("SlotBackground/Label") as Label


func _set_level_label_color(color: Color) -> void:
	if level_label == null:
		return

	if runtime_level_label_settings == null:
		if level_label.label_settings != null:
			runtime_level_label_settings = level_label.label_settings.duplicate() as LabelSettings
		else:
			runtime_level_label_settings = LabelSettings.new()
		level_label.label_settings = runtime_level_label_settings

	runtime_level_label_settings.font_color = color


func is_empty() -> bool:
	return _get_slot_relic_data() == null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed and mouse_event.double_click:
			purchase_requested.emit(slot_index)
