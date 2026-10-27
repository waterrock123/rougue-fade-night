## 编辑器隔离回归：不启动战斗，存档测试全部使用内存字典。
extends "res://scripts/utils/guiren_basic_attack_editor_check.gd"

const CATALOG_SCRIPT: String = "res://scripts/battlemap/debug_battle_map_catalog.gd"
const RUN_PATH: String = "res://scripts/run/run.gd"
const SAVE_PATH: String = "res://scripts/autoload/save_manager.gd"
const UI_PATH: String = "res://scripts/ui/debug_console.gd"
const MAP_A: String = "res://scenes/battlemap/templates/grass_open_01.tscn"
const MAP_B: String = "res://scenes/battlemap/templates/grass_corridor_01.tscn"
const MAP_C: String = "res://scenes/battlemap/templates/grass_center_wall_01.tscn"
var completed: int = 0


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	for path: String in [CATALOG_SCRIPT, RUN_PATH, SAVE_PATH, UI_PATH]:
		var script: GDScript = load(path) as GDScript
		_check(script != null and script.reload(true) == OK, "脚本解析：" + path)
	_check_catalog()
	_check_override()
	_check_saved_checkpoint()
	_check_ui()
	_check(completed == 4, "全部检查分支执行完成")
	print("下场战斗地图调试编辑器检查：%d项，失败%d项；未启动游戏、未访问玩家存档。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _methods(path: String, names: Array) -> String:
	var result: String = ""
	for method: String in names:
		result += _function_source(path, method).strip_edges() + "\n\n"
	return result


func _checkpoint_data() -> Dictionary:
	return {"flow_state": "event_room", "rng": {"seed": "654321", "state": "12345"}, "level_up_rewards": [{"id": "fixed"}], "current_room": {"row": 0, "column": 1}, "run_stats": {"gold": 6, "current_floor_index": 0, "current_battle_map_template_path": "", "inventory": ["bucket"]}}


func _memory_saver() -> RefCounted:
	var source: String = "@tool\nextends RefCounted\nvar saved = {}\nvar writes = 0\nfunc load_save_data() -> Dictionary:\n\treturn saved.duplicate(true)\nfunc _write_save_data(data: Dictionary) -> bool:\n\tsaved = data.duplicate(true)\n\twrites += 1\n\treturn true\n"
	var script: GDScript = _fixture(source + _methods(SAVE_PATH, ["save_debug_battle_map_override"]))
	if script == null:
		return null
	var result: RefCounted = script.new()
	result.set("saved", _checkpoint_data())
	return result


func _map_run(saver: RefCounted, training: bool = false) -> RefCounted:
	var source: String = "@tool\nextends RefCounted\nvar debug_next_battle_map_template_path = \"\"\nvar save_manager\nvar run_stats = {\"gold\": 999, \"current_floor_index\": 0, \"current_battle_map_template_path\": \"\"}\nvar current_room = {\"row\": 0, \"column\": 1}\nvar event_entry_checkpoint\n"
	source += _methods(RUN_PATH, ["set_debug_next_battle_map_template", "clear_debug_next_battle_map_template", "get_debug_next_battle_map_template", "_persist_debug_battle_map_override", "_prepare_debug_battle_map_override", "get_event_checkpoint_save_data"]).replace("SaveManager.", "save_manager.")
	source += _methods("res://scripts/hub/training_room.gd" if training else RUN_PATH, ["can_debug_battle_map_override"])
	var script: GDScript = _fixture(source)
	if script == null:
		return null
	var result: RefCounted = script.new()
	result.set("save_manager", saver)
	result.set("event_entry_checkpoint", (load("res://scripts/run/event_entry_checkpoint.gd") as GDScript).new())
	return result


func _check_catalog() -> void:
	var paths: Array[String] = DebugBattleMapCatalog.collect_paths()
	_check(paths.has(MAP_A) and paths.has(MAP_B), "自动扫描现有模板")
	for path: String in [MAP_A, MAP_B, MAP_C]:
		var info: Dictionary = DebugBattleMapCatalog.read_info(path)
		_check(info.get("path", "") == path and not str(info.get("label", "")).is_empty(), "读取BattleMap元数据：" + path.get_file())
	_check(not DebugBattleMapCatalog.is_battle_map("res://scenes/ability/tree_bark_armor.tscn"), "排除非地图场景")
	_check(not DebugBattleMapCatalog.is_battle_map("res://missing.tscn"), "排除缺失资源")
	_check(not DebugBattleMapCatalog.is_battle_map("res://scenes/../play_scene.tscn"), "拒绝目录跳转路径")
	var source: String = FileAccess.get_file_as_string(CATALOG_SCRIPT)
	_check(not source.contains(".instantiate("), "扫描地图不实例化怪物、物件或地图")
	completed += 1


func _check_override() -> void:
	var saver: RefCounted = _memory_saver()
	var helper: RefCounted = _map_run(saver)
	if helper == null:
		return
	var play_script: GDScript = _fixture("@tool\nextends Node\nvar use_battle_map_templates = true\n")
	if play_script == null:
		return
	var play: Node = play_script.new()
	_check(helper.call("set_debug_next_battle_map_template", "  " + MAP_A + "  "), "设置合法地图并去掉空格")
	_check(not helper.call("set_debug_next_battle_map_template", "res://scenes/ability/tree_bark_armor.tscn"), "错误场景不替换原有待测试地图")
	_check(helper.call("get_debug_next_battle_map_template") == MAP_A, "拒绝错误设置后保留原选择")
	helper.call("_prepare_debug_battle_map_override", play)
	_check(helper.get("run_stats")["current_battle_map_template_path"] == MAP_A and helper.call("get_debug_next_battle_map_template") == "", "新战斗消费覆盖恰好一次")
	helper.call("set_debug_next_battle_map_template", MAP_B)
	helper.call("_prepare_debug_battle_map_override", play)
	_check(helper.get("run_stats")["current_battle_map_template_path"] == MAP_A and helper.call("get_debug_next_battle_map_template") == MAP_B, "已锁定房间不换图，新的覆盖留待下一场")
	_check_resolver_priority(helper.get("run_stats"))
	helper.get("run_stats")["current_battle_map_template_path"] = ""
	play.set("use_battle_map_templates", false)
	helper.call("_prepare_debug_battle_map_override", play)
	_check(helper.call("get_debug_next_battle_map_template") == MAP_B, "禁用模板的场次不吞掉待测试地图")
	play.set("use_battle_map_templates", true)
	helper.call("_prepare_debug_battle_map_override", play)
	_check(helper.get("run_stats")["current_battle_map_template_path"] == MAP_B and helper.call("get_debug_next_battle_map_template") == "", "下一场使用B后恢复正常规则")
	helper.call("set_debug_next_battle_map_template", MAP_C)
	helper.call("clear_debug_next_battle_map_template")
	_check(helper.call("get_debug_next_battle_map_template") == "" and helper.get("run_stats")["current_battle_map_template_path"] == MAP_B, "取消只清待测试配置，不清本房地图")
	helper.get("run_stats")["current_battle_map_template_path"] = ""
	helper.set("debug_next_battle_map_template_path", "res://missing.tscn")
	helper.call("_prepare_debug_battle_map_override", play)
	_check(helper.call("get_debug_next_battle_map_template") == "" and helper.get("run_stats")["current_battle_map_template_path"] == "", "已丢失模板安全失效，不污染本房模板")
	play.free()
	_check_training_guard(saver)
	completed += 1


func _check_training_guard(saver: RefCounted) -> void:
	var helper: RefCounted = _map_run(saver, true)
	if helper == null:
		return
	var before: Dictionary = saver.get("saved").duplicate(true)
	var writes: int = int(saver.get("writes"))
	_check(not helper.call("set_debug_next_battle_map_template", MAP_A), "训练场拒绝地图覆盖")
	helper.call("clear_debug_next_battle_map_template")
	helper.call("_persist_debug_battle_map_override")
	_check(saver.get("saved") == before and int(saver.get("writes")) == writes, "训练场设置、取消与直接保存均不触碰正式存档")


func _check_resolver_priority(stats: Dictionary) -> void:
	var body: String = _methods("res://scripts/scenes/play_scene.gd", ["_resolve_battle_map_template_path"])
	body = body.replace("var battle_data: BattleStats =", "var battle_data: Variant =").replace("RunRng.pick(valid_paths)", "_pick(valid_paths)")
	var source: String = "@tool\nextends RefCounted\nvar run_stats\nvar pending_battle_stats = {\"battle_map_template_path\": \"" + MAP_C + "\"}\nvar enemy_spawner\nvar picks = 0\nfunc _get_valid_battle_map_template_paths() -> Array[String]:\n\treturn [\"" + MAP_B + "\"]\nfunc _pick(paths):\n\tpicks += 1\n\treturn paths[0]\n"
	var script: GDScript = _fixture(source + body)
	if script == null:
		return
	var resolver: RefCounted = script.new()
	resolver.set("run_stats", stats)
	_check(resolver.call("_resolve_battle_map_template_path") == MAP_A and resolver.get("picks") == 0, "调试模板优先于Boss固定地图，且不消耗随机抽图")
	resolver.set("run_stats", {"current_battle_map_template_path": ""})
	_check(resolver.call("_resolve_battle_map_template_path") == MAP_C, "无覆盖时Boss仍使用原固定模板")
	resolver.set("pending_battle_stats", {"battle_map_template_path": ""})
	resolver.set("run_stats", {"current_battle_map_template_path": ""})
	_check(resolver.call("_resolve_battle_map_template_path") == MAP_B and resolver.get("picks") == 1, "无覆盖及固定图时恢复原随机池")


func _check_saved_checkpoint() -> void:
	var saver: RefCounted = _memory_saver()
	var helper: RefCounted = _map_run(saver)
	if helper == null:
		return
	var before: Dictionary = saver.get("saved").duplicate(true)
	helper.call("set_debug_next_battle_map_template", MAP_B)
	var after: Dictionary = saver.get("saved")
	_check(after["run_stats"] == before["run_stats"] and after["rng"] == before["rng"] and after["level_up_rewards"] == before["level_up_rewards"], "设置调试地图不会把当前金币999写入金币6的事件或升级检查点")
	_check(after["debug_next_battle_map_template_path"] == MAP_B, "待测试配置可独立保存")
	helper.get("event_entry_checkpoint").call("capture", before)
	helper.get("run_stats")["current_battle_map_template_path"] = MAP_A
	for attempt: int in range(3):
		var snapshot: Dictionary = helper.call("get_event_checkpoint_save_data")
		var parsed: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
		_check(parsed["run_stats"]["gold"] == 6 and parsed["run_stats"]["current_battle_map_template_path"] == MAP_A, "续档保留入房奖励回退和本房地图：%d" % attempt)
		_check(parsed["debug_next_battle_map_template_path"] == MAP_B, "本房之外的下一场覆盖可跨续档保留：%d" % attempt)
		helper.get("event_entry_checkpoint").call("restore", parsed)
	helper.call("clear_debug_next_battle_map_template")
	_check(saver.get("saved")["debug_next_battle_map_template_path"] == "" and saver.get("saved")["run_stats"] == before["run_stats"], "取消覆盖也只补写调试字段")
	_check(_function_source(RUN_PATH, "_initialize_continued_run").contains("save_data.get(\"debug_next_battle_map_template_path\", \"\")"), "旧档缺少新字段时默认正常随机规则")
	var open_battle: String = _function_source(RUN_PATH, "_open_battle_scene")
	_check(open_battle.find("_prepare_debug_battle_map_override(play_scene)") < open_battle.find("_replace_current_view(play_scene)"), "覆盖设置早于战斗ready及模板选择")
	completed += 1


func _check_ui() -> void:
	var scene: PackedScene = load("res://scenes/ui/debug_console.tscn") as PackedScene
	var console: Control = scene.instantiate() as Control
	for name: String in ["BattleMapOption", "SetBattleMapButton", "ClearBattleMapButton", "ReloadBattleMapsButton"]:
		_check(console.has_node("Panel/MarginContainer/VBoxContainer/BattleMapOverride/MapRow/" + name), "UI节点存在：" + name)
	var option: OptionButton = console.get_node("Panel/MarginContainer/VBoxContainer/BattleMapOverride/MapRow/BattleMapOption")
	_check(option.clip_text and not option.fit_to_longest_item, "长地图文件名不会撑宽调试面板")
	var panel: Control = console.get_node("Panel")
	_check(panel.get_combined_minimum_size().y <= 1020.0, "新增选项后调试面板仍能容纳在1080高度窗口")
	var source: String = _function_source(UI_PATH, "open_panel")
	_check(source.contains("DebugBattleMapCatalog.collect_paths() != battle_map_catalog_paths"), "重新打开调试台可发现工坊新保存的地图")
	console.free()
	completed += 1
