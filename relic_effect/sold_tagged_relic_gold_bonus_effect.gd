## 遗物效果：出售带指定 tag 的遗物后额外获得金币。
## 可选限制当前商店老板名称，适合“在某个商人处出售诅咒物品”。
class_name SoldTaggedRelicGoldBonusEffect
extends RelicEffect

@export var target_tag_name: String = ""
@export var bonus_gold: int = 1
@export var required_shopkeeper_name: String = ""

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var run_stats := _resolve_run_stats(relic_context.owner if relic_context != null else null)
	if run_stats == null:
		return

	active_contexts[str(effect_key)] = run_stats
	if not EventBus.relic_sold.is_connected(_on_relic_sold):
		EventBus.relic_sold.connect(_on_relic_sold)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	if active_contexts.is_empty() and EventBus.relic_sold.is_connected(_on_relic_sold):
		EventBus.relic_sold.disconnect(_on_relic_sold)


func _on_relic_sold(relic: Relic) -> void:
	if relic == null or not _relic_has_target_tag(relic):
		return

	for value in active_contexts.values():
		var run_stats := value as RunStats
		if run_stats == null:
			continue
		if not _matches_shopkeeper(run_stats):
			continue

		run_stats.set_gold(run_stats.gold + max(bonus_gold, 0))


func _relic_has_target_tag(relic: Relic) -> bool:
	if target_tag_name.is_empty():
		return true

	for tag in relic.tags:
		if tag != null and tag.tag_name == target_tag_name:
			return true
	return false


func _matches_shopkeeper(run_stats: RunStats) -> bool:
	if required_shopkeeper_name.is_empty():
		return true
	if run_stats.shop == null or run_stats.shop.shopkeeper == null:
		return false
	return run_stats.shop.shopkeeper.name == required_shopkeeper_name


func _resolve_run_stats(owner: Node) -> RunStats:
	var node := owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()

	return null
