## 编辑器隔离回归：执行实际检查点/保存分流函数，不启动游戏，不访问真实玩家存档。
extends "res://scripts/utils/guiren_basic_attack_editor_check.gd"

const CHECKPOINT: String = "res://scripts/run/event_entry_checkpoint.gd"
const RUN_SCRIPT: String = "res://scripts/run/run.gd"
const SAVE_SCRIPT: String = "res://scripts/autoload/save_manager.gd"


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	for path: String in [CHECKPOINT, RUN_SCRIPT, SAVE_SCRIPT]:
		var script: Script = load(path) as Script
		_check(script != null and script.reload(true) == OK, "脚本解析：" + path)
	_check_snapshot_isolation()
	_check_save_routing()
	_check_rng_precision()
	_check_repeated_continue()
	_check_legacy_save()
	_check_entry_order()
	print("事件入房检查点编辑器检查：%d项，失败%d项；未启动游戏、未访问玩家存档。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _entry_data() -> Dictionary:
	return {
		"version": 1, "flow_state": "event_room", "rng": {"seed": 654321, "state": 12345},
		"current_room": {"row": 0, "column": 1},
		"map": {"rooms": [{"event_scene_path": "treasure_room.tscn"}]},
		"level_up_rewards": [],
		"run_stats": {
			"gold": 8, "current_floor_index": 0, "current_battle_map_template_path": "",
			"player_build": {"inventory": ["bucket"], "equipment": ["sword"], "health": 30, "speed": 100},
			"pending_bounty_enemy_entries": [], "pending_free_relic_choice_levels": [],
			"persistent_passive_counters": {"kills": 2}, "shop": {"keeper": "a", "slots": ["milk"]},
		},
	}


func _mutate_after_choice(data: Dictionary) -> void:
	var stats: Dictionary = data["run_stats"]
	stats["gold"] += 6
	stats["player_build"]["inventory"].append("reward")
	stats["player_build"]["equipment"].clear()
	stats["player_build"]["health"] -= 5
	stats["player_build"]["speed"] -= 4
	stats["pending_bounty_enemy_entries"].append("robot")
	stats["pending_free_relic_choice_levels"].append(3)
	stats["persistent_passive_counters"]["kills"] += 1
	stats["shop"]["slots"].clear()
	data["rng"]["state"] += 100
	data["map"]["rooms"][0]["event_scene_path"] = "changed.tscn"


func _check_snapshot_isolation() -> void:
	var checkpoint: RefCounted = (load(CHECKPOINT) as GDScript).new()
	var live: Dictionary = _entry_data()
	var expected: Dictionary = live.duplicate(true)
	checkpoint.call("capture", live)
	_mutate_after_choice(live)
	var saved: Dictionary = checkpoint.call("build_save_data", expected["current_room"], 0, "grass_corridor_01.tscn")
	var expected_stats: Dictionary = expected["run_stats"].duplicate(true)
	expected_stats["current_battle_map_template_path"] = "grass_corridor_01.tscn"
	_check(saved["run_stats"] == expected_stats, "金币、奖励、装备消耗、扣血、减速、商人、计数与待结算奖励全部回退")
	_check(saved["rng"] == expected["rng"], "事件与战斗后的随机数不会覆盖入房随机状态")
	_check(saved["map"] == expected["map"], "地图事件数据独立复制")
	_check(saved["replay_event"] and saved["event_checkpoint_version"] == 1, "新检查点恢复事件起点")
	saved["run_stats"]["player_build"]["inventory"].clear()
	saved["rng"]["state"] = 0
	var again: Dictionary = checkpoint.call("build_save_data", expected["current_room"], 0, "")
	_check(again["run_stats"] == expected["run_stats"] and again["rng"] == expected["rng"], "修改保存返回值不会污染冻结快照")
	_check(checkpoint.call("build_save_data", {"row": 0, "column": 2}, 0, "").is_empty(), "禁止跨房间使用旧快照")
	_check(checkpoint.call("build_save_data", expected["current_room"], 1, "").is_empty(), "禁止跨楼层使用同坐标快照")
	checkpoint.call("clear")
	_check(checkpoint.call("build_save_data", expected["current_room"], 0, "").is_empty(), "清理后不能误用旧检查点")


func _save_fixture() -> RefCounted:
	var body: String = ""
	for method: String in ["save_run", "_get_run_save_data", "build_run_snapshot", "_serialize_rng_state"]:
		body += _function_source(SAVE_SCRIPT, method).strip_edges() + "\n\n"
	body = body.replace("run: Run", "run: RefCounted").replace("Run.FLOW_EVENT_ROOM", "\"event_room\"")
	body = body.replace("RunRng.get_save_data()", "fixture_rng")
	var source: String = "@tool\nextends RefCounted\nconst SAVE_VERSION = 1\nvar fixture_rng = {}\nvar written = {}\nvar writes = 0\n"
	source += "func _serialize_run_stats(stats):\n\treturn stats\nfunc _serialize_room_key(room):\n\treturn room\nfunc _serialize_level_up_rewards(rewards):\n\treturn rewards\n"
	source += "func _write_save_data(data: Dictionary) -> bool:\n\twritten = data.duplicate(true)\n\twrites += 1\n\treturn true\n"
	var script: GDScript = _fixture(source + body)
	return script.new() if script != null else null


func _run_fixture(manager: RefCounted) -> RefCounted:
	var source: String = "@tool\nextends RefCounted\nconst FLOW_MAP = \"map\"\nconst FLOW_EVENT_ROOM = \"event_room\"\nconst FLOW_LEVEL_UP = \"level_up\"\nconst FLOW_STARTING_SKILL = \"starting_skill\"\nconst FLOW_REST_PERIOD = \"rest_period\"\n"
	source += "var run_stats\nvar current_room\nvar map\nvar debug_next_battle_map_template_path = \"\"\nvar level_up_reward_options = []\nvar current_flow_state = FLOW_EVENT_ROOM\nvar pending_flow_state = FLOW_EVENT_ROOM\nvar level_up_checkpoint_locked = false\nvar save_manager\nvar event_entry_checkpoint\nvar opened = \"\"\n"
	source += "func _open_event_room(_room):\n\topened = \"event\"\nfunc _open_battle_scene(_room):\n\topened = \"battle\"\n"
	source += "func change_to_level_up():\n\topened = \"level_up\"\nfunc change_to_starting_skill_select():\n\tpass\nfunc change_to_rest_period(_restore):\n\tpass\n"
	for method: String in ["get_event_checkpoint_save_data", "_save_current_run", "_restore_saved_flow_view"]:
		source += _function_source(RUN_SCRIPT, method).replace("SaveManager.", "save_manager.").strip_edges() + "\n\n"
	var script: GDScript = _fixture(source)
	if script == null:
		return null
	var helper: RefCounted = script.new()
	_check(helper.has_method("_restore_saved_flow_view"), "恢复流程函数成功纳入隔离夹具")
	helper.set("save_manager", manager)
	helper.set("event_entry_checkpoint", (load(CHECKPOINT) as GDScript).new())
	return helper


func _check_save_routing() -> void:
	var manager: RefCounted = _save_fixture()
	var helper: RefCounted = _run_fixture(manager)
	if manager == null or helper == null:
		return
	var entry: Dictionary = _entry_data()
	helper.set("run_stats", entry["run_stats"])
	helper.set("current_room", entry["current_room"])
	manager.set("fixture_rng", entry["rng"])
	var snapshot: Dictionary = manager.call("build_run_snapshot", helper)
	helper.get("event_entry_checkpoint").call("capture", snapshot)
	_mutate_after_choice(entry)
	_check(snapshot["run_stats"]["gold"] == 8 and int(snapshot["rng"]["state"]) == 12345, "SaveManager生成快照时已隔离运行时引用")
	helper.get("run_stats")["current_battle_map_template_path"] = "selected.tscn"
	helper.call("_save_current_run", false)
	_check(manager.get("writes") == 0, "普通事件保存不覆盖检查点")
	helper.call("_save_current_run", true)
	var written: Dictionary = manager.get("written")
	_check(manager.get("writes") == 1 and written["run_stats"]["gold"] == 8, "入战强制保存仍使用入房金币")
	_check(written["run_stats"]["current_battle_map_template_path"] == "selected.tscn", "入战强制保存可补记地图模板")
	_check(written["run_stats"]["player_build"]["inventory"] == ["bucket"], "强制保存不会保留事件装备奖励")
	manager.call("save_run", helper)
	_check(manager.get("writes") == 2 and int(manager.get("written")["rng"]["state"]) == 12345, "直接调用SaveManager也不能绕过检查点")
	_check_victory_save(helper, manager)


func _check_victory_save(helper: RefCounted, manager: RefCounted) -> void:
	helper.set("current_flow_state", "level_up")
	helper.set("level_up_reward_options", [{"id": "fixed_reward"}])
	helper.call("_save_current_run", true)
	var written: Dictionary = manager.get("written")
	_check(written["flow_state"] == "level_up" and written["run_stats"]["gold"] == 14, "胜利后保存当前事件收益，不再回退")
	_check(written["level_up_rewards"] == [{"id": "fixed_reward"}], "升级奖励选项随胜利检查点保留")
	_check(not written.has("event_checkpoint_version"), "胜利存档不混入入房恢复标记")
	helper.set("level_up_checkpoint_locked", true)
	helper.get("run_stats")["gold"] = 0
	helper.call("_save_current_run", false)
	_check(manager.get("written")["run_stats"]["gold"] == 14, "胜利后原有奖励检查点锁仍有效")
	helper.set("current_flow_state", "event_room")
	helper.set("level_up_checkpoint_locked", false)
	_check(helper.call("get_event_checkpoint_save_data").is_empty(), "胜利后清理旧入房快照，缺失时拒绝污染保存")


func _check_rng_precision() -> void:
	var manager: RefCounted = _save_fixture()
	if manager == null:
		return
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = 654321
	generator.randf()
	var state: int = generator.state
	manager.set("fixture_rng", {"seed": generator.seed, "state": state})
	var serialized: Dictionary = manager.call("_serialize_rng_state")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(serialized))
	_check(parsed["state"] is String and int(parsed["state"]) == state, "64位随机状态经过JSON后无精度损失")
	var restored: RandomNumberGenerator = RandomNumberGenerator.new()
	restored.seed = int(parsed["seed"])
	restored.state = int(parsed["state"])
	for index: int in range(8):
		_check(restored.randi() == generator.randi(), "续档后事件随机序列一致：%d" % index)


func _check_repeated_continue() -> void:
	var checkpoint: RefCounted = (load(CHECKPOINT) as GDScript).new()
	var entry: Dictionary = _entry_data()
	checkpoint.call("capture", entry)
	for attempt: int in range(4):
		var saved: Dictionary = checkpoint.call("build_save_data", entry["current_room"], 0, "selected.tscn")
		# 模拟JSON读回；不能依赖字典整型/浮点型差异判断房间身份。
		var parsed: Dictionary = JSON.parse_string(JSON.stringify(saved))
		checkpoint.call("restore", parsed)
		_mutate_after_choice(parsed)
		var again: Dictionary = checkpoint.call("build_save_data", entry["current_room"], 0, "selected.tscn")
		_check(not again.is_empty(), "JSON读回后房间身份匹配：%d" % attempt)
		if again.is_empty():
			return
		_check(again["run_stats"]["gold"] == 8 and again["run_stats"]["player_build"]["inventory"] == ["bucket"], "连续退出续档不累积奖励：%d" % attempt)
		_check(again["rng"]["state"] == 12345 and again["run_stats"]["current_battle_map_template_path"] == "selected.tscn", "连续续档保留入房RNG与已选地图：%d" % attempt)


func _check_legacy_save() -> void:
	var manager: RefCounted = _save_fixture()
	var helper: RefCounted = _run_fixture(manager)
	if helper == null:
		return
	var checkpoint: RefCounted = helper.get("event_entry_checkpoint")
	var legacy: Dictionary = _entry_data()
	helper.set("current_room", legacy["current_room"])
	checkpoint.call("restore", legacy)
	helper.call("_restore_saved_flow_view")
	_check(helper.get("opened") == "event", "旧版未入战的检查点仍恢复事件")
	legacy["run_stats"]["current_battle_map_template_path"] = "selected.tscn"
	_mutate_after_choice(legacy)
	checkpoint.call("restore", legacy)
	helper.call("_restore_saved_flow_view")
	_check(helper.get("opened") == "battle", "旧版已入战存档直接续战，阻止重复事件奖励")
	var migrated: Dictionary = checkpoint.call("build_save_data", legacy["current_room"], 0, "selected.tscn")
	checkpoint.call("restore", migrated)
	_check(not checkpoint.call("should_replay_event"), "旧档迁移后的续战规则可再次保存恢复")
	checkpoint.call("capture", _entry_data())
	helper.call("_restore_saved_flow_view")
	_check(helper.get("opened") == "event", "下一间新房间恢复正常事件检查点规则")


func _check_entry_order() -> void:
	var selected: String = _function_source(RUN_SCRIPT, "_on_map_room_selected")
	_check(selected.find("event_entry_checkpoint.capture(") < selected.find("_save_current_run(true)"), "入房先冻结后保存")
	_check(selected.find("_save_current_run(true)") < selected.find("_open_event_room(room)"), "入房先保存后执行事件ready/setup")
	var continued: String = _function_source(RUN_SCRIPT, "_initialize_continued_run")
	_check(continued.contains("event_entry_checkpoint.restore(save_data)"), "续档恢复原始快照，不从已初始化构筑重新捕获")
	var ready: String = _function_source(RUN_SCRIPT, "_ready")
	_check(ready.find("_initialize_run_state()") < ready.find("_initialize_runtime_proxy()"), "续档检查点在装备初始化副作用前恢复")
