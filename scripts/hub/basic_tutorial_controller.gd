class_name BasicTutorialController
extends Node

signal tutorial_completed()

var player: Player
var dummy: Enemy
var lesson: TutorialCharacterLesson
var panel: BasicTutorialPanel
var marker: TutorialWorldMarker
var character_name: String
var movement_goal: Vector2
var progress: BasicTutorialProgress = BasicTutorialProgress.new()
var ability_controller: AbilityController
var basic_ability: Ability
var aim_ability: Ability
var previous_position: Vector2


func _ready() -> void:
	if not is_instance_valid(player) or lesson == null or not is_instance_valid(dummy):
		_show_configuration_error()
		return
	ability_controller = player.ability_controller
	if not is_instance_valid(ability_controller):
		_show_configuration_error()
		return
	for ability: Ability in ability_controller.abilities:
		if ability_controller.is_basic_ability(ability):
			basic_ability = ability
		if lesson.aim_skill != null and ability.id == lesson.aim_skill.id:
			aim_ability = ability
	if basic_ability == null or aim_ability == null or not aim_ability.has_cast_preview():
		_show_configuration_error()
		return
	previous_position = player.global_position
	_bind_signals()
	_show_stage(progress.stage)


func _show_configuration_error() -> void:
	if is_instance_valid(panel):
		panel.show_step(character_name, 0, "教学配置需要补充", "当前角色缺少基础攻击或可瞄准技能，请配置教学资源后重试。可以安全返回大厅。", "")
	set_process(false)


func _bind_signals() -> void:
	progress.stage_changed.connect(_show_stage)
	progress.completed.connect(func() -> void: tutorial_completed.emit())
	ability_controller.ability_preview_started.connect(_on_preview_started)
	ability_controller.ability_preview_released.connect(_on_preview_released)
	ability_controller.ability_preview_cancelled.connect(_on_preview_cancelled)
	ability_controller.cast_prepared.connect(_on_cast_prepared)
	player.damage_dealt.connect(_on_damage_dealt)
	InputSettingsManager.bindings_changed.connect(_on_bindings_changed)


func _exit_tree() -> void:
	if InputSettingsManager.bindings_changed.is_connected(_on_bindings_changed):
		InputSettingsManager.bindings_changed.disconnect(_on_bindings_changed)
	if is_instance_valid(ability_controller):
		ability_controller.cancel_ability_preview()


func _process(delta: float) -> void:
	if not is_instance_valid(player) or player.is_dead:
		return
	var distance: float = previous_position.distance_to(player.global_position)
	previous_position = player.global_position
	if get_tree().paused:
		return
	if Input.get_vector(&"leftmove", &"rightmove", &"upmove", &"downmove").length_squared() > 0.01:
		progress.record_movement(distance, player.global_position.distance_to(movement_goal) <= marker.radius)
	if ability_controller.previewing_ability == aim_ability:
		progress.tick_preview(delta)
	if progress.stage != BasicTutorialProgress.Stage.MOVE and is_instance_valid(dummy):
		marker.global_position = dummy.global_position
	_update_progress_text()


func _on_preview_started(ability: Ability, caster: Entity) -> void:
	if caster == player and ability == aim_ability:
		progress.begin_preview()


func _on_preview_released(ability: Ability, caster: Entity) -> void:
	if caster == player and ability == aim_ability:
		progress.release_preview()


func _on_preview_cancelled(ability: Ability, caster: Entity) -> void:
	if caster == player and ability == aim_ability:
		progress.cancel_preview()


func _on_cast_prepared(context: AbilityContext) -> void:
	if context.caster == player and context.ability == aim_ability and context.cast_record != null:
		# 只认可这次确实由“按住后松开”产生的施法，不能用之前飞出的弹体代替。
		progress.authorize_cast(context.cast_record.get_instance_id())


func _on_damage_dealt(data: DamageData) -> void:
	if data == null or data.source != player or data.target != dummy or data.final_damage <= 0.0 or data.is_miss:
		return
	if data.source_ability_id == basic_ability.id:
		progress.record_basic_hit()
	elif data.source_ability_id == aim_ability.id and data.cast_record != null:
		progress.record_aim_hit(data.cast_record.get_instance_id())
	_update_progress_text()


func _on_bindings_changed(_action: StringName) -> void:
	_show_stage(progress.stage)


func _show_stage(stage: int) -> void:
	match stage:
		BasicTutorialProgress.Stage.MOVE:
			panel.show_step(character_name, stage, "移动到标记处", "控制当前角色走进地上的蓝色圆圈。移动和攻击可以同时进行。", TutorialInputLabels.movement_text())
			marker.global_position = movement_goal
			marker.set_caption("移动到这里")
		BasicTutorialProgress.Stage.BASIC_ATTACK:
			panel.show_step(character_name, stage, "基础攻击命中假人", lesson.basic_hint, "基础攻击：" + _ability_keys(basic_ability))
			marker.set_caption("基础攻击目标")
		BasicTutorialProgress.Stage.AIM_HOLD:
			panel.show_step(character_name, stage, "按住技能键，观察范围", "本次临时提供【%s】。\n%s" % [aim_ability.ability_name, lesson.aim_hint], "按住：" + _ability_keys(aim_ability))
			marker.set_caption("让指示范围覆盖假人")
		BasicTutorialProgress.Stage.AIM_RELEASE:
			panel.show_step(character_name, stage, "松开技能键，命中假人", "保持鼠标指向假人，然后松开刚才按住的技能键。没有命中可以等冷却结束后再试。", "松开：" + _ability_keys(aim_ability))
		BasicTutorialProgress.Stage.COMPLETE:
			marker.hide()
			panel.show_step(character_name, stage, "已掌握基础操作", "你已经完成移动、基础攻击和瞄准释放。可以继续练习，也可以返回大厅开始冒险。", "教学技能不会带出训练。")


func _ability_keys(ability: Ability) -> String:
	var index: int = ability_controller.abilities.find(ability)
	return TutorialInputLabels.action_text(StringName("ability_%d" % (index + 1)))


func _update_progress_text() -> void:
	match progress.stage:
		BasicTutorialProgress.Stage.MOVE:
			panel.set_progress("距离标记：%d" % int(player.global_position.distance_to(movement_goal)))
		BasicTutorialProgress.Stage.BASIC_ATTACK:
			panel.set_progress("有效命中：%d / %d" % [progress.basic_hits, progress.required_basic_hits])
		BasicTutorialProgress.Stage.AIM_HOLD:
			panel.set_progress("观察指示范围：%d%%" % int(clampf(progress.hold_seconds / progress.required_hold_seconds, 0.0, 1.0) * 100.0))
		BasicTutorialProgress.Stage.AIM_RELEASE:
			panel.set_progress("教学持续补充能量；未命中不会扣除教学进度。")
