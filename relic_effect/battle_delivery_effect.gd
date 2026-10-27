## 战斗配送入口：每件装备建立一个独立任务，效果与奖励由资源配置。
## 非战斗代理不创建任务；重复刷新装备只重新绑定原任务，不重置配送进度。
class_name BattleDeliveryEffect
extends RelicEffect

@export var cargo_scene: PackedScene
@export var destination_scene: PackedScene
@export var cargo_options: Array[WeightedRelicEffectOption] = []
@export var gold_reward: int = 1
@export var upgraded_gold_reward: int = 3
@export var minimum_distance: float = 120.0


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not (context.owner is Entity):
		return
	var entity: Entity = context.owner as Entity
	var node_name: String = "Delivery_%s_%s" % [context.own_relic.get_instance_id(), str(effect_key).hash()]
	var runner: BattleDeliveryTask = entity.get_node_or_null(NodePath(node_name)) as BattleDeliveryTask
	if runner == null:
		runner = BattleDeliveryTask.new()
		runner.name = node_name
		runner.configuration = self
		runner.context = context
		entity.add_child(runner)
	runner.context = context
	runner.equipped = true


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var node_name: String = "Delivery_%s_%s" % [context.own_relic.get_instance_id(), str(effect_key).hash()]
	var runner: BattleDeliveryTask = context.owner.get_node_or_null(NodePath(node_name)) as BattleDeliveryTask
	if runner != null:
		runner.equipped = false
		# 全量装备刷新会立即再次激活；延迟确认后才认定为真正卸下。
		runner.cancel_if_unequipped.call_deferred()
