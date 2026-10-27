class_name RelicWarehousePanel
extends Control

signal closed

const RELIC_TOOLTIP_SCENE: PackedScene = preload("res://scenes/tooltip/relic_tool_tip_panel.tscn")

enum SortMode {
	RECOVERY_ORDER,
	LEVEL_ASCENDING,
	LEVEL_DESCENDING,
	NAME,
	TAG,
}

@onready var relic_list: ItemList = %RelicList
@onready var tooltip_host: VBoxContainer = %TooltipHost
@onready var empty_detail_label: Label = %EmptyDetailLabel
@onready var risk_label: RichTextLabel = %RiskLabel
@onready var carry_button: Button = %CarryButton
@onready var clear_button: Button = %ClearButton
@onready var discard_button: Button = %DiscardButton
@onready var close_button: Button = %CloseButton
@onready var capacity_label: Label = %CapacityLabel
@onready var sort_option: OptionButton = %SortOption
@onready var lock_button: Button = %LockButton

var entry_ids: Array[String] = []
var selected_entry_id: String = ""
var pending_discard_entry_id: String = ""
var discard_dialog: ConfirmationDialog
var relic_tooltip: RelicToolTip
var sort_mode: SortMode = SortMode.RECOVERY_ORDER
var relics_by_entry_id: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	relic_list.item_selected.connect(_on_item_selected)
	carry_button.pressed.connect(_on_carry_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	close_button.pressed.connect(_close)
	_setup_sort_options()
	sort_option.item_selected.connect(_on_sort_selected)
	ProfileManager.relic_warehouse_changed.connect(_refresh)
	_create_relic_tooltip()
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
	var carried_id: String = ProfileManager.get_selected_warehouse_entry_id()
	var entries: Array[Dictionary] = ProfileManager.get_warehouse_entries()
	entries.sort_custom(_compare_entries)
	capacity_label.text = "容量：%d / %d" % [entries.size(), ProfileManager.get_relic_warehouse_capacity()]
	for entry: Dictionary in entries:
		var entry_id: String = str(entry.get("entry_id", ""))
		var relic: Relic = ProfileManager.get_warehouse_relic(entry_id)
		if relic == null:
			continue
		relics_by_entry_id[entry_id] = relic
		entry_ids.append(entry_id)
		var suffix: String = ""
		if bool(entry.get("locked", false)):
			suffix += "  [锁定]"
		if entry_id == carried_id:
			suffix += "  [已携带]"
		var index: int = relic_list.item_count
		relic_list.add_item("Lv.%d  %s%s" % [relic.level, relic.relic_name, suffix], relic.icon)
	if entry_ids.is_empty():
		selected_entry_id = ""
		_show_relic(null)
		return
	var select_index: int = entry_ids.find(previous_id)
	if select_index < 0:
		select_index = entry_ids.find(carried_id)
	if select_index < 0:
		select_index = 0
	relic_list.select(select_index)
	_select_index(select_index)


func _on_item_selected(index: int) -> void:
	_select_index(index)


func _select_index(index: int) -> void:
	if index < 0 or index >= entry_ids.size():
		return
	selected_entry_id = entry_ids[index]
	_show_relic(relics_by_entry_id.get(selected_entry_id) as Relic)


func _show_relic(relic: Relic) -> void:
	var has_relic: bool = relic != null
	var is_locked: bool = has_relic and ProfileManager.is_warehouse_entry_locked(selected_entry_id)
	carry_button.disabled = not has_relic
	discard_button.disabled = not has_relic or is_locked
	lock_button.disabled = not has_relic
	lock_button.text = "解除锁定" if is_locked else "锁定装备"
	clear_button.disabled = ProfileManager.get_selected_warehouse_entry_id().is_empty()
	empty_detail_label.visible = not has_relic
	risk_label.visible = has_relic
	if relic_tooltip != null:
		relic_tooltip.visible = has_relic
	if not has_relic:
		empty_detail_label.text = "仓库暂无装备。\n\n在一局冒险中死亡后，拾荒者会随机带回背包或装备栏中的一件非临时装备。"
		return
	relic_tooltip.set_tool_tip(relic)
	var rate: float = ProfileManager.get_carry_penalty_rate(relic)
	var state: String = "已放入大厅背包，下一次新冒险开始时转入局内背包。" if selected_entry_id == ProfileManager.get_selected_warehouse_entry_id() else "可选择携带到下一次新冒险。"
	if is_locked:
		state += "\n[color=#ffd86b]装备已锁定，不可丢弃，也不会被剧情或自动消耗选中。[/color]"
	if rate <= 0.0:
		risk_label.text = "[color=#9fdcff][b]稳定携带[/b][/color]\n%s\n该装备等阶较低，不会产生荒域阻力。" % state
	else:
		risk_label.text = "[color=#ff9c70][b]荒域阻力：%d%%[/b][/color]\n%s\n进入新冒险后，最大生命与最大能量降低 %d%%。该惩罚持续整局，途中出售或丢弃装备也不会解除。" % [roundi(rate * 100.0), state, roundi(rate * 100.0)]


func _create_relic_tooltip() -> void:
	if tooltip_host == null or relic_tooltip != null:
		return
	relic_tooltip = RELIC_TOOLTIP_SCENE.instantiate() as RelicToolTip
	if relic_tooltip == null:
		return
	tooltip_host.add_child(relic_tooltip)
	relic_tooltip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	relic_tooltip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	relic_tooltip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _on_carry_pressed() -> void:
	if selected_entry_id.is_empty():
		return
	ProfileManager.select_warehouse_entry(selected_entry_id)


func _on_clear_pressed() -> void:
	ProfileManager.select_warehouse_entry("")


func _on_lock_pressed() -> void:
	if selected_entry_id.is_empty():
		return
	var next_locked: bool = not ProfileManager.is_warehouse_entry_locked(selected_entry_id)
	ProfileManager.set_warehouse_entry_locked(selected_entry_id, next_locked)


func _on_discard_pressed() -> void:
	if selected_entry_id.is_empty() or ProfileManager.is_warehouse_entry_locked(selected_entry_id):
		return
	var relic: Relic = ProfileManager.get_warehouse_relic(selected_entry_id)
	if relic == null:
		return
	pending_discard_entry_id = selected_entry_id
	if discard_dialog == null:
		discard_dialog = ConfirmationDialog.new()
		discard_dialog.title = "丢弃仓库装备"
		discard_dialog.ok_button_text = "确认丢弃"
		discard_dialog.cancel_button_text = "保留装备"
		discard_dialog.exclusive = true
		add_child(discard_dialog)
		discard_dialog.confirmed.connect(_confirm_discard)
	discard_dialog.dialog_text = "确定永久丢弃“%s”吗？此操作无法撤销。" % relic.relic_name
	discard_dialog.popup_centered(Vector2i(520, 210))
	discard_dialog.get_cancel_button().grab_focus()


func _confirm_discard() -> void:
	if pending_discard_entry_id.is_empty():
		return
	ProfileManager.discard_warehouse_entry(pending_discard_entry_id)
	pending_discard_entry_id = ""


func _setup_sort_options() -> void:
	sort_option.clear()
	sort_option.add_item("获取顺序", SortMode.RECOVERY_ORDER)
	sort_option.add_item("等阶：低到高", SortMode.LEVEL_ASCENDING)
	sort_option.add_item("等阶：高到低", SortMode.LEVEL_DESCENDING)
	sort_option.add_item("名称", SortMode.NAME)
	sort_option.add_item("标签", SortMode.TAG)
	sort_option.select(0)


func _on_sort_selected(index: int) -> void:
	sort_mode = sort_option.get_item_id(index) as SortMode
	_refresh()


func _compare_entries(left: Dictionary, right: Dictionary) -> bool:
	var left_relic: Relic = _get_relic_from_entry(left)
	var right_relic: Relic = _get_relic_from_entry(right)
	if left_relic == null:
		return false
	if right_relic == null:
		return true
	match sort_mode:
		SortMode.LEVEL_ASCENDING:
			if left_relic.level != right_relic.level:
				return left_relic.level < right_relic.level
		SortMode.LEVEL_DESCENDING:
			if left_relic.level != right_relic.level:
				return left_relic.level > right_relic.level
		SortMode.NAME:
			return left_relic.relic_name.naturalnocasecmp_to(right_relic.relic_name) < 0
		SortMode.TAG:
			var left_tags: String = _get_tag_sort_key(left_relic)
			var right_tags: String = _get_tag_sort_key(right_relic)
			if left_tags != right_tags:
				return left_tags.naturalnocasecmp_to(right_tags) < 0
		_:
			return int(left.get("recovered_at", 0)) < int(right.get("recovered_at", 0))
	return left_relic.relic_name.naturalnocasecmp_to(right_relic.relic_name) < 0


func _get_relic_from_entry(entry: Dictionary) -> Relic:
	var entry_id: String = str(entry.get("entry_id", ""))
	var relic: Relic = relics_by_entry_id.get(entry_id) as Relic
	if relic == null:
		relic = ProfileManager.get_warehouse_relic(entry_id)
		if relic != null:
			relics_by_entry_id[entry_id] = relic
	return relic


func _get_tag_sort_key(relic: Relic) -> String:
	var tag_names: Array[String] = []
	for tag: RelicTag in relic.tags:
		if tag != null and not tag.tag_name.is_empty():
			tag_names.append(tag.tag_name)
	tag_names.sort()
	# 无标签装备排在有标签装备之后。
	return "~" if tag_names.is_empty() else "|".join(tag_names)


func _close() -> void:
	closed.emit()
	queue_free()
