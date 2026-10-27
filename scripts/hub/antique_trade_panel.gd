class_name AntiqueTradePanel
extends Control

signal closed
signal cuisine_offered

const DEFAULT_RELIC_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")
const CUISINE_TAG_NAME := "佳肴"

@export var keyword_database: KeywordDatabase = preload("res://custom_resource/default_keyword_database.tres")

@onready var relic_list: ItemList = %RelicList
@onready var detail_label: RichTextLabel = %DetailLabel
@onready var action_button: Button = %ActionButton
@onready var close_button: Button = %CloseButton
@onready var keyword_explain_panel: KeywordExplainPanel = %KeywordExplainPanel

var entry_ids: Array[String] = []
var selected_entry_id: String = ""
var relics_by_entry_id: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	relic_list.item_selected.connect(_on_item_selected)
	action_button.pressed.connect(_on_action_pressed)
	close_button.pressed.connect(_close)
	ProfileManager.relic_warehouse_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_close()


func _refresh() -> void:
	var previous_id: String = selected_entry_id
	entry_ids.clear()
	relics_by_entry_id.clear()
	relic_list.clear()
	for entry: Dictionary in ProfileManager.get_warehouse_entries():
		var entry_id: String = str(entry.get("entry_id", ""))
		var relic: Relic = ProfileManager.get_warehouse_relic(entry_id)
		if relic == null:
			continue
		relics_by_entry_id[entry_id] = relic
		entry_ids.append(entry_id)
		var suffix: String = "  [锁定]" if bool(entry.get("locked", false)) else ""
		relic_list.add_item("Lv.%d  %s%s" % [relic.level, relic.relic_name, suffix], relic.icon)
	if entry_ids.is_empty():
		selected_entry_id = ""
		_show_selected(null)
		return
	var selected_index: int = entry_ids.find(previous_id)
	if selected_index < 0:
		selected_index = 0
	relic_list.select(selected_index)
	_select_index(selected_index)


func _on_item_selected(index: int) -> void:
	_select_index(index)


func _select_index(index: int) -> void:
	if index < 0 or index >= entry_ids.size():
		return
	selected_entry_id = entry_ids[index]
	_show_selected(relics_by_entry_id.get(selected_entry_id) as Relic)


func _show_selected(relic: Relic) -> void:
	if relic == null:
		detail_label.text = "仓库里暂时没有可用于交换的装备。"
		_clear_keyword_explanations()
		action_button.disabled = true
		return
	var locked: bool = ProfileManager.is_warehouse_entry_locked(selected_entry_id)
	var is_first_cuisine_offer: bool = _has_tag(relic, CUISINE_TAG_NAME) and not ProfileManager.has_completed_event(&"appetite_cuisine_offered")
	action_button.text = "送给小乐一份佳肴" if is_first_cuisine_offer else "交换同等阶装备"
	action_button.disabled = locked
	var lock_text: String = "\n[color=#ffd86b]该装备已锁定，无法交换或赠送。[/color]" if locked else ""
	var formatted_description: KeywordTextResult = KeywordTextFormatter.format_text(relic.tooltip, keyword_database)
	detail_label.text = "[b]%s[/b]　Lv.%d\n%s%s" % [relic.relic_name, relic.level, formatted_description.bbcode_text, lock_text]
	if keyword_explain_panel != null:
		keyword_explain_panel.setup_keywords(formatted_description.keywords)


func _on_action_pressed() -> void:
	var relic: Relic = ProfileManager.get_warehouse_relic(selected_entry_id)
	if relic == null or ProfileManager.is_warehouse_entry_locked(selected_entry_id):
		return
	if _has_tag(relic, CUISINE_TAG_NAME) and not ProfileManager.has_completed_event(&"appetite_cuisine_offered"):
		# 将面板里选中的佳肴同步为大厅携带装备，后续对话才能准确消耗这一件。
		if not ProfileManager.select_warehouse_entry(selected_entry_id):
			detail_label.text = "无法将这件佳肴交给小乐，请稍后重试。"
			return
		if ProfileManager.try_complete_event(&"appetite_cuisine_offered"):
			cuisine_offered.emit()
			_close()
		return
	_exchange_selected_relic(relic)


func _exchange_selected_relic(relic: Relic) -> void:
	var candidates: Array[Relic] = []
	for candidate: Relic in DEFAULT_RELIC_POOL.get_relics_by_level(relic.level):
		if candidate != null and candidate.id != relic.id:
			candidates.append(candidate)
	if candidates.is_empty():
		detail_label.text = "当前没有可交换的同等阶装备。"
		return
	var replacement: Relic = candidates.pick_random() as Relic
	if replacement == null:
		return
	if ProfileManager.exchange_warehouse_relic(selected_entry_id, replacement.duplicate(true) as Relic):
		detail_label.text = "小乐收下了%s，并交给你一件%s。" % [relic.relic_name, replacement.relic_name]
		_clear_keyword_explanations()


func _clear_keyword_explanations() -> void:
	if keyword_explain_panel == null:
		return
	var empty_keywords: Array[KeywordData] = []
	keyword_explain_panel.setup_keywords(empty_keywords)


func _has_tag(relic: Relic, tag_name: String) -> bool:
	for tag: RelicTag in relic.tags:
		if tag != null and tag.tag_name == tag_name:
			return true
	return false


func _close() -> void:
	closed.emit()
	queue_free()
