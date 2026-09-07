@tool
class_name BattleMapRandomArea
extends Node2D

## 模板战斗地图中的“随机区域”标记节点。
## 你可以把它放到 BattleMap/RandomAreas 下，用它框出哪些地方允许随机生成地图物体、特殊地形或装饰。

enum AreaType {
	MAP_OBJECT,
	TERRAIN,
	OBSTACLE,
	DECORATION,
	SPAWN,
}

@export var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()

## 区域类型。当前先用于区分用途，下一步 ObjectSpawnerFromTileMap 会优先读取 MAP_OBJECT 区域。
@export var area_type: AreaType = AreaType.MAP_OBJECT:
	set(value):
		area_type = value
		queue_redraw()

## 可选标识，例如 beneficial_plant_area / ammo_area。后续规则需要指定区域时可以用它筛选。
@export var area_id: StringName = &""

## 区域权重。多个同类区域都可用时，权重越高越容易被选中。
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0

## 允许生成的地图物体 id。留空代表此区域不限制 object_id。
@export var allowed_object_ids: Array[StringName] = []

## 区域尺寸，节点自身位置就是矩形中心点。
@export var size: Vector2 = Vector2(192.0, 128.0):
	set(value):
		size = Vector2(max(value.x, 1.0), max(value.y, 1.0))
		queue_redraw()

@export_group("编辑器显示")
@export var draw_in_game: bool = false:
	set(value):
		draw_in_game = value
		queue_redraw()

@export var use_type_color: bool = true:
	set(value):
		use_type_color = value
		queue_redraw()

@export var fill_color: Color = Color(0.25, 0.85, 0.32, 0.18):
	set(value):
		fill_color = value
		queue_redraw()

@export var border_color: Color = Color(0.65, 1.0, 0.68, 0.75):
	set(value):
		border_color = value
		queue_redraw()

@export_range(1.0, 8.0, 0.5) var border_width: float = 2.0:
	set(value):
		border_width = max(value, 1.0)
		queue_redraw()

@export var show_center_cross: bool = true:
	set(value):
		show_center_cross = value
		queue_redraw()


func _enter_tree() -> void:
	add_to_group("battle_map_random_area")
	set_notify_transform(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() and not draw_in_game:
		return

	var rect: Rect2 = get_local_rect()
	var resolved_fill_color: Color = _get_area_fill_color()
	var resolved_border_color: Color = _get_area_border_color()
	if not enabled:
		resolved_fill_color.a *= 0.35
		resolved_border_color.a *= 0.35

	draw_rect(rect, resolved_fill_color, true)
	draw_rect(rect, resolved_border_color, false, border_width)

	if show_center_cross:
		var half_cross_size: float = 6.0
		draw_line(Vector2(-half_cross_size, 0.0), Vector2(half_cross_size, 0.0), resolved_border_color, 1.0)
		draw_line(Vector2(0.0, -half_cross_size), Vector2(0.0, half_cross_size), resolved_border_color, 1.0)


## 返回本地矩形。区域以节点原点为中心，方便你直接拖动节点位置。
func get_local_rect() -> Rect2:
	return Rect2(-size * 0.5, size)


## 返回世界坐标下的矩形。当前按“不旋转矩形”处理，模板里建议只调位置和尺寸。
func get_world_rect() -> Rect2:
	var top_left: Vector2 = to_global(-size * 0.5)
	var bottom_right: Vector2 = to_global(size * 0.5)
	var min_position: Vector2 = Vector2(min(top_left.x, bottom_right.x), min(top_left.y, bottom_right.y))
	var max_position: Vector2 = Vector2(max(top_left.x, bottom_right.x), max(top_left.y, bottom_right.y))
	return Rect2(min_position, max_position - min_position)


func contains_world_position(world_position: Vector2) -> bool:
	return get_world_rect().has_point(world_position)


func can_spawn_object(object_id: StringName) -> bool:
	if not enabled or area_type != AreaType.MAP_OBJECT:
		return false
	if allowed_object_ids.is_empty():
		return true
	return allowed_object_ids.has(object_id)


func matches_area_type(expected_type: int) -> bool:
	return enabled and area_type == expected_type


## 从区域中随机取一个连续世界坐标。适合纯装饰或不需要贴格子的表现。
func get_random_world_position() -> Vector2:
	var rect: Rect2 = get_world_rect()
	return Vector2(
		randf_range(rect.position.x, rect.position.x + rect.size.x),
		randf_range(rect.position.y, rect.position.y + rect.size.y)
	)


## 获取区域覆盖到的所有地图格子。真正生成地图物件时推荐基于格子中心生成，位置更稳定。
func get_cells_in_area(battle_map) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if battle_map == null or not enabled:
		return result

	var world_rect: Rect2 = get_world_rect()
	var first_cell: Vector2i = battle_map.world_to_cell(world_rect.position)
	var second_cell: Vector2i = battle_map.world_to_cell(world_rect.position + world_rect.size)
	var min_x: int = min(first_cell.x, second_cell.x)
	var max_x: int = max(first_cell.x, second_cell.x)
	var min_y: int = min(first_cell.y, second_cell.y)
	var max_y: int = max(first_cell.y, second_cell.y)

	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var cell: Vector2i = Vector2i(x, y)
			var world_position: Vector2 = battle_map.cell_to_world_center(cell)
			if world_rect.has_point(world_position):
				result.append(cell)

	return result


## 从区域里随机取一个可行走格子的中心点。地图物体生成器下一步会主要调用这个接口。
func get_random_walkable_position(battle_map, max_attempts: int = 80) -> Variant:
	if battle_map == null or not enabled:
		return null

	var cells: Array[Vector2i] = get_cells_in_area(battle_map)
	if cells.is_empty():
		return null

	var attempts: int = min(max(max_attempts, 1), cells.size())
	for _attempt: int in range(attempts):
		var index: int = randi_range(0, cells.size() - 1)
		var cell: Vector2i = cells[index]
		cells.remove_at(index)
		var world_position: Vector2 = battle_map.cell_to_world_center(cell)
		if battle_map.is_world_position_walkable(world_position):
			return world_position

	return null


func _get_area_fill_color() -> Color:
	if not use_type_color:
		return fill_color

	match area_type:
		AreaType.MAP_OBJECT:
			return Color(0.25, 0.85, 0.32, 0.18)
		AreaType.TERRAIN:
			return Color(0.25, 0.58, 1.0, 0.16)
		AreaType.OBSTACLE:
			return Color(1.0, 0.58, 0.2, 0.16)
		AreaType.DECORATION:
			return Color(0.85, 0.72, 1.0, 0.14)
		AreaType.SPAWN:
			return Color(1.0, 0.22, 0.22, 0.14)
		_:
			return fill_color


func _get_area_border_color() -> Color:
	if not use_type_color:
		return border_color

	var color: Color = _get_area_fill_color()
	color.a = 0.75
	color = color.lightened(0.25)
	return color


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if size.x <= 1.0 or size.y <= 1.0:
		warnings.append("随机区域尺寸过小，可能无法选到有效地图格子。")
	if weight <= 0.0:
		warnings.append("区域权重为 0 时，后续随机生成器不会主动选择这个区域。")
	return warnings
