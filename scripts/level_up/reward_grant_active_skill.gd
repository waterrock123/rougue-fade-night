class_name RewardGrantActiveSkill
extends LevelUpReward

@export var skill_data: ActiveSkillData


func apply(context: LevelUpRewardContext):
	if context == null or context.skill_controller == null:
		return

	context.skill_controller.grant_active_skill(skill_data)


func is_available(context: LevelUpRewardContext) -> bool:
	if skill_data == null:
		return false
	if context != null and not skill_data.is_available_for_character(context.picked_character):
		return false
	if context == null or context.player_build == null:
		return true

	return context.player_build.find_active_skill_entry(skill_data.id) == null


func get_display_title() -> String:
	if not title.is_empty():
		return title
	if skill_data != null:
		return "获得技能：%s" % skill_data.skill_name
	return ""


func get_display_desc() -> String:
	if not desc.is_empty():
		return desc
	if skill_data != null:
		return skill_data.desc
	return ""


func get_display_icon() -> Texture2D:
	if icon != null:
		return icon
	if skill_data != null:
		return skill_data.icon
	return null
