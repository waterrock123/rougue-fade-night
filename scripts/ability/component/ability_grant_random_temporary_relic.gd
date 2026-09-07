## 临时随机装备组件：从指定遗物池中按权重抽取一件指定标签装备。
## 装备栏有空位时直接装备，否则放入背包；临时装备在战斗结算时统一清理。
class_name AbilityGrantRandomTemporaryRelic
extends AbilityComponent

const DEFAULT_RELIC_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")
const DEFAULT_AMMO_TAG: RelicTag = preload("res://relic_tags/弹药tag.tres")

@export_group("Random Relic")
@export var relic_pool: RelicPool = DEFAULT_RELIC_POOL
@export var required_tag: RelicTag = DEFAULT_AMMO_TAG
@export var max_relic_level: int = 99
## 等阶权重公式为：基础权重 / 等阶的此指数次方。
@export var level_weight_exponent: float = 1.0
@export var temporary_source_key: StringName = &"reserve_ammo"
@export var temporary_name_prefix: String = "临时"


func _activate(context: AbilityContext) -> void:
	if context == null or context.caster == null:
		return

	var player_build: PlayerBuild = _resolve_player_build(context.caster)
	if player_build == null:
		return

	var source_relic: Relic = _pick_relic()
	if source_relic == null:
		return

	var temporary_relic: Relic = source_relic.duplicate(true) as Relic
	if temporary_relic == null:
		return

	temporary_relic.is_temporary = true
	temporary_relic.temporary_source_key = temporary_source_key
	if not temporary_name_prefix.is_empty() and not temporary_relic.relic_name.begins_with(temporary_name_prefix):
		temporary_relic.relic_name = temporary_name_prefix + temporary_relic.relic_name

	player_build.add_temporary_relic_to_equipment_or_inventory(temporary_relic)


func _resolve_player_build(caster: Entity) -> PlayerBuild:
	var current_node: Node = caster
	while current_node != null:
		var run_stats_value: Variant = current_node.get("run_stats")
		if run_stats_value is RunStats:
			return (run_stats_value as RunStats).player_build
		current_node = current_node.get_parent()
	return null


func _pick_relic() -> Relic:
	if relic_pool == null:
		return null

	var candidates: Array[Relic] = []
	for relic: Relic in relic_pool.get_relics_up_to_level(max_relic_level):
		if relic != null and _has_required_tag(relic):
			candidates.append(relic)
	if candidates.is_empty():
		return null

	var total_weight: float = 0.0
	var weights: Array[float] = []
	for relic: Relic in candidates:
		var pool_weight: float = relic_pool.get_weight_for_relic(relic, 1.0)
		var level_weight: float = 1.0 / pow(float(maxi(relic.level, 1)), maxf(level_weight_exponent, 0.0))
		var final_weight: float = maxf(pool_weight * level_weight, 0.0)
		weights.append(final_weight)
		total_weight += final_weight

	if total_weight <= 0.0:
		return candidates[0]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var roll: float = rng.randf_range(0.0, total_weight)
	for index in range(candidates.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]

	return candidates.back()


func _has_required_tag(relic: Relic) -> bool:
	if relic == null:
		return false
	for relic_tag: RelicTag in relic.tags:
		if relic_tag == null:
			continue
		if required_tag != null and relic_tag.resource_path == required_tag.resource_path:
			return true
	return false
