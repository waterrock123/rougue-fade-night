class_name PassiveAddStatusEffect
extends PassiveSkillEffect

# 被动技能提供一个常驻状态。
# 例如“护甲+1”会通过 armor 状态接入同 id 多来源叠层系统，而不是直接写死派生属性。
@export var status_data: StatusData
@export var stacks: int = 1


func apply(context: SkillContext) -> void:
	var status_controller := _get_status_controller(context)
	if status_controller == null or status_data == null:
		return

	status_controller.add_status(status_data, _get_source_node(context), context.effect_key, stacks)


func remove(context: SkillContext) -> void:
	var status_controller := _get_status_controller(context)
	if status_controller == null or status_data == null:
		return

	status_controller.remove_status_source(status_data.id, context.effect_key)


func _get_status_controller(context: SkillContext) -> StatusController:
	if context == null:
		return null
	if context.status_controller != null:
		return context.status_controller
	if context.caster != null and context.caster.has_method("get_status_controller"):
		return context.caster.get_status_controller()
	if context.skill_controller != null:
		return context.skill_controller.get_node_or_null("../StatusController") as StatusController
	return null


func _get_source_node(context: SkillContext) -> Node:
	if context != null and context.caster != null:
		return context.caster
	return context.skill_controller if context != null else null
