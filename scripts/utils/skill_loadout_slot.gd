class_name SkillLoadoutSlot
extends PanelContainer

signal toggle_requested(entry: SkillEntry)
signal drop_requested(entry: SkillEntry, should_equip: bool)

@onready var icon_texture: TextureRect = %IconTexture
@onready var state_label: Label = %StateLabel

var skill_entry: SkillEntry
var target_is_equipped: bool = false
var locked: bool = false


## 设置技能图标、携带状态和当前槽位是否允许调整。
func setup(new_entry: SkillEntry, is_equipped_slot: bool, is_locked: bool = false) -> void:
	skill_entry = new_entry
	target_is_equipped = is_equipped_slot
	locked = is_locked

	if skill_entry == null or skill_entry.skill_data == null:
		icon_texture.texture = null
		state_label.text = "空位"
		modulate = Color(1.0, 1.0, 1.0, 0.45)
		tooltip_text = ""
		return

	icon_texture.texture = skill_entry.skill_data.icon
	state_label.text = "已携带" if is_equipped_slot else "未携带"
	if locked:
		state_label.text = "固定"
		modulate = Color(0.72, 0.78, 0.82, 1.0)
	else:
		modulate = Color.WHITE
	tooltip_text = " "


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## 右键技能槽可以直接在已携带和未携带之间切换。
func _gui_input(event: InputEvent) -> void:
	if locked or skill_entry == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			toggle_requested.emit(skill_entry)
			accept_event()


## 拖拽技能时只传递 SkillEntry，不把 UI 节点本身带到另一个容器。
func _get_drag_data(_at_position: Vector2) -> Variant:
	if locked or skill_entry == null or skill_entry.skill_data == null:
		return null

	var preview := TextureRect.new()
	preview.texture = skill_entry.skill_data.icon
	preview.custom_minimum_size = Vector2(64.0, 64.0)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"type": "skill_loadout", "entry": skill_entry}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var data_dict: Dictionary = data
	return data_dict.get("type", "") == "skill_loadout" and data_dict.get("entry") is SkillEntry


## 把技能拖到上排代表携带，拖到下排代表卸下。
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var data_dict: Dictionary = data
	var dragged_entry: SkillEntry = data_dict.get("entry") as SkillEntry
	drop_requested.emit(dragged_entry, target_is_equipped)


func _make_custom_tooltip(_for_text: String) -> Object:
	if skill_entry == null or skill_entry.skill_data == null:
		return null
	var tooltip := FloatText.SKILL_TOOL_TIP_PANEL.instantiate() as SkillToolTipPanel
	tooltip.set_skill(skill_entry)
	return tooltip
