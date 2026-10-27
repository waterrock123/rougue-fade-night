class_name FeastTable
extends LostCargo

const RELIC_PICKUP: PackedScene = preload("res://scenes/battlemap/map_relic_pickup.tscn")
@export var reward_tag: RelicTag = preload("res://relic_tags/佳肴tag.tres")


## 佳肴奖励使用全装备池而不是商人私人池，避免某位商人没有佳肴而无法掉落。
func _get_candidate_relics(stats: RunStats) -> Array[Relic]:
	var result: Array[Relic] = []
	if fallback_relic_pool == null or reward_tag == null:
		return result
	for relic: Relic in fallback_relic_pool.get_relics_up_to_level(_get_max_relic_level(stats)):
		for tag: RelicTag in relic.tags:
			if tag != null and tag.tag_name == reward_tag.tag_name:
				result.append(relic)
				break
	return result


func _grant_lost_cargo_rewards() -> void:
	if not has_prepared_rewards:
		prepare_rewards()
	for index: int in range(prepicked_reward_relics.size()):
		var relic: Relic = prepicked_reward_relics[index]
		var desired: Vector2 = global_position + _get_drop_offset(24.0, index)
		var map: BattleMap = get_tree().get_first_node_in_group("battle_map") as BattleMap
		if map != null:
			var safe: Variant = map.get_nearest_playable_position(desired, 4)
			if safe is Vector2:
				desired = safe
			else:
				desired = global_position
		_drop_relic.call_deferred(relic, desired)
	prepicked_reward_relics.clear()


func _drop_relic(relic: Relic, world_position: Vector2) -> void:
	var parent: Node = _get_drop_parent()
	if not is_instance_valid(parent) or relic == null:
		return
	var pickup: MapRelicPickup = RELIC_PICKUP.instantiate() as MapRelicPickup
	pickup.run_stats = _get_run_stats()
	pickup.prepared_reward_relic = relic
	pickup.has_prepared_reward = true
	parent.add_child(pickup)
	pickup.global_position = world_position
