## 动画关键帧触发组件。监听施法者 AnimatedSprite2D 的指定动画帧，手动触发同级技能组件。
class_name AbilityTriggerComponentsOnSpriteFrame
extends AbilityComponent

# 监听 AnimatedSprite2D 动画播放到指定帧时，
# 手动触发同一个 Ability 下的其他技能组件。
# 适合逐帧动画角色，不依赖 AnimationPlayer 的方法轨道。

@export var animation_name: String = ""
@export var animated_sprite_path: NodePath
@export var frame_events: Array[AbilityAnimationFrameEvent] = []
@export var wait_for_animation_end: bool = true


func _activate(context: AbilityContext):
	var caster := context.caster
	var ability := context.ability
	if caster == null or ability == null or not context.is_caster_action_valid():
		return

	var animated_sprite := _resolve_animated_sprite(caster)
	if animated_sprite == null:
		return

	var triggered_frames: Dictionary = {}

	if animated_sprite.animation == animation_name:
		_try_trigger_frame_events(animated_sprite.frame, context, triggered_frames)

	var frame_callback := func():
		if not context.is_caster_action_valid():
			return
		if animated_sprite.animation != animation_name:
			return
		_try_trigger_frame_events(animated_sprite.frame, context, triggered_frames)

	animated_sprite.frame_changed.connect(frame_callback)

	if wait_for_animation_end:
		while is_instance_valid(animated_sprite) and animated_sprite.animation == animation_name and animated_sprite.is_playing():
			if not context.is_caster_action_valid():
				break
			await get_tree().process_frame
	else:
		await get_tree().process_frame

	if is_instance_valid(animated_sprite) and animated_sprite.frame_changed.is_connected(frame_callback):
		animated_sprite.frame_changed.disconnect(frame_callback)


# 遍历当前帧对应的所有事件，并手动触发目标组件。
func _try_trigger_frame_events(current_frame: int, context: AbilityContext, triggered_frames: Dictionary) -> void:
	if context == null or not context.is_caster_action_valid():
		return
	for frame_event in frame_events:
		if frame_event == null:
			continue
		if current_frame < frame_event.frame:
			continue
		if triggered_frames.has(frame_event):
			continue

		triggered_frames[frame_event] = true
		_trigger_components(frame_event, context)


# 触发一组同级技能组件。
func _trigger_components(frame_event: AbilityAnimationFrameEvent, context: AbilityContext) -> void:
	var ability := context.ability
	if ability == null or not context.is_caster_action_valid():
		return

	for component_name in frame_event.component_names:
		if not context.is_caster_action_valid():
			return
		if component_name.is_empty():
			continue
		ability.trigger_component_by_name(component_name, context)


# 优先按导出的路径找 AnimatedSprite2D；
# 没配路径时，默认使用施法者上的 AnimatedSprite2D。
func _resolve_animated_sprite(caster: Entity) -> AnimatedSprite2D:
	if not animated_sprite_path.is_empty():
		return caster.get_node_or_null(animated_sprite_path) as AnimatedSprite2D

	return caster.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
