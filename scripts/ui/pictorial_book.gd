class_name PictorialBook
extends Control

enum BookType {
	EQUIPMENT,
	ACTIVE_SKILL,
	PASSIVE_SKILL,
}

const EQUIPMENT_ITEM_SCENE := preload("res://scenes/ui/pictorial_equipment_ui.tscn")
const ACTIVE_SKILL_ITEM_SCENE := preload("res://scenes/ui/pictorial_active_skill_ui.tscn")
const PASSIVE_SKILL_ITEM_SCENE := preload("res://scenes/ui/pictorial_passive_skill_ui.tscn")
const EQUIPMENT_DETAIL_SCENE := preload("res://scenes/ui/equipment_book_detail_ui.tscn")
const ACTIVE_SKILL_DETAIL_SCENE := preload("res://scenes/ui/active_skill_book_detail.tscn")
const PASSIVE_SKILL_DETAIL_SCENE := preload("res://scenes/ui/passive_skill_book_detail.tscn")
const BOOK_TYPE_ORDER: Array[int] = [BookType.EQUIPMENT, BookType.ACTIVE_SKILL, BookType.PASSIVE_SKILL]

@export var relic_root_folder: String = "res://relics"
@export var active_skill_folder: String = "res://activate_skill"
@export var passive_skill_folder: String = "res://passive_skill"

@onready var left_button: TextureButton = %LeftButton
@onready var right_button: TextureButton = %RightButton
@onready var type_label: Label = %DivideLabel
@onready var grid_container: GridContainer = $Panel/PictorialBookBar/GridContainer
@onready var detail_container: MarginContainer = %DetailContainer
@onready var exit_button: Button = $Panel2/ExitButton

var current_type: int = BookType.EQUIPMENT
var relics: Array[Relic] = []
var active_skills: Array[ActiveSkillData] = []
var passive_skills: Array[PassiveSkillData] = []
var current_items: Array[Control] = []


func _ready() -> void:
	_connect_buttons()
	_load_all_data()
	_show_type(BookType.EQUIPMENT)


func _connect_buttons() -> void:
	if left_button != null and not left_button.pressed.is_connected(_on_left_button_pressed):
		left_button.pressed.connect(_on_left_button_pressed)
	if right_button != null and not right_button.pressed.is_connected(_on_right_button_pressed):
		right_button.pressed.connect(_on_right_button_pressed)
	if exit_button != null and not exit_button.pressed.is_connected(_on_exit_button_pressed):
		exit_button.pressed.connect(_on_exit_button_pressed)


# 图鉴只读取静态资源，不依赖 Run，因此主菜单也可以直接打开。
func _load_all_data() -> void:
	relics = _load_relics()
	active_skills = _load_active_skills()
	passive_skills = _load_passive_skills()


func _show_type(type: int) -> void:
	current_type = type
	_refresh_type_label()
	_clear_grid()
	_clear_detail()

	match current_type:
		BookType.EQUIPMENT:
			_build_relic_grid()
		BookType.ACTIVE_SKILL:
			_build_active_skill_grid()
		BookType.PASSIVE_SKILL:
			_build_passive_skill_grid()

	_select_first_item()


func _build_relic_grid() -> void:
	for relic in relics:
		var item := EQUIPMENT_ITEM_SCENE.instantiate() as PictorialEquipmentUI
		grid_container.add_child(item)
		item.setup(relic)
		item.selected.connect(_on_relic_selected)
		current_items.append(item)


func _build_active_skill_grid() -> void:
	for skill_data in active_skills:
		var item := ACTIVE_SKILL_ITEM_SCENE.instantiate() as PictorialSkillUI
		grid_container.add_child(item)
		item.setup(skill_data)
		item.selected.connect(_on_skill_selected)
		current_items.append(item)


func _build_passive_skill_grid() -> void:
	for skill_data in passive_skills:
		var item := PASSIVE_SKILL_ITEM_SCENE.instantiate() as PictorialSkillUI
		grid_container.add_child(item)
		item.setup(skill_data)
		item.selected.connect(_on_skill_selected)
		current_items.append(item)


func _select_first_item() -> void:
	if current_items.is_empty():
		return

	var first_item := current_items[0]
	match current_type:
		BookType.EQUIPMENT:
			var equipment_item := first_item as PictorialEquipmentUI
			if equipment_item != null:
				_on_relic_selected(equipment_item, equipment_item.relic)
		_:
			var skill_item := first_item as PictorialSkillUI
			if skill_item != null:
				_on_skill_selected(skill_item, skill_item.skill_data)


func _on_relic_selected(ui: PictorialEquipmentUI, relic: Relic) -> void:
	_set_selected_item(ui)
	_clear_detail()
	var detail := EQUIPMENT_DETAIL_SCENE.instantiate() as PictorialEquipmentBookDetail
	detail_container.add_child(detail)
	detail.setup(relic)


func _on_skill_selected(ui: PictorialSkillUI, skill_data: SkillData) -> void:
	_set_selected_item(ui)
	_clear_detail()

	var detail_scene := ACTIVE_SKILL_DETAIL_SCENE if skill_data is ActiveSkillData else PASSIVE_SKILL_DETAIL_SCENE
	var detail := detail_scene.instantiate() as PictorialSkillBookDetail
	detail_container.add_child(detail)
	detail.setup(skill_data)


func _set_selected_item(selected_item: Control) -> void:
	for item in current_items:
		if item is PictorialEquipmentUI:
			(item as PictorialEquipmentUI).set_selected(item == selected_item)
		elif item is PictorialSkillUI:
			(item as PictorialSkillUI).set_selected(item == selected_item)


func _on_left_button_pressed() -> void:
	_show_type(_get_previous_type())


func _on_right_button_pressed() -> void:
	_show_type(_get_next_type())


func _on_exit_button_pressed() -> void:
	ResourceLocator.go_to_home_scene()


func _get_previous_type() -> int:
	var current_index := BOOK_TYPE_ORDER.find(current_type)
	if current_index < 0:
		return BookType.EQUIPMENT
	return BOOK_TYPE_ORDER[(current_index - 1 + BOOK_TYPE_ORDER.size()) % BOOK_TYPE_ORDER.size()]


func _get_next_type() -> int:
	var current_index := BOOK_TYPE_ORDER.find(current_type)
	if current_index < 0:
		return BookType.EQUIPMENT
	return BOOK_TYPE_ORDER[(current_index + 1) % BOOK_TYPE_ORDER.size()]


func _refresh_type_label() -> void:
	if type_label == null:
		return

	match current_type:
		BookType.EQUIPMENT:
			type_label.text = "装备"
		BookType.ACTIVE_SKILL:
			type_label.text = "主动技能"
		BookType.PASSIVE_SKILL:
			type_label.text = "被动技能"


func _clear_grid() -> void:
	current_items.clear()
	if grid_container == null:
		return

	for child in grid_container.get_children():
		grid_container.remove_child(child)
		child.queue_free()


func _clear_detail() -> void:
	if detail_container == null:
		return

	for child in detail_container.get_children():
		detail_container.remove_child(child)
		child.queue_free()


func _load_relics() -> Array[Relic]:
	var resources: Array[Resource] = []
	_collect_resources(relic_root_folder, resources)

	var result: Array[Relic] = []
	for resource in resources:
		if resource is Relic:
			result.append(resource as Relic)

	result.sort_custom(Callable(self, "_sort_relics"))
	return result


func _load_active_skills() -> Array[ActiveSkillData]:
	var resources: Array[Resource] = []
	_collect_resources(active_skill_folder, resources)

	var result: Array[ActiveSkillData] = []
	for resource in resources:
		if resource is ActiveSkillData:
			result.append(resource as ActiveSkillData)

	result.sort_custom(Callable(self, "_sort_skills"))
	return result


func _load_passive_skills() -> Array[PassiveSkillData]:
	var resources: Array[Resource] = []
	_collect_resources(passive_skill_folder, resources)

	var result: Array[PassiveSkillData] = []
	for resource in resources:
		if resource is PassiveSkillData:
			result.append(resource as PassiveSkillData)

	result.sort_custom(Callable(self, "_sort_skills"))
	return result


# 递归扫描资源文件夹，后续新增资源只要放进对应目录就会进入图鉴。
func _collect_resources(folder_path: String, result: Array[Resource]) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := folder_path.path_join(file_name)
		if dir.current_is_dir():
			_collect_resources(full_path, result)
		elif _is_resource_file(file_name):
			var resource := load(full_path) as Resource
			if resource != null:
				result.append(resource)

		file_name = dir.get_next()
	dir.list_dir_end()


func _is_resource_file(file_name: String) -> bool:
	var extension := file_name.get_extension().to_lower()
	return extension == "tres" or extension == "res"


func _sort_relics(a: Relic, b: Relic) -> bool:
	if a.level != b.level:
		return a.level < b.level
	return _resource_sort_key(a.id, a.relic_name) < _resource_sort_key(b.id, b.relic_name)


func _sort_skills(a: SkillData, b: SkillData) -> bool:
	return _resource_sort_key(String(a.id), a.skill_name) < _resource_sort_key(String(b.id), b.skill_name)


func _resource_sort_key(id_text: String, fallback_name: String) -> String:
	if not id_text.is_empty():
		return id_text
	return fallback_name
