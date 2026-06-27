class_name ShopKeeper
extends Resource

const DEFAULT_RELIC_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")

@export var name: String
@export var texture: Texture2D
@export var havetag:Array[RelicTag]
@export_multiline() var shop_desc:String

@export_group("Stock")
@export var relic_pool: RelicPool = DEFAULT_RELIC_POOL
# 旧版商人货物列表：仅当 relic_pool 为空时作为兜底使用，避免旧资源迁移时失效。
@export var relics: Array[Relic]
@export var extra_relics: Array[Relic] = []
@export var banned_relics: Array[Relic] = []
@export var preferred_tag_weight_bonus: float = 2.0

@export_group("Dialogue")
@export var enter_rest_period_dialogues: ShopKeeperDialoguePool
@export var exit_rest_period_dialogues: ShopKeeperDialoguePool
@export var buy_relic_dialogues: ShopKeeperDialoguePool
@export var sell_relic_dialogues: ShopKeeperDialoguePool


func get_available_relics(shop_level: int) -> Array[Relic]:
	var candidates: Array[Relic] = []
	if relic_pool != null:
		candidates = relic_pool.get_relics_up_to_level(shop_level)
	else:
		candidates = _filter_relics_up_to_level(relics, shop_level)

	for relic: Relic in extra_relics:
		if relic != null and relic.level <= shop_level:
			candidates.append(relic)

	return _remove_banned_and_duplicate_relics(candidates)


func get_available_relics_by_level(relic_level: int) -> Array[Relic]:
	var candidates: Array[Relic] = []
	if relic_pool != null:
		candidates = relic_pool.get_relics_by_level(relic_level)
	else:
		candidates = _filter_relics_by_level(relics, relic_level)

	for relic: Relic in extra_relics:
		if relic != null and relic.level == relic_level:
			candidates.append(relic)

	return _remove_banned_and_duplicate_relics(candidates)


func get_relic_base_weight(relic: Relic, fallback_weight: float = 1.0) -> float:
	if relic_pool == null:
		return fallback_weight
	return relic_pool.get_weight_for_relic(relic, fallback_weight)


func get_dialogue(pool: ShopKeeperDialoguePool) -> String:
	if pool == null:
		return ""
	return pool.get_random_line()


func _filter_relics_up_to_level(source_relics: Array[Relic], shop_level: int) -> Array[Relic]:
	var result: Array[Relic] = []
	for relic: Relic in source_relics:
		if relic != null and relic.level <= shop_level:
			result.append(relic)
	return result


func _filter_relics_by_level(source_relics: Array[Relic], relic_level: int) -> Array[Relic]:
	var result: Array[Relic] = []
	for relic: Relic in source_relics:
		if relic != null and relic.level == relic_level:
			result.append(relic)
	return result


func _remove_banned_and_duplicate_relics(source_relics: Array[Relic]) -> Array[Relic]:
	var result: Array[Relic] = []
	var seen: Dictionary = {}

	for relic: Relic in source_relics:
		if relic == null or _is_relic_banned(relic):
			continue

		var key: String = _get_relic_key(relic)
		if key.is_empty() or seen.has(key):
			continue

		seen[key] = true
		result.append(relic)

	return result


func _is_relic_banned(relic: Relic) -> bool:
	for banned_relic: Relic in banned_relics:
		if _is_same_relic(relic, banned_relic):
			return true
	return false


func _is_same_relic(a: Relic, b: Relic) -> bool:
	if a == null or b == null:
		return false
	if a == b:
		return true
	return _get_relic_key(a) == _get_relic_key(b)


func _get_relic_key(relic: Relic) -> String:
	if relic == null:
		return ""
	if not relic.id.is_empty():
		return "id:%s" % relic.id
	if not relic.resource_path.is_empty():
		return "path:%s" % relic.resource_path
	return "instance:%s" % str(relic.get_instance_id())

#

#商人名称
#商人货物
#商人立绘
