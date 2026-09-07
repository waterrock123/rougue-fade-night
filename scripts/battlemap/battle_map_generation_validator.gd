class_name BattleMapGenerationValidator
extends RefCounted

## 地图生成完成后的安全检查器。
## 它不负责生成瓦片，只负责发现配置问题，并给出可以安全修正的出生点。

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]

var battle_map: BattleMap
var minimum_reachable_ratio: float = 0.9
var repair_player_spawn: bool = true
var log_result: bool = true


func validate_and_repair() -> Dictionary:
	var report: Dictionary = {
		"is_valid": true,
		"issues": [],
		"walkable_cell_count": 0,
		"reachable_cell_count": 0,
		"reachable_ratio": 0.0,
		"player_spawn_valid": false,
		"player_spawn_repaired": false,
		"enemy_spawn_count": 0,
		"invalid_enemy_spawn_count": 0,
		"recommended_player_spawn_position": null,
	}

	if battle_map == null:
		return _finish_report(report, ["没有绑定 BattleMap。"])

	battle_map.refresh_layer_cache()
	var bounds: Rect2i = battle_map.get_map_bounds_cells()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return _finish_report(report, ["地图没有有效边界，请检查 GroundLayer 或 bounds_override。"])

	var walkable_cells: Array[Vector2i] = battle_map.get_walkable_cells()
	report["walkable_cell_count"] = walkable_cells.size()
	if walkable_cells.is_empty():
		return _finish_report(report, ["地图没有可行走格，请检查地面瓦片和障碍物 custom data。"])

	var configured_player_positions: Array[Vector2] = battle_map.get_spawn_positions(BattleMap.SPAWN_PLAYER)
	var player_spawn_position: Variant = _find_safe_player_spawn_position()
	if player_spawn_position is Vector2:
		report["recommended_player_spawn_position"] = player_spawn_position
		report["player_spawn_valid"] = true
		if not configured_player_positions.is_empty():
			var has_valid_configured_position: bool = false
			for configured_position: Vector2 in configured_player_positions:
				if battle_map.is_world_position_walkable(configured_position):
					has_valid_configured_position = true
					break
			if not has_valid_configured_position:
				report["player_spawn_repaired"] = true
				_add_issue(report, "配置的玩家出生点不可行走，已自动移动到最近的安全位置。")
	else:
		_add_issue(report, "找不到可行走的玩家出生点。")

	var enemy_spawn_positions: Array[Vector2] = battle_map.get_spawn_positions(BattleMap.SPAWN_ENEMY)
	enemy_spawn_positions.append_array(battle_map.get_spawn_positions(BattleMap.SPAWN_ANY))
	report["enemy_spawn_count"] = enemy_spawn_positions.size()
	var invalid_enemy_spawn_count: int = 0
	for enemy_spawn_position: Vector2 in enemy_spawn_positions:
		if not battle_map.is_world_position_walkable(enemy_spawn_position):
			invalid_enemy_spawn_count += 1
	report["invalid_enemy_spawn_count"] = invalid_enemy_spawn_count
	if invalid_enemy_spawn_count > 0:
		_add_issue(report, "发现 %d 个不可行走的敌人出生点，EnemySpawner 将使用随机安全位置兜底。" % invalid_enemy_spawn_count)

	if player_spawn_position is Vector2:
		var reachable_cells: Array[Vector2i] = _collect_reachable_cells(
			battle_map.world_to_cell(player_spawn_position as Vector2),
			walkable_cells
		)
		report["reachable_cell_count"] = reachable_cells.size()
		var reachable_ratio: float = float(reachable_cells.size()) / float(max(walkable_cells.size(), 1))
		report["reachable_ratio"] = reachable_ratio
		if reachable_ratio < minimum_reachable_ratio:
			_add_issue(report, "玩家出生区域只能到达 %.1f%% 的可行走区域，可能存在孤立区域。" % (reachable_ratio * 100.0))

	_validate_special_terrain_cells(report)
	return _finish_report(report, report["issues"] as Array)


func _find_safe_player_spawn_position() -> Variant:
	var configured_positions: Array[Vector2] = battle_map.get_spawn_positions(BattleMap.SPAWN_PLAYER)
	for position: Vector2 in configured_positions:
		if battle_map.is_world_position_walkable(position):
			return position

	var default_position: Vector2 = battle_map.get_player_spawn_position(Vector2.ZERO)
	if battle_map.is_world_position_walkable(default_position):
		return default_position

	return battle_map.get_nearest_walkable_position(default_position, 12)


func _collect_reachable_cells(start_cell: Vector2i, walkable_cells: Array[Vector2i]) -> Array[Vector2i]:
	var walkable_lookup: Dictionary = {}
	for cell: Vector2i in walkable_cells:
		walkable_lookup[cell] = true
	if not walkable_lookup.has(start_cell):
		return []

	var reachable_cells: Array[Vector2i] = []
	var pending_cells: Array[Vector2i] = [start_cell]
	var visited: Dictionary = {start_cell: true}
	while not pending_cells.is_empty():
		var current_cell: Vector2i = pending_cells.pop_front()
		reachable_cells.append(current_cell)
		for direction: Vector2i in CARDINAL_DIRECTIONS:
			var next_cell: Vector2i = current_cell + direction
			if not walkable_lookup.has(next_cell) or visited.has(next_cell):
				continue
			visited[next_cell] = true
			pending_cells.append(next_cell)

	return reachable_cells


func _validate_special_terrain_cells(report: Dictionary) -> void:
	if battle_map.effect_layer == null:
		return

	var invalid_terrain_count: int = 0
	for cell_value in battle_map.effect_layer.get_used_cells():
		var cell: Vector2i = cell_value
		var world_position: Vector2 = battle_map.cell_to_world_center(cell)
		if not battle_map.is_world_position_inside_bounds(world_position):
			invalid_terrain_count += 1
			continue
		if not battle_map.is_world_position_walkable(world_position):
			# 只有在同一格存在障碍或地面不可行走时才提示，允许特殊地形本身改变通行规则。
			if battle_map.obstacle_layer != null and battle_map.obstacle_layer.get_cell_source_id(cell) != -1:
				invalid_terrain_count += 1

	if invalid_terrain_count > 0:
		_add_issue(report, "发现 %d 个特殊地形与障碍物重叠。" % invalid_terrain_count)


func _add_issue(report: Dictionary, message: String) -> void:
	var issues: Array = report["issues"] as Array
	issues.append(message)
	report["issues"] = issues
	report["is_valid"] = false


func _finish_report(report: Dictionary, issues: Array) -> Dictionary:
	report["is_valid"] = issues.is_empty()
	if log_result:
		if report["is_valid"]:
			print("BattleMap 生成验证通过：可行走格 %d，可达比例 %.1f%%。" % [report["walkable_cell_count"], float(report["reachable_ratio"]) * 100.0])
		else:
			for issue_value in issues:
				var issue_text: String = str(issue_value)
				push_warning("BattleMap 生成验证：" + issue_text)
	return report
