## 消耗品效果：恢复本次开局的基础属性快照，清除本局永久属性成长。
## 装备/被动常驻修饰保留；可选择清除临时属性增减。此效果不是治疗，不补充生命或能量。
class_name UseResetBaseStatsEffect
extends RelicEffect

@export var clear_temporary_stats: bool = true


func on_use(context: RelicContext, _effect_key: Variant) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var controller: StatsController = _get_stats_controller(context)
	if controller == null or controller.player_build == null:
		return
	var build: PlayerBuild = controller.player_build
	if build.initial_stats == null:
		push_warning("缺少开局属性快照，跳过属性重置。")
		return
	var health: float = controller.current_health
	var energy: float = controller.current_energy
	if clear_temporary_stats:
		_clear_temporary_attributes(context.owner, controller)
	build.player_stats = build.initial_stats.duplicate(true) as StatsData
	build.permanent_stat_bonuses.clear()
	controller.bind_player_build(build)
	controller.restore_resource_snapshot(health, energy)


func _clear_temporary_attributes(effect_owner: Node, controller: StatsController) -> void:
	controller.clear_temporary_attribute_effects()
	var statuses: StatusController = effect_owner.get_node_or_null("StatusController") as StatusController
	if statuses != null:
		statuses.clear_temporary_attribute_statuses()
	var handler: ModifierHandler = effect_owner.get_node_or_null("ModifierHandler") as ModifierHandler
	if handler != null:
		handler.clear_runtime_modifiers()


func _get_stats_controller(context: RelicContext) -> StatsController:
	if is_instance_valid(context.relic_controller):
		return context.relic_controller.get_stats_controller()
	return context.owner.get_node_or_null("StatsController") as StatsController
