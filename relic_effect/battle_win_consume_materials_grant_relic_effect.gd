## 战斗胜利后消耗背包里的原料，并按原料等阶转化为其他装备。
## 用于“锻造锤”等用具，统一走 RelicConsumption 以触发原料自己的被消耗效果。
class_name BattleWinConsumeMaterialsGrantRelicEffect
extends RelicEffect

@export var material_tag: RelicTag
@export var consume_count: int = 1
@export var grant_same_level_relic: bool = true
@export var output_required_tags: Array[RelicTag] = []
## 勾选后，遗物处于升级态时跳过这条基础转换效果，避免基础和升级效果重复消耗。
@export var ignore_when_relic_levelup: bool = false

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if ignore_when_relic_levelup and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return
	active_contexts[str(effect_key)] = relic_context
	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	if active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)


func _on_battle_rewards_resolving() -> void:
	var contexts := active_contexts.duplicate()
	active_contexts.clear()
	if EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)

	for context_value in contexts.values():
		_transform_materials(context_value as RelicContext)


func _transform_materials(relic_context: RelicContext) -> void:
	var player_build := _get_player_build(relic_context)
	var run_stats := _resolve_run_stats(relic_context.owner if relic_context != null else null)
	if player_build == null or player_build.player_inventory == null or run_stats == null:
		return

	var material_slots := _collect_material_slots(player_build.player_inventory)
	RunRng.shuffle_array(material_slots)
	var count = min(max(consume_count, 1), material_slots.size())
	for index in range(count):
		var slot := material_slots[index] as Slot
		var consumed_relic := slot.item
		if consumed_relic == null:
			continue

		RelicConsumption.consume_slot(slot, relic_context.owner, relic_context.relic_controller, "battle_win_material_%s" % index, false)
		_grant_replacement(run_stats, consumed_relic)

	EventBus.inventory_update.emit()
	EventBus.equipment_update.emit()


func _grant_replacement(run_stats: RunStats, consumed_relic: Relic) -> void:
	var candidates := _get_candidates(run_stats, consumed_relic)
	if candidates.is_empty():
		return

	var relic = RunRng.pick(candidates) as Relic
	if relic != null:
		run_stats.player_build.add_relic(relic.duplicate(true) as Relic)


func _collect_material_slots(inventory: Inventory) -> Array[Slot]:
	var result: Array[Slot] = []
	for slot in inventory.slots:
		if slot == null or slot.item == null:
			continue
		if _relic_has_tag(slot.item, material_tag):
			result.append(slot)
	return result


func _get_candidates(run_stats: RunStats, consumed_relic: Relic) -> Array[Relic]:
	var result: Array[Relic] = []
	if run_stats.shop == null or run_stats.shop.shopkeeper == null:
		return result

	for relic in run_stats.shop.shopkeeper.relics:
		if relic == null or relic.id == consumed_relic.id:
			continue
		if grant_same_level_relic and relic.level != consumed_relic.level:
			continue
		if not output_required_tags.is_empty() and not _has_any_required_tag(relic):
			continue
		result.append(relic)
	return result


func _has_any_required_tag(relic: Relic) -> bool:
	for tag in output_required_tags:
		if _relic_has_tag(relic, tag):
			return true
	return output_required_tags.is_empty()


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false
	for relic_tag in relic.tags:
		if relic_tag != null and (relic_tag == target_tag or relic_tag.tag_name == target_tag.tag_name):
			return true
	return false


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is Entity:
		var stats_controller := (relic_context.owner as Entity).stats_controller
		return stats_controller.player_build if stats_controller != null else null
	return null


func _resolve_run_stats(owner: Node) -> RunStats:
	var node := owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()
	return null
