class_name VictoryRelicSelectionPanel
extends Control

signal selection_confirmed(kept_entry_ids: Array[String], selected_relics: Array[Relic])

@onready var instruction_label: Label = %InstructionLabel
@onready var count_label: Label = %CountLabel
@onready var relic_list: ItemList = %RelicList
@onready var feedback_label: Label = %FeedbackLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var title_label: Label = %TitleLabel

var candidate_items: Array[Dictionary] = []
var required_selection_count: int = 0
var death_recovery: bool = false


func _ready() -> void:
	get_tree().paused = false
	if relic_list != null and not relic_list.multi_selected.is_connected(_on_relic_multi_selected):
		relic_list.multi_selected.connect(_on_relic_multi_selected)
	if confirm_button != null and not confirm_button.pressed.is_connected(_on_confirm_button_pressed):
		confirm_button.pressed.connect(_on_confirm_button_pressed)


## 同时展示仓库原有装备和本局装备，让玩家决定结算后的最终仓库内容。
func setup(
	victory_relics: Array[Relic],
	warehouse_entries: Array[Dictionary],
	warehouse_capacity: int,
	after_death: bool = false
) -> void:
	death_recovery = after_death
	if title_label != null:
		title_label.text = "避难装备回收" if death_recovery else "胜利装备回收"
	candidate_items.clear()
	for entry: Dictionary in warehouse_entries:
		var entry_id: String = str(entry.get("entry_id", ""))
		var relic: Relic = ProfileManager.get_warehouse_relic(entry_id)
		if relic == null:
			continue
		candidate_items.append({
			"source": "warehouse",
			"entry_id": entry_id,
			"relic": relic,
			"locked": bool(entry.get("locked", false)),
		})
	for relic: Relic in victory_relics:
		if relic == null or relic.is_temporary:
			continue
		candidate_items.append({
			"source": "victory",
			"entry_id": "",
			"relic": relic,
			"locked": false,
		})
	required_selection_count = mini(maxi(warehouse_capacity, 0), candidate_items.size())
	_build_relic_list()
	_update_selection_state()


func show_store_error(message: String) -> void:
	if feedback_label != null:
		feedback_label.text = message
		feedback_label.modulate = Color(1.0, 0.38, 0.32)
	if confirm_button != null:
		confirm_button.disabled = false


func _build_relic_list() -> void:
	if relic_list == null:
		return
	relic_list.clear()
	relic_list.select_mode = ItemList.SELECT_MULTI
	for item: Dictionary in candidate_items:
		var relic: Relic = item.get("relic") as Relic
		if relic == null:
			continue
		var is_warehouse_item: bool = str(item.get("source", "")) == "warehouse"
		var is_locked: bool = bool(item.get("locked", false))
		var source_text: String = "[仓库]" if is_warehouse_item else "[本局]"
		var upgrade_text: String = " [已升级]" if relic.leveltip == Relic.LevelTip.LEVELUP else ""
		var lock_text: String = " [已锁定]" if is_locked else ""
		var index: int = relic_list.item_count
		relic_list.add_item("%s Lv.%d  %s%s%s" % [source_text, relic.level, relic.relic_name, upgrade_text, lock_text], relic.icon)
		relic_list.set_item_tooltip(index, "%s\n%s" % [relic.relic_name, relic.tooltip])
		if is_warehouse_item:
			relic_list.select(index, false)
		if is_locked:
			relic_list.set_item_selectable(index, false)

	if instruction_label != null:
		instruction_label.text = "仓库空间不足，请决定最终保留的 %d 件装备。直接点击即可独立勾选或取消，无需按住 Ctrl；锁定装备不能丢弃。" % required_selection_count


# ItemList 的原生多选更偏向桌面软件：普通点击会清除之前的选择，按住 Ctrl 才会追加。
# 在 GUI 默认处理前拦截列表左键，使结算界面变成“点击一件、独立切换一件”的游戏式交互。
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or relic_list == null:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var local_position: Vector2 = relic_list.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, relic_list.size).has_point(local_position):
		return

	# 空白处的点击也要拦截，否则 ItemList 会按原生规则清空现有选择。
	get_viewport().set_input_as_handled()
	var index: int = relic_list.get_item_at_position(local_position, true)
	if index < 0 or index >= relic_list.item_count:
		return
	if not relic_list.is_item_selectable(index):
		_show_feedback("这件装备已锁定，结算时必须保留。", Color(0.72, 0.84, 1.0))
		return

	if relic_list.is_selected(index):
		relic_list.deselect(index)
	else:
		var selected_count: int = relic_list.get_selected_items().size()
		if selected_count >= required_selection_count:
			_show_feedback(
				"仓库容量为 %d，请先取消一件旧装备再选择新装备。" % required_selection_count,
				Color(1.0, 0.78, 0.3)
			)
			return
		relic_list.select(index, false)

	_update_selection_state()


func _on_relic_multi_selected(index: int, selected: bool) -> void:
	if relic_list == null:
		return
	if selected and relic_list.get_selected_items().size() > required_selection_count:
		relic_list.deselect(index)
		_show_feedback(
			"仓库容量为 %d，请先取消一件旧装备再选择新装备。" % required_selection_count,
			Color(1.0, 0.78, 0.3)
		)
	_update_selection_state()


func _update_selection_state() -> void:
	var selected_count: int = relic_list.get_selected_items().size() if relic_list != null else 0
	if count_label != null:
		count_label.text = "已选择：%d / %d" % [selected_count, required_selection_count]
	if confirm_button != null:
		confirm_button.disabled = selected_count != required_selection_count
		confirm_button.text = "确认保留并查看死亡结果" if death_recovery else "确认仓库内容并结束本局"
	if feedback_label != null and selected_count == required_selection_count:
		feedback_label.text = "已选满仓库容量，可以确认结算。"
		feedback_label.modulate = Color(0.7, 0.9, 0.66)
	elif feedback_label != null:
		feedback_label.text = "还需要选择 %d 件装备。" % max(required_selection_count - selected_count, 0)
		feedback_label.modulate = Color(0.85, 0.85, 0.82)


func _show_feedback(message: String, color: Color) -> void:
	if feedback_label == null:
		return
	feedback_label.text = message
	feedback_label.modulate = color


func _on_confirm_button_pressed() -> void:
	if relic_list == null or relic_list.get_selected_items().size() != required_selection_count:
		return
	var kept_entry_ids: Array[String] = []
	var selected_relics: Array[Relic] = []
	for selected_index: int in relic_list.get_selected_items():
		if selected_index < 0 or selected_index >= candidate_items.size():
			continue
		var item: Dictionary = candidate_items[selected_index]
		if str(item.get("source", "")) == "warehouse":
			kept_entry_ids.append(str(item.get("entry_id", "")))
		else:
			var relic: Relic = item.get("relic") as Relic
			if relic != null:
				selected_relics.append(relic)
	if confirm_button != null:
		confirm_button.disabled = true
	selection_confirmed.emit(kept_entry_ids, selected_relics)
