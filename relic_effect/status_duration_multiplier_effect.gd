## 遗物效果：当拥有者身上出现指定状态时，按倍率调整该状态剩余时间。
## 适合“保暖裤：冻结持续时间减少”“抗毒护符：中毒时间减少”等装备。
class_name StatusDurationMultiplierEffect
extends RelicEffect

@export var target_status_id: StringName = &"freeze"
## 0.5 表示剩余时间变为一半，也就是持续时间 -50%。
@export_range(0.0, 2.0, 0.01) var duration_multiplier: float = 0.5
@export var min_duration: float = 0.05

var _applied_revisions: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var status_controller := _get_status_controller(relic_context)
	if status_controller == null:
		return

	var callback := Callable(self, "_on_status_changed").bind(status_controller, str(effect_key))
	if not status_controller.status_changed.is_connected(callback):
		status_controller.status_changed.connect(callback)

	_apply_to_current_status(status_controller, str(effect_key))


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var status_controller := _get_status_controller(relic_context)
	if status_controller == null:
		return

	var callback := Callable(self, "_on_status_changed").bind(status_controller, str(effect_key))
	if status_controller.status_changed.is_connected(callback):
		status_controller.status_changed.disconnect(callback)
	_applied_revisions.erase(str(effect_key))


func _on_status_changed(status_controller: StatusController, effect_key: String) -> void:
	_apply_to_current_status(status_controller, effect_key)


func _apply_to_current_status(status_controller: StatusController, effect_key: String) -> void:
	if status_controller == null:
		return

	var instance := status_controller.get_status(target_status_id)
	if instance == null:
		_applied_revisions.erase(effect_key)
		return
	if not instance.is_temporary():
		return

	var revision_key := "%s_%s" % [effect_key, target_status_id]
	var last_revision := int(_applied_revisions.get(revision_key, -1))
	if last_revision == instance.duration_revision:
		return

	_applied_revisions[revision_key] = instance.duration_revision
	instance.remaining_duration = max(instance.remaining_duration * duration_multiplier, min_duration)


func _get_status_controller(relic_context: RelicContext) -> StatusController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_status_controller()
	if relic_context.owner != null and relic_context.owner.has_method("get_status_controller"):
		return relic_context.owner.get_status_controller()
	if relic_context.owner != null:
		return relic_context.owner.get_node_or_null("StatusController") as StatusController
	return null
