## 战斗期间挂载带逻辑的随身场景（护盾、轨道物等）。效果重建时保留原实例。
class_name AttachBattleVisualEffect
extends RelicEffect

@export var attached_scene: PackedScene


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not context.owner is Entity or attached_scene == null:
		return
	var actor: Entity = context.owner as Entity
	var node: Node = actor.get_node_or_null(_node_name(effect_key))
	if node == null:
		node = attached_scene.instantiate()
		node.name = _node_name(effect_key)
		actor.add_child(node)
	node.set_meta(&"relic_attached_enabled", true)


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var node: Node = context.owner.get_node_or_null(_node_name(effect_key))
	if node != null:
		node.set_meta(&"relic_attached_enabled", false)
		_finish_cleanup.call_deferred(weakref(node))


func _finish_cleanup(reference: WeakRef) -> void:
	var node: Variant = reference.get_ref()
	if is_instance_valid(node) and not bool(node.get_meta(&"relic_attached_enabled", false)):
		node.queue_free()


func _node_name(effect_key) -> String:
	return "Attached_%s_%s" % [get_instance_id(), String(effect_key).validate_node_name()]
