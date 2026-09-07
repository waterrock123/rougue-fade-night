class_name UseRemoveRandomNegativeStatusEffect
extends RelicEffect

## 使用消耗品时随机移除一个负面状态；若当前没有负面状态，则施加备用状态。
@export var fallback_status_data: StatusData
@export var fallback_stacks: int = 1
@export var fallback_duration_override: float = INF


func on_use(relic_context: RelicContext, effect_key) -> void:
	var status_controller: StatusController = _get_status_controller(relic_context)
	if status_controller == null:
		return

	var negative_status_ids: Array[StringName] = []
	for status_id_variant in status_controller.statuses.keys():
		var status_id: StringName = StringName(str(status_id_variant))
		var instance: StatusInstance = status_controller.get_status(status_id)
		if instance != null and instance.status_data != null and instance.status_data.is_negative():
			negative_status_ids.append(status_id)

	if not negative_status_ids.is_empty():
		var random_index: int = randi_range(0, negative_status_ids.size() - 1)
		status_controller.remove_status(negative_status_ids[random_index])
		return

	if fallback_status_data != null:
		status_controller.add_status(
			fallback_status_data,
			relic_context.owner,
			effect_key,
			fallback_stacks,
			fallback_duration_override
		)


func _get_status_controller(relic_context: RelicContext) -> StatusController:
	if relic_context == null or relic_context.owner == null:
		return null
	if relic_context.owner.has_method("get_status_controller"):
		return relic_context.owner.get_status_controller()
	return relic_context.owner.get_node_or_null("StatusController") as StatusController

