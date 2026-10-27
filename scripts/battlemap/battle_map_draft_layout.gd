@tool
class_name BattleMapDraftLayout
extends RefCounted
## 纯格子布局生成。先保证结构连通，再交给工坊绘制Terrain；不依赖场景树和全局随机数。

const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const STYLE_NAMES: Array[String] = ["环形林地", "多片空地相连", "中央竞技场"]

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var bounds: Rect2i
var playable: Dictionary = {}
var roads: Dictionary = {}
var centers: Array[Vector2i] = []
var passage_radius: int = 3


func generate(settings: Resource) -> Dictionary:
	var errors: PackedStringArray = settings.call("validate")
	if not errors.is_empty():
		return {"errors": errors}
	rng.seed = int(settings.get("seed_value"))
	var size: Vector2i = Vector2i(settings.get("width"), settings.get("height"))
	bounds = Rect2i(Vector2i(-size.x / 2, -size.y / 2), size)
	playable = {}
	roads = {}
	centers = []
	passage_radius = int(settings.get("passage_width")) / 2
	match int(settings.get("layout_style")):
		0: _build_ring()
		1: _build_clearings(int(settings.get("clearing_count")))
		2: _build_arena()
	var player: Vector2i = centers[0]
	var enemies: Array[Vector2i] = _select_enemy_spawns(player)
	_add_cover(int(settings.get("obstacle_count")), player, enemies)
	var result: Dictionary = {
		"bounds": bounds, "playable": playable, "roads": roads, "player": player,
		"enemies": enemies, "centers": centers, "seed": int(settings.get("seed_value")),
		"style": STYLE_NAMES[int(settings.get("layout_style"))], "settings": settings.duplicate(true),
	}
	result["errors"] = validate_layout(result)
	return result


func _build_ring() -> void:
	var radii: Vector2 = Vector2(bounds.size) * Vector2(0.31, 0.27)
	for index: int in range(12):
		var angle: float = PI + TAU * float(index) / 12.0
		var jitter: float = rng.randf_range(0.9, 1.08)
		var center: Vector2i = Vector2i(Vector2(cos(angle), sin(angle)) * radii * jitter)
		centers.append(center)
		_carve_ellipse(center, Vector2i(passage_radius + 2, passage_radius + 2))
	for index: int in range(centers.size()):
		_connect(centers[index], centers[(index + 1) % centers.size()])


func _build_clearings(count: int) -> void:
	var half: Vector2 = Vector2(bounds.size) * 0.5
	for index: int in range(count):
		var weight: float = float(index) / float(count - 1)
		var x: int = roundi(lerpf(-half.x * 0.65, half.x * 0.65, weight))
		var y: int = roundi(half.y * (0.32 if index % 2 == 0 else -0.32)) + rng.randi_range(-2, 2)
		var center: Vector2i = Vector2i(x, y)
		centers.append(center)
		_carve_ellipse(center, Vector2i(rng.randi_range(6, 9), rng.randi_range(5, 8)))
		if index > 0:
			_connect(centers[index - 1], center)
	# 较大的地图增加一条捷径，避免只有单线绕路。
	if count >= 5:
		_connect(centers[1], centers[count - 2])


func _build_arena() -> void:
	_carve_ellipse(Vector2i.ZERO, Vector2i(bounds.size.x * 0.40, bounds.size.y * 0.38))
	centers = [Vector2i(-bounds.size.x / 4, 0), Vector2i.ZERO]
	centers.append(Vector2i(bounds.size.x / 4, -bounds.size.y / 6))
	centers.append(Vector2i(bounds.size.x / 4, bounds.size.y / 6))
	centers.append(Vector2i(0, -bounds.size.y / 4))
	centers.append(Vector2i(0, bounds.size.y / 4))
	for index: int in range(1, centers.size()):
		_connect(centers[0], centers[index])


func _carve_ellipse(center: Vector2i, radii: Vector2i) -> void:
	for y: int in range(-radii.y, radii.y + 1):
		for x: int in range(-radii.x, radii.x + 1):
			var normalized: Vector2 = Vector2(x, y) / Vector2(radii)
			var cell: Vector2i = center + Vector2i(x, y)
			if normalized.length_squared() <= 1.0 and bounds.grow(-3).has_point(cell):
				playable[cell] = true


func _connect(start: Vector2i, end: Vector2i) -> void:
	var steps: int = maxi(absi(end.x - start.x), absi(end.y - start.y)) * 2
	for index: int in range(steps + 1):
		var weight: float = float(index) / float(maxi(steps, 1))
		var cell: Vector2i = Vector2i(Vector2(start).lerp(Vector2(end), weight).round())
		_carve_ellipse(cell, Vector2i(passage_radius, passage_radius))
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if playable.has(cell + offset):
				roads[cell + offset] = true


func _select_enemy_spawns(player: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for center: Vector2i in centers:
		if center.distance_to(player) < float(bounds.size.x) * 0.18 or not _has_clearance(playable, center, 2):
			continue
		var separated: bool = true
		for used: Vector2i in result:
			if center.distance_to(used) < 6.0:
				separated = false
		if separated:
			result.append(center)
	return result


func _add_cover(count: int, player: Vector2i, enemies: Array[Vector2i]) -> void:
	var protected: Array[Vector2i] = [player]
	protected.append_array(enemies)
	var accepted: int = 0
	var cells: Array = playable.keys()
	for _attempt: int in range(count * 25):
		if accepted >= count:
			break
		var center: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		if roads.has(center) or not _has_clearance(playable, center, 3):
			continue
		var trial: Dictionary = _try_cover(center, protected)
		if trial.is_empty() or reachable_cells(trial, player).size() != trial.size():
			continue
		if not _spawns_connected_with_clearance(trial, player, enemies):
			continue
		playable = trial
		accepted += 1


func _try_cover(center: Vector2i, protected: Array[Vector2i]) -> Dictionary:
	for spawn: Vector2i in protected:
		if center.distance_to(spawn) < 7.0:
			return {}
	var result: Dictionary = playable.duplicate()
	var radius: int = rng.randi_range(1, 2)
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			var cell: Vector2i = center + Vector2i(x, y)
			if roads.has(cell):
				return {}
			if Vector2(x, y).length() <= float(radius) + 0.2:
				result.erase(cell)
	return result


static func reachable_cells(cells: Dictionary, start: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	if not cells.has(start):
		return visited
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var index: int = 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = current + direction
			if cells.has(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return visited


static func validate_layout(layout: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var cells: Dictionary = layout.get("playable", {})
	var player: Vector2i = layout.get("player", Vector2i.ZERO)
	if cells.size() < 100 or reachable_cells(cells, player).size() != cells.size():
		errors.append("可游玩区域为空、过小或存在断开的区域。")
	if not _has_clearance(cells, player, 2):
		errors.append("玩家出生点周围空间不足。")
	var enemies: Array = layout.get("enemies", [])
	if enemies.is_empty():
		errors.append("没有足够安全的敌人出生点。")
	for cell: Vector2i in enemies:
		if not _has_clearance(cells, cell, 2):
			errors.append("敌人出生点周围空间不足。")
	if not _spawns_connected_with_clearance(cells, player, enemies):
		errors.append("主要出生点之间的通道过窄。")
	for cell: Vector2i in layout.get("roads", {}):
		if not cells.has(cell):
			errors.append("道路延伸到了可游玩区域外。")
	return errors


static func _has_clearance(cells: Dictionary, center: Vector2i, radius: int) -> bool:
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			if not cells.has(center + Vector2i(x, y)):
				return false
	return true


static func _spawns_connected_with_clearance(cells: Dictionary, player: Vector2i, enemies: Array) -> bool:
	var wide_cells: Dictionary = {}
	for cell: Vector2i in cells:
		if _has_clearance(cells, cell, 1):
			wide_cells[cell] = true
	var reachable: Dictionary = reachable_cells(wide_cells, player)
	for cell: Vector2i in enemies:
		if not reachable.has(cell):
			return false
	return reachable.has(player)
