## 控制类状态效果。
## 状态存在期间锁住目标行动，可选暂停目标动画；同时可以根据指定属性缩短持续时间。
class_name StatusControlEffect
extends StatusEffect

enum DurationReductionMode {
	NONE,
	FLAT_SECONDS,
	PERCENT,
}

## 是否让目标无法移动、攻击、释放技能等。
@export var lock_actions: bool = true
## 是否让目标当前动画停止在原帧，适合冻结、石化等控制。
@export var pause_animation: bool = true

@export_group("Duration Reduction")
## 用哪个属性减免持续时间。冻结默认用 constitution。
@export var reduction_stat: StringName = &"constitution"
## 减免方式：固定秒数或百分比。
@export var reduction_mode: DurationReductionMode = DurationReductionMode.PERCENT
## 每点属性减免量。PERCENT 时 0.03 表示每点减少 3% 持续时间。
@export var reduction_per_point: float = 0.03
## 最大减免比例，避免高体质直接免疫。
@export_range(0.0, 0.95, 0.01) var max_percent_reduction: float = 0.75
## 最短持续时间，避免被减到 0 导致状态表现不出来。
@export var min_duration: float = 0.1


func on_apply(instance: StatusInstance) -> void:
	if instance == null:
		return

	_apply_duration_reduction_once(instance)

	var target := instance.target
	if lock_actions and target != null and target.has_method("add_action_lock"):
		target.add_action_lock(_get_lock_key(instance), pause_animation)
		_cancel_current_preview(target)


func on_remove(instance: StatusInstance) -> void:
	if instance == null:
		return

	var target := instance.target
	if target != null and target.has_method("remove_action_lock"):
		target.remove_action_lock(_get_lock_key(instance))


func _apply_duration_reduction_once(instance: StatusInstance) -> void:
	if reduction_mode == DurationReductionMode.NONE:
		return
	if not instance.is_temporary():
		return

	var effect_key := _get_duration_effect_key(instance)
	if int(instance.duration_adjusted_effect_revisions.get(effect_key, -1)) == instance.duration_revision:
		return

	instance.duration_adjusted_effect_revisions[effect_key] = instance.duration_revision
	var stat_value := _get_reduction_stat_value(instance)
	if stat_value <= 0.0:
		return

	var original_duration := instance.remaining_duration
	var reduced_duration := original_duration
	match reduction_mode:
		DurationReductionMode.FLAT_SECONDS:
			reduced_duration = original_duration - stat_value * reduction_per_point
		DurationReductionMode.PERCENT:
			var percent = clamp(stat_value * reduction_per_point, 0.0, max_percent_reduction)
			reduced_duration = original_duration * (1.0 - percent)

	instance.remaining_duration = max(reduced_duration, min_duration)


func _get_reduction_stat_value(instance: StatusInstance) -> float:
	if instance.controller == null:
		return 0.0

	var stats_controller := instance.controller.get_stats_controller()
	if stats_controller == null:
		return 0.0

	return stats_controller.get_stat(reduction_stat, 0.0)


func _get_lock_key(instance: StatusInstance) -> String:
	return "%s_control" % instance.get_effect_key()


func _get_duration_effect_key(instance: StatusInstance) -> String:
	return "%s_duration_reduction" % instance.get_effect_key()


func _cancel_current_preview(target: Node) -> void:
	var ability_controller := target.get_node_or_null("AbilityController")
	if ability_controller != null and ability_controller.has_method("cancel_ability_preview"):
		ability_controller.cancel_ability_preview()
