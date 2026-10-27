@tool
extends RefCounted
## 将纯布局转换为普通BattleMap模板。只读取源场景数据，不实例化其中的怪物、物件或生成器。

const LAYERS: Array[String] = ["GroundLayer", "RoadLayer", "DecorationLayer", "ObstacleLayer", "EffectLayer", "ObjectSpawnLayer"]
const ROOT_SCRIPT: String = "res://scripts/battlemap/battle_map.gd"
const SPAWNER_SCRIPT: String = "res://scripts/battlemap/object_spawner_from_tile_map.gd"
const DEFAULT_PROFILE: String = "res://custom_resource/default_map_object_spawn_profile.tres"


func build(layout: Dictionary, settings: Resource) -> Dictionary:
	var errors: PackedStringArray = layout.get("errors", [])
	if not errors.is_empty():
		return {"errors": errors}
	var palette: Dictionary = read_palette(str(settings.get("palette_scene")))
	errors = _validate_palette(palette, settings)
	if not errors.is_empty():
		return {"errors": errors}
	var root: Node2D = Node2D.new()
	root.name = "BattleMap"
	for layer_name: String in LAYERS:
		_add_layer(root, layer_name, palette.get(layer_name) as TileSet)
	_paint_layers(root, layout, settings)
	errors = _validate_painted_layers(root, layout)
	if not errors.is_empty():
		root.free()
		return {"errors": errors}
	_add_markers(root, layout)
	_add_boundary(root, layout, palette["GroundLayer"].tile_size)
	_add_runtime_containers(root)
	# 最后才附加运行脚本；预览中不会运行非@tool脚本的ready或战斗逻辑。
	root.set_script(load(ROOT_SCRIPT))
	root.set("playable_area_cells", packed_cells(layout["playable"]))
	root.set_meta("map_workshop_settings", settings.duplicate(true))
	root.set_meta("map_workshop_version", 1)
	_own_descendants(root, root)
	return {"root": root, "errors": PackedStringArray()}


func read_palette(path: String) -> Dictionary:
	if not path.begins_with("res://") or not ResourceLoader.exists(path, "PackedScene"):
		return {}
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return {}
	var state: SceneState = packed.get_state()
	var result: Dictionary = {}
	for index: int in range(state.get_node_count()):
		var layer_name: String = str(state.get_node_name(index))
		if not LAYERS.has(layer_name) or str(state.get_node_path(index)).trim_prefix("./").contains("/"):
			continue
		for property: int in range(state.get_node_property_count(index)):
			if state.get_node_property_name(index, property) == &"tile_set":
				result[layer_name] = state.get_node_property_value(index, property)
	return result


func _validate_palette(palette: Dictionary, settings: Resource) -> PackedStringArray:
	var errors: PackedStringArray = []
	var terrains: Dictionary = {"GroundLayer": settings.get("grass_terrain"), "RoadLayer": settings.get("road_terrain"), "ObstacleLayer": settings.get("hill_terrain")}
	var cell_size: Vector2i = Vector2i.ZERO
	for layer_name: String in terrains:
		var tiles: TileSet = palette.get(layer_name) as TileSet
		if tiles == null:
			errors.append("素材场景缺少%s的TileSet。" % layer_name)
			continue
		if tiles.tile_shape != TileSet.TILE_SHAPE_SQUARE or tiles.tile_layout != TileSet.TILE_LAYOUT_STACKED:
			errors.append("首版仅支持正交方格TileSet：%s。" % layer_name)
		if cell_size != Vector2i.ZERO and tiles.tile_size != cell_size:
			errors.append("地面、道路与障碍的格子尺寸必须一致。")
		cell_size = tiles.tile_size
		if find_terrain(tiles, str(terrains[layer_name])) == Vector2i(-1, -1):
			errors.append("%s找不到Terrain：%s。" % [layer_name, terrains[layer_name]])
	return errors


static func find_terrain(tiles: TileSet, terrain_name: String) -> Vector2i:
	for set_index: int in range(tiles.get_terrain_sets_count()):
		for index: int in range(tiles.get_terrains_count(set_index)):
			if tiles.get_terrain_name(set_index, index).strip_edges().to_lower() == terrain_name.strip_edges().to_lower():
				return Vector2i(set_index, index)
	return Vector2i(-1, -1)


func _add_layer(root: Node2D, layer_name: String, tiles: TileSet) -> void:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tiles.duplicate(true) as TileSet if tiles != null else null
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.navigation_enabled = false
	match layer_name:
		"GroundLayer": layer.z_index = -100
		"RoadLayer": layer.z_index = -99
		"EffectLayer": layer.z_index = -80
		"ObjectSpawnLayer": layer.visible = false
		_: layer.y_sort_enabled = true
	root.add_child(layer)


func _paint_layers(root: Node2D, layout: Dictionary, settings: Resource) -> void:
	var ground: Dictionary = layout["playable"].duplicate()
	var bounds: Rect2i = layout["bounds"]
	for cell: Vector2i in layout["playable"]:
		for y: int in range(-int(settings.get("ground_padding")), int(settings.get("ground_padding")) + 1):
			for x: int in range(-int(settings.get("ground_padding")), int(settings.get("ground_padding")) + 1):
				if bounds.has_point(cell + Vector2i(x, y)):
					ground[cell + Vector2i(x, y)] = true
	var walls: Dictionary = {}
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if not layout["playable"].has(cell):
				walls[cell] = true
	_paint(root.get_node("GroundLayer"), ground, str(settings.get("grass_terrain")))
	_paint(root.get_node("RoadLayer"), layout["roads"], str(settings.get("road_terrain")))
	_paint(root.get_node("ObstacleLayer"), walls, str(settings.get("hill_terrain")))


func _paint(layer: TileMapLayer, cells: Dictionary, terrain_name: String) -> void:
	var terrain: Vector2i = find_terrain(layer.tile_set, terrain_name)
	var typed_cells: Array[Vector2i] = []
	for cell: Vector2i in cells:
		typed_cells.append(cell)
	layer.set_cells_terrain_connect(typed_cells, terrain.x, terrain.y, true)
	layer.update_internals()


## Terrain配置不完整时，视觉铺设可能没有遵守布局，必须拒绝这种地图。
func _validate_painted_layers(root: Node2D, layout: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	var ground: TileMapLayer = root.get_node("GroundLayer") as TileMapLayer
	for cell: Vector2i in layout["playable"]:
		if ground.get_cell_source_id(cell) < 0:
			errors.append("地面Terrain未能覆盖可游玩格子：%s。" % cell)
			break
	for layer_name: String in ["GroundLayer", "RoadLayer", "ObstacleLayer"]:
		var layer: TileMapLayer = root.get_node(NodePath(layer_name)) as TileMapLayer
		if layer.tile_set.get_custom_data_layer_by_name("blocks_movement") < 0:
			continue
		for cell: Vector2i in layout["playable"]:
			var data: TileData = layer.get_cell_tile_data(cell)
			if data != null and bool(data.get_custom_data("blocks_movement")):
				errors.append("%s的Terrain把场内格子%s标记为阻挡，请检查Terrain边缘和自定义数据。" % [layer_name, cell])
				break
	return errors


func _add_markers(root: Node2D, layout: Dictionary) -> void:
	var container: Node2D = Node2D.new()
	container.name = "SpawnPoints"
	root.add_child(container)
	var ground: TileMapLayer = root.get_node("GroundLayer") as TileMapLayer
	_add_marker(container, "PlayerSpawn", ground.map_to_local(layout["player"]))
	var enemies: Array = layout["enemies"]
	for index: int in range(enemies.size()):
		_add_marker(container, "EnemySpawn%d" % (index + 1), ground.map_to_local(enemies[index]))


func _add_marker(parent: Node2D, marker_name: String, position: Vector2) -> void:
	var marker: Marker2D = Marker2D.new()
	marker.name = marker_name
	marker.position = position
	parent.add_child(marker)


func _add_runtime_containers(root: Node2D) -> void:
	for container_name: String in ["ObjectContainer", "RuntimeEffectContainer", "RandomAreas"]:
		var container: Node2D = Node2D.new()
		container.name = container_name
		root.add_child(container)
	var spawner: Node2D = Node2D.new()
	spawner.name = "ObjectSpawnerFromTileMap"
	spawner.set_script(load(SPAWNER_SCRIPT))
	spawner.set("auto_spawn_on_ready", false)
	spawner.set("random_spawn_profile", load(DEFAULT_PROFILE))
	root.add_child(spawner)


## 把不可走格子按连续行合并为矩形碰撞，避免每格一个碰撞节点。
## 这层碰撞与美术瓦片独立，确保边缘过渡瓦片不能形成可钻出的缺口。
func boundary_rectangles(layout: Dictionary) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var active: Dictionary = {}
	var bounds: Rect2i = layout["bounds"]
	for y: int in range(bounds.position.y, bounds.end.y):
		var next: Dictionary = {}
		var x: int = bounds.position.x
		while x < bounds.end.x:
			if layout["playable"].has(Vector2i(x, y)):
				x += 1
				continue
			var start: int = x
			while x < bounds.end.x and not layout["playable"].has(Vector2i(x, y)):
				x += 1
			var key: Vector2i = Vector2i(start, x - start)
			var rect: Rect2i = active.get(key, Rect2i(start, y, x - start, 0))
			rect.size.y += 1
			next[key] = rect
		for key: Vector2i in active:
			if not next.has(key):
				result.append(active[key])
		active = next
	for key: Vector2i in active:
		result.append(active[key])
	return result


func _add_boundary(root: Node2D, layout: Dictionary, cell_size: Vector2i) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "GeneratedBoundary"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	for rect: Rect2i in boundary_rectangles(layout):
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rectangle: RectangleShape2D = RectangleShape2D.new()
		rectangle.size = Vector2(rect.size * cell_size)
		shape.shape = rectangle
		shape.position = (Vector2(rect.position) + Vector2(rect.size) * 0.5) * Vector2(cell_size)
		body.add_child(shape)


func _own_descendants(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_own_descendants(child, root)


static func packed_cells(cells: Dictionary) -> PackedVector2Array:
	var result: PackedVector2Array = []
	for cell: Vector2i in cells:
		result.append(Vector2(cell))
	return result


func save_new_template(root: Node, path: String, palette_path: String) -> Error:
	# 禁止覆盖素材模板及任何已有文件，防止一键生成误伤手工地图。
	if not path.begins_with("res://scenes/battlemap/templates/") or path.contains("..") or not path.ends_with(".tscn"):
		return ERR_INVALID_PARAMETER
	if path == palette_path or FileAccess.file_exists(path):
		return ERR_ALREADY_EXISTS
	if root == null or not root.has_meta("map_workshop_version"):
		return ERR_INVALID_DATA
	var packed: PackedScene = PackedScene.new()
	var error: Error = packed.pack(root)
	if error != OK:
		return error
	return ResourceSaver.save(packed, path)
