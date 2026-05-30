class_name LevelUPController
extends Control

enum SceneMode {
	LEVEL_UP,
	STARTING_SKILL,
}

@export var reward_pool: LevelUpRewardPool
@export var reward_count: int = 4
@export var primary_attribute_reward_amount: float = 1.0
@export var keyword_database: KeywordDatabase = preload("res://custom_resource/default_keyword_database.tres")

var run_stats: RunStats
var run: Run
var stats_controller: StatsController
var skill_controller: SkillController
var scene_mode: SceneMode = SceneMode.LEVEL_UP
var fixed_rewards: Array[LevelUpReward] = []
var current_rewards: Array[LevelUpReward] = []

@onready var reward_container: HBoxContainer = $MarginContainer/HBoxContainer
@onready var title_label: Label = $Panel/Label
@onready var tooltip_label: RichTextLabel = %TooltipLabel
@onready var attributes_panel: AttributesPanel = $AttributesPanel
@onready var active_skill_grid: GridContainer = $SkillContainer/HBoxContainer/ActiveSkill/GridContainer
@onready var passive_skill_grid: GridContainer = $SkillContainer/HBoxContainer/PassiveSkill/GridContainer
@onready var refresh_label: Label = $HBoxContainer2/HBoxContainer/RefreshLabel
@onready var refresh_button: Button = $HBoxContainer2/RefreshButton


func _ready() -> void:
	_bind_reward_buttons()
	_bind_refresh_button()
	_refresh_all_ui()


# Run 创建升级场景后会调用这里，把本局数据和运行时控制器传进来。
func setup_level_up(
	new_run_stats: RunStats,
	new_run: Run,
	new_stats_controller: StatsController,
	new_skill_controller: SkillController,
	new_fixed_rewards: Array[LevelUpReward] = []
) -> void:
	scene_mode = SceneMode.LEVEL_UP
	_setup_common(new_run_stats, new_run, new_stats_controller, new_skill_controller, new_fixed_rewards)


# 开局技能选择不是“升级”，只是给玩家开局补一份主动技能战斗力。
func setup_starting_skill(
	new_run_stats: RunStats,
	new_run: Run,
	new_stats_controller: StatsController,
	new_skill_controller: SkillController,
	new_fixed_rewards: Array[LevelUpReward] = []
) -> void:
	scene_mode = SceneMode.STARTING_SKILL
	_setup_common(new_run_stats, new_run, new_stats_controller, new_skill_controller, new_fixed_rewards)


func _setup_common(
	new_run_stats: RunStats,
	new_run: Run,
	new_stats_controller: StatsController,
	new_skill_controller: SkillController,
	new_fixed_rewards: Array[LevelUpReward] = []
) -> void:
	run_stats = new_run_stats
	run = new_run
	stats_controller = new_stats_controller
	skill_controller = new_skill_controller
	fixed_rewards = new_fixed_rewards
	_refresh_all_ui()


# 连接奖励按钮的点击和悬停信号，统一交给控制器处理奖励应用与提示刷新。
func _bind_reward_buttons() -> void:
	for child in reward_container.get_children():
		if child is RewardChoseButton:
			var reward_button := child as RewardChoseButton
			if not reward_button.reward_chosen.is_connected(_on_reward_chosen):
				reward_button.reward_chosen.connect(_on_reward_chosen)
			if not reward_button.reward_focused.is_connected(_on_reward_focused):
				reward_button.reward_focused.connect(_on_reward_focused)


# 统一刷新升级界面的奖励、属性面板和技能展示。
func _refresh_all_ui() -> void:
	if not is_inside_tree():
		return

	_refresh_title_label()
	_refresh_rewards()
	_refresh_attributes_panel()
	_refresh_skill_grid(active_skill_grid, _get_active_skill_entries())
	_refresh_skill_grid(passive_skill_grid, _get_passive_skill_entries())
	_refresh_tooltip_label()
	_refresh_reroll_ui()


# 初始化升级奖励按钮；奖励池不足时，会用角色主要属性奖励补足。
func _refresh_rewards() -> void:
	var rewards := fixed_rewards if not fixed_rewards.is_empty() else _build_reward_options()
	current_rewards = rewards
	var buttons := reward_container.get_children()

	for index in range(buttons.size()):
		if not (buttons[index] is RewardChoseButton):
			continue

		var reward := rewards[index] if index < rewards.size() else null
		(buttons[index] as RewardChoseButton).setup(reward)


# 绑定刷新按钮，按钮只负责发起“消耗一次次数并重抽奖励”的请求。
func _bind_refresh_button() -> void:
	if refresh_button == null:
		return
	if not refresh_button.pressed.is_connected(_on_refresh_button_pressed):
		refresh_button.pressed.connect(_on_refresh_button_pressed)


# 升级界面内嵌的属性面板只负责展示当前运行时属性。
func _refresh_attributes_panel() -> void:
	if attributes_panel == null or stats_controller == null:
		return

	attributes_panel.stats_controller = stats_controller
	attributes_panel.setup()
	attributes_panel.open_panel()


# 把玩家已拥有的技能条目填进对应的技能格子。
func _refresh_skill_grid(grid: GridContainer, entries: Array[SkillEntry]) -> void:
	if grid == null:
		return

	var spell_uis := _collect_spell_uis(grid)
	for index in range(spell_uis.size()):
		var entry := entries[index] if index < entries.size() else null
		spell_uis[index].setup(entry)


# 未悬停具体奖励时，显示升级界面的默认提示。
func _refresh_tooltip_label() -> void:
	if tooltip_label == null:
		return

	_set_tooltip_text(_get_default_tooltip_text())


# 刷新次数显示和按钮可用状态都从 RunStats 读取，避免 UI 自己保存运行数据。
func _refresh_reroll_ui() -> void:
	var count := _get_refresh_count()
	if refresh_label != null:
		refresh_label.text = "剩余刷新次数：%s" % str(count)
	if refresh_button != null:
		refresh_button.disabled = count <= 0


# 顶部标题根据当前模式切换，避免开局奖励被误认为升级。
func _refresh_title_label() -> void:
	if title_label == null:
		return

	match scene_mode:
		SceneMode.STARTING_SKILL:
			title_label.text = "请选择一个开局技能！"
		_:
			title_label.text = "你升级了！"


# 先从配置的奖励池抽奖励，不足的数量再用角色主要属性奖励补齐。
func _build_reward_options() -> Array[LevelUpReward]:
	if scene_mode == SceneMode.STARTING_SKILL:
		return _build_starting_skill_reward_options()

	var rewards: Array[LevelUpReward] = []
	var reward_context := _build_reward_context()
	if reward_pool != null:
		rewards = reward_pool.get_random_rewards(reward_count, reward_context)

	var main_attributes := _get_main_attributes()
	main_attributes.shuffle()
	var attr_index := 0
	while rewards.size() < reward_count:
		if main_attributes.is_empty():
			break
		var stat_reward := _create_primary_attribute_reward(main_attributes[attr_index % main_attributes.size()])
		if stat_reward == null:
			break
		rewards.append(stat_reward)
		attr_index += 1

	return rewards


# 开局奖励只提供主动技能，目的是让玩家在第一场战斗前拥有更强的操作手段。
func _build_starting_skill_reward_options() -> Array[LevelUpReward]:
	var rewards: Array[LevelUpReward] = []
	if reward_pool == null:
		return rewards

	var reward_context := _build_reward_context()
	var candidates := reward_pool.rewards.duplicate()
	candidates.shuffle()
	for reward in candidates:
		if not (reward is RewardGrantActiveSkill):
			continue
		if not reward.is_available(reward_context):
			continue

		rewards.append(reward)
		if rewards.size() >= reward_count:
			break

	return rewards


func get_current_rewards() -> Array[LevelUpReward]:
	return current_rewards


# 玩家点击刷新时，消耗一次次数并重抽当前模式下的奖励。
func _on_refresh_button_pressed() -> void:
	if run_stats == null:
		return
	if not run_stats.spend_level_up_reward_refresh_count():
		_refresh_reroll_ui()
		return

	fixed_rewards.clear()
	_refresh_rewards()
	_refresh_tooltip_label()
	_refresh_reroll_ui()
	if run != null and run.has_method("update_level_up_reward_options"):
		run.update_level_up_reward_options(current_rewards, true)


# 将一个主要属性包装成可点击领取的升级奖励。
func _create_primary_attribute_reward(stat_name: StringName) -> LevelUpReward:
	if stat_name == &"":
		return null

	var reward := RewardIncreaseStat.new()
	reward.id = StringName("increase_%s" % String(stat_name))
	reward.title = "%s +%s" % [_get_attribute_display_name(stat_name), str(int(primary_attribute_reward_amount))]
	reward.desc = "提升角色的主要属性。"
	reward.stat_name = stat_name
	reward.amount = primary_attribute_reward_amount
	return reward


# 鼠标悬停奖励时，刷新顶部提示文字，让玩家确认将获得什么。
func _on_reward_focused(reward: LevelUpReward) -> void:
	if tooltip_label == null or reward == null:
		return

	if reward is RewardIncreaseStat:
		var stat_reward := reward as RewardIncreaseStat
		_set_tooltip_text("选择后：%s +%s" % [
			_get_attribute_display_name(stat_reward.stat_name),
			str(int(stat_reward.amount))
		])
		return

	_set_tooltip_text(reward.get_display_desc())


# 点击奖励后应用效果，并把流程交还给 Run 进入修整期。
func _on_reward_chosen(reward: LevelUpReward) -> void:
	if reward == null:
		return

	var context := _build_reward_context()
	reward.apply(context)

	if skill_controller != null:
		skill_controller.refresh_all_skills()

	if run == null:
		return

	if scene_mode == SceneMode.STARTING_SKILL and run.has_method("finish_starting_skill_select"):
		run.finish_starting_skill_select()
	else:
		run.change_to_rest_period()


# 构建奖励应用所需的上下文，避免奖励脚本直接依赖 Run 场景。
func _build_reward_context() -> LevelUpRewardContext:
	var context := LevelUpRewardContext.new()
	context.run_stats = run_stats
	context.player_build = run_stats.player_build if run_stats != null else null
	context.picked_character = run_stats.picked_character if run_stats != null else null
	context.skill_controller = skill_controller
	context.stats_controller = stats_controller
	return context


# 递归收集技能格子，兼容 SpellUI 外面套 MarginContainer 的场景结构。
func _collect_spell_uis(root: Node) -> Array[SpellUI]:
	var result: Array[SpellUI] = []
	for child in root.get_children():
		if child is SpellUI:
			result.append(child)
		else:
			result.append_array(_collect_spell_uis(child))
	return result


# 读取玩家当前拥有的主动技能，用于升级界面展示。
func _get_active_skill_entries() -> Array[SkillEntry]:
	if run_stats == null or run_stats.player_build == null:
		return []
	return run_stats.player_build.owned_active_skills


# 读取玩家当前拥有的被动技能，用于升级界面展示。
func _get_passive_skill_entries() -> Array[SkillEntry]:
	if run_stats == null or run_stats.player_build == null:
		return []
	return run_stats.player_build.owned_passive_skills


# 角色资源可以配置 2 到 3 个主要属性；未配置时使用一组保底属性。
func _get_main_attributes() -> Array[StringName]:
	if run_stats != null and run_stats.picked_character != null:
		var attrs := run_stats.picked_character.main_attributes
		if not attrs.is_empty():
			var copied_attrs: Array[StringName] = []
			for attr in attrs:
				copied_attrs.append(attr)
			return copied_attrs

	var fallback_attrs: Array[StringName] = [&"strength", &"constitution", &"dexterity"]
	return fallback_attrs


# 将内部属性名翻译成面板上更易读的中文名称。
func _get_attribute_display_name(stat_name: StringName) -> String:
	match stat_name:
		&"strength":
			return "力量"
		&"dexterity":
			return "敏捷"
		&"intelligence":
			return "智慧"
		&"constitution":
			return "体质"
		&"speed":
			return "速度"
		&"charm":
			return "魅力"
		&"luck":
			return "幸运"
		_:
			return String(stat_name)


func _set_tooltip_text(raw_text: String) -> void:
	if tooltip_label == null:
		return

	var result := KeywordTextFormatter.format_text(raw_text, keyword_database)
	tooltip_label.clear()
	tooltip_label.append_text(result.bbcode_text)


func _get_refresh_count() -> int:
	if run_stats == null:
		return 0
	return max(run_stats.level_up_reward_refresh_count, 0)


func _get_default_tooltip_text() -> String:
	match scene_mode:
		SceneMode.STARTING_SKILL:
			return "请选择一个开局技能！"
		_:
			return "选择一个升级奖励，确认后前往修整期。"
