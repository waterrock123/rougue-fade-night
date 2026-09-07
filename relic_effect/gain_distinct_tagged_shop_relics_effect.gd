## 获得遗物时，从当前商人完整货池中按标签发放不同等阶的装备。
## 优先选择玩家当前未拥有的遗物；不足时才允许重复，避免奖励因池子较小而直接失效。
class_name GainDistinctTaggedShopRelicsEffect
extends RelicEffect

@export var required_tag: RelicTag
@export var grant_count: int = 3
@export var prefer_unowned_relics: bool = true


func on_gain(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or required_tag == null or grant_count <= 0:
		return

	var player_build: PlayerBuild = _get_player_build(relic_context)
	var run_stats: RunStats = _resolve_run_stats(relic_context.owner)
	if player_build == null or run_stats == null or run_stats.shop == null or run_stats.shop.shopkeeper == null:
		return

	var candidates: Array[Relic] = _collect_candidates(run_stats.shop.shopkeeper, relic_context.own_relic)
	var owned_relic_ids: Dictionary = _collect_owned_relic_ids(player_build)
	var used_levels: Dictionary = {}
	for _index: int in range(grant_count):
		var selected: Relic = _pick_candidate(candidates, owned_relic_ids, used_levels)
		if selected == null:
			break
		used_levels[selected.level] = true
		owned_relic_ids[selected.id] = true
		player_build.add_relic(selected.duplicate(true) as Relic)


func _collect_candidates(shopkeeper: ShopKeeper, own_relic: Relic) -> Array[Relic]:
	var result: Array[Relic] = []
	for relic: Relic in shopkeeper.get_available_relics(99):
		if relic == null or not _relic_has_tag(relic, required_tag):
			continue
		if own_relic != null and relic.id == own_relic.id:
			continue
		result.append(relic)
	return result


func _pick_candidate(candidates: Array[Relic], owned_relic_ids: Dictionary, used_levels: Dictionary) -> Relic:
	var preferred: Array[Relic] = []
	var fallback: Array[Relic] = []
	for relic: Relic in candidates:
		if relic == null or used_levels.has(relic.level):
			continue
		if prefer_unowned_relics and not owned_relic_ids.has(relic.id):
			preferred.append(relic)
		else:
			fallback.append(relic)

	if not preferred.is_empty():
		return RunRng.pick(preferred) as Relic
	if not fallback.is_empty():
		return RunRng.pick(fallback) as Relic
	return null


func _collect_owned_relic_ids(player_build: PlayerBuild) -> Dictionary:
	var result: Dictionary = {}
	if player_build.player_inventory != null:
		for slot: Slot in player_build.player_inventory.slots:
			_add_slot_relic_id(result, slot)
	if player_build.player_equipment != null:
		for slot: Slot in player_build.player_equipment.equip_slots:
			_add_slot_relic_id(result, slot)
	return result


func _add_slot_relic_id(result: Dictionary, slot: Slot) -> void:
	if slot != null and slot.item != null and not slot.item.id.is_empty():
		result[slot.item.id] = true


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	for tag: RelicTag in relic.tags:
		if tag != null and (tag == target_tag or tag.tag_name == target_tag.tag_name):
			return true
	return false


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context != null and relic_context.relic_controller != null:
		return relic_context.relic_controller.player_build
	var run_stats: RunStats = _resolve_run_stats(relic_context.owner if relic_context != null else null)
	return run_stats.player_build if run_stats != null else null


func _resolve_run_stats(owner: Node) -> RunStats:
	var node: Node = owner
	while node != null:
		if "run_stats" in node:
			return node.run_stats as RunStats
		node = node.get_parent()
	return null
