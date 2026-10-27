class_name HubNpcInteractionData
extends Resource

## 大厅 NPC 的静态交互配置。功能类型由 MainHomeMap 调度，NPC 本身不依赖具体 UI。
enum InteractionType {
	NONE,
	OPEN_PICTORIAL_BOOK,
}

## 单句随机适合日常闲聊；顺序播放适合剧情或功能引导。
enum DialoguePlaybackMode {
	RANDOM_LINE,
	PLAY_ALL_LINES,
}

@export_group("基础信息")
@export var npc_id: StringName
@export var display_name: String = "未命名 NPC"
@export_multiline var description: String
@export var interaction_type: InteractionType = InteractionType.NONE

@export_group("对话框展示")
## 头像用于 SpeakUi，未填写时自动隐藏头像区域。
@export var portrait: Texture2D

@export_group("外观资源")
## 视觉资源单独保存，交互配置可直接复用同一套外观。
@export var visual_data: HubNpcVisualData

@export_group("交互表现")
@export var interaction_radius: float = 36.0
@export var prompt_text: String = "交谈"
@export_multiline var dialogue_lines: Array[String] = []
@export var dialogue_playback_mode: DialoguePlaybackMode = DialoguePlaybackMode.RANDOM_LINE
@export_range(0.1, 10.0, 0.1, "suffix:s") var dialogue_duration: float = 1.5

@export_group("环境气泡")
## 玩家未与 NPC 交谈时随机出现的自言自语，用于增加大厅的生活感。
@export_multiline var ambient_bubble_lines: Array[String] = []
@export_range(1.0, 60.0, 0.5, "suffix:s") var ambient_bubble_interval: float = 8.0
@export_range(0.1, 10.0, 0.1, "suffix:s") var ambient_bubble_duration: float = 2.5

@export_group("功能按钮")
## 为空时会兼容旧的 interaction_type 配置，方便已有资源逐步迁移。
@export var actions: Array[HubNpcActionData] = []

@export_group("交互状态")
## 只有完成这些局外事件后，NPC 才会允许交互。
@export var required_completed_event_ids: Array[StringName] = []
## 关闭后，本次进入大厅期间只能与该 NPC 交互一次。
@export var can_repeat_interaction: bool = true
## 对白完整播放后由大厅发出的事件标识；留空时不会发出事件。
@export var completion_event_id: StringName
## 完成事件后消耗大厅背包当前携带的装备；阶段配置会覆盖到本次对话副本。
@export var consume_carried_relic_on_completion: bool = false

@export_group("对话阶段")
## 按顺序选择首个符合条件的阶段；留空时使用原来的单段对话配置。
@export var dialogue_stages: Array[HubNpcDialogueStage] = []


## 焦点检测每帧运行，只检查条件，不在此复制对话资源。
func has_available_stage(completed_ids: Array[StringName], carried_relic: Relic = null, carried_relic_locked: bool = false) -> bool:
	for stage: HubNpcDialogueStage in dialogue_stages:
		if stage != null and stage.matches(completed_ids, carried_relic, carried_relic_locked):
			return true
	return false


## 返回本次交谈的独立配置，事件状态变化不会改变已经打开的对白和奖励。
func resolve_dialogue(completed_ids: Array[StringName], carried_relic: Relic = null, carried_relic_locked: bool = false) -> HubNpcInteractionData:
	if dialogue_stages.is_empty():
		return self
	for stage: HubNpcDialogueStage in dialogue_stages:
		if stage == null or not stage.matches(completed_ids, carried_relic, carried_relic_locked):
			continue
		var resolved: HubNpcInteractionData = duplicate() as HubNpcInteractionData
		resolved.dialogue_lines = stage.dialogue_lines.duplicate()
		resolved.dialogue_playback_mode = DialoguePlaybackMode.RANDOM_LINE if stage.random_line else DialoguePlaybackMode.PLAY_ALL_LINES
		resolved.actions = stage.actions.duplicate()
		resolved.interaction_type = InteractionType.NONE
		resolved.completion_event_id = stage.completion_event_id
		resolved.can_repeat_interaction = stage.repeatable
		resolved.consume_carried_relic_on_completion = stage.consume_carried_relic_on_completion
		return resolved
	return null


func get_random_dialogue() -> String:
	if dialogue_lines.is_empty():
		return ""
	return dialogue_lines[randi_range(0, dialogue_lines.size() - 1)]


## 过滤空行后按播放模式提供本次交互应显示的对白。
func get_dialogue_lines_for_interaction() -> Array[String]:
	var valid_lines: Array[String] = []
	for dialogue_line: String in dialogue_lines:
		if not dialogue_line.strip_edges().is_empty():
			valid_lines.append(dialogue_line)
	if valid_lines.is_empty():
		return valid_lines
	if dialogue_playback_mode == DialoguePlaybackMode.PLAY_ALL_LINES:
		return valid_lines
	return [valid_lines.pick_random()]


func get_random_ambient_bubble() -> String:
	var valid_lines: Array[String] = []
	for dialogue_line: String in ambient_bubble_lines:
		if not dialogue_line.strip_edges().is_empty():
			valid_lines.append(dialogue_line)
	return valid_lines.pick_random() if not valid_lines.is_empty() else ""


## 将旧版单一功能字段转换为临时按钮，避免已有 NPC 资源失效。
func get_available_actions() -> Array[HubNpcActionData]:
	if not actions.is_empty():
		return actions
	if interaction_type == InteractionType.NONE:
		return []
	var legacy_action: HubNpcActionData = HubNpcActionData.new()
	legacy_action.action_id = &"legacy_action"
	legacy_action.display_name = "打开图鉴" if interaction_type == InteractionType.OPEN_PICTORIAL_BOOK else "使用功能"
	legacy_action.action_type = HubNpcActionData.ActionType.OPEN_PICTORIAL_BOOK if interaction_type == InteractionType.OPEN_PICTORIAL_BOOK else HubNpcActionData.ActionType.NONE
	return [legacy_action]
