@tool
extends Window
## 地图工坊窗口：配置、生成、预览、另存。不会改当前打开的场景或自动加入正式地图池。

signal template_saved(path: String)

const SETTINGS: Script = preload("res://scripts/battlemap/battle_map_draft_settings.gd")
const LAYOUT: Script = preload("res://scripts/battlemap/battle_map_draft_layout.gd")
const BUILDER: Script = preload("res://addons/battle_map_workshop/map_scene_builder.gd")
const PREVIEW: Script = preload("res://addons/battle_map_workshop/map_preview.gd")

var settings: Resource = SETTINGS.new()
var builder: RefCounted = BUILDER.new()
var preview: SubViewportContainer
var fields: Dictionary = {}
var style_choice: OptionButton
var source_path: LineEdit
var report: Label
var save_button: Button
var dialog: FileDialog
var layout: Dictionary = {}
var generated_root: Node2D
var pending_action: String = ""
var syncing: bool = false


func _init() -> void:
	visible = false
	title = "战斗地图工坊"
	min_size = Vector2i(1020, 700)
	size = Vector2i(1260, 800)
	transient = true
	exclusive = true
	close_requested.connect(hide)
	_build_ui()
	_sync_fields()


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)
	_label(main, "战斗地图工坊", 24)
	_label(main, "先生成、再预览、满意后另存模板。不会覆盖旧地图，也不会修改正式地图池。")
	var columns: HSplitContainer = HSplitContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(columns)
	_build_options(columns)
	_build_preview(columns)
	report = _label(main, "选择布局后点击生成。预览中P为玩家出生点，E为敌人出生点。")
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.custom_minimum_size.y = 54
	dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.file_selected.connect(_on_file_selected)
	add_child(dialog)


func _build_options(parent: Control) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size.x = 300
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var options: VBoxContainer = VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 10)
	scroll.add_child(options)
	_label(options, "布局配置", 18)
	style_choice = OptionButton.new()
	for text: String in ["环形林地", "多片空地相连", "中央竞技场"]:
		style_choice.add_item(text)
	style_choice.item_selected.connect(_mark_dirty.unbind(1))
	options.add_child(style_choice)
	for spec: Array in [["seed_value", "种子", 0, 999999999, 1], ["width", "地图列数", 48, 128, 1], ["height", "地图行数", 36, 96, 1], ["passage_width", "通道宽度（格）", 5, 13, 2], ["clearing_count", "空地数量", 3, 7, 1], ["obstacle_count", "障碍簇上限", 0, 16, 1], ["ground_padding", "草地外扩（格）", 0, 3, 1]]:
		_number(options, spec)
	_label(options, "瓦片素材来源", 18)
	source_path = LineEdit.new()
	source_path.tooltip_text = "只读取此场景的TileSet，不会改动源地图。"
	source_path.text_changed.connect(_mark_dirty.unbind(1))
	options.add_child(source_path)
	_button(options, "选择素材地图…", _choose_palette)
	_button(options, "按当前种子生成", generate_map)
	_button(options, "换一个种子生成", _randomize_seed)
	options.add_child(HSeparator.new())
	save_button = _button(options, "保存为新模板…", _choose_template_path)
	save_button.disabled = true
	_button(options, "保存配置…", _choose_preset_save)
	_button(options, "载入配置…", _choose_preset_load)


func _build_preview(parent: Control) -> void:
	var section: VBoxContainer = VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(section)
	var toolbar: HBoxContainer = HBoxContainer.new()
	section.add_child(toolbar)
	_label(toolbar, "瓦片预览", 18)
	_button(toolbar, "适应窗口", func() -> void: preview.call("_fit_map"))
	var show_spawns: CheckButton = CheckButton.new()
	show_spawns.text = "显示出生点"
	show_spawns.button_pressed = true
	show_spawns.toggled.connect(func(value: bool) -> void: preview.call("set_spawns_visible", value))
	toolbar.add_child(show_spawns)
	preview = PREVIEW.new()
	section.add_child(preview)
	_label(section, "滚轮缩放 · 中键拖动 · 预览不运行战斗与地图物件逻辑")


func _number(parent: Control, spec: Array) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var label: Label = _label(row, str(spec[1]))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var field: SpinBox = SpinBox.new()
	field.min_value = float(spec[2])
	field.max_value = float(spec[3])
	field.step = float(spec[4])
	field.custom_minimum_size.x = 140
	field.value_changed.connect(_mark_dirty.unbind(1))
	row.add_child(field)
	fields[str(spec[0])] = field


func _label(parent: Node, text: String, font_size: int = 14) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _sync_fields() -> void:
	syncing = true
	style_choice.select(int(settings.get("layout_style")))
	source_path.text = str(settings.get("palette_scene"))
	for key: String in fields:
		fields[key].value = float(settings.get(key))
	syncing = false


func _read_fields() -> void:
	settings.set("layout_style", style_choice.selected)
	settings.set("palette_scene", source_path.text.strip_edges())
	for key: String in fields:
		settings.set(key, int(fields[key].value))


func _mark_dirty() -> void:
	if syncing or save_button == null:
		return
	save_button.disabled = true
	if report != null:
		report.text = "参数已更改；请重新生成后再保存。当前预览仍是上一次的结果。"


func generate_map() -> void:
	_read_fields()
	var generator: RefCounted = LAYOUT.new()
	var draft: Dictionary = generator.call("generate", settings)
	var errors: PackedStringArray = draft.get("errors", [])
	if not errors.is_empty():
		_show_errors(errors)
		return
	if is_instance_valid(generated_root):
		preview.call("clear_map")
		generated_root = null
	var result: Dictionary = builder.call("build", draft, settings)
	errors = result.get("errors", [])
	if not errors.is_empty():
		_show_errors(errors)
		return
	layout = draft
	generated_root = result["root"] as Node2D
	preview.call("show_map", generated_root, layout)
	save_button.disabled = false
	report.text = "%s · 种子%d · 可游玩%d格 · 敌人出生点%d处。连通及出生点校验通过。\n保存后仍可在2D编辑器中调整装饰；通行区域由遮罩和独立边界碰撞共同控制。" % [layout["style"], layout["seed"], layout["playable"].size(), layout["enemies"].size()]


func _show_errors(errors: PackedStringArray) -> void:
	save_button.disabled = true
	report.text = "无法生成：\n" + "\n".join(errors)


func _randomize_seed() -> void:
	var local_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	local_rng.randomize()
	fields["seed_value"].value = local_rng.randi_range(1, 999999999)
	generate_map()


func _show_dialog(action: String, mode: FileDialog.FileMode, filter: String, directory: String, file_name: String = "") -> void:
	pending_action = action
	dialog.file_mode = mode
	dialog.filters = PackedStringArray([filter])
	dialog.current_dir = directory
	dialog.current_file = file_name
	dialog.popup_centered(Vector2i(900, 600))


func _choose_palette() -> void:
	_show_dialog("palette", FileDialog.FILE_MODE_OPEN_FILE, "*.tscn ; 地图场景", "res://scenes/battlemap/templates")


func _choose_template_path() -> void:
	var slug: String = ["ring", "clearings", "arena"][int(settings.get("layout_style"))]
	_show_dialog("template", FileDialog.FILE_MODE_SAVE_FILE, "*.tscn ; 地图模板", "res://scenes/battlemap/templates", "workshop_grass_%s_%d.tscn" % [slug, int(settings.get("seed_value"))])


func _choose_preset_save() -> void:
	_read_fields()
	_show_dialog("preset_save", FileDialog.FILE_MODE_SAVE_FILE, "*.tres ; 工坊配置", "res://custom_resource", "map_workshop_settings.tres")


func _choose_preset_load() -> void:
	_show_dialog("preset_load", FileDialog.FILE_MODE_OPEN_FILE, "*.tres ; 工坊配置", "res://custom_resource")


func _on_file_selected(path: String) -> void:
	match pending_action:
		"palette":
			source_path.text = path
			_mark_dirty()
		"template": _save_template(path)
		"preset_save": _save_preset(path)
		"preset_load": _load_preset(path)


func _save_template(path: String) -> void:
	if save_button.disabled:
		return
	var error: Error = builder.call("save_new_template", generated_root, path, str(settings.get("palette_scene")))
	if error != OK:
		report.text = "保存失败：%s。模板仅允许另存到scenes/battlemap/templates下的新文件，不覆盖旧文件。" % error_string(error)
		return
	report.text = "已保存：%s\n尚未加入正式地图池。可以关闭工坊后打开该场景，继续调整装饰和随机区域。" % path
	template_saved.emit(path)


func _save_preset(path: String) -> void:
	if FileAccess.file_exists(path):
		report.text = "配置文件已存在，请更换文件名，避免覆盖原配置。"
		return
	var error: Error = ResourceSaver.save(settings.duplicate(true), path)
	report.text = "配置已保存：%s" % path if error == OK else "配置保存失败：%s" % error_string(error)


func _load_preset(path: String) -> void:
	var loaded: Resource = load(path) as Resource
	if loaded == null or loaded.get_script() != SETTINGS:
		report.text = "请选择BattleMapDraftSettings类型的工坊配置。"
		return
	var errors: PackedStringArray = loaded.call("validate")
	if not errors.is_empty():
		_show_errors(errors)
		return
	settings = loaded.duplicate(true)
	_sync_fields()
	_mark_dirty()
