extends ConfirmationDialog

signal continue_requested

var continue_button: Button
@onready var token_count_label: Label = %CountLabel
@onready var token_list: VBoxContainer = %TokenList
@onready var character_name_label: Label = %CharacterName
@onready var character_description: Label = %CharacterDescription
@onready var character_stats: Label = %CharacterStats
@onready var save_warning: Label = %SaveWarning
@onready var carried_relic_label: RichTextLabel = %CarriedRelicLabel

var token_buttons: Dictionary = {}
var updating_token_selection: bool = false


func _ready() -> void:
	# 自定义内容由固定边界承载，避免首帧换行高度参与窗口自动扩张。
	get_label().hide()
	continue_button = add_button("继续冒险", false, "continue")
	custom_action.connect(_on_custom_action)
	if not ProfileManager.equipped_tokens_changed.is_connected(_on_equipped_tokens_changed):
		ProfileManager.equipped_tokens_changed.connect(_on_equipped_tokens_changed)


func _on_custom_action(action: StringName) -> void:
	if action == &"continue" and SaveManager.has_continue_save():
		hide()
		continue_requested.emit()

## 出发面板只负责展示与确认，创建 Run 的职责保留在大厅总控中。
func show_character(character: Character) -> void:
	continue_button.visible = SaveManager.has_continue_save()
	title = "单人出发"
	ok_button_text = "开始冒险"
	cancel_button_text = "取消"
	# 内置文本与自定义内容会共享弹窗区域，统一使用场景里的容器布局。
	dialog_text = ""
	character_name_label.text = character.character_name
	character_description.text = character.description
	_update_character_stats(character)
	save_warning.visible = SaveManager.has_continue_save()
	_rebuild_token_list()
	_update_carried_relic_preview()
	popup_centered(Vector2i(920, 650))
	# 默认聚焦取消，避免开启入口的同一次按键被误当作出发确认。
	get_cancel_button().grab_focus()


func _update_carried_relic_preview() -> void:
	var relic: Relic = ProfileManager.get_selected_warehouse_relic()
	if relic == null:
		carried_relic_label.text = "[color=#b9c8d8][b]大厅背包[/b]：未携带仓库装备[/color]"
		return
	var rate: float = ProfileManager.get_carry_penalty_rate(relic)
	if rate <= 0.0:
		carried_relic_label.text = "[color=#9fdcff][b]大厅背包：%s　Lv.%d[/b][/color]\n稳定携带：不会产生荒域阻力。仅开始新冒险时转入背包；继续冒险不会消耗。" % [relic.relic_name, relic.level]
		return
	var percent: int = roundi(rate * 100.0)
	var risk_color: String = "#ff6f61" if rate >= 0.20 else "#ffad66"
	carried_relic_label.text = "[color=%s][b]大厅背包：%s　Lv.%d　荒域阻力 %d%%[/b][/color]\n新冒险最大生命与最大能量降低 %d%%，持续整局且无法通过丢弃装备解除。继续冒险不会消耗该装备。" % [risk_color, relic.relic_name, relic.level, percent, percent]


## 出发预览展示角色初始属性，信物的具体增益单独列在右侧。
func _update_character_stats(character: Character) -> void:
	var stats: StatsData = character.start_stats
	character_stats.visible = stats != null
	if stats == null:
		return
	character_stats.text = "初始属性\n\n力量  %d     敏捷  %d\n智力  %d     体质  %d\n速度  %d     魅力  %d\n幸运  %d" % [stats.strength, stats.dexterity, stats.intelligence, stats.constitution, stats.speed, stats.charm, stats.luck]


## 信物从局外档案读取，玩家的勾选会立即保存，方便下次出发沿用同一套构筑。
func _rebuild_token_list() -> void:
	if token_list == null:
		return
	updating_token_selection = true
	token_buttons.clear()
	for child: Node in token_list.get_children():
		token_list.remove_child(child)
		child.queue_free()

	var tokens: Array[ProfileModifierData] = ProfileManager.get_equippable_tokens()
	var equipped_ids: Array[StringName] = ProfileManager.get_equipped_token_ids()
	if tokens.is_empty():
		var empty_label := Label.new()
		empty_label.text = "尚未获得可携带的 NPC 信物。完成大厅剧情事件后，它们会收录在这里。"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 18)
		token_list.add_child(empty_label)
	else:
		for token_data: ProfileModifierData in tokens:
			var check_button := CheckButton.new()
			check_button.text = "%s\n%s" % [token_data.display_name, token_data.description]
			check_button.custom_minimum_size = Vector2(0.0, 76.0)
			check_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			check_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			check_button.add_theme_font_size_override("font_size", 18)
			check_button.button_pressed = equipped_ids.has(token_data.modifier_id)
			token_list.add_child(check_button)
			token_buttons[token_data.modifier_id] = check_button
			check_button.toggled.connect(_on_token_toggled.bind(token_data.modifier_id))
	updating_token_selection = false
	_refresh_token_selection_state()


func _on_token_toggled(_pressed: bool, _modifier_id: StringName) -> void:
	if updating_token_selection:
		return
	var selected_ids: Array[StringName] = []
	for raw_id: Variant in token_buttons.keys():
		var modifier_id: StringName = StringName(raw_id)
		var check_button: CheckButton = token_buttons[raw_id] as CheckButton
		if check_button != null and check_button.button_pressed:
			selected_ids.append(modifier_id)
	ProfileManager.set_equipped_token_ids(selected_ids)


## 选满三件后仅禁用未勾选项，仍允许玩家取消已携带的信物。
func _refresh_token_selection_state() -> void:
	var selected_count: int = 0
	for raw_id: Variant in token_buttons.keys():
		var check_button: CheckButton = token_buttons[raw_id] as CheckButton
		if check_button != null and check_button.button_pressed:
			selected_count += 1
	if token_count_label != null:
		token_count_label.text = "已携带：%d / %d" % [selected_count, ProfileManager.MAX_EQUIPPED_TOKENS]
	for raw_id: Variant in token_buttons.keys():
		var check_button: CheckButton = token_buttons[raw_id] as CheckButton
		if check_button != null:
			check_button.disabled = not check_button.button_pressed and selected_count >= ProfileManager.MAX_EQUIPPED_TOKENS


func _on_equipped_tokens_changed(_token_ids: Array[StringName]) -> void:
	_refresh_token_selection_state()
