## 动作绑定状态：施加时记录动作版本，被硬直、死亡或控制中断动作后撤销状态。
class_name StatusRemoveOnActionCancelEffect
extends StatusEffect

var versions: Dictionary = {}


func on_apply(instance: StatusInstance) -> void:
	if is_instance_valid(instance.target) and instance.target.has_method("get_action_version"):
		versions[instance.get_instance_id()] = instance.target.call("get_action_version")


func on_tick(instance: StatusInstance, _delta: float) -> void:
	if not is_instance_valid(instance.target) or not is_instance_valid(instance.controller):
		return
	var key: int = instance.get_instance_id()
	if versions.has(key) and instance.target.call("get_action_version") != versions[key]:
		instance.controller.remove_status(instance.get_status_id())


func on_remove(instance: StatusInstance) -> void:
	versions.erase(instance.get_instance_id())
