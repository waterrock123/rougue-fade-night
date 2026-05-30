class_name BattleStatsPool
extends Resource

@export var pool: Array[BattleStats]

var total_weights_by_tier: Array[float] = []


func _get_all_battles_for_tier(tier: int) -> Array[BattleStats]:
	return pool.filter(
		func(battle: BattleStats):
			return battle.battle_tier == tier
	)


func _setup_weight_for_tier(tier: int) -> void:
	_ensure_tier_index(tier)
	var battles := _get_all_battles_for_tier(tier)
	total_weights_by_tier[tier] = 0.0
	
	for battle: BattleStats in battles:
		total_weights_by_tier[tier] += battle.weight
		battle.accumulated_weight = total_weights_by_tier[tier]


func get_random_battle_for_tier(tier: int) -> BattleStats:
	_ensure_tier_index(tier)
	if total_weights_by_tier[tier] <= 0.0:
		return null

	var roll := RunRng.randf_range(0.0, total_weights_by_tier[tier])
	var battles := _get_all_battles_for_tier(tier)
	
	for battle: BattleStats in battles:
		if battle.accumulated_weight > roll:
			return battle
		
	return null


func setup() -> void:
	var max_tier := 0
	for battle in pool:
		if battle != null:
			max_tier = max(max_tier, battle.battle_tier)

	for tier in range(max_tier + 1):
		_setup_weight_for_tier(tier)


func _ensure_tier_index(tier: int) -> void:
	if tier < 0:
		return
	while total_weights_by_tier.size() <= tier:
		total_weights_by_tier.append(0.0)
