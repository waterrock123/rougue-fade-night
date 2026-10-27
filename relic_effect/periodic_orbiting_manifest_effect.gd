## 穿戴期间每隔一段战斗时间生成一个限时环绕Manifest。仅负责注册，计时/生成/清理由独立节点管理。
## 同一件装备重建效果时不重置计时，真正卸下后清理。可替换场景复用于环绕法球等装备。
class_name PeriodicOrbitingManifestEffect
extends RelicEffect

@export var manifest_scene: PackedScene
@export_range(0.1, 120.0, 0.1) var interval: float = 30.0
@export var manifest_lifetime: float = 5.0
@export var damage: float = 150.0


func on_activate(context: RelicContext, _effect_key: Variant) -> void:
	if context == null or not is_instance_valid(context.owner) or not context.owner is Entity or manifest_scene == null:
		return
	var actor: Entity = context.owner as Entity
	var runner: PeriodicOrbitingManifestRunner = actor.get_node_or_null(_runner_name(context)) as PeriodicOrbitingManifestRunner
	if runner == null:
		runner = PeriodicOrbitingManifestRunner.new()
		runner.name = _runner_name(context)
		actor.add_child(runner)
	runner.configure(self, actor)


func on_deactivate(context: RelicContext, _effect_key: Variant) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var runner: PeriodicOrbitingManifestRunner = context.owner.get_node_or_null(_runner_name(context)) as PeriodicOrbitingManifestRunner
	if runner != null:
		runner.request_cleanup()


func _runner_name(context: RelicContext) -> String:
	# 不使用装备格下标；同件遗物换格或普通刷新仍能复用当前计时节点。
	return "PeriodicOrbit_%d_%d" % [context.own_relic.get_instance_id(), get_instance_id()]
