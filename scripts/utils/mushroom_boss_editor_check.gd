## 仅编辑器扫描和隔离函数检查；不启动战斗，不读写存档。
extends SceneTree

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
	_check_scripts()
	_check_boss()
	_check_abilities()
	_check_manifests()
	_check_pool()
	_check_gap()
	_check_completion_count()
	_check_placement_rules()
	_check_visual_restore()
	_check_template_selection()
	print("菌冠古树编辑器检查：%d项，失败%d项；未启动战斗。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_scripts() -> void:
	for name: String in ["entity/anchored_encounter_boss", "ability/component/ability_timed_sequence", "ability/component/ability_sector_warning", "ability/component/ability_scatter_landing_areas", "ability/component/ability_radial_gap_volley", "ability/component/ability_relocate_to_anchor", "ability/manifest/encounter_warning", "ability/manifest/landing_status_area_manifest"]:
		var script: Script = load("res://scripts/%s.gd" % name) as Script
		_check(script != null and script.reload(true) == OK, "脚本解析：" + name)
	for path: String in ["res://custom_resource/battle_stats.gd", "res://scripts/scenes/play_scene.gd"]:
		var script: Script = load(path) as Script
		_check(script != null and script.reload(true) == OK, "地图选择扩展解析")


func _check_boss() -> void:
	var scene: PackedScene = load("res://entity/enemy/mushroom_tree_boss.tscn") as PackedScene
	_check(scene != null, "Boss 场景载入")
	if scene == null:
		return
	var boss: Node = scene.instantiate()
	_check(boss is CharacterBody2D and boss.is_in_group("boss"), "实体与 Boss 分组")
	_check(boss.get("attacks_before_relocation") == 3, "三次完整攻击后迁根")
	_check(boss.get("phase_two_health_ratio") == 0.4, "40% 血量进入二阶段")
	_check(boss.get_node("AbilityController").get_child_count() == 4, "三个攻击加一个迁根")
	_check(boss.get_node("RelocationPoints").get_child_count() == 4, "四个默认迁根候选点")
	_check(boss.get_node("BodyCollisionShape2D").get("shape").get("radius") == 30.0, "身体尺寸与落点查询一致")
	_check((int(boss.get_node("Area2D").get("collision_layer")) & 1) != 0, "受击区域兼容现有默认投射物的检测掩码")
	var frames: SpriteFrames = boss.get_node("AnimatedSprite2D").get("sprite_frames") as SpriteFrames
	for animation: StringName in [&"idle", &"attack", &"cast", &"relocate", &"die"]:
		_check(frames.has_animation(animation), "美术动画预留：" + animation)
	_check(not frames.get_animation_loop(&"die"), "死亡动画不循环")
	_check(boss.get_node("StatsController").get("stats_data").get("base_max_health") == 1800.0, "独立 Boss 属性")
	boss.free()


func _check_abilities() -> void:
	for name: String in ["root_sweep", "spore_scatter", "ring_pulse", "root_relocation"]:
		var scene: PackedScene = load("res://scenes/ability/mushroom_%s.tscn" % name) as PackedScene
		_check(scene != null, "技能场景：" + name)
		if scene == null:
			continue
		var skill: Node = scene.instantiate()
		_check(skill.get("energy_cost") == 0.0 and skill.has_node("Sequence"), "Boss 技能无需能量且有完成信号")
		if name == "root_sweep":
			_check(skill.get_node("Sequence/Warning").get("duration") == 0.8, "横扫预警0.8秒")
			_check(skill.get_node("Sequence/Warning").get("radius") == skill.get_node("Sequence/Impact/Targets").get("radius"), "预警半径与伤害一致")
			_check(skill.get_node("Sequence/Impact").get("exec_delay") == 0.8, "预警完成后结算横扫")
			_check(skill.get_node("Sequence").get("total_duration") == 1.8, "横扫恢复窗口1秒")
		if name == "spore_scatter":
			_check(skill.get_node("Sequence/Spores").get("count") == 3 and skill.get_node("Sequence/Spores").get("phase_two_extra_count") == 1, "孢子三颗/二阶段四颗")
		if name == "ring_pulse":
			_check(skill.get_node("Sequence").get("total_duration") == 2.2 and skill.get_node("Sequence").get("phase_two_duration") == 3.2, "两阶段均保留1.2秒恢复")
		if name == "root_relocation":
			_check(skill.get_node("Sequence/Move").get("clearance_cells") == 2, "大型 Boss 落点格子留边")
			_check(skill.get_node("Sequence/Move").get("minimum_player_distance") >= 150.0, "不在玩家脚下出现")
		skill.free()


func _check_manifests() -> void:
	for name: String in ["landing_spore", "ring_spore"]:
		var scene: PackedScene = load("res://scenes/ability/manifest/mushroom_%s.tscn" % name) as PackedScene
		_check(scene != null, "表现体：" + name)
		if scene == null:
			continue
		var node: Node = scene.instantiate()
		if name == "landing_spore":
			_check(node.get("flight_time") == 1.0 and node.get("area_duration") == 4.0, "1秒抛射/4秒领域")
			_check(node.get("status_data").get("polarity") == 2, "短暂负面减速状态")
			_check(node.has_node("VisualPivot/Sprite2D") and node.has_node("AreaVisual/Sprite2D"), "抛射和落地美术留空")
		else:
			_check(node.get("blocked_by_world") and node.get("homing_turn_speed") == 0.0 and not node.get("is_penetrate"), "环弹撞墙/不追踪/不穿透")
			_check(node.get("target_group") == "player", "命中玩家阵营")
			_check(node.get("max_distance") + 52.0 == 280.0, "环弹终点与预警外缘一致")
		node.free()


func _check_pool() -> void:
	var pool: Resource = load("res://first_battle_pool/grass_battle_pool.tres") as Resource
	_check(pool != null, "第一层战斗池载入")
	if pool == null:
		return
	var found: bool = false
	for battle: Resource in pool.get("pool"):
		if battle.resource_path.ends_with("mushroom_tree_boss_battle.tres"):
			found = true
			_check(battle.get("battle_tier") == 3, "只加入 Boss 难度层级")
			_check(battle.get("battle_map_template_path") == "res://scenes/battlemap/templates/grass_open_01.tscn", "大型 Boss 使用开阔场地")
			var wave: Resource = battle.get("waves")[0]
			_check(wave.get("max_enemies") == 0 and wave.get("fixed_spawns")[0].get("count") == 1, "单只 Boss 无额外小怪")
	_check(found, "第一层随机池包含菌冠古树")
	var floor: Resource = load("res://custom_resource/run_floor_02.tres") as Resource
	_check(floor.get("battle_pool").resource_path.ends_with("frost_battle_pool.tres"), "第二层战斗池未改动")


## 测试实际方向生成函数，不执行 Ability 节点生命周期。
func _check_gap() -> void:
	var body: String = _function_source("res://scripts/ability/component/ability_radial_gap_volley.gd", "get_volley_directions")
	var fixture: GDScript = _fixture("@tool\nextends RefCounted\nvar safe_gap_degrees: float = 65.0\nvar projectile_count: int = 24\n" + body)
	var instance: RefCounted = fixture.new()
	for angle: float in [0.0, 1.5, -2.6]:
		var directions: Array = instance.call("get_volley_directions", angle)
		_check(directions.size() == 24, "环弹数量24")
		var all_outside_gap: bool = true
		for direction: Vector2 in directions:
			if absf(wrapf(direction.angle() - angle, -PI, PI)) < deg_to_rad(32.5) - 0.0001:
				all_outside_gap = false
		_check(all_outside_gap, "所有弹道避开65度安全缺口")


## 使用实际计数回调验证：取消不计数、三次成功达到迁根条件、迁根完成后归零。
func _check_completion_count() -> void:
	var body: String = _function_source("res://scripts/entity/anchored_encounter_boss.gd", "_on_sequence_finished").replace("context: AbilityContext", "context: RefCounted")
	var fixture: GDScript = _fixture("@tool\nextends Node\nvar is_dead: bool = false\nvar action_busy: bool = true\nvar rest_remaining: float = 0.0\nvar interrupted_recovery: float = 1.0\nvar completed_attacks: int = 0\nvar current_anim: Variant\nvar relocation: Node\nfunc play_animation(_animation: Variant) -> void:\n\tpass\n" + body)
	var context_fixture: GDScript = _fixture("@tool\nextends RefCounted\nvar caster: Node\nvar ability: Node\n")
	var instance: Node = fixture.new()
	var context: RefCounted = context_fixture.new()
	var relocation: Node = Node.new()
	context.set("caster", instance)
	instance.set("relocation", relocation)
	instance.call("_on_sequence_finished", context, false)
	_check(instance.get("completed_attacks") == 0, "被打断不计数")
	for index: int in range(3):
		instance.call("_on_sequence_finished", context, true)
	_check(instance.get("completed_attacks") == 3, "三次完整攻击达到迁根条件")
	context.set("ability", relocation)
	instance.call("_on_sequence_finished", context, true)
	_check(instance.get("completed_attacks") == 0, "迁根完成后重置计数")
	instance.free()
	relocation.free()


func _check_placement_rules() -> void:
	var body: String = _function_source("res://scripts/ability/component/ability_relocate_to_anchor.gd", "is_candidate_safe")
	body = body.replace("caster: Entity", "caster: Node2D").replace("caster.get_tree()", "tree_stub").replace("map: BattleMap", "map: RefCounted").replace("as BattleMap", "as RefCounted").replace("node is Entity", "node is Node2D")
	var fixture: GDScript = _fixture("@tool\nextends RefCounted\nvar minimum_relocation_distance: float = 90.0\nvar minimum_player_distance: float = 150.0\nvar clearance_cells: int = 2\nvar tree_stub: RefCounted\nvar footprint_clear: bool = true\nfunc is_footprint_clear(_caster: Node2D, _point: Vector2) -> bool:\n\treturn footprint_clear\n" + body)
	var tree_fixture: GDScript = _fixture("@tool\nextends RefCounted\nvar map: RefCounted\nvar actors: Array[Node] = []\nfunc get_first_node_in_group(_group: String) -> RefCounted:\n\treturn map\nfunc get_nodes_in_group(_group: StringName) -> Array[Node]:\n\treturn actors\n")
	var map_fixture: GDScript = _fixture("@tool\nextends RefCounted\nvar reachable: bool = true\nfunc is_world_position_in_playable_region(_point: Vector2, _clearance: int) -> bool:\n\treturn reachable\n")
	var actor_fixture: GDScript = _fixture("@tool\nextends Node2D\nvar is_dead: bool = false\n")
	var helper: RefCounted = fixture.new()
	var tree_stub: RefCounted = tree_fixture.new()
	var map_stub: RefCounted = map_fixture.new()
	var caster: Node2D = actor_fixture.new()
	var player: Node2D = actor_fixture.new()
	var actors: Array[Node] = [player]
	tree_stub.set("actors", actors)
	tree_stub.set("map", map_stub)
	helper.set("tree_stub", tree_stub)
	player.position = Vector2(-200, 0)
	_check(not helper.call("is_candidate_safe", caster, Vector2(20, 0)), "不能在原地附近假迁根")
	_check(helper.call("is_candidate_safe", caster, Vector2(300, 0)), "合法空地允许迁根")
	map_stub.set("reachable", false)
	_check(not helper.call("is_candidate_safe", caster, Vector2(300, 0)), "不可达区域拒绝迁根")
	map_stub.set("reachable", true)
	helper.set("footprint_clear", false)
	_check(not helper.call("is_candidate_safe", caster, Vector2(300, 0)), "完整身体压墙则拒绝")
	helper.set("footprint_clear", true)
	player.position = Vector2(310, 0)
	_check(not helper.call("is_candidate_safe", caster, Vector2(300, 0)), "预警后玩家移入落点则取消迁根")
	caster.free()
	player.free()


func _check_visual_restore() -> void:
	var body: String = _function_source("res://scripts/ability/component/ability_relocate_to_anchor.gd", "_restore_visual")
	var fixture: GDScript = _fixture("@tool\nextends RefCounted\nvar visual_tween: Tween\nvar visual: CanvasItem\nvar visual_color: Color = Color.WHITE\nvar active_action: RefCounted\n" + body)
	var helper: RefCounted = fixture.new()
	var sprite: Sprite2D = Sprite2D.new()
	sprite.modulate.a = 0.0
	helper.set("visual", sprite)
	helper.call("_restore_visual")
	_check(sprite.modulate.a == 1.0 and helper.get("visual") == null, "中断时恢复透明度并释放视觉引用")
	sprite.free()


func _check_template_selection() -> void:
	var body: String = _function_source("res://scripts/scenes/play_scene.gd", "_resolve_battle_map_template_path").replace("battle_data: BattleStats", "battle_data: Resource")
	var fixture: GDScript = _fixture("@tool\nextends RefCounted\nvar run_stats: RefCounted\nvar pending_battle_stats: Resource\nvar enemy_spawner: Node\nfunc _get_valid_battle_map_template_paths() -> Array[String]:\n\treturn []\n" + body)
	var stats_fixture: GDScript = _fixture("@tool\nextends RefCounted\nvar current_battle_map_template_path: String = \"\"\nfunc clear_battle_map_template() -> void:\n\tcurrent_battle_map_template_path = \"\"\n")
	var battle_fixture: GDScript = _fixture("@tool\nextends Resource\nvar battle_map_template_path: String = \"\"\n")
	var helper: RefCounted = fixture.new()
	var stats: RefCounted = stats_fixture.new()
	var battle: Resource = battle_fixture.new()
	var preferred: String = "res://scenes/battlemap/templates/grass_open_01.tscn"
	var saved: String = "res://scenes/battlemap/templates/grass_corridor_01.tscn"
	battle.set("battle_map_template_path", preferred)
	helper.set("pending_battle_stats", battle)
	_check(helper.call("_resolve_battle_map_template_path") == preferred, "无局内数据时也可直接指定测试战场")
	helper.set("run_stats", stats)
	_check(helper.call("_resolve_battle_map_template_path") == preferred and stats.get("current_battle_map_template_path") == preferred, "指定战场路径写入本局数据")
	stats.set("current_battle_map_template_path", saved)
	_check(helper.call("_resolve_battle_map_template_path") == saved, "继续游戏优先保留存档战场")


func _function_source(path: String, name: String) -> String:
	var source: String = FileAccess.get_file_as_string(path)
	var start: int = source.find("func " + name + "(")
	var end: int = source.find("\nfunc ", start + 1)
	return source.substr(start, end - start if end >= 0 else -1)


func _fixture(source: String) -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = source
	_check(script.reload() == OK, "隔离测试夹具解析")
	return script


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error(label)
