## 改变之后新增的正向临时属性增量的保存方式，不改变已有增益与共享StatusData持续时间。
class_name StatusTemporaryStatGainPolicyEffect
extends StatusEffect

@export var mode: TemporaryStatGainPolicy.Mode = TemporaryStatGainPolicy.Mode.BATTLE


func on_apply(instance: StatusInstance) -> void:
	if instance == null or not is_instance_valid(instance.controller):
		return
	var controller: StatsController = instance.controller.get_stats_controller()
	if is_instance_valid(controller):
		controller.temporary_gain_policy.set_policy(_get_key(instance), mode)


func on_remove(instance: StatusInstance) -> void:
	if instance == null or not is_instance_valid(instance.controller):
		return
	var controller: StatsController = instance.controller.get_stats_controller()
	if is_instance_valid(controller):
		controller.temporary_gain_policy.clear_policy(_get_key(instance))


func _get_key(instance: StatusInstance) -> String:
	return instance.get_effect_key(instance.status_data.effects.find(self))
