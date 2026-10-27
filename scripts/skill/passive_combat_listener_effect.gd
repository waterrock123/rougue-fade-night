## 事件型被动的生命周期管理：每个角色拥有独立监听器，共享资源不保存战斗计数。
class_name PassiveCombatListenerEffect
extends PassiveSkillEffect

var listeners: Dictionary = {}


func apply(context: SkillContext) -> void:
	if context == null or not is_instance_valid(context.caster) or not is_instance_valid(context.ability_controller):
		return
	remove(context)
	var listener: SkillCombatListener = _create_listener()
	if listener == null:
		return
	listeners[_key(context)] = listener
	context.caster.add_child(listener)
	listener.bind(self, context)


func remove(context: SkillContext) -> void:
	if context == null:
		return
	var key: String = _key(context)
	var listener: Variant = listeners.get(key)
	if is_instance_valid(listener):
		listener.stop()
		listener.queue_free()
	listeners.erase(key)


func _key(context: SkillContext) -> String:
	var actor_id: int = context.caster.get_instance_id() if is_instance_valid(context.caster) else 0
	return "%d:%s" % [actor_id, str(context.effect_key)]


func _create_listener() -> SkillCombatListener:
	return null
