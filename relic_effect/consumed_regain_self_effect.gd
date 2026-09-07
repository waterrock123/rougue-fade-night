## 遗物被“消耗”后重新获得一份自身的通用效果。
## 临时遗物会继续以临时遗物形式放回装备栏或背包，避免借此把临时装备转为永久装备。
class_name ConsumedRegainSelfEffect
extends RelicEffect


func on_consumed(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or relic_context.own_relic == null:
		return

	var player_build: PlayerBuild = _resolve_player_build(relic_context)
	if player_build == null:
		return

	var regained_relic: Relic = relic_context.own_relic.duplicate(true) as Relic
	if regained_relic == null:
		return

	if regained_relic.is_temporary:
		player_build.add_temporary_relic_to_equipment_or_inventory(regained_relic)
	else:
		player_build.add_relic(regained_relic)


func _resolve_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is PlayerBuildProxy:
		return (relic_context.owner as PlayerBuildProxy).player_build
	if relic_context.owner is Entity:
		var stats_controller: StatsController = (relic_context.owner as Entity).stats_controller
		if stats_controller != null and stats_controller.player_build != null:
			return stats_controller.player_build

	var current_node: Node = relic_context.owner
	while current_node != null:
		var run_stats_value: Variant = current_node.get("run_stats")
		if run_stats_value is RunStats:
			return (run_stats_value as RunStats).player_build
		current_node = current_node.get_parent()
	return null
