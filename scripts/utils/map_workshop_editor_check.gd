## 工坊编辑器隔离回归：不启动正式场景，不读写玩家存档，写入测试仅发生于.godot。
extends "res://scripts/utils/guiren_basic_attack_editor_check.gd"

const SETTINGS_PATH: String = "res://scripts/battlemap/battle_map_draft_settings.gd"
const LAYOUT_PATH: String = "res://scripts/battlemap/battle_map_draft_layout.gd"
const BUILDER_PATH: String = "res://addons/battle_map_workshop/map_scene_builder.gd"
const WINDOW_PATH: String = "res://addons/battle_map_workshop/workshop_window.gd"
const MAP_PATH: String = "res://scripts/battlemap/battle_map.gd"
var settings_script: GDScript
var layout_script: GDScript
var builder: RefCounted
var completed: int = 0


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	settings_script = load(SETTINGS_PATH) as GDScript
	layout_script = load(LAYOUT_PATH) as GDScript
	for path: String in [SETTINGS_PATH, LAYOUT_PATH, BUILDER_PATH, WINDOW_PATH, MAP_PATH, "res://addons/battle_map_workshop/map_preview.gd", "res://addons/battle_map_workshop/plugin.gd"]:
		var script: GDScript = load(path) as GDScript
		_check(script != null and script.reload(true) == OK, "脚本解析：" + path)
	builder = (load(BUILDER_PATH) as GDScript).new()
	_check_layouts()
	_check_invalid_settings()
	_check_scene_and_save()
	_check_mask()
	_check_window()
	_check(completed == 5, "全部测试分支执行完成")
	print("地图工坊编辑器检查：%d项，失败%d项；未启动游戏、未访问玩家存档。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _draft(style: int = 0, seed_value: int = 654321, width: int = 72, height: int = 48, passage: int = 7) -> Dictionary:
	var config: Resource = settings_script.new()
	config.set("layout_style", style)
	config.set("seed_value", seed_value)
	config.set("width", width)
	config.set("height", height)
	config.set("passage_width", passage)
	return layout_script.new().call("generate", config)


func _check_layouts() -> void:
	var signatures: Array[int] = []
	for style: int in range(3):
		for seed_value: int in [0, 1, 12, 654321, 999999999]:
			for size: Vector2i in [Vector2i(48, 36), Vector2i(72, 48), Vector2i(128, 96)]:
				var draft: Dictionary = _draft(style, seed_value, size.x, size.y)
				_check(draft["errors"].is_empty(), "布局连通及实体通道校验：%d/%d/%s：%s" % [style, seed_value, size, draft["errors"]])
				_check(draft["playable"].has(draft["player"]) and not draft["enemies"].is_empty(), "出生点位于场内")
		var first: Dictionary = _draft(style)
		var second: Dictionary = _draft(style)
		_check(first["playable"] == second["playable"] and first["roads"] == second["roads"] and first["enemies"] == second["enemies"], "同种子同配置布局完全一致：%d" % style)
		var changed: Dictionary = _draft(style, 192837)
		_check(first["playable"] != changed["playable"], "换种子能改变布局：%d" % style)
		for width: int in [5, 9, 13]:
			_check(_draft(style, 654321, 48, 36, width)["errors"].is_empty(), "不同通道宽度有效：%d/%d" % [style, width])
		signatures.append(hash(first["playable"]))
	_check(signatures[0] != signatures[1] and signatures[1] != signatures[2], "三种布局不是同一个椭圆换参数")
	var generator_source: String = FileAccess.get_file_as_string(LAYOUT_PATH)
	_check(not generator_source.contains("RunRng") and not generator_source.contains("rng.randomize"), "生成不消费局内随机流，固定种子不随机化")
	completed += 1


func _check_invalid_settings() -> void:
	var config: Resource = settings_script.new()
	for invalid: Array in [["width", 10], ["height", 200], ["passage_width", 6], ["layout_style", 99], ["clearing_count", 0]]:
		var old: Variant = config.get(invalid[0])
		config.set(invalid[0], invalid[1])
		_check(not config.call("validate").is_empty(), "拒绝非法配置：%s" % invalid[0])
		config.set(invalid[0], old)
	_check(builder.call("read_palette", "res://missing_map.tscn").is_empty(), "缺失素材给出失败结果，不实例化场景")
	var draft: Dictionary = _draft()
	config.set("grass_terrain", "missing_terrain")
	var result: Dictionary = builder.call("build", draft, config)
	_check(not result["errors"].is_empty() and not result.has("root"), "缺少Terrain时拒绝输出残缺模板")
	completed += 1


func _check_scene_and_save() -> void:
	for style: int in range(3):
		var draft: Dictionary = _draft(style)
		var result: Dictionary = builder.call("build", draft, draft["settings"])
		_check(result["errors"].is_empty() and result.has("root"), "实际TileSet绘制成功：%d：%s" % [style, result["errors"]])
		if not result.has("root"):
			return
		var map_root: Node2D = result["root"]
		_check(map_root.get_script().resource_path == MAP_PATH, "模板挂载真实BattleMap脚本")
		_check(not map_root.has_node("BattleMapGenerator") and map_root.has_node("ObjectSpawnerFromTileMap"), "不带自动重画生成器，保留物体及标签联动入口")
		_check(not map_root.get_node("ObjectSpawnerFromTileMap").get("auto_spawn_on_ready"), "物件生成仍交给PlayScene，不在预览里触发")
		_check(map_root.get("playable_area_cells").size() == draft["playable"].size(), "场内遮罩不包含外扩草地")
		_check_boundary(draft, map_root)
		_check_real_navigation(map_root, draft)
		_check_roundtrip(map_root)
		if style == 0:
			_check_save_protection(map_root, draft)
		map_root.free()
	completed += 1


func _check_boundary(draft: Dictionary, map_root: Node2D) -> void:
	var rectangles: Array[Rect2i] = builder.call("boundary_rectangles", draft)
	var covered: Dictionary = {}
	for rect: Rect2i in rectangles:
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				covered[Vector2i(x, y)] = true
	var bounds: Rect2i = draft["bounds"]
	_check(covered.size() + draft["playable"].size() == bounds.get_area(), "合并边界碰撞完整覆盖地图外区域")
	var overlap: bool = false
	for cell: Vector2i in draft["playable"]:
		overlap = overlap or covered.has(cell)
	_check(not overlap, "边界碰撞不侵入可游玩格子")
	_check(map_root.get_node("GeneratedBoundary").get_child_count() == rectangles.size() and rectangles.size() < covered.size(), "合并碰撞而非逐格创建节点")
	var ground: TileMapLayer = map_root.get_node("GroundLayer") as TileMapLayer
	_check(ground.get_used_cells().size() > draft["playable"].size(), "草地外扩正常铺设")
	var missing: int = 0
	for cell: Vector2i in draft["playable"]:
		if ground.get_cell_source_id(cell) < 0:
			missing += 1
	_check(missing == 0, "可游玩区域实际瓦片没有缺格")


func _check_roundtrip(map_root: Node2D) -> void:
	var packed: PackedScene = PackedScene.new()
	_check(packed.pack(map_root) == OK, "生成场景能够正常打包")
	var restored: Node2D = packed.instantiate() as Node2D
	_check(restored != null and restored.get_node("SpawnPoints").get_child_count() > 1, "打包后出生点未丢失")
	if restored != null:
		_check(restored.get("playable_area_cells") == map_root.get("playable_area_cells"), "打包后场内遮罩保留")
		_check(restored.get_node("GeneratedBoundary").get_child_count() == map_root.get_node("GeneratedBoundary").get_child_count(), "打包后边界碰撞保留")
		restored.free()


func _check_real_navigation(map_root: Node2D, draft: Dictionary) -> void:
	# 仅在未入树的副本上给原BattleMap源码加@tool，执行实际瓦片/寻路查询，不运行ready。
	var source: String = FileAccess.get_file_as_string(MAP_PATH).replace("class_name BattleMap", "@tool")
	var script: GDScript = _fixture(source)
	if script == null:
		return
	var probe: Node2D = map_root.duplicate() as Node2D
	var mask: PackedVector2Array = map_root.get("playable_area_cells")
	probe.set_script(script)
	probe.set("playable_area_cells", mask)
	probe.call("refresh_layer_cache")
	probe.call("rebuild_navigation_grid")
	var player: Vector2 = probe.get_node("SpawnPoints/PlayerSpawn").position
	_check(probe.call("is_world_position_walkable", player), "实际瓦片和遮罩均允许玩家出生")
	_check(probe.get("playable_reachable_cells").size() == draft["playable"].size(), "实际寻路可达范围与生成布局完全一致")
	for marker: Node2D in probe.get_node("SpawnPoints").get_children():
		_check(probe.call("is_world_position_in_playable_region", marker.position, 1), "出生点在真实寻路区域内且有实体间隙")
	var bounds: Rect2i = draft["bounds"]
	var outside: Vector2 = probe.call("cell_to_world_center", bounds.position)
	_check(not probe.call("is_world_position_in_playable_region", outside), "真实召唤落点查询拒绝场外位置")
	var path: PackedVector2Array = probe.call("get_navigation_path", player, probe.get_node("SpawnPoints/EnemySpawn1").position)
	_check(path.size() > 1, "真实AStarGrid2D可以从出生点走到敌人出生区")
	probe.free()


func _check_save_protection(map_root: Node2D, draft: Dictionary) -> void:
	var palette: String = str(draft["settings"].get("palette_scene"))
	var original: String = FileAccess.get_file_as_string(palette)
	_check(builder.call("save_new_template", map_root, palette, palette) == ERR_ALREADY_EXISTS, "拒绝覆盖素材原图")
	_check(builder.call("save_new_template", map_root, "res://../escape.tscn", palette) == ERR_INVALID_PARAMETER, "拒绝目录穿越")
	_check(FileAccess.get_file_as_string(palette) == original, "源场景内容保持不变")
	# 把生产保存函数的目录白名单重定向到.godot，只测试临时文件，绝不触碰玩家模板。
	var body: String = _function_source(BUILDER_PATH, "save_new_template").replace("res://scenes/battlemap/templates/", "res://.godot/map_workshop_checks/")
	var fixture: GDScript = _fixture("@tool\nextends RefCounted\n" + body)
	if fixture == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/map_workshop_checks"))
	var path: String = "res://.godot/map_workshop_checks/draft_%d.tscn" % Time.get_ticks_usec()
	var writer: RefCounted = fixture.new()
	_check(writer.call("save_new_template", map_root, path, palette) == OK, "实际保存新模板成功（测试目录）")
	var saved: String = FileAccess.get_file_as_string(path)
	_check(writer.call("save_new_template", map_root, path, palette) == ERR_ALREADY_EXISTS, "不允许二次覆盖已保存模板")
	_check(FileAccess.get_file_as_string(path) == saved, "覆盖被拒绝后原文件内容不变")
	var loaded: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	_check(loaded != null and loaded.get_state().get_node_count() > 15, "磁盘模板可被编辑器重新读取")


func _check_mask() -> void:
	var body: String = _function_source(MAP_PATH, "_is_cell_in_authored_playable_area").strip_edges() + "\n\n"
	body += _function_source(MAP_PATH, "is_world_position_walkable").strip_edges() + "\n\n"
	body += _function_source(MAP_PATH, "_is_cell_static_walkable_for_navigation").strip_edges() + "\n\n"
	var header: String = "@tool\nextends RefCounted\nvar playable_area_cells = PackedVector2Array()\nvar authored_playable_cells = {}\nvar require_ground_tile_for_walkable = true\nvar obstacle_layer\nvar effect_layer\nvar obstacle_tiles_block_by_default = true\nvar effect_tiles_block_by_default = false\nvar ground_layers = []\n"
	header += "func world_to_cell(point):\n\treturn Vector2i(point)\nfunc is_world_position_inside_bounds(_point):\n\treturn true\nfunc _has_ground_tile(_cell):\n\treturn true\nfunc _is_runtime_navigation_blocked(_cell):\n\treturn false\nfunc _cell_blocks_movement(_layer, _cell, _fallback):\n\treturn false\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return
	var helper: RefCounted = script.new()
	_check(helper.call("is_world_position_walkable", Vector2(99, 99)), "旧地图空遮罩沿用原有规则")
	helper.set("playable_area_cells", PackedVector2Array([Vector2.ZERO, Vector2(1, 0)]))
	_check(helper.call("is_world_position_walkable", Vector2.ZERO), "遮罩内可走")
	_check(not helper.call("is_world_position_walkable", Vector2(99, 99)), "外铺草地不能绕过场内遮罩")
	_check(not helper.call("_is_cell_static_walkable_for_navigation", Vector2i(99, 99)), "导航与出生/召唤查询共用遮罩")
	_check(_function_source(MAP_PATH, "refresh_layer_cache").contains("authored_playable_cells.clear()"), "地图缓存刷新时同步失效遮罩缓存")
	completed += 1


func _check_window() -> void:
	var window_script: GDScript = load(WINDOW_PATH) as GDScript
	var window: Window = window_script.new()
	_check(not window.visible and window.min_size.y >= 680, "工具窗口初始隐藏且有最小尺寸")
	window.call("generate_map")
	var generated: Node2D = window.get("generated_root") as Node2D
	_check(generated != null and not window.get("save_button").disabled, "窗口生成能驱动真实预览和保存状态")
	window.call("_mark_dirty")
	_check(window.get("save_button").disabled, "参数更改后不能误存旧预览")
	window.free()
	completed += 1
