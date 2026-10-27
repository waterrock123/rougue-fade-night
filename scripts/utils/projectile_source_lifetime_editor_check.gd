## 只在编辑器执行原调用函数的隔离回归：来源先释放时不能再进入steer；不启动战斗、不读写存档。
extends "res://scripts/utils/guiren_basic_attack_editor_check.gd"

const PROJECTILES: Array[String] = [
	"res://scripts/ability/manifest/projectile_manifest.gd",
	"res://scripts/ability/manifest/animated_projectile_manifest.gd",
]


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	for path: String in PROJECTILES:
		var script: Script = load(path) as Script
		_check(script != null and script.reload(true) == OK, "脚本解析：" + path)
		_check_source_states(path)
		_check_no_movement_after_cleanup(path)
	_check_selection()
	print("投射物来源生命周期编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _projectile_fixture(path: String) -> GDScript:
	var body: String = _function_source(path, "_get_valid_source") + _function_source(path, "_update_homing_direction")
	body = body.replace("Entity", "Node2D").replace("valid_source.is_dead", "bool(valid_source.get(\"is_dead\"))")
	var fields: String = "@tool\nextends Node2D\nvar source: Node2D\nvar runtime_homing_turn_speed: float = 5.0\nvar homing_controller: RefCounted\nvar target_group: StringName = &\"enemy\"\nvar current_dir: Vector2 = Vector2.RIGHT\nvar homing_acquire_radius: float = 500.0\nvar homing_retarget_interval: float = 0.12\nvar is_rotate: bool = false\nvar rotate_while_flying: bool = false\n"
	fields += "var homing_require_target_in_range: bool = false\n"
	if path == PROJECTILES[0]:
		body += _function_source(path, "_process_forward")
	else:
		body += _function_source(path, "_process")
	fields += "var speed: float = 100.0\nvar current_distance: float = 0.0\nvar max_distance: float = 1000.0\nvar return_to_source_after_max_distance: bool = false\nvar is_hit_finishing: bool = false\nvar rotate_speed: float = 10.0\nvar move_calls: int = 0\n"
	fields += "func _should_free_for_source_state() -> bool:\n\treturn false\nfunc _move_or_free_on_world_hit(_movement: Vector2) -> bool:\n\tmove_calls += 1\n\treturn true\nfunc _move_or_finish_on_world_hit(_movement: Vector2) -> bool:\n\tmove_calls += 1\n\treturn true\nfunc _begin_returning() -> void:\n\tpass\nfunc _notify_resolution(_reason: StringName) -> void:\n\tpass\n"
	return _fixture(fields + body)


func _homing_probe() -> RefCounted:
	# 保留强类型来源参数；若调用端再次传入freed引用，测试会直接暴露同样的类型错误。
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar calls: int = 0\nvar resets: int = 0\nfunc reset() -> void:\n\tresets += 1\nfunc steer(_projectile: Node2D, _source: Node2D, _group: StringName, _direction: Vector2, _turn: float, _radius: float, _interval: float, _delta: float, _require_range: bool = false) -> Vector2:\n\tcalls += 1\n\treturn Vector2.UP\n")
	return script.new() if script != null else null


func _actor() -> Node2D:
	var script: GDScript = _fixture("@tool\nextends Node2D\nvar is_dead: bool = false\n")
	return script.new() if script != null else null


func _check_source_states(path: String) -> void:
	var script: GDScript = _projectile_fixture(path)
	if script == null:
		return
	var tree_root: Node = EditorInterface.get_base_control().get_tree().root
	for state: String in ["live", "freed", "queued", "detached", "dead", "null"]:
		var projectile: Node2D = script.new()
		var probe: RefCounted = _homing_probe()
		var actor: Node2D = _actor()
		tree_root.add_child(projectile)
		if state != "detached":
			tree_root.add_child(actor)
		projectile.set("source", actor if state != "null" else null)
		projectile.set("homing_controller", probe)
		match state:
			"freed": actor.free()
			"queued": actor.queue_free()
			"dead": actor.set("is_dead", true)
		projectile.call("_update_homing_direction", 0.05)
		_check(int(probe.get("calls")) == (1 if state == "live" else 0), "强类型steer入口：" + state)
		_check(projectile.is_queued_for_deletion() == (state != "live"), "残留投射物清理：" + state)
		if state != "live":
			_check(probe.get("resets") == 1, "失效时清空追踪目标：" + state)
		else:
			_check(projectile.get("current_dir") == Vector2.UP, "有效来源仍可正常追踪")
		projectile.free()
		if is_instance_valid(actor):
			actor.free()


func _check_no_movement_after_cleanup(path: String) -> void:
	var script: GDScript = _projectile_fixture(path)
	if script == null:
		return
	var projectile: Node2D = script.new()
	var actor: Node2D = _actor()
	projectile.set("source", actor)
	projectile.set("homing_controller", _homing_probe())
	EditorInterface.get_base_control().get_tree().root.add_child(projectile)
	actor.free()
	projectile.call("_process_forward" if path == PROJECTILES[0] else "_process", 0.1)
	_check(projectile.is_queued_for_deletion(), "飞行更新遇到释放来源时销毁")
	_check(projectile.get("current_distance") == 0.0 and projectile.get("move_calls") == 0, "清理后同帧不再推进/碰撞/触发射程结算")
	projectile.free()
