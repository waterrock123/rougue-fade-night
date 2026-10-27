## 获得/升级类遗物效果的上下文与去重工具。不持有静态玩家引用，也不修改共享装备模板。
class_name RelicGainRuntimeHelper
extends RefCounted


static func get_run(context: RelicContext) -> Run:
	if context == null or not is_instance_valid(context.owner):
		return null
	var node: Node = context.owner
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()
	return null


static func claim_once(context: RelicContext, key: StringName) -> bool:
	if context == null or context.own_relic == null or key == &"":
		return false
	var counters: Dictionary = context.own_relic.effect_counters
	if int(counters.get(str(key), 0)) > 0:
		return false
	counters[str(key)] = 1
	return true


## 延迟重算避开获得物品时的物理回调；同步两份控制器并防止多次重算叠乘生命比例。
static func refresh_attributes(context: RelicContext) -> void:
	var run: Run = get_run(context)
	if run == null or run.run_stats == null or run.run_stats.player_build == null:
		return
	var build: PlayerBuild = run.run_stats.player_build
	var controllers: Array[StatsController] = []
	if is_instance_valid(run.player_build_proxy):
		controllers.append(run.player_build_proxy.get_stats_controller())
	var active: StatsController = controllers[0] if not controllers.is_empty() else null
	if run.current_view.get_child_count() > 0:
		var battle: PlayScene = run.current_view.get_child(0) as PlayScene
		if battle != null and is_instance_valid(battle.player):
			active = battle.player.stats_controller
			if active != null and not controllers.has(active):
				controllers.append(active)
	if active == null:
		return
	var ratio: float = clampf(build.current_health / active.get_stat(&"max_health"), 0.0, 1.0) if active.get_stat(&"max_health") > 0.0 else 1.0
	var energy: float = build.current_energy
	for controller: StatsController in controllers:
		if is_instance_valid(controller):
			controller.bind_player_build(build)
	var health: float = active.get_stat(&"max_health") * ratio
	for controller: StatsController in controllers:
		if is_instance_valid(controller):
			controller.restore_resource_snapshot(health, energy)
	active.restore_resource_snapshot(health, energy)
	EventBus.attribute_update.emit()
	# 只沿用已有检查点规则，不强制保存战斗/事件尚未结算的结果。
	run.save_current_run()
