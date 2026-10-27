## 无阵营敌人：复用Enemy的移动、硬直与死亡逻辑，攻击最近的玩家/友军/敌人，不攻击地图物件。
## 不视为玩家伤害来源，避免僵尸杀敌时把奖励错误归给玩家；生成方决定是否计入关卡胜利。
class_name FreeForAllEnemy
extends Enemy

@export_range(0.05, 2.0, 0.05) var target_refresh_interval: float = 0.25
var cached_target: Entity
var next_target_refresh_msec: int = 0


func _ready() -> void:
	super._ready()
	add_to_group("free_for_all_actor")
	EventBus.battle_rewards_resolving.connect(_clear_after_battle)
	EventBus.battle_lost.connect(_clear_after_battle)


## 只改变目标匹配，不把自己加入player/player_ally组，不冒充玩家或友军。
func matches_target_group(group_name: StringName) -> bool:
	if group_name in [&"player", &"enemy"]:
		return true
	return super.matches_target_group(group_name)


func _find_nearest_player_side_target() -> Entity:
	var now: int = Time.get_ticks_msec()
	if now < next_target_refresh_msec and _is_combat_target(cached_target):
		return cached_target
	next_target_refresh_msec = now + int(target_refresh_interval * 1000.0)
	cached_target = null
	var closest: float = INF
	var seen: Dictionary = {}
	for group: StringName in [&"enemy", &"player", &"player_ally", &"summon_pet"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(node) or not node is Entity or seen.has(node.get_instance_id()):
				continue
			seen[node.get_instance_id()] = true
			var candidate: Entity = node as Entity
			if not _is_combat_target(candidate):
				continue
			var distance: float = global_position.distance_squared_to(candidate.global_position)
			if distance < closest:
				closest = distance
				cached_target = candidate
	return cached_target


func _is_combat_target(candidate: Variant) -> bool:
	return is_instance_valid(candidate) and candidate is Entity and candidate != self and not candidate.is_in_group("map_object") and candidate.can_be_targeted()


func _clear_after_battle() -> void:
	cancel_active_actions()
	queue_free()
