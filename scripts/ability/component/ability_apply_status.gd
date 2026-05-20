## 给当前 AbilityContext.targets 中的目标添加 StatusData 状态。适合做中毒、减速、眩晕、护甲等 buff/debuff。
class_name AbilityApplyStatus
extends AbilityComponent

@export var status_data: StatusData
@export var stacks: int = 1


# 给当前 AbilityContext 里的目标添加状态。
# 通常放在 AbilityGetTarget / 命中检测组件之后使用。
func _activate(context: AbilityContext):
	if status_data == null:
		return

	for target_data in context.targets:
		var target := _resolve_target(target_data)
		if target == null:
			continue

		var status_controller = target.get_status_controller() if target.has_method("get_status_controller") else null
		if status_controller == null:
			status_controller = target.get_node_or_null("StatusController") as StatusController
		if status_controller == null:
			continue

		status_controller.add_status(status_data, context.caster, context.ability.id, stacks)


func _resolve_target(target_data) -> Node:
	if target_data is Node:
		return target_data as Node
	return null
