## 战斗胜利后，给背包中符合条件的装备添加指定 tag。
## 适合“给随机原料添加寒霜/火炎/加工品”等局外成长效果。
class_name BattleWinAddTagToInventoryRelicEffect
extends RelicEffect


## 只有带有这些 tag 之一的装备才会成为候选；为空时不限制。
@export var candidate_tags: Array[RelicTag] = []
## 要添加到候选装备上的 tag。
@export var tag_to_add: RelicTag
## 每次战斗胜利处理几件装备。
@export var relic_count: int = 1

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if tag_to_add == null:
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
	for context_value in contexts.values():
		_add_tag_to_inventory_relics(context_value as RelicContext)


func _add_tag_to_inventory_relics(relic_context: RelicContext) -> void:
	var player_build := _get_player_build(relic_context)
	if player_build == null or player_build.player_inventory == null:
		return

	var candidates := _collect_candidates(player_build.player_inventory)
	RunRng.shuffle_array(candidates)
	var count = min(max(relic_count, 1), candidates.size())
	for index in range(count):
		var relic := candidates[index] as Relic
		if relic == null or _relic_has_tag(relic, tag_to_add):
			continue
		relic.tags.append(tag_to_add)

	if count > 0:
		EventBus.inventory_update.emit()


func _collect_candidates(inventory: Inventory) -> Array[Relic]:
	var result: Array[Relic] = []
	for slot in inventory.slots:
		if slot == null or slot.item == null:
			continue
		if _relic_has_tag(slot.item, tag_to_add):
			continue
		if not _matches_candidate_tags(slot.item):
			continue
		result.append(slot.item)
	return result


func _matches_candidate_tags(relic: Relic) -> bool:
	if candidate_tags.is_empty():
		return true
	for candidate_tag in candidate_tags:
		if _relic_has_tag(relic, candidate_tag):
			return true
	return false


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
