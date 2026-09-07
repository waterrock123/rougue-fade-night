class_name BlockNegativeStatusEffect
extends RelicEffect

## 装备生效期间抵消指定次数的负面状态施加。
@export var blocked_count: int = 1


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var status_controller: StatusController = _get_status_controller(relic_context)
	if status_controller == null or blocked_count <= 0:
		return
	status_controller.add_negative_status_blocker(effect_key, blocked_count)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var status_controller: StatusController = _get_status_controller(relic_context)
	if status_controller == null:
		return
	status_controller.remove_negative_status_blocker(effect_key)


func _get_status_controller(relic_context: RelicContext) -> StatusController:
	if relic_context == null or relic_context.owner == null:
		return null
	if relic_context.owner.has_method("get_status_controller"):
		return relic_context.owner.get_status_controller()
	return relic_context.owner.get_node_or_null("StatusController") as StatusController

