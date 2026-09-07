class_name SkillOverviewPanel
extends PanelContainer

const SKILL_SLOT_SCENE := preload("res://scenes/ui/passive_skill_ui.tscn")
const LOADOUT_SLOT_SCENE := preload("res://scenes/ui/skill_loadout_slot.tscn")

@export var empty_passive_slot_count: int = 4

@onready var carried_skill_container: HBoxContainer = %CarriedSkillContainer
@onready var uncarried_skill_container: HBoxContainer = %UncarriedSkillContainer
@onready var passive_container: HBoxContainer = %PassiveSkillContainer

var player_build: PlayerBuild


func _ready() -> void:
	refresh()
	close_panel()


## 绑定本局玩家构筑，面板只读取 PlayerBuild，不保存自己的技能状态。
func setup(new_player_build: PlayerBuild) -> void:
	player_build = new_player_build
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	_refresh_active_loadout()
	_refresh_passive_skills()


func open_panel() -> void:
	refresh()
	show()


func close_panel() -> void:
	hide()


## 上排显示已携带技能，下排显示拥有但未携带的永久技能。
func _refresh_active_loadout() -> void:
	_clear_container(carried_skill_container)
	_clear_container(uncarried_skill_container)
	if player_build == null:
		return

	var carried_entries: Array[SkillEntry] = player_build.get_equipped_active_skill_entries()
	var uncarried_entries: Array[SkillEntry] = []
	for entry: SkillEntry in player_build.owned_active_skills:
		if entry == null or entry.is_temporary or entry.is_equipped:
			continue
		uncarried_entries.append(entry)

	for entry: SkillEntry in carried_entries:
		var locked: bool = entry.is_temporary or _is_basic_attack(entry)
		_add_loadout_slot(carried_skill_container, entry, true, locked)

	var carried_slot_limit: int = player_build.get_active_skill_equipped_limit() + 1
	while carried_skill_container.get_child_count() < carried_slot_limit:
		_add_loadout_slot(carried_skill_container, null, true, false)

	for entry: SkillEntry in uncarried_entries:
		_add_loadout_slot(uncarried_skill_container, entry, false, false)


func _refresh_passive_skills() -> void:
	if passive_container == null:
		return
	_clear_container(passive_container)

	var entries: Array[SkillEntry] = []
	if player_build != null:
		entries = player_build.owned_passive_skills
	var slot_count: int = max(empty_passive_slot_count, entries.size())
	for index in range(slot_count):
		var slot_ui := SKILL_SLOT_SCENE.instantiate() as PassiveSkillUI
		passive_container.add_child(slot_ui)
		var entry: SkillEntry = entries[index] if index < entries.size() else null
		slot_ui.setup(entry)


func _add_loadout_slot(
	container: HBoxContainer,
	entry: SkillEntry,
	target_is_equipped: bool,
	locked: bool
) -> void:
	var slot := LOADOUT_SLOT_SCENE.instantiate() as SkillLoadoutSlot
	container.add_child(slot)
	slot.setup(entry, target_is_equipped, locked)
	slot.toggle_requested.connect(_on_skill_toggle_requested)
	slot.drop_requested.connect(_on_skill_drop_requested)


func _on_skill_toggle_requested(entry: SkillEntry) -> void:
	if entry == null or player_build == null:
		return
	_apply_loadout_change(entry, not entry.is_equipped)


func _on_skill_drop_requested(entry: SkillEntry, should_equip: bool) -> void:
	if entry == null or player_build == null:
		return
	_apply_loadout_change(entry, should_equip)


func _apply_loadout_change(entry: SkillEntry, should_equip: bool) -> void:
	if not player_build.set_active_skill_equipped(entry, should_equip):
		if FloatText != null and FloatText.has_method("show_screen_tip"):
			FloatText.show_screen_tip("主动技能携带栏已满")
		return

	refresh()
	if EventBus != null:
		EventBus.skill_loadout_changed.emit()


func _is_basic_attack(entry: SkillEntry) -> bool:
	if entry == null or entry.skill_data == null or not entry.skill_data is ActiveSkillData:
		return false
	var active_data := entry.skill_data as ActiveSkillData
	return active_data.is_basic_attack or active_data.id == &"101"


func _clear_container(container: Container) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
