class_name HubNpc
extends Node2D

## 大厅通用 NPC：负责外观、距离判定、提示与台词；实际功能由 MainHomeMap 统一处理。
signal interaction_completed(event_id: StringName)

@export var interaction_data: HubNpcInteractionData

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt_label: Label = $CanvasLayer/PromptLabel
@onready var dialogue_ui: DialogueUI = $CanvasLayer/DialogueUI

var has_completed_interaction: bool = false
var interaction_active: bool = false
var ambient_bubbles_enabled: bool = true
var ambient_bubble_timer: float = 0.0
var active_dialogue_data: HubNpcInteractionData


func _ready() -> void:
	add_to_group("hub_npc")
	_apply_visual()
	prompt_label.hide()
	refresh_profile_availability()
	_schedule_next_ambient_bubble()


func _process(delta: float) -> void:
	_update_bubble_screen_position()
	if not visible or not ambient_bubbles_enabled or interaction_active or interaction_data == null:
		return
	if interaction_data.ambient_bubble_lines.is_empty():
		return
	ambient_bubble_timer -= delta
	if ambient_bubble_timer > 0.0:
		return
	var bubble_text: String = interaction_data.get_random_ambient_bubble()
	if not bubble_text.is_empty() and dialogue_ui != null:
		dialogue_ui.show_dialogue(interaction_data.display_name, bubble_text, interaction_data.ambient_bubble_duration)
	_schedule_next_ambient_bubble()


func _apply_visual() -> void:
	if animated_sprite == null:
		return

	# 先清空场景中可能遗留的显示，避免更换资源后仍播放旧动画。
	animated_sprite.stop()
	animated_sprite.sprite_frames = null
	animated_sprite.visible = false

	if interaction_data == null or interaction_data.visual_data == null:
		return

	var visual_data: HubNpcVisualData = interaction_data.visual_data
	if visual_data.sprite_frames == null:
		return

	animated_sprite.sprite_frames = visual_data.sprite_frames
	animated_sprite.scale = visual_data.visual_scale
	animated_sprite.position = visual_data.visual_offset
	animated_sprite.flip_h = visual_data.default_facing_left
	animated_sprite.z_index = visual_data.visual_z_index
	animated_sprite.visible = true
	if visual_data.has_default_animation():
		animated_sprite.play(visual_data.default_animation)


func get_interaction_radius() -> float:
	return interaction_data.interaction_radius if interaction_data != null else 0.0


## 前置事件未完成时，NPC 不会出现在大厅，避免出现“看得见却不能互动”的体验问题。
func refresh_profile_availability() -> void:
	visible = _has_required_profile_events()
	if not visible:
		prompt_label.hide()
		if dialogue_ui != null:
			dialogue_ui.hide()


func _has_required_profile_events() -> bool:
	return interaction_data != null and ProfileManager.are_events_completed(interaction_data.required_completed_event_ids)


## 不可重复交互的 NPC 在本次大厅停留中完成后不再成为可交互目标。
func can_interact() -> bool:
	if interaction_data == null or not visible:
		return false
	if not _has_required_profile_events():
		return false
	if not interaction_data.dialogue_stages.is_empty():
		return interaction_data.has_available_stage(
			ProfileManager.profile_data.completed_event_ids,
			ProfileManager.get_selected_warehouse_relic(),
			ProfileManager.is_warehouse_entry_locked(ProfileManager.get_selected_warehouse_entry_id())
		)
	if interaction_data.can_repeat_interaction:
		return true
	if has_completed_interaction:
		return false
	return interaction_data.completion_event_id == &"" or not ProfileManager.has_completed_event(interaction_data.completion_event_id)


## 打开功能对话时暂停环境气泡，避免两种对白 UI 同时出现。
func begin_interaction() -> bool:
	if not can_interact():
		return false
	active_dialogue_data = interaction_data.resolve_dialogue(
		ProfileManager.profile_data.completed_event_ids,
		ProfileManager.get_selected_warehouse_relic(),
		ProfileManager.is_warehouse_entry_locked(ProfileManager.get_selected_warehouse_entry_id())
	)
	if active_dialogue_data == null:
		return false
	interaction_active = true
	if dialogue_ui != null:
		dialogue_ui.hide()
	return true


func should_consume_carried_relic_on_completion() -> bool:
	return active_dialogue_data != null and active_dialogue_data.consume_carried_relic_on_completion


## 功能对话结束后恢复环境气泡；一次性 NPC 同时在这里发出完成事件。
func end_interaction(completed: bool) -> void:
	interaction_active = false
	if completed:
		has_completed_interaction = true
		if active_dialogue_data != null and not active_dialogue_data.completion_event_id.is_empty():
			interaction_completed.emit(active_dialogue_data.completion_event_id)
	active_dialogue_data = null
	_schedule_next_ambient_bubble()


func set_ambient_bubbles_enabled(enabled: bool) -> void:
	ambient_bubbles_enabled = enabled
	if not enabled and dialogue_ui != null:
		dialogue_ui.hide()
	if enabled:
		_schedule_next_ambient_bubble()


func _schedule_next_ambient_bubble() -> void:
	if interaction_data == null:
		return
	ambient_bubble_timer = maxf(interaction_data.ambient_bubble_interval, 1.0)


## 环境气泡位于 CanvasLayer 中，需要持续同步 NPC 的屏幕坐标。
func _update_bubble_screen_position() -> void:
	if dialogue_ui == null:
		return
	var screen_position: Vector2 = get_global_transform_with_canvas().origin
	dialogue_ui.position = (screen_position + Vector2(-100.0, -150.0)).round()


func update_prompt(focused: bool) -> void:
	prompt_label.visible = focused and interaction_data != null
	if not prompt_label.visible:
		return
	prompt_label.text = "%s · %s" % [interaction_data.display_name, interaction_data.prompt_text]
	var screen_position: Vector2 = get_global_transform_with_canvas().origin
	prompt_label.position = (screen_position + Vector2(-120.0, -66.0)).round()
