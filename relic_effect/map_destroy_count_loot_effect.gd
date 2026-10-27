## 装备者击破指定地图物件时累计单件进度，达到阈值后掉落预抽奖励的宝罐。
## 计数、普通奖励池、大奖池和掉落场景分别配置，可复用于寻宝装备。
class_name MapDestroyCountLootEffect
extends RelicEffect

const FALLBACK_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")
@export var pickup_scene: PackedScene
@export var counter_key: StringName = &"map_destroy_loot"
@export_range(1, 1000, 1) var required_count: int = 10
@export var excluded_feature_tags: Array[StringName] = [&"animal"]
@export_range(0.0, 1.0, 0.01) var jackpot_chance: float = 0.05
@export_range(0.0, 1.0, 0.01) var upgraded_jackpot_chance: float = 0.1
@export var normal_rewards: Array[MapLootReward] = []
@export var jackpot_rewards: Array[MapLootReward] = []
var bindings: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not (context.owner is Entity):
		return
	var scene: PlayScene = _find_scene(context.owner)
	if scene == null or scene.run_stats == null:
		return
	var key: String = "%s:%s" % [context.owner.get_instance_id(), effect_key]
	# 缓存候选模板，击破/拾取时不遍历文件目录。
	var candidates: Array[Relic] = []
	var stats: RunStats = scene.run_stats
	var max_level: int = stats.shop.level if stats.shop != null else 1
	if stats.shop != null and stats.shop.shopkeeper != null:
		candidates = stats.shop.shopkeeper.get_available_relics(max_level)
	else:
		candidates = FALLBACK_POOL.get_relics_up_to_level(max_level)
	bindings[key] = {"context": context, "scene": scene, "candidates": candidates}
	if not EventBus.map_object_destroyed.is_connected(_on_destroyed):
		EventBus.map_object_destroyed.connect(_on_destroyed)


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context != null and is_instance_valid(context.owner):
		bindings.erase("%s:%s" % [context.owner.get_instance_id(), effect_key])
	if bindings.is_empty() and EventBus.map_object_destroyed.is_connected(_on_destroyed):
		EventBus.map_object_destroyed.disconnect(_on_destroyed)


func _find_scene(node: Node) -> PlayScene:
	while node != null:
		if node is PlayScene:
			return node as PlayScene
		node = node.get_parent()
	return null


func _on_destroyed(object: Node, killer: Entity) -> void:
	if not EventBus.is_battle_active or not is_instance_valid(object) or not (object is MapObject):
		return
	var map_object: MapObject = object as MapObject
	for tag: StringName in excluded_feature_tags:
		if map_object.has_feature_tag(tag):
			return
	for value: Variant in bindings.values():
		var record: Dictionary = value as Dictionary
		var context: RelicContext = record["context"] as RelicContext
		var scene: PlayScene = record["scene"] as PlayScene
		if not is_instance_valid(killer) or killer != context.owner or killer.is_dead:
			continue
		if not is_instance_valid(scene) or scene.battle_completion_started:
			continue
		var relic: Relic = context.own_relic
		var count: int = int(relic.effect_counters.get(String(counter_key), 0)) + 1
		if count >= maxi(required_count, 1):
			# 拷贝坐标和缓存记录，延迟生成不再访问已销毁的地图物件。
			relic.effect_counters[String(counter_key)] = 0
			_spawn.call_deferred(record.duplicate(), map_object.global_position)
		else:
			relic.effect_counters[String(counter_key)] = count


func _pick_reward(pool: Array[MapLootReward]) -> MapLootReward:
	var total: float = 0.0
	for reward: MapLootReward in pool:
		if reward != null:
			total += maxf(reward.weight, 0.0)
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for reward: MapLootReward in pool:
		if reward == null or reward.weight <= 0.0:
			continue
		roll -= reward.weight
		if roll <= 0.0:
			return reward
	return null


func _spawn(record: Dictionary, position_value: Vector2) -> void:
	var context: RelicContext = record["context"] as RelicContext
	var scene: PlayScene = record["scene"] as PlayScene
	if pickup_scene == null or not is_instance_valid(scene) or not scene.is_inside_tree():
		return
	if not is_instance_valid(context.owner) or (context.owner as Entity).is_dead:
		return
	if not EventBus.is_battle_active or scene.battle_completion_started:
		return
	if not is_instance_valid(scene.battle_map):
		return
	var probability: float = upgraded_jackpot_chance if context.own_relic.leveltip == Relic.LevelTip.LEVELUP else jackpot_chance
	var jackpot: bool = randf() < probability
	var reward: MapLootReward = _pick_reward(jackpot_rewards if jackpot else normal_rewards)
	if reward == null:
		return
	var instance: Node = pickup_scene.instantiate()
	if not (instance is MapLootPickup):
		instance.queue_free()
		return
	var pickup: MapLootPickup = instance as MapLootPickup
	pickup.reward = reward
	pickup.jackpot = jackpot
	pickup.collector_owner = context.owner as Entity
	pickup.battle_scene = scene
	pickup.run_stats = scene.run_stats
	pickup.cached_candidate_relics.assign(record["candidates"])
	var container: Node = scene.battle_map.get_runtime_effect_container()
	if container == null:
		container = scene.battle_map
	container.add_child(pickup)
	pickup.global_position = position_value
	pickup.prepare_contents()
