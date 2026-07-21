## 遗物效果：当指定状态被施加到目标身上时，按概率从当前商人货池获得带指定 tag 的装备。
## 适合“敌人进入束缚/燃烧/冰冻后，有概率获得某类奖励”的触发型装备。
class_name StatusAppliedGrantTaggedShopRelicEffect
extends RelicEffect


@export var status_id: StringName
@export_range(0.0, 1.0, 0.01) var chance: float = 0.1
@export var required_tags: Array[RelicTag] = []
@export var fixed_level: int = -1
@export var level_offset: int = 0
@export var allow_lower_level: bool = true
@export var require_status_source_owner: bool = true
@export var granted_relic_count: int = 1

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or status_id == &"":
		return

	var key: String = str(effect_key)
	active_contexts[key] = relic_context
	if not EventBus.status_applied.is_connected(_on_status_applied):
		EventBus.status_applied.connect(_on_status_applied)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	if active_contexts.is_empty() and EventBus.status_applied.is_connected(_on_status_applied):
		EventBus.status_applied.disconnect(_on_status_applied)


func _on_status_applied(target: Node, applied_status_id: StringName, source: Node, _stacks: int) -> void:
	if applied_status_id != status_id:
		return

	var contexts: Dictionary = active_contexts.duplicate()
	for relic_context_value in contexts.values():
		var relic_context: RelicContext = relic_context_value as RelicContext
		_try_grant_for_context(relic_context, target, source)


func _try_grant_for_context(relic_context: RelicContext, target: Node, source: Node) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	var target_entity: Entity = target as Entity
	if owner == null or target_entity == null:
		return
	if require_status_source_owner and source != owner:
		return
	if not _is_valid_opponent(owner, target_entity):
		return
	if randf() > chance:
		return

	var run_stats: RunStats = _resolve_run_stats(owner)
	if run_stats == null or run_stats.player_build == null:
		return

	var candidates: Array[Relic] = _collect_candidates(run_stats)
	if candidates.is_empty():
		return

	for _index: int in range(max(granted_relic_count, 1)):
		var template: Relic = RunRng.pick(candidates) as Relic
		if template == null:
			continue
		run_stats.player_build.add_relic(template.duplicate(true) as Relic)


func _collect_candidates(run_stats: RunStats) -> Array[Relic]:
	var result: Array[Relic] = []
	var shop_keeper: ShopKeeper = _get_shop_keeper(run_stats)
	if shop_keeper == null:
		return result

	var target_level: int = _get_target_level(run_stats)
	for relic: Relic in shop_keeper.get_available_relics(target_level):
		if relic == null:
			continue
		if not _matches_level(relic.level, target_level):
			continue
		if not _matches_required_tags(relic):
			continue
		result.append(relic)

	return result


func _matches_level(relic_level: int, target_level: int) -> bool:
	if target_level < 0:
		return true
	if allow_lower_level:
		return relic_level <= target_level
	return relic_level == target_level


func _matches_required_tags(relic: Relic) -> bool:
	if required_tags.is_empty():
		return true

	for required_tag: RelicTag in required_tags:
		if required_tag != null and _relic_has_tag(relic, required_tag):
			return true
	return false


func _is_valid_opponent(owner: Entity, target: Entity) -> bool:
	if owner.is_player_side():
		return target.is_enemy_side()
	if owner.is_enemy_side():
		return target.is_player_side()
	return target != owner


func _get_shop_keeper(run_stats: RunStats) -> ShopKeeper:
	if run_stats != null and run_stats.shop != null and run_stats.shop.shopkeeper != null:
		return run_stats.shop.shopkeeper
	return null


func _get_target_level(run_stats: RunStats) -> int:
	if fixed_level >= 0:
		return fixed_level
	var shop_level: int = 0
	if run_stats != null and run_stats.shop != null:
		shop_level = run_stats.shop.level
	return max(shop_level + level_offset, 0)


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false

	for relic_tag: RelicTag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == target_tag or relic_tag.tag_name == target_tag.tag_name:
			return true

	return false


func _resolve_run_stats(owner: Node) -> RunStats:
	var node: Node = owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()
	return null


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
