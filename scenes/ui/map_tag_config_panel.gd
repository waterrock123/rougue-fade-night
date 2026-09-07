class_name MapTagConfigPanel
extends Control

signal opened
signal closed

const DEFAULT_INFLUENCE_DATABASE := preload("res://custom_resource/default_map_tag_influence_database.tres")
const DEFAULT_KEYWORD_DATABASE := preload("res://custom_resource/default_keyword_database.tres")
const TAG_UI_SCENE := preload("res://scenes/tooltip/tag_ui.tscn")

@export var influence_database: MapTagInfluenceDatabase = DEFAULT_INFLUENCE_DATABASE
@export var keyword_database: KeywordDatabase = DEFAULT_KEYWORD_DATABASE
@export var tag_button_min_size: Vector2 = Vector2(132, 38)

@onready var limit_label: Label = $Panel/VBoxContainer/Header/LimitLabel
@onready var close_button: Button = $Panel/VBoxContainer/Header/CloseButton
@onready var enabled_tag_container: HFlowContainer = $Panel/VBoxContainer/MainArea/LeftColumn/EnabledSection/VBoxContainer/EnabledTagScroll/EnabledTagContainer
@onready var owned_tag_container: HFlowContainer = $Panel/VBoxContainer/MainArea/LeftColumn/OwnedSection/VBoxContainer/OwnedTagScroll/OwnedTagContainer
@onready var enabled_empty_label: Label = $Panel/VBoxContainer/MainArea/LeftColumn/EnabledSection/VBoxContainer/EnabledEmptyLabel
@onready var owned_empty_label: Label = $Panel/VBoxContainer/MainArea/LeftColumn/OwnedSection/VBoxContainer/OwnedEmptyLabel
@onready var detail_list: VBoxContainer = $Panel/VBoxContainer/MainArea/SummarySection/VBoxContainer/DetailScroll/DetailList
@onready var summary_text: RichTextLabel = $Panel/VBoxContainer/MainArea/SummarySection/VBoxContainer/SummaryScroll/SummaryText
@onready var keyword_title: Label = $Panel/VBoxContainer/MainArea/SummarySection/VBoxContainer/KeywordTitle
@onready var keyword_explain_scroll: ScrollContainer = $Panel/VBoxContainer/MainArea/SummarySection/VBoxContainer/KeywordExplainScroll
@onready var keyword_explain_panel: KeywordExplainPanel = $Panel/VBoxContainer/MainArea/SummarySection/VBoxContainer/KeywordExplainScroll/KeywordExplainPanel
@onready var feedback_label: Label = $Panel/VBoxContainer/FeedbackLabel

var run_stats: RunStats
var is_refreshing: bool = false


func _ready() -> void:
	hide()
	if close_button != null and not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)
	_connect_runtime_signals()


func _exit_tree() -> void:
	_disconnect_runtime_signals()


func bind_run_stats(new_run_stats: RunStats) -> void:
	run_stats = new_run_stats
	refresh()


func open_panel() -> void:
	var was_visible: bool = visible
	show()
	if not was_visible:
		opened.emit()
	refresh()


func close_panel() -> void:
	if not visible:
		return

	hide()
	closed.emit()


func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open_panel()


func refresh() -> void:
	if is_refreshing:
		return

	is_refreshing = true
	_resolve_nodes()
	_clear_tag_buttons()

	if run_stats == null:
		_show_no_run_stats()
		is_refreshing = false
		return

	var tag_counts: Dictionary = run_stats.get_owned_relic_tag_counts()
	_prune_unowned_enabled_tags(tag_counts)
	var enabled_keys: Array[String] = run_stats.get_enabled_map_tag_keys()

	_refresh_limit_label(enabled_keys.size())
	_build_enabled_tags(enabled_keys, tag_counts)
	_build_owned_tags(enabled_keys, tag_counts)
	_refresh_summary(enabled_keys, tag_counts)
	_set_feedback("点击下方标签会启用 1 个同类标签；点击上方标签会移除 1 个启用槽。")
	is_refreshing = false


func _build_enabled_tags(enabled_keys: Array[String], tag_counts: Dictionary) -> void:
	if enabled_empty_label != null:
		enabled_empty_label.visible = enabled_keys.is_empty()
	if enabled_tag_container == null:
		return

	for tag_key: String in enabled_keys:
		var tag: RelicTag = _get_tag_for_key(tag_key)
		var tag_name: String = _get_tag_name(tag_key, tag)
		var button: Button = _create_tag_button(tag_name, 1, tag, "移除 1 个")
		button.pressed.connect(_on_enabled_tag_pressed.bind(tag_key))
		enabled_tag_container.add_child(button)


func _build_owned_tags(enabled_keys: Array[String], tag_counts: Dictionary) -> void:
	var owned_tags: Array[RelicTag] = run_stats.get_owned_relic_tags()
	if owned_empty_label != null:
		owned_empty_label.visible = owned_tags.is_empty()
	if owned_tag_container == null:
		return

	for tag: RelicTag in owned_tags:
		var tag_key: String = run_stats.get_map_tag_key(tag)
		var count: int = int(tag_counts.get(tag_key, 0))
		var enabled_count: int = _count_key_in_array(enabled_keys, tag_key)
		var remaining_count: int = max(count - enabled_count, 0)
		var suffix: String = "启用 %d/%d" % [enabled_count, count]
		var button: Button = _create_tag_button(tag.tag_name, count, tag, suffix)
		button.disabled = remaining_count <= 0 or enabled_keys.size() >= max(run_stats.map_tag_enable_limit, 0)
		button.pressed.connect(_on_owned_tag_pressed.bind(tag))
		owned_tag_container.add_child(button)


func _refresh_summary(enabled_keys: Array[String], tag_counts: Dictionary) -> void:
	_clear_detail_rows()
	var displayed_keywords: Array[KeywordData] = []
	if enabled_keys.is_empty():
		_add_detail_empty_row("尚未启用地图标签。")
		_set_rich_text_collect(summary_text, "启用后，这里会显示叠加后的地图影响。", displayed_keywords)
		_refresh_keyword_explanations(displayed_keywords)
		return

	_build_detail_summary_rows(enabled_keys, displayed_keywords)
	var aggregate_lines: Array[String] = _get_aggregate_summary_lines(enabled_keys, tag_counts)

	if aggregate_lines.is_empty():
		_set_rich_text_collect(summary_text, "当前启用标签还没有可汇总的地图影响。", displayed_keywords)
	else:
		_set_rich_text_collect(summary_text, "\n".join(aggregate_lines), displayed_keywords)
	_refresh_keyword_explanations(displayed_keywords)


func _build_detail_summary_rows(enabled_keys: Array[String], displayed_keywords: Array[KeywordData]) -> void:
	if influence_database == null:
		_add_detail_empty_row("当前没有可用的地图标签影响数据库。")
		return

	for tag_key: String in enabled_keys:
		var tag: RelicTag = _get_tag_for_key(tag_key)
		var influence: MapTagInfluenceData = influence_database.get_influence_for_tag_key(tag_key)
		var summary: String = _get_single_tag_player_summary(influence)
		_add_detail_card(tag, tag_key, summary, displayed_keywords)


func _get_aggregate_summary_lines(enabled_keys: Array[String], _tag_counts: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if influence_database == null:
		return result

	var object_groups: Dictionary = {}
	var terrain_groups: Dictionary = {}
	var note_groups: Dictionary = {}
	for tag_key: String in enabled_keys:
		var influence: MapTagInfluenceData = influence_database.get_influence_for_tag_key(tag_key)
		if influence == null or not influence.enabled:
			continue

		var tag_count: int = 1
		_collect_object_modifier_summary(object_groups, influence, tag_count)
		_collect_terrain_modifier_summary(terrain_groups, influence)
		_collect_note_summary(note_groups, influence)

	_append_object_group_lines(result, object_groups)
	_append_terrain_group_lines(result, terrain_groups)
	_append_note_group_lines(result, note_groups)
	return result


func _collect_object_modifier_summary(
	object_groups: Dictionary,
	influence: MapTagInfluenceData,
	tag_count: int
) -> void:
	for modifier: MapTagObjectSpawnModifier in influence.object_spawn_modifiers:
		if modifier == null:
			continue
		if is_zero_approx(modifier.chance_bonus):
			continue

		var target_text: String = _get_object_modifier_target_text(modifier)
		var group_key: String = "object_chance|%s" % target_text
		var data: Dictionary = _get_or_make_summary_group(object_groups, group_key, target_text)
		data["instance_count"] = int(data["instance_count"]) + 1
		data["chance_bonus"] = float(data["chance_bonus"]) + modifier.chance_bonus
		data["count_hint"] = int(data["count_hint"]) + modifier.get_min_count_bonus(tag_count) + modifier.get_max_count_bonus(tag_count)
		object_groups[group_key] = data


func _collect_terrain_modifier_summary(
	terrain_groups: Dictionary,
	influence: MapTagInfluenceData
) -> void:
	for modifier: MapTagTerrainSpawnModifier in influence.terrain_spawn_modifiers:
		if modifier == null:
			continue
		if is_zero_approx(modifier.chance_bonus):
			continue

		var target_text: String = _get_terrain_modifier_target_text(modifier)
		var group_key: String = "terrain_chance|%s" % target_text
		var data: Dictionary = _get_or_make_summary_group(terrain_groups, group_key, target_text)
		data["instance_count"] = int(data["instance_count"]) + 1
		data["chance_bonus"] = float(data["chance_bonus"]) + modifier.chance_bonus
		terrain_groups[group_key] = data


func _collect_note_summary(
	note_groups: Dictionary,
	influence: MapTagInfluenceData
) -> void:
	for note: String in influence.future_terrain_notes:
		if note.is_empty():
			continue
		_add_note_summary(note_groups, note)


func _add_note_summary(note_groups: Dictionary, note: String) -> void:
	var group_key: String = "note|%s" % note
	var data: Dictionary = _get_or_make_summary_group(note_groups, group_key, note)
	data["instance_count"] = int(data["instance_count"]) + 1
	note_groups[group_key] = data


func _append_object_group_lines(result: Array[String], object_groups: Dictionary) -> void:
	for group_key: String in object_groups.keys():
		var data: Dictionary = object_groups[group_key]
		result.append(_make_chance_sentence(String(data["target_text"]), float(data["chance_bonus"])))


func _append_terrain_group_lines(result: Array[String], terrain_groups: Dictionary) -> void:
	for group_key: String in terrain_groups.keys():
		var data: Dictionary = terrain_groups[group_key]
		result.append(_make_chance_sentence(String(data["target_text"]), float(data["chance_bonus"])))


func _append_note_group_lines(result: Array[String], note_groups: Dictionary) -> void:
	for group_key: String in note_groups.keys():
		var data: Dictionary = note_groups[group_key]
		var text: String = String(data["target_text"])
		if int(data["instance_count"]) > 1:
			text += "（生效 %d 次）" % int(data["instance_count"])
		result.append(text)


func _get_or_make_summary_group(groups: Dictionary, group_key: String, target_text: String) -> Dictionary:
	if groups.has(group_key):
		return groups[group_key] as Dictionary

	var data: Dictionary = {
		"target_text": target_text,
		"instance_count": 0,
		"chance_bonus": 0.0,
		"count_hint": 0,
	}
	groups[group_key] = data
	return data


func _get_object_modifier_target_text(modifier: MapTagObjectSpawnModifier) -> String:
	var mode: StringName = StringName(modifier.target_mode)
	if mode == MapTagObjectSpawnModifier.TARGET_MODE_OBJECT_ID and modifier.object_id != &"":
		return _keyword_or_plain(modifier.object_id, _humanize_id(modifier.object_id))
	if mode == MapTagObjectSpawnModifier.TARGET_MODE_FEATURE_KIND:
		var feature_kind: StringName = StringName(modifier.target_feature_kind)
		if feature_kind == MapObjectEntry.FEATURE_KIND_SPECIAL_OBJECT:
			return _keyword_or_plain(&"map_special_object", "地图特殊物体")
		if feature_kind == MapObjectEntry.FEATURE_KIND_SPECIAL_TERRAIN:
			return _keyword_or_plain(&"map_special_terrain", "地图特殊地形")
		return _humanize_id(feature_kind)
	if mode == MapTagObjectSpawnModifier.TARGET_MODE_FEATURE_TAG:
		var parts: Array[String] = []
		for feature_tag: StringName in modifier.feature_tags:
			parts.append(_keyword_or_plain(feature_tag, _humanize_id(feature_tag)))
		if not parts.is_empty():
			return " / ".join(parts)
	return _keyword_or_plain(&"map_special_object", "地图特殊物体")


func _get_terrain_modifier_target_text(modifier: MapTagTerrainSpawnModifier) -> String:
	if modifier.display_keyword_id != &"":
		return _keyword_or_plain(modifier.display_keyword_id, _humanize_id(modifier.display_keyword_id))
	if modifier.terrain_id != &"":
		return _keyword_or_plain(modifier.terrain_id, _humanize_id(modifier.terrain_id))
	return _keyword_or_plain(&"map_special_terrain", "地图特殊地形")


func _get_single_tag_player_summary(influence: MapTagInfluenceData) -> String:
	if influence == null or not influence.enabled:
		return "暂无地图影响配置。"

	var lines: Array[String] = []
	for modifier: MapTagObjectSpawnModifier in influence.object_spawn_modifiers:
		if modifier == null:
			continue
		lines.append_array(_get_object_modifier_player_sentences(modifier))

	for modifier: MapTagTerrainSpawnModifier in influence.terrain_spawn_modifiers:
		if modifier == null:
			continue
		lines.append_array(_get_terrain_modifier_player_sentences(modifier))

	for note: String in influence.future_terrain_notes:
		if not note.is_empty():
			lines.append(note)

	if lines.is_empty() and not influence.summary.is_empty():
		lines.append(influence.summary)
	if lines.is_empty():
		lines.append("暂无地图影响配置。")
	return "；".join(lines)


func _get_object_modifier_player_sentences(modifier: MapTagObjectSpawnModifier) -> Array[String]:
	var result: Array[String] = []
	var target_text: String = _get_object_modifier_target_text(modifier)
	if not is_zero_approx(modifier.chance_bonus):
		result.append(_make_chance_sentence(target_text, modifier.chance_bonus))
	elif modifier.get_min_count_bonus(1) != 0 or modifier.get_max_count_bonus(1) != 0:
		result.append("使地图中的%s出现数量增加。" % target_text)
	elif not is_zero_approx(modifier.get_weight_bonus(1)):
		result.append("使地图中的%s更容易出现。" % target_text)
	elif not modifier.summary.is_empty():
		result.append(modifier.summary)
	return result


func _get_terrain_modifier_player_sentences(modifier: MapTagTerrainSpawnModifier) -> Array[String]:
	var result: Array[String] = []
	var target_text: String = _get_terrain_modifier_target_text(modifier)
	if not is_zero_approx(modifier.chance_bonus):
		result.append(_make_chance_sentence(target_text, modifier.chance_bonus))
	elif modifier.flat_count_bonus != 0:
		result.append("使地图中的%s出现数量增加。" % target_text)
	elif not modifier.summary.is_empty():
		result.append(modifier.summary)
	return result


func _make_chance_sentence(target_text: String, chance_bonus: float) -> String:
	var verb: String = "提升" if chance_bonus >= 0.0 else "降低"
	return "使地图中的%s出现概率%s%s。" % [target_text, verb, _format_percent_abs(chance_bonus)]


func _format_percent_abs(value: float) -> String:
	var percent: float = abs(value) * 100.0
	var rounded: float = round(percent)
	if is_equal_approx(percent, rounded):
		return "%d%%" % int(rounded)
	return "%.1f%%" % percent


func _keyword_or_plain(keyword_id: StringName, fallback: String) -> String:
	if keyword_database != null and keyword_database.has_keyword(keyword_id):
		return "{%s}" % String(keyword_id)
	return fallback


func _humanize_id(value: StringName) -> String:
	var raw_text: String = String(value)
	if raw_text.is_empty():
		return "未知对象"
	return raw_text.replace("_", " ")


func _add_detail_card(
	tag: RelicTag,
	tag_key: String,
	raw_summary: String,
	displayed_keywords: Array[KeywordData]
) -> void:
	if detail_list == null:
		return

	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_detail_card_style(tag.color if tag != null else Color(0.38, 0.45, 0.54)))
	detail_list.add_child(card)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var tag_ui: TagUI = TAG_UI_SCENE.instantiate() as TagUI
	row.add_child(tag_ui)
	if tag_ui != null:
		tag_ui.setup(tag)
		if tag == null:
			tag_ui.hide()

	if tag == null:
		var fallback_label: Label = Label.new()
		fallback_label.custom_minimum_size = Vector2(64, 24)
		fallback_label.text = _get_tag_name(tag_key, tag)
		fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(fallback_label)

	var desc_label: RichTextLabel = RichTextLabel.new()
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.bbcode_enabled = true
	desc_label.add_theme_font_size_override("normal_font_size", 16)
	row.add_child(desc_label)
	_set_rich_text_collect(desc_label, raw_summary, displayed_keywords)


func _add_detail_empty_row(text: String) -> void:
	if detail_list == null:
		return

	var label: Label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	detail_list.add_child(label)


func _make_detail_card_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.14, 0.18, 0.82)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = color.lightened(0.2)
	style.content_margin_left = 8
	style.content_margin_top = 7
	style.content_margin_right = 8
	style.content_margin_bottom = 7
	return style


func _clear_detail_rows() -> void:
	_clear_children(detail_list)


func _set_rich_text(label: RichTextLabel, raw_text: String) -> void:
	var ignored_keywords: Array[KeywordData] = []
	_set_rich_text_collect(label, raw_text, ignored_keywords)


func _set_rich_text_collect(
	label: RichTextLabel,
	raw_text: String,
	displayed_keywords: Array[KeywordData]
) -> void:
	if label == null:
		return

	label.clear()
	label.text = ""
	if raw_text.is_empty():
		return

	var formatted: KeywordTextResult = KeywordTextFormatter.format_text(raw_text, keyword_database)
	label.append_text(formatted.bbcode_text)
	_append_keywords(displayed_keywords, formatted.keywords)


func _append_keywords(target: Array[KeywordData], source: Array[KeywordData]) -> void:
	for keyword: KeywordData in source:
		if keyword == null or target.has(keyword):
			continue
		target.append(keyword)


func _refresh_keyword_explanations(displayed_keywords: Array[KeywordData]) -> void:
	var has_keywords: bool = not displayed_keywords.is_empty()
	if keyword_title != null:
		keyword_title.visible = has_keywords
	if keyword_explain_scroll != null:
		keyword_explain_scroll.visible = has_keywords
	if keyword_explain_panel == null:
		return

	keyword_explain_panel.setup_keywords(displayed_keywords)


func _on_owned_tag_pressed(tag: RelicTag) -> void:
	if run_stats == null or tag == null:
		return

	if run_stats.enable_map_tag(tag):
		_set_feedback("已启用 1 个：%s" % tag.tag_name)
	else:
		_set_feedback("启用栏已满，先移除一个已启用标签。")
	refresh()


func _on_enabled_tag_pressed(tag_key: String) -> void:
	if run_stats == null:
		return

	var tag: RelicTag = _get_tag_for_key(tag_key)
	run_stats.disable_map_tag_key(tag_key)
	_set_feedback("已移除：%s" % _get_tag_name(tag_key, tag))
	refresh()


func _prune_unowned_enabled_tags(tag_counts: Dictionary) -> void:
	var enabled_keys: Array[String] = run_stats.get_enabled_map_tag_keys()
	var filtered_keys: Array[String] = []
	var used_counts: Dictionary = {}
	for tag_key: String in enabled_keys:
		var owned_count: int = int(tag_counts.get(tag_key, 0))
		var used_count: int = int(used_counts.get(tag_key, 0))
		if used_count >= owned_count:
			continue

		filtered_keys.append(tag_key)
		used_counts[tag_key] = used_count + 1

	if filtered_keys != enabled_keys:
		run_stats.set_enabled_map_tag_keys(filtered_keys)


func _count_key_in_array(keys: Array[String], tag_key: String) -> int:
	var result: int = 0
	for key: String in keys:
		if key == tag_key:
			result += 1
	return result


func _refresh_limit_label(enabled_count: int) -> void:
	if limit_label == null or run_stats == null:
		return

	limit_label.text = "启用：%d / %d" % [enabled_count, max(run_stats.map_tag_enable_limit, 0)]


func _create_tag_button(tag_name: String, count: int, tag: RelicTag, suffix: String) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = tag_button_min_size
	button.text = "%s x%d\n%s" % [tag_name, count, suffix]
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.85, 0.85, 0.85, 0.72))
	_apply_button_style(button, tag.color if tag != null else Color(0.35, 0.42, 0.52))
	return button


func _apply_button_style(button: Button, color: Color) -> void:
	var base_color: Color = color.darkened(0.2)
	var hover_color: Color = color.lightened(0.12)
	var disabled_color: Color = Color(color.r, color.g, color.b, 0.42)
	button.add_theme_stylebox_override("normal", _make_button_style(base_color))
	button.add_theme_stylebox_override("hover", _make_button_style(hover_color))
	button.add_theme_stylebox_override("pressed", _make_button_style(color.darkened(0.35)))
	button.add_theme_stylebox_override("disabled", _make_button_style(disabled_color))


func _make_button_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.88, 0.55, 0.75)
	return style


func _get_tag_for_key(tag_key: String) -> RelicTag:
	if run_stats != null:
		for tag: RelicTag in run_stats.get_owned_relic_tags():
			if run_stats.get_map_tag_key(tag) == tag_key:
				return tag

	if ResourceLoader.exists(tag_key):
		return load(tag_key) as RelicTag
	return null


func _get_tag_name(tag_key: String, tag: RelicTag) -> String:
	if tag != null and not tag.tag_name.is_empty():
		return tag.tag_name
	return tag_key.get_file().get_basename()


func _clear_tag_buttons() -> void:
	_clear_children(enabled_tag_container)
	_clear_children(owned_tag_container)


func _clear_children(container: Node) -> void:
	if container == null:
		return
	for child: Node in container.get_children():
		child.queue_free()


func _show_no_run_stats() -> void:
	_refresh_limit_label(0)
	_clear_detail_rows()
	_add_detail_empty_row("当前没有可用的局内数据。")
	_set_rich_text(summary_text, "当前没有可用的局内数据。")
	var empty_keywords: Array[KeywordData] = []
	_refresh_keyword_explanations(empty_keywords)
	if enabled_empty_label != null:
		enabled_empty_label.visible = true
	if owned_empty_label != null:
		owned_empty_label.visible = true
	_set_feedback("无法读取 RunStats。")


func _set_feedback(text: String) -> void:
	if feedback_label != null:
		feedback_label.text = text


func _on_close_button_pressed() -> void:
	close_panel()


func _connect_runtime_signals() -> void:
	if not EventBus.inventory_update.is_connected(refresh):
		EventBus.inventory_update.connect(refresh)
	if not EventBus.equipment_update.is_connected(refresh):
		EventBus.equipment_update.connect(refresh)
	if not EventBus.map_tag_selection_changed.is_connected(refresh):
		EventBus.map_tag_selection_changed.connect(refresh)


func _disconnect_runtime_signals() -> void:
	if EventBus.inventory_update.is_connected(refresh):
		EventBus.inventory_update.disconnect(refresh)
	if EventBus.equipment_update.is_connected(refresh):
		EventBus.equipment_update.disconnect(refresh)
	if EventBus.map_tag_selection_changed.is_connected(refresh):
		EventBus.map_tag_selection_changed.disconnect(refresh)


func _resolve_nodes() -> void:
	if limit_label == null:
		limit_label = get_node_or_null("Panel/VBoxContainer/Header/LimitLabel") as Label
	if close_button == null:
		close_button = get_node_or_null("Panel/VBoxContainer/Header/CloseButton") as Button
	if enabled_tag_container == null:
		enabled_tag_container = get_node_or_null("Panel/VBoxContainer/MainArea/LeftColumn/EnabledSection/VBoxContainer/EnabledTagScroll/EnabledTagContainer") as HFlowContainer
	if owned_tag_container == null:
		owned_tag_container = get_node_or_null("Panel/VBoxContainer/MainArea/LeftColumn/OwnedSection/VBoxContainer/OwnedTagScroll/OwnedTagContainer") as HFlowContainer
	if enabled_empty_label == null:
		enabled_empty_label = get_node_or_null("Panel/VBoxContainer/MainArea/LeftColumn/EnabledSection/VBoxContainer/EnabledEmptyLabel") as Label
	if owned_empty_label == null:
		owned_empty_label = get_node_or_null("Panel/VBoxContainer/MainArea/LeftColumn/OwnedSection/VBoxContainer/OwnedEmptyLabel") as Label
	if detail_list == null:
		detail_list = get_node_or_null("Panel/VBoxContainer/MainArea/SummarySection/VBoxContainer/DetailScroll/DetailList") as VBoxContainer
	if summary_text == null:
		summary_text = get_node_or_null("Panel/VBoxContainer/MainArea/SummarySection/VBoxContainer/SummaryScroll/SummaryText") as RichTextLabel
	if keyword_title == null:
		keyword_title = get_node_or_null("Panel/VBoxContainer/MainArea/SummarySection/VBoxContainer/KeywordTitle") as Label
	if keyword_explain_scroll == null:
		keyword_explain_scroll = get_node_or_null("Panel/VBoxContainer/MainArea/SummarySection/VBoxContainer/KeywordExplainScroll") as ScrollContainer
	if keyword_explain_panel == null:
		keyword_explain_panel = get_node_or_null("Panel/VBoxContainer/MainArea/SummarySection/VBoxContainer/KeywordExplainScroll/KeywordExplainPanel") as KeywordExplainPanel
	if feedback_label == null:
		feedback_label = get_node_or_null("Panel/VBoxContainer/FeedbackLabel") as Label
