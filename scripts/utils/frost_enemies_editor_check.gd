## 冰原敌人的编辑器资源与隔离逻辑检查；不运行战斗场景、不读写玩家存档。
extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_scripts()
	_check_enemies()
	_check_abilities()
	_check_guard_direction()
	_check_pool()
	_check_visual_copy()
	_check_animation_isolation()
	_check_action_bound_guard()
	print("冰原敌人编辑器检查：%d项，失败%d项；未运行战斗。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_scripts() -> void:
	for path: String in ["scripts/entity/configured_enemy.gd", "scripts/ability/component/ability_lock_facing.gd", "scripts/ability/component/ability_physics_charge.gd", "scripts/ability/component/ability_damage_status_window.gd", "scripts/status/status_remove_on_action_cancel_effect.gd", "scripts/status/status_incoming_damage_taken_effect.gd", "scripts/stats/stats_controller.gd"]:
		var script: Script = load("res://" + path) as Script
		_check(script != null and script.reload(true) == OK, "脚本解析：" + path)


func _check_enemies() -> void:
	for name: String in ["frost_fang_hound", "frost_crystal_sentinel", "frost_shell_beast"]:
		var scene: PackedScene = load("res://entity/enemy/" + name + ".tscn") as PackedScene
		_check(scene != null, "敌人场景：" + name)
		if scene == null:
			continue
		var node: Node = scene.instantiate()
		_check(node is CharacterBody2D, "保留物理实体根节点")
		_check(node.has_node("BodyCollisionShape2D") and node.has_node("StatusController"), "碰撞/状态控制器")
		var loadout: Array = node.get("combat_abilities")
		_check(loadout.size() == 1 and loadout[0] != null, "独立技能配置")
		var sprite: AnimatedSprite2D = node.get_node("AnimatedSprite2D") as AnimatedSprite2D
		_check(node.get_node("EnemyHealthBar").get("texture_progress") != null, "血条纹理可用")
		_check(sprite.sprite_frames.has_animation(&"idle") and sprite.sprite_frames.has_animation(&"die"), "占位待机/死亡动画")
		var stats: Resource = node.get_node("StatsController").get("stats_data") as Resource
		_check(stats != null and float(stats.get("base_max_health")) > 0.0, "独立属性资源")
		if name == "frost_fang_hound":
			_check(not node.get("is_bounty_elite") and not node.get_node("RedEyes").get("visible"), "猎犬非中立悬赏/无红眼")
		node.free()


func _check_abilities() -> void:
	var pounce: Node = (load("res://scenes/ability/frost_fang_pounce.tscn") as PackedScene).instantiate()
	_check(pounce.get_node("Pounce").get("exec_delay") == 0.6, "扑击蓄力0.6秒")
	_check(pounce.get_node("Pounce/Move").get_script().resource_path.ends_with("ability_physics_charge.gd"), "冲刺使用物理移动")
	_check(pounce.get_node("LockMovement").get("lock_duration") > 0.95, "冲刺后有恢复窗口")
	pounce.free()
	var volley: Node = (load("res://scenes/ability/frost_sentinel_volley.tscn") as PackedScene).instantiate()
	_check(volley.get_node("Bolt1").get("direction_angle_offset") == -18.0 and volley.get_node("Bolt3").get("direction_angle_offset") == 18.0, "三发分散方向")
	_check(volley.get_node("Bolt1").get("exec_delay") < volley.get_node("Bolt3").get("exec_delay"), "三发错时释放")
	volley.free()
	var projectile: Node = (load("res://scenes/ability/manifest/frost_sentinel_bolt.tscn") as PackedScene).instantiate()
	_check(projectile.get("target_group") == &"player" and not projectile.get("is_penetrate"), "攻击玩家侧、不穿透")
	_check(projectile.get("on_hit_status").get("id") == &"frost_slow", "减速而非强制冰冻")
	_check(projectile.get("blocked_by_world"), "冰锥被墙挡住")
	projectile.free()
	var status: Resource = load("res://status/frost_shell_guard.tres")
	_check(status.get("duration") == 1.0, "防御不是永久状态")
	var effects: Array = status.get("effects")
	_check(effects[0].get("percent_bonus") == -0.6 and effects[0].get("front_angle_degrees") == 120.0, "正面120度减伤60%")
	_check(effects[1].get_script().resource_path.ends_with("status_remove_on_action_cancel_effect.gd"), "防御绑定动作取消")


## 抽取实际方向筛选函数，用tool夹具测试，避免启动StatsController生命周期。
func _check_guard_direction() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stats/stats_controller.gd")
	var start: int = source.find("func _matches_incoming_direction(")
	var end: int = source.find("\nfunc ", start + 1)
	var body: String = source.substr(start, end - start).replace("data: DamageData", "data: Resource")
	var helper: GDScript = _fixture("@tool\nextends RefCounted\n" + body)
	var actor_script: GDScript = _fixture("@tool\nextends Node2D\nfunc get_facing_direction() -> Vector2:\n\treturn Vector2.RIGHT\n")
	var data_script: GDScript = _fixture("@tool\nextends Resource\nvar source: Node2D\nvar target: Node2D\nvar impact_direction: Vector2\nvar tags: Array[String] = []\n")
	var instance: RefCounted = helper.new()
	var actor: Node2D = actor_script.new()
	var attacker: Node2D = actor_script.new()
	var data: Resource = data_script.new()
	data.set("target", actor)
	data.set("source", attacker)
	for row: Array in [[Vector2.LEFT, true], [Vector2.RIGHT, false], [Vector2.DOWN, false]]:
		data.set("impact_direction", row[0])
		_check(instance.call("_matches_incoming_direction", data, 120.0) == row[1], "正面/背面/侧面筛选")
	var tags: Array[String] = ["periodic"]
	data.set("tags", tags)
	data.set("impact_direction", Vector2.LEFT)
	_check(not instance.call("_matches_incoming_direction", data, 120.0), "持续伤害不受防御保护")
	_check(instance.call("_matches_incoming_direction", data, 0.0), "旧易伤不受方向扩展影响")
	tags.clear()
	data.set("tags", tags)
	data.set("impact_direction", Vector2.ZERO)
	attacker.position = Vector2(20.0, 0.0)
	_check(instance.call("_matches_incoming_direction", data, 120.0), "近战按来源位置判断")
	actor.free()
	attacker.free()


func _check_pool() -> void:
	var floor: Resource = load("res://custom_resource/run_floor_02.tres")
	var pool: Resource = floor.get("battle_pool") as Resource
	_check(pool != null and pool.resource_path.ends_with("frost_battle_pool.tres"), "第二层接入新战斗池")
	if pool == null:
		return
	var battles: Array = pool.get("pool")
	_check(battles.size() == 5, "四种普通组合与一场Boss配置")
	for battle: Resource in battles:
		var waves: Array = battle.get("waves")
		_check(waves.size() == 1 and waves[0].get("max_enemies") == 0, "固定编排不随机放大数量")
		var entries: Array = waves[0].get("fixed_spawns")
		for entry: Resource in entries:
			_check(entry.get("enemy_scene") != null and int(entry.get("count")) > 0, "生成条目有效")


func _check_visual_copy() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/entity/configured_enemy.gd")
	_check(source.contains("sprite_frames.duplicate(true)") and source.contains("set_animation_loop(animation, false)"), "占位动画不污染原怪且死亡不循环")
	_check(source.contains("cancel_active_actions()") and source.contains("remove_status(guarded_status_id)"), "硬直同步取消攻击和防御")
	var charge: String = FileAccess.get_file_as_string("res://scripts/ability/component/ability_physics_charge.gd")
	_check(charge.contains("is_inside_tree()") and charge.contains("context.is_caster_action_valid()"), "冲锋具备离树/死亡保护")


func _check_animation_isolation() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/entity/configured_enemy.gd")
	var start: int = source.find("func _prepare_visuals(")
	var end: int = source.find("\nfunc ", start + 1)
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar animated_sprite: AnimatedSprite2D\n" + source.substr(start, end - start))
	var scene: PackedScene = load("res://entity/enemy/big_dog.tscn") as PackedScene
	var node: Node = scene.instantiate()
	var sprite: AnimatedSprite2D = node.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var original: SpriteFrames = sprite.sprite_frames
	var helper: RefCounted = script.new()
	helper.set("animated_sprite", sprite)
	helper.call("_prepare_visuals")
	_check(sprite.sprite_frames != original, "每只怪物单独复制动画资源")
	_check(original.get_animation_loop(&"die"), "原大狗死亡动画配置不被改写")
	_check(not sprite.sprite_frames.get_animation_loop(&"die"), "新猎犬死亡动画可正常结束")
	_check(sprite.sprite_frames.has_animation(&"walk"), "move动画补上walk别名")
	node.free()


func _check_action_bound_guard() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/status/status_remove_on_action_cancel_effect.gd").replace("\r\n", "\n")
	source = source.replace("class_name StatusRemoveOnActionCancelEffect\n", "").replace("extends StatusEffect", "@tool\nextends Resource").replace("StatusInstance", "Resource")
	var effect_script: GDScript = _fixture(source)
	var target_script: GDScript = _fixture("@tool\nextends Node\nvar version: int = 0\nfunc get_action_version() -> int:\n\treturn version\n")
	var controller_script: GDScript = _fixture("@tool\nextends Node\nvar removed: bool = false\nfunc remove_status(_id: StringName) -> void:\n\tremoved = true\n")
	var instance_script: GDScript = _fixture("@tool\nextends Resource\nvar target: Node\nvar controller: Node\nfunc get_status_id() -> StringName:\n\treturn &'guard'\n")
	var target: Node = target_script.new()
	var controller: Node = controller_script.new()
	var instance: Resource = instance_script.new()
	instance.set("target", target)
	instance.set("controller", controller)
	var effect: Resource = effect_script.new()
	effect.call("on_apply", instance)
	effect.call("on_tick", instance, 0.1)
	_check(not controller.get("removed"), "动作未取消时保留防御")
	target.set("version", 1)
	effect.call("on_tick", instance, 0.1)
	_check(controller.get("removed"), "动作版本变化时撤销防御")
	effect.call("on_remove", instance)
	_check((effect.get("versions") as Dictionary).is_empty(), "防御记录清理")
	target.free()
	controller.free()


func _fixture(source: String) -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = source
	_check(script.reload() == OK, "隔离夹具解析")
	return script


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[失败] " + label)
