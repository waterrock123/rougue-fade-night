## 只在编辑器加载资源、隔离执行真实函数；不启动游戏、不读写玩家存档。
extends "res://scripts/utils/scount_combat_skills_editor_check.gd"

const GUARD: String = "res://scripts/ability/component/ability_directional_guard.gd"
const LEAP: String = "res://scripts/ability/component/ability_leap_to_cursor.gd"
const BREAKER: String = "res://scripts/skill/poise_break_basic_attack_listener.gd"


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_warrior_resources()
	_check_guard_directions()
	_check_guard_timing()
	_check_receive_hook()
	_check_leap_motion()
	_check_leap_cleanup()
	_check_break_rewards()
	_check_break_splash_claims()
	_check_guard_cleanup()
	print("战狂战斗技能编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_warrior_resources() -> void:
	var level: Node = (load("res://scenes/ability/level_up_controller.tscn") as PackedScene).instantiate()
	var rewards: Array = level.get("reward_pool").get("rewards")
	for spec: Array in [["activate_skill", "125_leap_slam"], ["activate_skill", "126_iron_counter"], ["passive_skill", "041_formation_breaker"], ["passive_skill", "042_overwhelming_force"], ["passive_skill", "043_seize_the_breach"]]:
		var data: Resource = load("res://%s/%s.tres" % [spec[0], spec[1]]) as Resource
		_check(data != null, "加载" + str(spec[1]))
		if data == null:
			continue
		_check(data.get("id") == StringName(str(spec[1]).left(3)), "技能编号正确")
		_check(data.get("allowed_character_ids") == [&"warrior"] and data.get("icon") != null, "战狂专属且有图标")
		var count: int = 0
		for reward: Resource in rewards:
			if "skill_data" in reward and reward.get("skill_data") == data:
				count += 1
		_check(count == (0 if data.get("is_upgrade_skill") else 1), "只将初始技能放入奖励池一次")
		if spec[0] == "activate_skill":
			var ability: Node = (data.get("ability_scene") as PackedScene).instantiate()
			_check(ability.get("energy_cost") == data.get("base_energy_cost") and ability.get("cooldown") == data.get("base_cooldown"), "场景与资源成本一致")
			ability.free()
	var initial: Resource = load("res://passive_skill/041_formation_breaker.tres") as Resource
	_check(initial.get("upgrade_options").size() == 2, "破阵者有两个升级分支")
	for upgrade: Resource in initial.get("upgrade_options"):
		_check(upgrade.get("is_upgrade_skill") and upgrade.get("upgrade_options").is_empty(), "升级分支仅有两级")
	level.free()
	_check_warrior_scene_values()


func _check_warrior_scene_values() -> void:
	var leap: Node = (load("res://scenes/ability/warrior_leap_slam_ability.tscn") as PackedScene).instantiate()
	_check(leap.get_node("Indicator").get("shape") == 4 and leap.get_node("Indicator").get("radius") == 180.0, "大圆落点预览、最大180")
	_check(leap.get_node("Leap").get("max_distance") == 180.0 and leap.get_node("Leap/Targets").get("radius") == 75.0, "实际跃进与预览距离一致")
	_check(leap.get_node("Leap/Damage").get("damage") == 30.0 and leap.get_node("Leap/Damage").get("poise_damage") == 36.0, "落地30伤害、36削韧")
	_check(leap.get_node("Leap/Damage").get("scaling_rule").get("physical_formula") == "strength * 1.5", "重斩力量1.5倍")
	_check(leap.get_node("Leap/Targets").get("require_line_of_sight"), "重斩不隔墙伤害")
	leap.free()
	var guard: Node = (load("res://scenes/ability/warrior_iron_counter_ability.tscn") as PackedScene).instantiate()
	_check(guard.get_node("Guard").get("guard_seconds") == 0.8 and guard.get_node("Guard").get("perfect_seconds") == 0.25, "0.8防御、0.25精准窗口")
	_check(guard.get_node("Guard/Damage").get("damage") == 25.0 and guard.get_node("Guard/Damage").get("poise_damage") == 40.0, "反击25伤害、40削韧")
	_check(guard.get_node("Guard/Targets").get("direction_mode") == 4 and guard.get_node("Guard/Targets").get("require_line_of_sight"), "反击锁定施法方向并检查墙体")
	guard.free()
	var visual: Node = (load("res://scenes/ability/manifest/iron_counter_visual_manifest.tscn") as PackedScene).instantiate()
	_check(visual.get_script().resource_path.ends_with("animated_ability_manifest.gd"), "反击纯视觉不重新读取鼠标、不隐藏武器")
	_check(not (visual.get_node("AnimatedSprite2D").get("sprite_frames") as SpriteFrames).get_animation_loop(&"default"), "反击动画不循环，播完清理")
	visual.free()
	var db: String = FileAccess.get_file_as_string("res://custom_resource/default_keyword_database.tres")
	_check(db.contains('id = &"melee_damage"'), "近战关键词已存在")


func _warrior_actor() -> Node2D:
	var script: GDScript = _fixture("@tool\nextends Node2D\nsignal damage_receive_prepared(data: Resource)\nvar stats_controller: Node\nvar status_controller: Node\nvar is_dead: bool = false\nvar blocked: bool = false\nvar locks: Dictionary = {\"other\": true}\nvar current_energy: float = 10.0\nfunc can_act() -> bool:\n\treturn not is_dead\nfunc can_be_targeted() -> bool:\n\treturn not is_dead\nfunc add_movement_lock(key: String) -> void:\n\tlocks[key] = true\nfunc remove_movement_lock(key: String) -> void:\n\tlocks.erase(key)\nfunc clear_terrain_motion_velocity() -> void:\n\tpass\nfunc spend_energy(amount: float) -> void:\n\tcurrent_energy = minf(current_energy - amount, 50.0)\nfunc move_direct_with_physics(motion: Vector2, _slide: bool) -> Vector2:\n\tif blocked:\n\t\treturn Vector2.ZERO\n\tposition += motion\n\treturn motion\n")
	return script.new()


func _guard_hit(target: Node2D, source: Node2D, direction: Vector2 = Vector2.LEFT) -> Resource:
	var script: GDScript = _fixture("@tool\nextends Resource\nvar source: Node2D\nvar target: Node2D\nvar final_damage: float = 100.0\nvar impact_direction: Vector2\nvar tags: Array[String] = []\nvar is_miss: bool = false\nvar allow_skill_procs: bool = true\nvar cast_record: RefCounted\n")
	var data: Resource = script.new()
	data.set("target", target)
	data.set("source", source)
	data.set("impact_direction", direction)
	return data


func _guard_helper() -> Node:
	var body: String = _functions(GUARD, ["_on_incoming", "_is_frontal_attack", "_can_continue", "_process"])
	body = body.replace("AbilityContext", "RefCounted").replace("DamageData", "Resource").replace("Entity", "Node2D").replace("EventBus.is_battle_active", "battle_active")
	var header: String = "@tool\nextends Node\nvar active_context: RefCounted\nvar elapsed: float = 0.0\nvar guard_seconds: float = 0.8\nvar perfect_seconds: float = 0.25\nvar front_angle: float = 180.0\nvar damage_reduction: float = 0.6\nvar perfect_reduction: float = 0.9\nvar counter_pending: bool = false\nvar battle_active: bool = true\nvar visual: Node\nvar results: Array = []\nfunc _finish(value: bool) -> void:\n\tresults.append(value)\n\tactive_context = null\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _check_guard_directions() -> void:
	var helper: Node = _guard_helper()
	if helper == null:
		return
	var caster: Node2D = _warrior_actor()
	var enemy: Node2D = _warrior_actor()
	enemy.position = Vector2(50, 0)
	var context: RefCounted = _ctx()
	context.set("caster", caster)
	helper.set("active_context", context)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		context.set("locked_direction", -direction)
		var data: Resource = _guard_hit(caster, enemy, direction)
		_check(helper.call("_is_frontal_attack", data), "支持全二维朝向精准防御")
		data.set("impact_direction", -direction)
		_check(not helper.call("_is_frontal_attack", data), "背面攻击不能防御")
	context.set("locked_direction", Vector2.RIGHT)
	for tag: String in ["status", "periodic", "terrain", "self_damage", "reflect", "retaliation"]:
		var data: Resource = _guard_hit(caster, enemy)
		var tags: Array[String] = [tag]
		data.set("tags", tags)
		_check(not helper.call("_is_frontal_attack", data), "排除" + tag)
	_check(not helper.call("_is_frontal_attack", _guard_hit(caster, caster)), "排除自伤")
	_check(helper.call("_is_frontal_attack", _guard_hit(caster, enemy, Vector2.ZERO)), "近战未填方向时回退来源位置")
	var freed: Resource = _guard_hit(caster, enemy)
	enemy.free()
	_check(helper.call("_is_frontal_attack", freed), "来源释放后仍使用命中方向快照")
	caster.free()
	helper.free()


func _receive_fixture() -> Node2D:
	var body: String = _functions("res://scripts/entity/entity.gd", ["apply_damage"])
	var header: String = "@tool\nextends Node2D\nsignal damage_receive_prepared(data: Resource)\nsignal damage_taken(data: Resource)\nsignal damage_dealt(data: Resource)\nsignal damage_evaded(data: Resource)\nvar current_health: float = 100.0\nvar is_dead: bool = false\nvar stats_controller: Node\nvar invulnerable: bool = false\nfunc _normalize_damage_event(data: Resource) -> Resource:\n\treturn data\nfunc is_invulnerable() -> bool:\n\treturn invulnerable\nfunc _show_damage_taken_effect() -> void:\n\tpass\nfunc show_damage_popup(_data: Resource) -> void:\n\tpass\nfunc _handle_damage_callback(_data: Resource) -> void:\n\tpass\nfunc _die() -> void:\n\tis_dead = true\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _check_receive_hook() -> void:
	var target: Node2D = _receive_fixture()
	var stats_script: GDScript = _fixture("@tool\nextends Node\nvar current_health: float = 100.0\nvar dodge: bool = false\nfunc should_dodge_damage(_data: Resource) -> bool:\n\treturn dodge\nfunc process_incoming_damage(data: Resource) -> Resource:\n\tdata.final_damage *= 0.5\n\treturn data\nfunc sync_runtime_resources() -> void:\n\tpass\n")
	if target == null or stats_script == null:
		return
	var stats: Node = stats_script.new()
	target.set("stats_controller", stats)
	var seen: Array = []
	target.connect("damage_receive_prepared", func(data: Resource) -> void:
		seen.append([data.get("final_damage"), target.get("current_health")])
		data.set("final_damage", float(data.get("final_damage")) * 0.1))
	var data: Resource = _guard_hit(target, null)
	target.call("apply_damage", data)
	_check(seen == [[50.0, 100.0]], "防御拦截位于属性减伤后、扣血前")
	_check(target.get("current_health") == 95.0 and stats.get("current_health") == 95.0, "扣血及运行属性均使用格挡后5点伤害")
	stats.set("dodge", true)
	target.call("apply_damage", _guard_hit(target, null))
	_check(seen.size() == 1 and target.get("current_health") == 95.0, "闪避不触发精准格挡")
	stats.set("dodge", false)
	target.set("invulnerable", true)
	target.call("apply_damage", _guard_hit(target, null))
	_check(seen.size() == 1, "无敌不触发防御拦截")
	target.free()
	stats.free()


func _leap_helper() -> Node:
	var names: Array = ["_physics_process", "_can_continue", "_set_visual_offset", "_finish"]
	var body: String = _functions(LEAP, names)
	body = body.replace('get_tree().get_first_node_in_group("battle_map")', "null")
	body = body.replace("AbilityContext", "RefCounted").replace("Entity", "Node2D").replace("EventBus.is_battle_active", "battle_active")
	var header: String = "@tool\nextends Node\nvar active_context: RefCounted\nvar elapsed: float = 0.0\nvar start_position: Vector2\nvar landing_position: Vector2 = Vector2(180, 0)\nvar visual_offset: float = 0.0\nvar visuals: Array[Node2D] = []\nvar controller: Node\nvar lock_key: String = \"leap\"\nvar leap_seconds: float = 0.4\nvar visual_height: float = 32.0\nvar battle_active: bool = true\nvar safe: bool = true\nfunc _is_safe(_caster: Node2D, _map: Node, _start: Vector2, _end: Vector2) -> bool:\n\treturn safe\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _check_leap_motion() -> void:
	var helper: Node = _leap_helper()
	if helper == null:
		return
	var caster: Node2D = _warrior_actor()
	var visual: Node2D = Node2D.new()
	visual.position = Vector2(2, -8)
	var context: RefCounted = _ctx()
	context.set("caster", caster)
	helper.set("active_context", context)
	helper.get("visuals").append(visual)
	caster.call("add_movement_lock", "leap")
	helper.call("_physics_process", 0.2)
	_check(caster.position == Vector2(90, 0) and visual.position.is_equal_approx(Vector2(2, -40)), "半程实体平移90，贴图单独升高32")
	helper.call("_physics_process", 0.2)
	_check(caster.position == Vector2(180, 0) and visual.position.is_equal_approx(Vector2(2, -8)), "落地180并还原原始贴图偏移")
	_check(helper.get("active_context") == null and caster.get("locks") == {"other": true}, "落地只移除自己的锁")
	helper.set("active_context", context)
	helper.set("elapsed", 0.0)
	helper.set("start_position", Vector2(180, 0))
	helper.set("landing_position", Vector2(360, 0))
	caster.set("blocked", true)
	helper.call("_physics_process", 0.1)
	_check(caster.position == Vector2(180, 0) and helper.get("active_context") == null, "动态墙体阻挡时停在原地落地")
	caster.set("blocked", false)
	helper.set("active_context", context)
	helper.set("safe", false)
	helper.call("_physics_process", 0.1)
	_check(caster.position == Vector2(180, 0), "途中地图区域不可达不继续前进")
	_check(FileAccess.get_file_as_string(LEAP).contains("extends AbilityTeleportToCursor"), "复用已验证的沿线安全落点解析")
	visual.free()
	caster.free()
	helper.free()


func _check_leap_cleanup() -> void:
	var helper: Node = _leap_helper()
	if helper == null:
		return
	var caster: Node2D = _warrior_actor()
	var visual: Node2D = Node2D.new()
	visual.position.y = -12.0
	var context: RefCounted = _ctx()
	context.set("caster", caster)
	for reason: String in ["control", "death", "battle", "unload"]:
		helper.set("active_context", context)
		helper.get("visuals").append(visual)
		helper.call("_set_visual_offset", -25.0)
		caster.call("add_movement_lock", "leap")
		context.set("valid", reason != "control")
		caster.set("is_dead", reason == "death")
		helper.set("battle_active", reason != "battle")
		if reason == "unload":
			helper.call("_finish", false)
		else:
			helper.call("_physics_process", 0.1)
		_check(helper.get("active_context") == null and visual.position.y == -12.0, "取消并还原跳跃高度：" + reason)
		_check(caster.get("locks") == {"other": true}, "取消不影响其他来源的移动锁")
	visual.free()
	caster.free()
	helper.free()


func _break_helper(upgrade: int = 0) -> Node:
	var body: String = _functions(BREAKER, ["_on_break", "_reduce_cooldowns", "_on_cast", "_on_hit", "_process", "_reset_state"])
	body = body.replace("AbilityContext", "RefCounted").replace("Ability", "Node").replace("Entity", "Node2D").replace("DamageData", "Resource").replace("StatusData", "Resource")
	var header: String = "@tool\nextends Node\nvar caster: Node2D\nvar controller: Node\nvar config: Resource\nvar source_key: String = \"breaker\"\nvar ready_remaining: float = 0.0\nvar cooldown_remaining: float = 0.0\nvar eligible: bool = true\nvar splashes: int = 0\nvar removals: int = 0\nfunc _ready_for_event() -> bool:\n\treturn eligible and is_instance_valid(caster) and not caster.is_dead\nfunc _remove_status() -> void:\n\tremovals += 1\nfunc _splash(_target: Node2D, _data: Resource) -> void:\n\tsplashes += 1\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return null
	var helper: Node = script.new()
	var path: String = ["041_formation_breaker", "042_overwhelming_force", "043_seize_the_breach"][upgrade]
	helper.set("config", load("res://passive_skill/%s.tres" % path).get("effects")[0])
	return helper


func _break_controller() -> Node:
	var body: String = _functions("res://scripts/ability/core/ability_controller.gd", ["reduce_remaining_cooldown_seconds"]).replace("Ability", "Node")
	var script: GDScript = _fixture("@tool\nextends Node\nvar abilities: Array[Node] = []\nvar cooldowns: Dictionary = {}\nfunc is_basic_ability(ability: Node) -> bool:\n\treturn ability.get_meta(\"basic\", false)\n" + body)
	return script.new() if script != null else null


func _check_break_rewards() -> void:
	var helper: Node = _break_helper(2)
	var controller: Node = _break_controller()
	if helper == null or controller == null:
		return
	var caster: Node2D = _warrior_actor()
	var enemy: Node2D = _warrior_actor()
	enemy.add_to_group("enemy")
	helper.set("caster", caster)
	helper.set("controller", controller)
	var abilities: Array[Node] = []
	var ability_script: GDScript = _fixture("@tool\nextends Node\nvar current_cooldown: float = 0.0\n")
	for i: int in range(3):
		var ability: Node = ability_script.new()
		ability.set_meta("basic", i == 0)
		abilities.append(ability)
		controller.get("abilities").append(ability)
		controller.get("cooldowns")[ability] = 0.5 if i == 2 else 4.0
	var data: Resource = _guard_hit(enemy, caster)
	helper.call("_on_break", enemy, caster, data)
	_check(helper.get("ready_remaining") == 5.0, "本人破韧准备5秒强化")
	_check(controller.get("cooldowns")[abilities[0]] == 4.0 and controller.get("cooldowns")[abilities[1]] == 3.0 and controller.get("cooldowns")[abilities[2]] == 0.0, "所有非基础技能减1秒，最低0且排除普攻")
	helper.call("_on_break", enemy, caster, data)
	_check(controller.get("cooldowns")[abilities[1]] == 3.0, "同帧群体破韧不重复减冷却")
	helper.call("_process", 2.0)
	helper.call("_on_break", enemy, caster, data)
	_check(controller.get("cooldowns")[abilities[1]] == 2.0 and helper.get("ready_remaining") == 5.0, "2秒后允许减冷却，并刷新强化时间")
	_check_break_filters(helper, caster, enemy, data)
	for ability: Node in abilities:
		ability.free()
	caster.free()
	enemy.free()
	controller.free()
	helper.free()


func _check_break_filters(helper: Node, caster: Node2D, enemy: Node2D, data: Resource) -> void:
	helper.call("_reset_state")
	helper.call("_on_break", enemy, enemy, data)
	_check(helper.get("ready_remaining") == 0.0, "他人破韧不给本人强化")
	data.set("allow_skill_procs", false)
	helper.call("_on_break", enemy, caster, data)
	_check(helper.get("ready_remaining") == 0.0, "次级递归伤害不触发破阵")
	data.set("allow_skill_procs", true)
	enemy.add_to_group("map_object")
	helper.call("_on_break", enemy, caster, data)
	_check(helper.get("ready_remaining") == 0.0, "地图物件不触发破阵")
	enemy.remove_from_group("map_object")
	helper.set("eligible", false)
	helper.call("_on_break", enemy, caster, data)
	_check(helper.get("ready_remaining") == 0.0, "战斗结束不再触发破阵")


func _check_break_splash_claims() -> void:
	var helper: Node = _break_helper(1)
	if helper == null:
		return
	var caster: Node2D = _warrior_actor()
	var enemy: Node2D = _warrior_actor()
	enemy.add_to_group("enemy")
	helper.set("caster", caster)
	helper.set("ready_remaining", 5.0)
	var context: RefCounted = _ctx()
	context.set("caster", caster)
	helper.call("_on_cast", context)
	_check(helper.get("ready_remaining") == 5.0, "非普攻不消费破阵强化")
	context.get("cast_record").set("is_basic_attack", true)
	helper.call("_on_cast", context)
	_check(is_equal_approx(context.get("cast_record").get("damage_multiplier"), 1.7) and helper.get("ready_remaining") == 0.0, "升级为整次普攻70%伤害强化")
	var data: Resource = _guard_hit(enemy, caster)
	data.set("cast_record", context.get("cast_record"))
	helper.call("_on_hit", data)
	helper.call("_on_hit", data)
	_check(helper.get("splashes") == 1, "同次多目标或多弹普攻只溅射一次")
	context.set("cast_record", _record())
	context.get("cast_record").set("is_basic_attack", true)
	helper.call("_on_cast", context)
	data.set("cast_record", context.get("cast_record"))
	helper.call("_on_hit", data)
	_check(helper.get("splashes") == 1 and context.get("cast_record").get("damage_multiplier") == 1.0, "下一次普通普攻没有额外溅射")
	helper.set("ready_remaining", 1.0)
	helper.call("_process", 1.1)
	helper.call("_on_cast", context)
	_check(context.get("cast_record").get("damage_multiplier") == 1.0, "到期不再强化普攻")
	var source: String = FileAccess.get_file_as_string(BREAKER)
	_check(source.contains("data.allow_skill_procs = false") and source.contains("target.apply_damage(data)"), "次级伤害经统一入口并关闭递归")
	caster.free()
	enemy.free()
	helper.free()


func _guard_cleanup_helper() -> Node:
	var body: String = _functions(GUARD, ["_finish"])
	body = body.replace("AbilityContext", "RefCounted").replace("Entity", "Node2D").replace("AbilityComponent", "Node").replace("EventBus.is_battle_active", "battle_active")
	var header: String = "@tool\nextends Node\nvar active_context: RefCounted\nvar counter_pending: bool = true\nvar visual: Node\nvar controller: Node\nvar lock_key: String = \"guard\"\nvar guard_status: Resource\nvar perfect_energy_refund: float = 5.0\nvar battle_active: bool = true\nfunc _on_incoming(_data: Resource) -> void:\n\tpass\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _guard_cleanup_stats() -> Node:
	var script: GDScript = _fixture("@tool\nextends Node\nvar effects: Dictionary = {\"guard\": true, \"other\": true}\nfunc clear_effect_modifiers(key: String) -> void:\n\teffects.erase(key)\n")
	return script.new() if script != null else null


func _guard_cleanup_controller() -> Node:
	var script: GDScript = _fixture("@tool\nextends Node\nvar blocks: Dictionary = {\"guard\": true, \"other\": true}\nfunc clear_cast_block_modifier(key: String) -> void:\n\tblocks.erase(key)\n")
	return script.new() if script != null else null


func _check_guard_cleanup() -> void:
	var helper: Node = _guard_cleanup_helper()
	var stats: Node = _guard_cleanup_stats()
	var controller: Node = _guard_cleanup_controller()
	if helper == null or stats == null or controller == null:
		return
	var caster: Node2D = _warrior_actor()
	caster.set("stats_controller", stats)
	var context: RefCounted = _ctx()
	context.set("caster", caster)
	helper.set("active_context", context)
	helper.set("controller", controller)
	caster.connect("damage_receive_prepared", Callable(helper, "_on_incoming"))
	var child_script: GDScript = _fixture("@tool\nextends Node\nvar auto_activate: bool = true\nvar calls: int = 0\nfunc activate(_context: RefCounted) -> void:\n\tcalls += 1\n")
	var child: Node = child_script.new()
	helper.add_child(child)
	helper.call("_finish", true)
	_check(not caster.is_connected("damage_receive_prepared", Callable(helper, "_on_incoming")), "防御结束解绑扣血前监听")
	_check(stats.get("effects") == {"other": true} and controller.get("blocks") == {"other": true}, "恢复自己的减速和施法锁，不清除其他来源")
	_check(caster.get("current_energy") == 15.0 and child.get("calls") == 1, "精准反击只退款5能量并执行一次子组件")
	helper.call("_finish", true)
	_check(caster.get("current_energy") == 15.0 and child.get("calls") == 1, "重复清理不会重复退款和反击")
	context.set("valid", false)
	helper.set("active_context", context)
	helper.call("_finish", true)
	_check(child.get("calls") == 1 and caster.get("current_energy") == 15.0, "被控制打断即使有反击请求也不退款或攻击")
	caster.free()
	helper.set("active_context", context)
	helper.call("_finish", false)
	_check(helper.get("active_context") == null, "施法者已释放仍能安全清理")
	stats.free()
	controller.free()
	helper.free()


func _check_guard_timing() -> void:
	var helper: Node = _guard_helper()
	if helper == null:
		return
	var caster: Node2D = _warrior_actor()
	var enemy: Node2D = _warrior_actor()
	var context: RefCounted = _ctx()
	context.set("caster", caster)
	helper.set("active_context", context)
	var first: Resource = _guard_hit(caster, enemy)
	helper.call("_on_incoming", first)
	_check(is_equal_approx(first.get("final_damage"), 10.0) and helper.get("counter_pending"), "精准格挡90%并仅排队反击")
	var second: Resource = _guard_hit(caster, enemy)
	helper.call("_on_incoming", second)
	_check(is_equal_approx(second.get("final_damage"), 40.0), "同帧第二击仅普通防御，不能重复精准")
	helper.call("_process", 0.01)
	_check(helper.get("results") == [true], "反击延后处理而非伤害回调内执行")
	helper.set("active_context", context)
	helper.set("counter_pending", false)
	helper.set("elapsed", 0.3)
	var late: Resource = _guard_hit(caster, enemy)
	helper.call("_on_incoming", late)
	_check(is_equal_approx(late.get("final_damage"), 40.0) and not helper.get("counter_pending"), "普通窗口只减伤60%不反击")
	helper.set("elapsed", 0.8)
	var expired: Resource = _guard_hit(caster, enemy)
	helper.call("_on_incoming", expired)
	_check(expired.get("final_damage") == 100.0, "到期不再防御")
	for invalid: String in ["battle", "control", "death"]:
		helper.set("active_context", context)
		helper.set("counter_pending", true)
		helper.set("battle_active", invalid != "battle")
		context.set("valid", invalid != "control")
		caster.set("is_dead", invalid == "death")
		helper.call("_process", 0.01)
		_check(helper.get("results").back() == false, "取消待反击：" + invalid)
	caster.free()
	enemy.free()
	helper.free()
