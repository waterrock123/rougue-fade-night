class_name EventRoomPool
extends Resource

@export var event_rooms: Array[PackedScene]


## 事件在进入房间时抽取，厨王赛只对背包里带原料/佳肴标签的玩家开放。
func get_random(run_stats: RunStats = null) -> PackedScene:
	var candidates: Array[PackedScene] = []
	for scene: PackedScene in event_rooms:
		if scene == null:
			continue
		if scene.resource_path == "res://event_room/cooking_contest_room.tscn" and not _has_cooking_entry(run_stats):
			continue
		candidates.append(scene)
	return RunRng.pick(candidates) as PackedScene


func _has_cooking_entry(run_stats: RunStats) -> bool:
	if run_stats == null or run_stats.player_build == null or run_stats.player_build.player_inventory == null:
		return false
	for slot: Slot in run_stats.player_build.player_inventory.slots:
		if slot == null or slot.item == null:
			continue
		for tag: RelicTag in slot.item.tags:
			if tag != null and (tag.tag_name == "原料" or tag.tag_name == "佳肴"):
				return true
	return false
