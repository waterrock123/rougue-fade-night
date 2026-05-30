## 动画关键帧触发组件。
## 监听施法者 AnimatedSprite2D 的指定动画帧，并手动触发同一个 Ability 下的其他组件。
class_name AbilityTriggerComponentsOnSpriteFrame
extends AbilityComponent

## 要监听的动画名。留空时会以组件启动时的当前动画为准。
@export var animation_name: String = ""
## 施法者身上的 AnimatedSprite2D 路径。为空时默认读取 caster/AnimatedSprite2D。
@export var animated_sprite_path: NodePath
## 每个关键帧对应要触发的组件列表。
@export var frame_events: Array[AbilityAnimationFrameEvent] = []
## 是否等到动画结束后再结束监听。需要按动画中后段帧触发的技能建议保持开启。
@export var wait_for_animation_end: bool = true
## 等待动画真正切到目标动画的容错时间，避免同一帧内组件执行顺序导致漏监听。
@export var start_wait_time: float = 0.15


func _activate(context: AbilityContext):
	var caster := context.caster
	var ability := context.ability
	if caster == null or ability == null or not context.is_caster_action_valid():
		return

	var animated_sprite := _resolve_animated_sprite(caster)
	if animated_sprite == null:
		return

	var expected_animation := StringName(animation_name)
	if expected_animation == &"":
		expected_animation = animated_sprite.animation

	var animation_ready := await _wait_for_expected_animation(animated_sprite, expected_animation, context)
	if not animation_ready:
		return
	if not _is_expected_animation(animated_sprite, expected_animation):
		return

	var triggered_frames: Dictionary = {}

	# 逐帧轮询负责兜底：即使动画跳过某一帧，也会用 current_frame >= event.frame 补触发。
	_try_trigger_frame_events(animated_sprite.frame, context, triggered_frames)
	if wait_for_animation_end:
		while is_instance_valid(animated_sprite) and context.is_caster_action_valid():
			if not _is_expected_animation(animated_sprite, expected_animation):
				break
			_try_trigger_frame_events(animated_sprite.frame, context, triggered_frames)
			if not animated_sprite.is_playing():
				break
			var did_wait := await _wait_process_frame()
			if not did_wait:
				return
	else:
		await _wait_process_frame()


func _wait_for_expected_animation(
	animated_sprite: AnimatedSprite2D,
	expected_animation: StringName,
	context: AbilityContext
) -> bool:
	if _is_expected_animation(animated_sprite, expected_animation):
		return true

	var waited_time := 0.0
	while waited_time < start_wait_time:
		if not is_instance_valid(animated_sprite) or not context.is_caster_action_valid():
			return false
		var did_wait := await _wait_process_frame()
		if not did_wait:
			return false
		waited_time += get_process_delta_time()
		if _is_expected_animation(animated_sprite, expected_animation):
			return true

	return false


func _wait_process_frame() -> bool:
	if not is_inside_tree():
		return false

	var tree := get_tree()
	if tree == null:
		return false

	await tree.process_frame
	return is_inside_tree()


func _is_expected_animation(animated_sprite: AnimatedSprite2D, expected_animation: StringName) -> bool:
	if animated_sprite == null or not is_instance_valid(animated_sprite):
		return false
	return animated_sprite.animation == expected_animation


## 遍历当前帧对应的所有事件，并手动触发目标组件。
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


## 触发一组同级技能组件。
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


## 优先按导出的路径找 AnimatedSprite2D；没配置路径时默认使用施法者身上的 AnimatedSprite2D。
func _resolve_animated_sprite(caster: Entity) -> AnimatedSprite2D:
	if not animated_sprite_path.is_empty():
		# 先按“组件节点自身”的相对路径解析，适配 Ability 场景内写 ../../../AnimatedSprite2D 的情况。
		var sprite_from_component := get_node_or_null(animated_sprite_path) as AnimatedSprite2D
		if sprite_from_component != null:
			return sprite_from_component

		# 再按“施法者根节点”的相对路径解析，适配直接写 AnimatedSprite2D 的情况。
		var sprite_from_caster := caster.get_node_or_null(animated_sprite_path) as AnimatedSprite2D
		if sprite_from_caster != null:
			return sprite_from_caster

	return caster.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
