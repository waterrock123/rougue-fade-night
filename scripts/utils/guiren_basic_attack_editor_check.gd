## 仅编辑器资源检查与实际函数的隔离测试，不启动战斗、不读写存档。
extends SceneTree

const HOMING: String = "res://scripts/ability/manifest/projectile_homing_controller.gd"
const AIM: String = "res://scripts/ability/component/ability_lock_nearest_target_direction.gd"
const VOLLEY: String = "res://scripts/ability/component/ability_spawn_manifest_volley.gd"
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	for path: String in [HOMING, AIM, VOLLEY]:
		var script: Script = load(path) as Script
		_check(script != null and script.reload(true) == OK, "脚本解析：" + path)
	_check_resources()
	_check_missile_feel()
	_check_selection()
	_check_aim()
	_check_volley()
	print("贵人普攻编辑器检查：%d项，失败%d项；未启动战斗。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_resources() -> void:
	var skill: Resource = load("res://activate_skill/112_basic_guiren_attack.tres") as Resource
	_check(skill != null, "主动技能资源加载")
	if skill == null:
		return
	_check(skill.get("id") == &"112" and skill.get("is_basic_attack"), "独立编号及基础攻击标志")
	_check(skill.get("base_cooldown") == 0.65 and skill.get("base_energy_cost") == 3.0, "基础冷却0.65秒与3能量")
	var owners: Array = skill.get("allowed_character_ids")
	_check(owners.size() == 1 and owners[0] == &"wizard", "仅贵人归属")
	_check(skill.get("icon") != null, "技能图标可用")
	var character: Resource = load("res://character_resource/wizard/wizard.tres") as Resource
	_check(character.get("start_skill").get("skill_data") == skill, "贵人开局获得基础攻击")
	var scene: PackedScene = skill.get("ability_scene") as PackedScene
	var ability: Node = scene.instantiate()
	_check(ability.get("cooldown") == 0.65 and ability.get("energy_cost") == 3.0, "场景默认值与SkillData一致")
	var volley: Node = ability.get_node("MissileVolley")
	_check(volley.get("base_projectile_count") == 3 and volley.get("attacks_before_bonus") == 0, "每次固定三枚，不累计额外弹")
	_check(volley.get("side_spacing") == 0.0 and volley.get("spread_angle_degrees") == 20.0, "三枚以夹角展开，而非横向并列")
	_check(ability.get_node("LockNearestTarget").get("acquire_radius") == 160.0, "初始瞄准也不锁定远处目标")
	_check(volley.get("exec_delay") == 0.0, "同时发射，无延迟连射")
	_check(ability.get_child(0).name == &"LockNearestTarget", "先锁定方向再播放动画和发射")
	var projectile: Node = (volley.get("manifest_scene") as PackedScene).instantiate()
	_check(projectile.get("damage") == 3.0, "每枚基础伤害3")
	_check(not projectile.get("scaling_rule").get("enabled"), "不额外添加敏捷或智力加成")
	_check(not projectile.get("is_penetrate") and projectile.get("blocked_by_world"), "不穿透且撞墙销毁")
	_check(projectile.get("homing_turn_speed") > 0.0 and projectile.get("target_group") == "enemy", "飞行中自动追踪敌人")
	_check(projectile.get("max_distance") == 600.0 and projectile.get("homing_acquire_radius") == 160.0, "保留远射程，但仅近距离索敌")
	_check(projectile.get("homing_require_target_in_range"), "目标离开范围后解除追踪")
	_check(projectile.get_node("Area2D").get_signal_connection_list("area_entered").size() == 1, "命中接入统一伤害链")
	_check(projectile.has_node("Sprite2D") and projectile.has_node("Trail"), "弹体和拖尾可见节点")
	projectile.free()
	ability.free()


func _check_missile_feel() -> void:
	var scene: PackedScene = load("res://scenes/ability/manifest/guiren_magic_missile_manifest.tscn") as PackedScene
	_check(scene != null, "魔法飞弹场景可加载")
	if scene == null:
		return
	var projectile: Node = scene.instantiate()
	var trail: Line2D = projectile.get_node("Trail") as Line2D
	_check(projectile.get("speed") == 180.0, "魔法飞弹减速至180")
	_check(projectile.get("homing_turn_speed") == 2.5, "弱追踪转向速度2.5")
	_check(is_equal_approx(float(trail.get("trail_width")), 1.2), "拖尾最大宽度1.2")
	_check(trail.width_curve != null, "拖尾配置独立宽度曲线")
	if trail.width_curve != null:
		# 拖尾按历史坐标从旧到新排列：曲线0是尾端，1才是弹体前端，不能反过来。
		_check(trail.width_curve.sample(0.0) == 0.0 and trail.width_curve.sample(1.0) == 1.0, "尾端收尖、前端较粗")
		_check(trail.width_curve.sample(0.25) < trail.width_curve.sample(0.75), "宽度沿尾端到弹体方向渐增")
	_check(trail.end_cap_mode == Line2D.LINE_CAP_ROUND, "弹体连接端使用圆头")
	_check(trail.get("max_points") == 12 and trail.get("point_distance") == 2.0, "拖尾采样更细且长度受限")
	projectile.free()


func _check_selection() -> void:
	# 使用原筛选函数，只将场景树查询替换为可控候选列表，避免运行游戏实体。
	var body: String = _function_source(HOMING, "steer") + _function_source(HOMING, "_find_nearest_target") + _function_source(HOMING, "_is_valid_target")
	body = body.replace("not projectile.is_inside_tree()", "false")
	body = body.replace("Entity", "Node2D").replace("projectile.get_tree().get_nodes_in_group(String(target_group))", "candidates")
	body = body.replace("candidate.is_dead", "candidate.get(\"is_dead\")")
	body = body.replace("candidate.can_be_targeted()", "candidate.call(\"can_be_targeted\")")
	body = body.replace("candidate.is_neutral_bounty_elite()", "candidate.call(\"is_neutral_bounty_elite\")")
	body = body.replace("candidate.matches_target_group(target_group)", "candidate.call(\"matches_target_group\", target_group)")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar candidates: Array[Node] = []\nvar current_target: Node2D\nvar retarget_timer: float = 0.0\n" + body)
	var actor_script: GDScript = _fixture("@tool\nextends Node2D\nvar is_dead: bool = false\nvar neutral: bool = false\nvar targetable: bool = true\nvar faction: StringName = &\"enemy\"\nfunc can_be_targeted() -> bool:\n\treturn targetable\nfunc is_neutral_bounty_elite() -> bool:\n\treturn neutral\nfunc matches_target_group(group: StringName) -> bool:\n\treturn faction == group\n")
	if script == null or actor_script == null:
		return
	var helper: RefCounted = script.new()
	var source: Node2D = actor_script.new()
	var near: Node2D = actor_script.new()
	var far: Node2D = actor_script.new()
	near.position = Vector2(-20, 0)
	far.position = Vector2(100, 0)
	var candidates: Array[Node] = [far, source, near]
	helper.set("candidates", candidates)
	_check(helper.call("_find_nearest_target", source, source, &"enemy", 600.0) == near, "最近目标在背后也能锁定")
	for property: String in ["is_dead", "neutral"]:
		near.set(property, true)
		_check(helper.call("_find_nearest_target", source, source, &"enemy", 600.0) == far, "排除目标：" + property)
		near.set(property, false)
	near.set("targetable", false)
	_check(helper.call("_find_nearest_target", source, source, &"enemy", 600.0) == far, "排除不可选中目标")
	far.position = Vector2(700, 0)
	_check(helper.call("_find_nearest_target", source, source, &"enemy", 600.0) == null, "范围内没有有效敌人")
	_check_retarget_after_free(helper, source, near, far)
	_check_homing_range(helper, source, far)
	far.free()
	source.free()


func _check_retarget_after_free(helper: RefCounted, source: Node2D, near: Node2D, far: Node2D) -> void:
	# 模拟第一枚飞弹击杀目标，其他飞弹继续索敌；不把已释放对象传入强类型参数。
	far.position = Vector2(100, 0)
	var remaining: Array[Node] = [far, source]
	helper.set("candidates", remaining)
	helper.set("current_target", near)
	near.free()
	var direction: Vector2 = helper.call("steer", source, source, &"enemy", Vector2.UP, 12.0, 600.0, 0.12, 0.5)
	_check(direction.is_equal_approx(Vector2.RIGHT) and helper.get("current_target") == far, "目标释放后安全重新索敌")


func _check_homing_range(helper: RefCounted, projectile: Node2D, enemy: Node2D) -> void:
	projectile.position = Vector2.ZERO
	enemy.position = Vector2(300, 0)
	helper.set("current_target", null)
	helper.set("retarget_timer", 0.0)
	var direction: Vector2 = helper.call("steer", projectile, projectile, &"enemy", Vector2.UP, 2.5, 160.0, 0.12, 0.1, true)
	_check(direction == Vector2.UP and helper.get("current_target") == null, "远处敌人不会使飞弹提前转向")
	projectile.position = Vector2(150, 0)
	helper.set("retarget_timer", 0.0)
	direction = helper.call("steer", projectile, projectile, &"enemy", Vector2.UP, 2.5, 160.0, 0.12, 0.1, true)
	_check(helper.get("current_target") == enemy and direction.x > 0.0, "弹体飞近敌人后才开始追踪")
	_check(absf(Vector2.UP.angle_to(direction)) <= 0.25 + 0.0001, "近距离仍受弱追踪转向速度限制")
	enemy.position = Vector2(600, 0)
	direction = helper.call("steer", projectile, projectile, &"enemy", Vector2.UP, 2.5, 160.0, 0.12, 0.1, true)
	_check(helper.get("current_target") == null and direction == Vector2.UP, "已锁定目标离开范围也停止追踪")
	helper.set("current_target", enemy)
	helper.call("steer", projectile, projectile, &"enemy", Vector2.UP, 2.5, 160.0, 0.12, 0.1)
	_check(helper.get("current_target") == enemy, "其他投射物默认保留原有锁定行为")
	projectile.position = Vector2.ZERO


func _check_aim() -> void:
	var body: String = _function_source(AIM, "get_aim_direction").replace("Entity", "Node2D")
	body = body.replace("caster.get_global_mouse_position()", "mouse_position").replace("caster.get_facing_direction()", "fallback_facing")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar mouse_position: Vector2 = Vector2.LEFT\nvar fallback_facing: Vector2 = Vector2.DOWN\n" + body)
	if script == null:
		return
	var helper: RefCounted = script.new()
	var caster: Node2D = Node2D.new()
	var target: Node2D = Node2D.new()
	target.position = Vector2(0, -50)
	_check(helper.call("get_aim_direction", caster, target) == Vector2.UP, "优先瞄准敌人而不是鼠标")
	_check(helper.call("get_aim_direction", caster, null) == Vector2.LEFT, "无敌人时朝鼠标空放")
	helper.set("mouse_position", Vector2.ZERO)
	_check(helper.call("get_aim_direction", caster, null) == Vector2.DOWN, "鼠标重合时回退朝向")
	helper.set("fallback_facing", Vector2.ZERO)
	_check(helper.call("get_aim_direction", caster, null) == Vector2.RIGHT, "零向量安全兜底")
	target.free()
	caster.free()


func _check_volley() -> void:
	# 运行原齐射循环，只把实际场景生成替换为记录，验证数量、展开和上下文还原。
	var body: String = _function_source(VOLLEY, "_activate").replace("AbilityContext", "RefCounted")
	body = body.replace("context.is_caster_action_valid()", "context.call(\"is_caster_action_valid\")")
	body = body.replace("context.caster.get_facing_direction()", "Vector2.RIGHT")
	body = body.replace("super._activate(context)", "emissions.append({\"direction\": context.locked_direction, \"side\": side_offset})")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar base_projectile_count: int = 3\nvar bonus_projectile_count: int = 0\nvar attacks_before_bonus: int = 0\nvar attacks_since_bonus: int = 0\nvar side_offset: float = 0.0\nvar side_spacing: float = 5.0\nvar spread_angle_degrees: float = 8.0\nvar emissions: Array = []\n" + body)
	var context_script: GDScript = _fixture("@tool\nextends RefCounted\nvar locked_direction: Vector2 = Vector2.UP\nvar projectile_count_override: int = 0\nvar cast_record: Dictionary = {\"projectile_count_bonus\": 0}\nvar valid: bool = true\nfunc is_caster_action_valid() -> bool:\n\treturn valid\n")
	if script == null or context_script == null:
		return
	var helper: RefCounted = script.new()
	var context: RefCounted = context_script.new()
	for index: int in range(5):
		helper.set("emissions", [])
		helper.call("_activate", context)
		var emissions: Array = helper.get("emissions")
		_check(emissions.size() == 3, "连续攻击始终三枚")
		_check(emissions[0]["side"] == -5.0 and emissions[2]["side"] == 5.0, "齐射横向错开")
		_check(context.get("locked_direction") == Vector2.UP and helper.get("side_offset") == 0.0, "上下文与偏移还原")
	_check_fan_volley(helper, context)
	context.set("projectile_count_override", 5)
	helper.set("emissions", [])
	helper.call("_activate", context)
	_check(helper.get("emissions").size() == 5, "流星修正实际齐射为五枚")
	context.set("projectile_count_override", 0)
	helper.set("emissions", [])
	helper.call("_activate", context)
	_check(helper.get("emissions").size() == 3, "移除数量修正恢复三枚")
	context.set("valid", false)
	helper.set("emissions", [])
	helper.call("_activate", context)
	_check(helper.get("emissions").is_empty(), "死亡或取消动作不发射")


func _check_fan_volley(helper: RefCounted, context: RefCounted) -> void:
	helper.set("side_spacing", 0.0)
	helper.set("spread_angle_degrees", 20.0)
	helper.set("emissions", [])
	helper.call("_activate", context)
	var emissions: Array = helper.get("emissions")
	_check(emissions.size() == 3, "扇形齐射仍生成三枚")
	if emissions.size() == 3:
		for index: int in range(3):
			var direction: Vector2 = emissions[index]["direction"]
			var expected: Vector2 = Vector2.UP.rotated(deg_to_rad((index - 1) * 20.0))
			_check(direction.is_equal_approx(expected), "实际生成方向为-20/0/+20度：%d" % index)
			_check(emissions[index]["side"] == 0.0, "没有横向并列偏移：%d" % index)
	_check(context.get("locked_direction") == Vector2.UP and helper.get("side_offset") == 0.0, "扇形齐射后恢复上下文")


func _function_source(path: String, name: String) -> String:
	var source: String = FileAccess.get_file_as_string(path)
	var start: int = source.find("func " + name + "(")
	var end: int = source.find("\nfunc ", start + 1)
	return source.substr(start, end - start if end >= 0 else -1)


func _fixture(source: String) -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = source
	var error: Error = script.reload()
	_check(error == OK, "隔离夹具解析")
	return script if error == OK else null


func _check(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error(description)
