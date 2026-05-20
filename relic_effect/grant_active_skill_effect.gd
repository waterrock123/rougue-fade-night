## 遗物效果：装备期间临时获得一个主动技能。
## 用于“装备后可使用额外技能”的装备；卸下时只移除本装备提供的临时技能，不会删除玩家永久获得的同名技能。
class_name GrantActiveSkillEffect
extends RelicEffect

@export var skill_data: ActiveSkillData


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or skill_data == null:
		return

	var player_build := _get_player_build(relic_context)
	if player_build == null:
		return

	player_build.grant_temporary_active_skill(skill_data, StringName(effect_key))
	_refresh_skill_controller(relic_context)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null:
		return

	var player_build := _get_player_build(relic_context)
	if player_build == null:
		return

	player_build.remove_temporary_active_skill(StringName(effect_key))
	_refresh_skill_controller(relic_context)


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build

	if relic_context.owner is PlayerBuildProxy:
		return (relic_context.owner as PlayerBuildProxy).player_build

	if relic_context.owner != null and "player_build" in relic_context.owner:
		return relic_context.owner.player_build

	return null


func _refresh_skill_controller(relic_context: RelicContext) -> void:
	var skill_controller := _get_skill_controller(relic_context)
	if skill_controller != null:
		skill_controller.refresh_active_skills()


func _get_skill_controller(relic_context: RelicContext) -> SkillController:
	if relic_context.owner == null:
		return null
	if relic_context.owner.has_method("get_skill_controller"):
		return relic_context.owner.get_skill_controller()
	return relic_context.owner.get_node_or_null("SkillController") as SkillController
