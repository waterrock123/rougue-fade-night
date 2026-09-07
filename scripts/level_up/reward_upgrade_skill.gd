class_name RewardUpgradeSkill
extends LevelUpReward

@export var target_skill_id: StringName
@export var target_skill_data: SkillData
@export var source_skill_id: StringName
@export var source_skill_data: SkillData
@export var search_passive_first: bool = false


func apply(context: LevelUpRewardContext):
	if context == null or context.player_build == null or context.skill_controller == null:
		return

	var player_build := context.player_build
	var target_entry: SkillEntry = null

	var resolved_skill_id := _get_source_skill_id()
	if resolved_skill_id == &"":
		return

	if search_passive_first:
		target_entry = player_build.find_passive_skill_entry(resolved_skill_id)
		if target_entry == null:
			target_entry = player_build.find_active_skill_entry(resolved_skill_id)
	else:
		target_entry = player_build.find_active_skill_entry(resolved_skill_id)
		if target_entry == null:
			target_entry = player_build.find_passive_skill_entry(resolved_skill_id)

	if target_entry == null:
		return

	context.skill_controller.upgrade_skill_entry(target_entry, target_skill_data)


func is_available(context: LevelUpRewardContext) -> bool:
	if context == null or context.player_build == null or target_skill_data == null:
		return false

	var source_id := _get_source_skill_id()
	var entry := context.player_build.find_passive_skill_entry(source_id)
	if entry == null:
		entry = context.player_build.find_active_skill_entry(source_id)
	return entry != null and entry.can_evolve_to(target_skill_data)


func get_display_title() -> String:
	if not title.is_empty():
		return title
	if target_skill_data != null:
		return "升级技能：%s" % target_skill_data.skill_name
	return "升级技能"


func get_display_desc() -> String:
	if not desc.is_empty():
		return desc
	if target_skill_data != null:
		return target_skill_data.desc
	return "提升一个已拥有技能的等级。"


func get_display_icon() -> Texture2D:
	if icon != null:
		return icon
	if target_skill_data != null:
		return target_skill_data.icon
	return null


func _get_target_skill_id() -> StringName:
	if target_skill_id != &"":
		return target_skill_id
	if target_skill_data != null:
		return target_skill_data.id
	return &""


func _get_source_skill_id() -> StringName:
	if source_skill_id != &"":
		return source_skill_id
	return target_skill_id
