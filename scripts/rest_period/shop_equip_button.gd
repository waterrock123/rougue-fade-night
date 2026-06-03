class_name ShopEquipButton
extends Button

signal purchase_requested(slot_index: int)
signal purchase_focus_requested(slot_index: int)

const NORMAL_MODULATE := Color(1, 1, 1, 1)
const FROZEN_MODULATE := Color(0.6, 0.8, 1.0, 1.0)
const NORMAL_SLOT_COLOR := Color(0.31764707, 0.4509804, 0.8235294, 0.36078432)
const HOVER_SLOT_COLOR := Color(0.95, 0.72, 0.22, 0.58)
const PENDING_SLOT_COLOR := Color(1.0, 0.48, 0.12, 0.68)
const EMPTY_SLOT_COLOR := Color(0.18, 0.22, 0.32, 0.28)
const CONTENT_NORMAL_MODULATE := Color(1, 1, 1, 1)
const CONTENT_PENDING_MODULATE := Color(1, 1, 1, 0.25)
const PURCHASE_PROMPT_TEXT := "再次点击购买"
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
var is_hovered: bool = false
var is_purchase_pending: bool = false
var purchase_prompt_label: Label


func _ready() -> void:
	button_mask = MOUSE_BUTTON_MASK_LEFT
	if level_label != null:
		level_label_template = level_label.text if not level_label.text.is_empty() else level_label_template
	_setup_match_glow_material()
	_setup_purchase_prompt_label()
	_connect_hover_signals()
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
	_apply_interaction_visuals()


func set_purchase_pending(enabled: bool) -> void:
	is_purchase_pending = enabled and not is_empty()
	_apply_interaction_visuals()


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
	is_purchase_pending = false
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
		is_purchase_pending = false
		number_label.visible = false
		gold_icon.visible = false
		clear_label.visible = true
		_update_name_label(null)
		_update_level_label(null)
		_refresh_tags(null)
		set_owned_match_highlight(false)

	_apply_interaction_visuals()


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


func _setup_purchase_prompt_label() -> void:
	if purchase_prompt_label != null or slot_background == null:
		return

	purchase_prompt_label = Label.new()
	purchase_prompt_label.name = "PurchasePromptLabel"
	purchase_prompt_label.text = PURCHASE_PROMPT_TEXT
	purchase_prompt_label.visible = false
	purchase_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purchase_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	purchase_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	purchase_prompt_label.add_theme_font_size_override("font_size", 28)
	purchase_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.62, 1.0))
	purchase_prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	purchase_prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	purchase_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	slot_background.add_child(purchase_prompt_label)
	purchase_prompt_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	purchase_prompt_label.offset_left = 0.0
	purchase_prompt_label.offset_top = 0.0
	purchase_prompt_label.offset_right = 0.0
	purchase_prompt_label.offset_bottom = 0.0


func _connect_hover_signals() -> void:
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _apply_interaction_visuals() -> void:
	if slot_background == null:
		return

	if is_empty():
		slot_background.color = EMPTY_SLOT_COLOR
		_set_content_modulate(CONTENT_NORMAL_MODULATE)
		_set_purchase_prompt_visible(false)
		return

	if is_purchase_pending:
		slot_background.color = PENDING_SLOT_COLOR
		_set_content_modulate(CONTENT_PENDING_MODULATE)
		_set_purchase_prompt_visible(true)
		return

	slot_background.color = HOVER_SLOT_COLOR if is_hovered else NORMAL_SLOT_COLOR
	_set_content_modulate(CONTENT_NORMAL_MODULATE)
	_set_purchase_prompt_visible(false)


func _set_content_modulate(color: Color) -> void:
	for control in _get_content_controls():
		if control != null:
			control.modulate = color


func _get_content_controls() -> Array[CanvasItem]:
	return [
		center_container,
		clear_label,
		number_label,
		gold_icon,
		slot_button_slot_relic,
		name_label,
		tag_container,
		level_label,
	]


func _set_purchase_prompt_visible(visible: bool) -> void:
	if purchase_prompt_label != null:
		purchase_prompt_label.visible = visible


func _on_mouse_entered() -> void:
	is_hovered = true
	_apply_interaction_visuals()


func _on_mouse_exited() -> void:
	is_hovered = false
	_apply_interaction_visuals()


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
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return

		accept_event()
		if is_empty():
			purchase_focus_requested.emit(slot_index)
			return

		if is_purchase_pending:
			purchase_requested.emit(slot_index)
		else:
			purchase_focus_requested.emit(slot_index)
