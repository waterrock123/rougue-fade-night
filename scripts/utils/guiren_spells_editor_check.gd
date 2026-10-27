## 只在编辑器加载资源并隔离测试实际函数，不启动游戏，不读写玩家存档。
extends SceneTree

const CHANNEL: String = "res://scripts/ability/component/ability_channel.gd"
const BURST: String = "res://scripts/ability/component/ability_spawn_manifest_burst.gd"
const IMPACT: String = "res://scripts/ability/manifest/impact_projectile_manifest.gd"
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
	_check_resources()
	_check_formulas()
	_check_burst()
	_check_channel()
	_check_movement_locks()
	_check_stacks()
	_check_cooldown()
	_check_impact_targets()
	_check_impact_once()
	_check_hit_status()
	print("贵人法术编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_resources() -> void:
	var specs: Array = [["113_fireball", 15.0, 8.0], ["114_lightning_arrow", 10.0, 6.0], ["115_shield_spell", 15.0, 10.0], ["116_haste_spell", 15.0, 8.0]]
	var level: Node = (load("res://scenes/ability/level_up_controller.tscn") as PackedScene).instantiate()
	var rewards: Array = level.get("reward_pool").get("rewards")
	for spec: Array in specs:
		var data: Resource = load("res://activate_skill/%s.tres" % spec[0]) as Resource
		_check(data != null, "技能加载：" + spec[0])
		if data == null:
			continue
		_check(data.get("allowed_character_ids") == [&"wizard"], "贵人专属：" + spec[0])
		_check(data.get("base_energy_cost") == spec[1] and data.get("base_cooldown") == spec[2], "消耗与冷却：" + spec[0])
		_check(data.get("icon") != null, "现有图标可用：" + spec[0])
		var count: int = 0
		for reward: Resource in rewards:
			if "skill_data" in reward and reward.get("skill_data") == data:
				count += 1
		_check(count == 1, "奖励池登记一次：" + spec[0])
		var ability: Node = (data.get("ability_scene") as PackedScene).instantiate()
		_check(ability.get("cooldown") == spec[2] and ability.get("energy_cost") == spec[1], "场景参数一致：" + spec[0])
		if ability.has_node("Channel"):
			_check(ability.get_node("Channel").get("channel_seconds") == 2.0, "两秒吟唱：" + spec[0])
			_check(ability.get_node("Channel").get_child_count() == 1, "增益只在吟唱完成后执行：" + spec[0])
		else:
			_check(ability.has_node("Indicator") and ability.has_node("Aim"), "方向与瞄准预览：" + spec[0])
		ability.free()
	level.free()
	var fire: Node = (load("res://scenes/ability/manifest/guiren_fireball_manifest.tscn") as PackedScene).instantiate()
	_check(fire.get("impact_radius") == 90.0 and fire.get("blocked_by_world"), "爆炸半径与撞墙")
	fire.free()
	var arrow: Node = (load("res://scenes/ability/manifest/guiren_lightning_arrow_manifest.tscn") as PackedScene).instantiate()
	_check(not arrow.get("is_penetrate") and arrow.get("impact_radius") == 0.0, "闪电箭不穿透无范围伤害")
	_check(arrow.get("hit_status_chance") == 0.2 and arrow.get("hit_status").get("id") == &"paralysis", "20%麻痹")
	arrow.free()


func _check_formulas() -> void:
	var script: GDScript = _fixture("@tool\nextends RefCounted\n" + _functions("res://scripts/stats/damage_scaling_rule.gd", ["_evaluate_formula"]))
	if script == null:
		return
	var helper: RefCounted = script.new()
	for spec: Array in [["guiren_fireball_manifest", "fire_formula", 64.0, 2], ["guiren_lightning_arrow_manifest", "lightning_formula", 13.0, 4]]:
		var projectile: Node = (load("res://scenes/ability/manifest/%s.tscn" % spec[0]) as PackedScene).instantiate()
		var rule: Resource = projectile.get("scaling_rule")
		var bonus: float = helper.call("_evaluate_formula", rule.get(spec[1]), {"intelligence": 7.0})
		_check(is_equal_approx(float(projectile.get("damage")) + bonus, spec[2]), "实际智力成长公式：" + spec[0])
		_check(projectile.get("damage_types") == [spec[3]], "仅对应元素伤害，无默认远程加成")
		_check(rule.get("physical_formula") == "" and rule.get("ranged_formula") == "", "清空默认力量/敏捷成长")
		projectile.free()


func _context_script() -> GDScript:
	return _fixture("@tool\nextends RefCounted\nvar caster: Node\nvar valid: bool = true\nfunc is_caster_action_valid() -> bool:\n\treturn valid and is_instance_valid(caster)\n")


func _actor_script() -> GDScript:
	return _fixture("@tool\nextends Node2D\nvar actionable: bool = true\nvar targetable: bool = true\nvar faction: StringName = &\"enemy\"\nvar status_controller: Node\nvar locks: Dictionary = {\"other\": true}\nfunc can_act() -> bool:\n\treturn actionable\nfunc can_be_targeted() -> bool:\n\treturn targetable\nfunc add_movement_lock(key: Variant) -> void:\n\tlocks[key] = true\nfunc remove_movement_lock(key: Variant) -> void:\n\tlocks.erase(key)\n")


func _check_burst() -> void:
	var body: String = _functions(BURST, ["can_pay_ability_cost", "_activate", "_process", "_advance_burst", "_clear_burst", "_exit_tree"])
	body = body.replace("AbilityContext", "RefCounted").replace("super._activate(emitted_context)", "_emit_manifest(emitted_context)")
	var script: GDScript = _fixture("@tool\nextends Node\nvar active_context: RefCounted\nvar shot_count: int = 3\nvar shot_interval: float = 0.12\nvar shots_remaining: int = 0\nvar next_shot: float = 0.0\nvar emissions: int = 0\nvar clear_on_emit: bool = false\nfunc _emit_manifest(_context: RefCounted) -> void:\n\temissions += 1\n\tif clear_on_emit:\n\t\t_clear_burst()\n" + body)
	var ctx_script: GDScript = _context_script()
	var actor_script: GDScript = _actor_script()
	if script == null or ctx_script == null or actor_script == null:
		return
	var helper: Node = script.new()
	var actor: Node = actor_script.new()
	var context: RefCounted = ctx_script.new()
	context.set("caster", actor)
	helper.call("_activate", context)
	_check(helper.get("emissions") == 1 and not helper.call("can_pay_ability_cost", context), "连发第一枚立即发出且不允许重入")
	helper.call("_process", 0.11)
	_check(helper.get("emissions") == 1, "间隔前不发第二枚")
	helper.call("_process", 0.01)
	_check(helper.get("emissions") == 2, "0.12秒第二枚")
	helper.call("_process", 0.12)
	_check(helper.get("emissions") == 3 and helper.call("can_pay_ability_cost", context), "三枚结束后解除重入限制")
	helper.call("_process", 1.0)
	_check(helper.get("emissions") == 3, "不会多发第四枚")
	helper.call("_activate", context)
	context.set("valid", false)
	helper.call("_process", 1.0)
	_check(helper.get("emissions") == 4 and helper.get("active_context") == null, "动作中断停止剩余箭")
	context.set("valid", true)
	helper.call("_activate", context)
	helper.call("_exit_tree")
	helper.call("_process", 1.0)
	_check(helper.get("emissions") == 5, "移除技能后不继续连发")
	helper.set("clear_on_emit", true)
	helper.call("_activate", context)
	helper.call("_process", 1.0)
	_check(helper.get("emissions") == 6 and helper.get("active_context") == null, "发射事件中重建技能栏也可安全停止")
	helper.free()
	actor.free()


func _channel_fixture() -> Node:
	var body: String = _functions(CHANNEL, ["_activate", "_process", "_finish", "_exit_tree"])
	body = body.replace("AbilityContext", "RefCounted").replace(": AbilityController", ": Node").replace(" as AbilityController", " as Node")
	body = body.replace("EventBus.is_battle_active", "battle_active")
	body = body.replace("child is AbilityComponent", "child.has_method(\"activate\")")
	var header: String = "@tool\nextends Node\nvar active_context: RefCounted\nvar remaining: float = 0.0\nvar controller: Node\nvar lock_key: String\nvar channel_seconds: float = 2.0\nvar block_other_abilities: bool = true\nvar require_battle_active: bool = true\nvar battle_active: bool = true\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _check_channel() -> void:
	var helper: Node = _channel_fixture()
	var actor_script: GDScript = _actor_script()
	var ctx_script: GDScript = _context_script()
	var ctrl: GDScript = _fixture("@tool\nextends Node\nsignal channel_completed(context: RefCounted)\nvar completions: int = 0\nvar blocks: Dictionary = {\"other\": {}}\nfunc set_cast_block_modifier(key: String, data: Dictionary) -> void:\n\tblocks[key] = data\nfunc clear_cast_block_modifier(key: String) -> void:\n\tblocks.erase(key)\n")
	var child_script: GDScript = _fixture("@tool\nextends Node\nvar auto_activate: bool = true\nvar count: int = 0\nfunc activate(_context: RefCounted) -> void:\n\tcount += 1\n")
	if helper == null or actor_script == null or ctx_script == null or ctrl == null or child_script == null:
		return
	var actor: Node = actor_script.new()
	var controller: Node = ctrl.new()
	controller.name = "AbilityController"
	controller.connect("channel_completed", func(_context: RefCounted) -> void: controller.set("completions", int(controller.get("completions")) + 1))
	actor.add_child(controller)
	var effect: Node = child_script.new()
	helper.add_child(effect)
	var context: RefCounted = ctx_script.new()
	context.set("caster", actor)
	helper.call("_activate", context)
	_check(actor.get("locks").size() == 2 and controller.get("blocks").size() == 2, "吟唱按来源锁移动和全部技能")
	helper.call("_process", 1.99)
	_check(effect.get("count") == 0, "吟唱未满两秒不提前加增益")
	helper.call("_process", 0.02)
	helper.call("_process", 5.0)
	_check(effect.get("count") == 1, "完成时只执行一次增益")
	_check(controller.get("completions") == 1, "完成只发出一次吟唱成功事件")
	_check(actor.get("locks") == {"other": true} and controller.get("blocks").size() == 1, "完成只移除自己的限制")
	helper.call("_activate", context)
	context.set("valid", false)
	helper.call("_process", 2.1)
	_check(effect.get("count") == 1 and actor.get("locks").size() == 1, "控制/死亡导致动作失效，不授予增益")
	context.set("valid", true)
	helper.call("_activate", context)
	helper.set("battle_active", false)
	helper.call("_process", 2.1)
	_check(effect.get("count") == 1 and controller.get("blocks").size() == 1, "战斗结束取消吟唱")
	helper.set("battle_active", true)
	helper.call("_activate", context)
	helper.call("_exit_tree")
	_check(actor.get("locks").size() == 1 and effect.get("count") == 1, "移除技能/切场景不残留锁或增益")
	_check(controller.get("completions") == 1, "控制打断、战斗结束和卸载不发吟唱奖励事件")
	helper.free()
	actor.free()


func _check_stacks() -> void:
	var path: String = "res://scripts/status/status_instance.gd"
	var body: String = _functions(path, ["set_source_stacks", "_normalize_source_key", "_recalculate_stacks", "refresh_duration"])
	var header: String = "@tool\nextends RefCounted\nvar status_data: Resource\nvar source_stacks: Dictionary = {}\nvar attribute_gain_sources: Dictionary = {}\nvar stacks: int = 0\nvar remaining_duration: float = 0.0\nvar duration_revision: int = 0\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return
	for file: String in ["shield_spell", "haste_spell"]:
		var status: Resource = load("res://status/%s.tres" % file) as Resource
		var helper: RefCounted = script.new()
		helper.set("status_data", status)
		helper.call("set_source_stacks", "spell", 1)
		helper.set("remaining_duration", 1.0)
		helper.call("set_source_stacks", "spell", 1)
		helper.call("refresh_duration")
		_check(helper.get("stacks") == 1 and helper.get("remaining_duration") == status.get("duration"), "重复施法一层并刷新完整时长：" + file)
	var shield: Resource = load("res://status/shield_spell.tres") as Resource
	_check(shield.get("id") != &"armor" and shield.get("effects")[0].get("value_per_stack") == 4.0, "独立护甲增益不污染装备armor")
	var haste: Resource = load("res://status/haste_spell.tres") as Resource
	_check(haste.get("effects")[0].get("stat_name") == &"speed" and haste.get("effects")[0].get("value_per_stack") == 4.0, "速度加成4")


func _check_movement_locks() -> void:
	var body: String = _functions("res://scripts/entity/entity.gd", ["add_movement_lock", "remove_movement_lock", "is_movement_locked"])
	var header: String = "@tool\nextends CharacterBody2D\nvar movement_lock_sources: Dictionary = {}\nvar movement_lock_timer: float = 1.0\nfunc clear_terrain_motion_velocity() -> void:\n\tpass\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return
	var actor: Node = script.new()
	actor.set("velocity", Vector2.RIGHT * 100)
	actor.call("add_movement_lock", "channel")
	actor.call("add_movement_lock", "other")
	_check(actor.get("velocity") == Vector2.ZERO, "吟唱立即停止原移动速度")
	actor.call("remove_movement_lock", "channel")
	_check(actor.call("is_movement_locked"), "不误解除其他来源的移动锁")
	actor.call("remove_movement_lock", "other")
	_check(actor.call("is_movement_locked") and actor.get("movement_lock_timer") == 1.0, "不修改原有计时移动锁")
	actor.set("movement_lock_timer", 0.0)
	_check(not actor.call("is_movement_locked"), "全部限制结束可移动")
	actor.free()


func _check_cooldown() -> void:
	var body: String = _functions("res://scripts/ability/core/ability_controller.gd", ["_get_modified_cooldown", "_get_fixed_cooldown", "_cooldown_modifier_matches", "_is_cast_blocked"])
	body = body.replace("Ability", "Node").replace("ability.id", "ability.get(\"id\")")
	body = body.replace("var cooldown := ability.cooldown", "var cooldown: float = float(ability.get(\"cooldown\"))")
	var header: String = "@tool\nextends RefCounted\nvar entity = null\nvar abilities: Array[Node] = []\nvar cooldown_modifiers: Dictionary = {}\nvar cast_block_modifiers: Dictionary = {}\nvar training_cooldown_override: float = -1.0\n"
	var script: GDScript = _fixture(header + body)
	var actor_script: GDScript = _fixture("@tool\nextends Node\nvar id: StringName = &\"ability\"\nvar cooldown: float = 8.0\nvar skill_data = null\n")
	if script == null or actor_script == null:
		return
	var helper: RefCounted = script.new()
	var basic: Node = actor_script.new()
	basic.set("cooldown", 0.5)
	var spell: Node = actor_script.new()
	helper.set("abilities", [basic, spell] as Array[Node])
	var effect: Resource = (load("res://status/haste_spell.tres") as Resource).get("effects")[1]
	helper.set("cooldown_modifiers", {"haste": {"cooldown_multiplier": effect.get("cooldown_multiplier"), "excluded_slot_indices": effect.get("excluded_slot_indices")}})
	_check(is_equal_approx(helper.call("_get_modified_cooldown", spell), 6.4), "8秒主动技能变为6.4秒")
	_check(helper.call("_get_modified_cooldown", basic) == 0.5, "基础攻击不减冷却")
	helper.set("cast_block_modifiers", {"channel": {"block_all": true}})
	_check(helper.call("_is_cast_blocked", basic) and helper.call("_is_cast_blocked", spell), "吟唱同时阻止普攻和主动技能")
	helper.set("cooldown_modifiers", {})
	helper.set("cast_block_modifiers", {})
	_check(helper.call("_get_modified_cooldown", spell) == 8.0 and not helper.call("_is_cast_blocked", spell), "移除后恢复冷却与技能输入")
	basic.free()
	spell.free()


func _impact_fixture(extra: String = "") -> Node:
	var body: String = _functions(IMPACT, ["_is_impact_target", "_collect_impact_targets", "_try_apply_status"])
	body = body.replace("Entity", "Node2D").replace("DamageData", "Resource")
	body = body.replace("get_world_2d().direct_space_state.intersect_shape(query, 512)", "simulated_hits")
	body = body.replace("randf()", "roll")
	var header: String = "@tool\nextends Node2D\nvar source: Node2D\nvar impact_radius: float = 90.0\nvar impact_target_mask: int = 4294967295\nvar simulated_hits: Array[Dictionary] = []\nvar hit_status: Resource\nvar hit_status_chance: float = 0.2\nvar hit_status_stacks: int = 1\nvar hit_status_duration: float = INF\nvar source_ability_id: StringName = &\"114\"\nvar roll: float = 0.0\nfunc _matches_target_group(target: Node) -> bool:\n\treturn target.get(\"faction\") == &\"enemy\"\nfunc _has_impact_sight(_target: Node2D) -> bool:\n\treturn true\n"
	var script: GDScript = _fixture(header + body + extra)
	return script.new() if script != null else null


func _check_impact_targets() -> void:
	var helper: Node = _impact_fixture()
	var actor_script: GDScript = _actor_script()
	if helper == null or actor_script == null:
		return
	var first: Node = actor_script.new()
	var second: Node = actor_script.new()
	var ally: Node = actor_script.new()
	ally.set("faction", &"player")
	var hits: Array[Dictionary] = []
	for actor: Node in [first, first, second, ally]:
		var area: Area2D = Area2D.new()
		actor.add_child(area)
		hits.append({"collider": area})
	helper.set("simulated_hits", hits)
	var targets: Array = helper.call("_collect_impact_targets", first)
	_check(targets.size() == 2 and targets.count(first) == 1, "爆炸命中多个敌人且接触目标/多Area不重复伤害")
	helper.set("impact_radius", 0.0)
	_check(helper.call("_collect_impact_targets", first) == [first], "闪电箭只伤害接触的一个目标")
	first.free()
	_check(helper.call("_collect_impact_targets", first).is_empty(), "接触目标提前释放时安全跳过")
	helper.free()
	second.free()
	ally.free()


func _check_hit_status() -> void:
	var helper: Node = _impact_fixture()
	var actor_script: GDScript = _actor_script()
	var status_script: GDScript = _fixture("@tool\nextends Node\nvar applied: int = 0\nfunc add_status(_data: Resource, _source: Node, _key: Variant, stacks: int, _duration: float) -> void:\n\tapplied += stacks\n")
	var data_script: GDScript = _fixture("@tool\nextends Resource\nvar is_miss: bool = false\nvar final_damage: float = 13.0\n")
	if helper == null or actor_script == null or status_script == null or data_script == null:
		return
	var source: Node = actor_script.new()
	var target: Node = actor_script.new()
	var controller: Node = status_script.new()
	var data: Resource = data_script.new()
	target.set("status_controller", controller)
	helper.set("source", source)
	helper.set("hit_status", load("res://status/paralysis.tres"))
	for roll: float in [0.0, 0.1999, 0.2, 0.99]:
		helper.set("roll", roll)
		helper.call("_try_apply_status", target, source, data)
	_check(controller.get("applied") == 2, "概率边界严格为20%，不隐式附加幸运")
	helper.set("roll", 0.0)
	data.set("is_miss", true)
	helper.call("_try_apply_status", target, source, data)
	data.set("is_miss", false)
	data.set("final_damage", 0.0)
	helper.call("_try_apply_status", target, source, data)
	_check(controller.get("applied") == 2, "闪避/无敌/零伤害不施加麻痹")
	data.set("final_damage", 13.0)
	target.set("targetable", false)
	helper.call("_try_apply_status", target, source, data)
	_check(controller.get("applied") == 2, "死亡或不可选目标不施加状态")
	helper.free()
	source.free()
	target.free()
	controller.free()


func _check_impact_once() -> void:
	var body: String = _functions(IMPACT, ["_on_area_2d_area_entered"])
	body = body.replace("Entity", "Node2D")
	_check(body.contains("_resolve_impact.call_deferred") and body.contains("set_deferred"), "物理回调只排队结算与禁用碰撞")
	body = body.replace("_resolve_impact.call_deferred(candidate, global_position)", "_record_impact(candidate, global_position)")
	var header: String = "@tool\nextends Node2D\nvar impact_pending: bool = false\nvar resolved: int = 0\nfunc try_intercept_projectile_movement(_movement: Vector2) -> bool:\n\treturn false\nfunc _is_impact_target(_target: Node2D) -> bool:\n\treturn true\nfunc _record_impact(_target: Node2D, _position: Vector2) -> void:\n\tresolved += 1\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return
	var projectile: Node = script.new()
	var target: Node2D = Node2D.new()
	var area: Area2D = Area2D.new()
	target.add_child(area)
	projectile.call("_on_area_2d_area_entered", area)
	projectile.call("_on_area_2d_area_entered", area)
	_check(projectile.get("resolved") == 1 and projectile.get("impact_pending"), "同帧重复接触只排队一次，不穿透")
	projectile.free()
	target.free()


func _functions(path: String, names: Array) -> String:
	var source: String = FileAccess.get_file_as_string(path)
	var result: String = ""
	for name: String in names:
		var start: int = source.find("func " + name + "(")
		var end: int = source.find("\nfunc ", start + 1)
		result += source.substr(start, end - start if end >= 0 else -1).strip_edges() + "\n\n"
	return result


func _fixture(source: String) -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = source
	var error: Error = script.reload()
	_check(error == OK, "隔离函数解析")
	return script if error == OK else null


func _check(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error(description)
