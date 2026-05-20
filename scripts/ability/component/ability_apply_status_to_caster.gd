## 给施法者自己添加状态。适合暴怒、护盾、短时间强化这类“对自己生效”的主动技能。
class_name AbilityApplyStatusToCaster
extends AbilityComponent

@export var status_data: StatusData
@export var stacks: int = 1


# 释放技能时，把配置好的 StatusData 加到施法者身上。
func _activate(context: AbilityContext):
	if context == null or context.caster == null or status_data == null:
		return

	var status_controller := context.caster.get_status_controller()
	if status_controller == null:
		status_controller = context.caster.get_node_or_null("StatusController") as StatusController
	if status_controller == null:
		return

	var source_key := context.ability.id if context.ability != null else status_data.id
	status_controller.add_status(status_data, context.caster, source_key, stacks)
