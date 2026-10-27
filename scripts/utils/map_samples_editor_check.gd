## 三张样例地图的编辑器制作与校验入口。只新建缺失模板，重跑不会覆盖手工调整。
## 不启动正式游戏，不读写玩家存档，不修改地图池和战斗波次。
extends "res://scripts/utils/map_workshop_editor_check.gd"

const SAMPLES: Array[Dictionary] = [
	{"preset": "res://custom_resource/map_sample_ring.tres", "scene": "res://scenes/battlemap/templates/sample_01_环形林地.tscn", "purpose": "环形路线：测试绕怪、环形寻路，以及中央障碍内和外边界的召唤/瞬移落点。"},
	{"preset": "res://custom_resource/map_sample_clearings.tres", "scene": "res://scenes/battlemap/templates/sample_02_连通空地.tscn", "purpose": "五片空地及捷径：测试跨区域追击、通道宽度和寻找敌人的时间成本。"},
	{"preset": "res://custom_resource/map_sample_arena.tres", "scene": "res://scenes/battlemap/templates/sample_03_中央竞技场.tscn", "purpose": "中央竞技场：中央保留空地，测试大型Boss、召唤、瞬移和边界。BossSpawn仅为位置标记，不改变波次规则。"},
]


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	settings_script = load(SETTINGS_PATH) as GDScript
	layout_script = load(LAYOUT_PATH) as GDScript
	builder = (load(BUILDER_PATH) as GDScript).new()
	var scene_pool_before: String = FileAccess.get_file_as_string("res://scenes/play_scene.tscn")
	var code_pool_before: String = FileAccess.get_file_as_string("res://scripts/scenes/play_scene.gd")
	var results: Array[Dictionary] = []
	for sample: Dictionary in SAMPLES:
		var metrics: Dictionary = _prepare_sample(sample)
		if not metrics.is_empty():
			results.append(metrics)
	_check(results.size() == 3, "三张样例均完成制作与检查")
	_check(FileAccess.get_file_as_string("res://scenes/play_scene.tscn") == scene_pool_before, "正式场景地图池未改变")
	_check(FileAccess.get_file_as_string("res://scripts/scenes/play_scene.gd") == code_pool_before, "默认地图池代码未改变")
	var report_path: String = "res://.godot/map_samples_report.json"
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(results, "\t"))
		file.close()
	print("样例地图指标：", JSON.stringify(results))
	print("三张样例地图编辑器检查：%d项，失败%d项；未启动游戏、未访问玩家存档。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _prepare_sample(sample: Dictionary) -> Dictionary:
	var config: Resource = load(str(sample["preset"])) as Resource
	_check(config != null and config.get_script() == settings_script, "样例配置加载：" + str(sample["preset"]))
	if config == null:
		return {}
	var draft: Dictionary = layout_script.new().call("generate", config)
	_check(draft["errors"].is_empty(), "样例布局有效：%s：%s" % [config.resource_name, draft["errors"]])
	if not draft["errors"].is_empty():
		return {}
	var path: String = str(sample["scene"])
	if not FileAccess.file_exists(path):
		if not _create_sample(draft, config, sample):
			return {}
	var packed: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	_check(packed != null, "样例场景可从磁盘重新加载：" + path)
	if packed == null:
		return {}
	var root: Node2D = packed.instantiate() as Node2D
	_check_saved_sample(root, draft, config, sample)
	_check_boundary(draft, root)
	_check_real_navigation(root, draft)
	_check_roundtrip(root)
	var result: Dictionary = _metrics(root, draft, config, path)
	root.free()
	return result


func _create_sample(draft: Dictionary, config: Resource, sample: Dictionary) -> bool:
	var built: Dictionary = builder.call("build", draft, config)
	_check(built.get("errors", []).is_empty() and built.has("root"), "样例实际瓦片绘制成功")
	if not built.has("root"):
		return false
	var root: Node2D = built["root"] as Node2D
	root.editor_description = str(sample["purpose"])
	root.set_meta("map_sample_name", config.resource_name)
	root.set_meta("map_sample_purpose", sample["purpose"])
	if int(config.get("layout_style")) == 2:
		var marker: Marker2D = Marker2D.new()
		marker.name = "BossSpawn"
		marker.position = (root.get_node("GroundLayer") as TileMapLayer).map_to_local(Vector2i.ZERO)
		root.get_node("SpawnPoints").add_child(marker)
		marker.owner = root
	var error: Error = builder.call("save_new_template", root, str(sample["scene"]), str(config.get("palette_scene")))
	_check(error == OK, "另存新样例，不覆盖任何已有模板：" + error_string(error))
	root.free()
	return error == OK


func _check_saved_sample(root: Node2D, draft: Dictionary, config: Resource, sample: Dictionary) -> void:
	_check(root.get_script().resource_path == MAP_PATH, "样例使用BattleMap运行脚本")
	_check(root.get("playable_area_cells").size() == draft["playable"].size(), "样例场内遮罩与原布局一致")
	_check(root.get_node("ObjectContainer").get_child_count() == 0, "样例不硬塞怪物或地图物件，仍由正常战斗链生成")
	_check(root.get_node("ObjectSpawnerFromTileMap").get("random_spawn_profile") != null, "保留随机物件及标签联动入口")
	_check(not root.has_node("BattleMapGenerator"), "实战进入模板时不会被生成器重画")
	var info: Dictionary = DebugBattleMapCatalog.read_info(str(sample["scene"]))
	_check(not info.is_empty() and str(info.get("label", "")).contains(str(config.get("seed_value"))), "调试台可识别样例及工坊种子")
	_check(DebugBattleMapCatalog.collect_paths().has(str(sample["scene"])), "样例自动进入调试台候选列表")
	if int(config.get("layout_style")) == 2:
		_check(root.has_node("SpawnPoints/BossSpawn"), "竞技场包含中央Boss位置标记")
		_check(draft["playable"].has(Vector2i.ZERO), "竞技场中央可行走")
		_check(Vector2i(draft["enemies"][0]) == Vector2i.ZERO, "竞技场第一个普通敌人标记也位于中央")


func _metrics(root: Node2D, draft: Dictionary, config: Resource, path: String) -> Dictionary:
	var distances: Dictionary = _grid_distances(draft["playable"], draft["player"])
	var shortest: int = 1000000
	var longest: int = 0
	for cell: Vector2i in draft["enemies"]:
		var distance: int = int(distances.get(cell, 1000000))
		shortest = mini(shortest, distance)
		longest = maxi(longest, distance)
	return {
		"name": config.resource_name, "path": path, "seed": config.get("seed_value"),
		"width": config.get("width"), "height": config.get("height"), "passage_width": config.get("passage_width"),
		"playable_cells": draft["playable"].size(), "enemy_markers": draft["enemies"].size(),
		"nearest_enemy_steps": shortest, "farthest_enemy_steps": longest,
		"boundary_shapes": root.get_node("GeneratedBoundary").get_child_count(),
	}


func _grid_distances(cells: Dictionary, start: Vector2i) -> Dictionary:
	var result: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var index: int = 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if cells.has(next) and not result.has(next):
				result[next] = int(result[cell]) + 1
				queue.append(next)
	return result
