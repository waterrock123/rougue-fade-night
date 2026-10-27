## 编辑器资源与实际函数隔离检查，不启动主场景，不读写玩家存档。
extends SceneTree

const CONTROLLER: String = "res://scripts/ability/core/ability_controller.gd"
const CHARGE: String = "res://scripts/ability/component/ability_charge_release.gd"
const STATS: String = "res://scripts/stats/stats_controller.gd"
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
	_check_tuning()
	_check_charge()
	_check_charge_indicator()
	_check_charge_cooldown()
	_check_input()
	_check_immunity()
	_check_beam()
	print("贵人被动编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_resources() -> void:
	var skills: Array[Resource] = []
	for file: String in ["021_magic_missile_advanced", "022_magic_missile_meteor", "023_magic_missile_ray", "024_fire_ice_immunity"]:
		var data: Resource = load("res://passive_skill/%s.tres" % file) as Resource
		_check(data != null, "资源加载：" + file)
		if data == null:
			return
		skills.append(data)
		_check(data.get("allowed_character_ids") == [&"wizard"], "仅贵人归属：" + file)
		_check(data.get("icon") != null and not data.get("effects").is_empty(), "图标与效果：" + file)
		_check(not data.get("allowed_character_ids").has(&"warrior"), "不会分配给战狂：" + file)
	_check(skills[0].get("upgrade_options") == [skills[1], skills[2]], "进阶分叉到流星和射线")
	_check(skills[1].get("is_upgrade_skill") and skills[2].get("is_upgrade_skill"), "两分支标记为升级技能")
	var advanced: Resource = skills[0].get("effects")[0]
	var meteor: Resource = skills[1].get("effects")[0]
	var ray: Resource = skills[2].get("effects")[0]
	_check(advanced.get("damage_multiplier") == 1.5 and advanced.get("cooldown_multiplier") == 0.5, "进阶增伤和减冷却")
	_check(meteor.get("projectile_count") == 5 and meteor.get("damage_multiplier") == 1.5, "流星五发且保留增伤")
	_check(ray.get("charge_enabled") and ray.get("damage_multiplier") == 1.0 and ray.get("cooldown_multiplier") == 1.0, "射线不继承进阶倍率")
	var level_scene: Node = (load("res://scenes/ability/level_up_controller.tscn") as PackedScene).instantiate()
	var ids: Array = []
	for reward: Resource in level_scene.get("reward_pool").get("rewards"):
		if "skill_data" in reward and reward.get("skill_data") != null:
			ids.append(reward.get("skill_data").get("id"))
	_check(ids.has(&"021") and ids.has(&"024"), "两个初始被动进入奖励池")
	_check(not ids.has(&"022") and not ids.has(&"023"), "升级分支不混入初始奖励")
	level_scene.free()
	var ability: Node = (load("res://scenes/ability/guiren_basic_attack_ability.tscn") as PackedScene).instantiate()
	_check(ability.get("energy_cost") == 3.0, "普攻消耗3能量")
	_check(ability.has_node("ChargeRelease") and ability.has_node("FullChargeBeam"), "蓄力和满蓄力实体分工")
	_check(ability.get("cooldown") == 0.65 and ability.get_node("ChargeRelease").get("charge_seconds") == 3.5, "普攻0.65秒冷却，射线分支3.5秒蓄满")
	_check(ability.get_node("ChargeRelease").get("scale_charge_with_cooldown"), "贵人蓄力启用冷却同比缩短")
	ability.free()


func _tuning_fixture() -> Node:
	var body: String = ""
	for function: String in ["set_cast_tuning_modifier", "clear_cast_tuning_modifier", "get_cast_tuning", "_cooldown_modifier_matches", "set_cooldown_modifier", "clear_cooldown_modifier", "get_effective_cooldown", "_get_modified_cooldown", "_get_fixed_cooldown"]:
		body += _function_source(CONTROLLER, function)
	body = body.replace("Ability", "Node").replace("ability.id", "ability.get(\"id\")")
	body = body.replace("previewing_ability.has_cast_preview()", "previewing_ability.call(\"has_cast_preview\")")
	body = body.replace("ability.cooldown", "float(ability.get(\"cooldown\"))")
	var header: String = "@tool\nextends Node\nvar cast_tuning_modifiers: Dictionary = {}\nvar cooldown_modifiers: Dictionary = {}\nvar abilities: Array[Node] = []\nvar previewing_ability: Node\nvar entity\nvar training_cooldown_override: float = -1.0\nfunc cancel_ability_preview() -> void:\n\tpreviewing_ability = null\nfunc reduce_remaining_cooldown(_ability: Node, _ratio: float) -> void:\n\tpass\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _check_tuning() -> void:
	var controller: Node = _tuning_fixture()
	var actor: GDScript = _fixture("@tool\nextends Node\nvar id: StringName = &\"112\"\n")
	if controller == null or actor == null:
		return
	var ability: Node = actor.new()
	controller.set("abilities", [ability] as Array[Node])
	var body: String = _function_source("res://scripts/skill/passive_ability_cast_tuning_effect.gd", "apply")
	body += _function_source("res://scripts/skill/passive_ability_cast_tuning_effect.gd", "remove")
	body = body.replace("SkillContext", "RefCounted")
	var effect_script: GDScript = _fixture("@tool\nextends RefCounted\nvar target_ability_ids: Array[StringName] = [&\"112\"]\nvar damage_multiplier: float = 1.5\nvar cooldown_multiplier: float = 0.5\nvar projectile_count: int = 5\nvar charge_enabled: bool = false\n" + body)
	var context_script: GDScript = _fixture("@tool\nextends RefCounted\nvar ability_controller: Node\nvar effect_key: String = \"passive\"\n")
	if effect_script != null and context_script != null:
		var effect: RefCounted = effect_script.new()
		var context: RefCounted = context_script.new()
		context.set("ability_controller", controller)
		effect.call("apply", context)
		effect.call("apply", context)
		var tuning: Dictionary = controller.call("get_cast_tuning", ability)
		_check(tuning["damage_multiplier"] == 1.5 and tuning["projectile_count"] == 5, "重复刷新同来源不重复叠加")
		_check(controller.get("cooldown_modifiers")["passive"]["cooldown_multiplier"] == 0.5, "冷却按来源注册")
		ability.set("id", &"other")
		_check(controller.call("get_cast_tuning", ability)["damage_multiplier"] == 1.0, "不会改变其他主动技能")
		ability.set("id", &"112")
		effect.call("remove", context)
		_check(controller.get("cooldown_modifiers").is_empty(), "移除被动撤销冷却")
		_check(controller.call("get_cast_tuning", ability)["projectile_count"] == 0, "移除后恢复原齐射数")
	ability.free()
	controller.free()


func _check_charge() -> void:
	var body: String = _function_source(CHARGE, "get_charge_ratio") + _function_source(CHARGE, "_activate")
	body = body.replace("AbilityContext", "RefCounted")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar charge_seconds: float = 3.5\nvar active_charge_seconds: float = 0.0\nvar max_damage_multiplier: float = 2.0\nfunc is_preview_enabled() -> bool:\n\treturn true\n" + body)
	var ctx_script: GDScript = _fixture("@tool\nextends RefCounted\nvar charge_ratio: float = 0.0\nvar projectile_damage_multiplier: float = 1.0\n")
	if script == null or ctx_script == null:
		return
	var helper: RefCounted = script.new()
	var context: RefCounted = ctx_script.new()
	for seconds: float in [0.0, 1.5, 1.75, 3.5, 9.0]:
		var ratio: float = helper.call("get_charge_ratio", seconds)
		context.set("charge_ratio", ratio)
		context.set("projectile_damage_multiplier", 1.0)
		helper.call("_activate", context)
		_check(is_equal_approx(float(context.get("projectile_damage_multiplier")), 1.0 + minf(seconds / 3.5, 1.0)), "蓄力伤害线性且3.5秒到达2倍：%s" % seconds)
	var full_body: String = _function_source("res://scripts/ability/component/ability_spawn_manifest_on_full_charge.gd", "_activate")
	full_body = full_body.replace("AbilityContext", "RefCounted").replace("super._activate(context)", "spawned += 1")
	var full_script: GDScript = _fixture("@tool\nextends RefCounted\nvar spawned: int = 0\n" + full_body)
	if full_script != null:
		var full: RefCounted = full_script.new()
		context.set("charge_ratio", 0.99)
		full.call("_activate", context)
		_check(full.get("spawned") == 0, "非满蓄力不产生激光")
		context.set("charge_ratio", 1.0)
		full.call("_activate", context)
		_check(full.get("spawned") == 1, "满蓄力额外一次激光")


func _check_charge_indicator() -> void:
	var scene: Node = (load("res://scenes/ability/guiren_basic_attack_ability.tscn") as PackedScene).instantiate()
	var component: Node = scene.get_node("ChargeRelease")
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/ability_charge_indicator.gd")
	var indicator_script: GDScript = _fixture("@tool\n" + source.replace("class_name AbilityChargeIndicator\n", ""))
	var body: String = (_function_source(CHARGE, "begin_preview") + _function_source(CHARGE, "get_charge_ratio")).replace("AbilityContext", "RefCounted")
	body = body.replace("AbilityChargeIndicator.new()", "indicator_script.new()")
	var header: String = "@tool\nextends RefCounted\nvar active_context: RefCounted\nvar indicator\nvar elapsed: float = 0.0\nvar charge_seconds: float = 3.5\nvar active_charge_seconds: float = 0.0\nvar requested_duration: float = 2.8\nvar indicator_script: GDScript\nvar indicator_offset: Vector2\nvar indicator_radius: float\nvar indicator_line_width: float\nfunc get_charge_duration() -> float:\n\treturn requested_duration\nfunc end_preview() -> void:\n\tif is_instance_valid(indicator):\n\t\tindicator.free()\n\tindicator = null\n\tactive_charge_seconds = 0.0\n"
	var script: GDScript = _fixture(header + body)
	var context_script: GDScript = _fixture("@tool\nextends RefCounted\nvar caster: Node2D\n")
	if script != null and context_script != null and indicator_script != null:
		var helper: RefCounted = script.new()
		var context: RefCounted = context_script.new()
		var caster: Node2D = Node2D.new()
		context.set("caster", caster)
		helper.set("indicator_script", indicator_script)
		for key: String in ["indicator_offset", "indicator_radius", "indicator_line_width"]:
			helper.set(key, component.get(key))
		helper.call("begin_preview", context)
		var indicator: Node2D = helper.get("indicator") as Node2D
		_check(indicator.get("radius") == 6.0 and is_equal_approx(float(indicator.get("line_width")), 1.2), "实际生成小型细线蓄力环")
		_check(indicator.position == component.get("indicator_offset") and indicator.get_parent() == caster, "蓄力环读取组件位置配置且随人物移动")
		_check(is_equal_approx(float(helper.get("active_charge_seconds")), 2.8), "开始预览时保存本次缩减后的蓄力时长")
		helper.set("requested_duration", 3.5)
		_check(is_equal_approx(float(helper.call("get_charge_ratio", 1.4)), 0.5), "开始后修正变化不会使本次蓄力进度倒退")
		helper.call("end_preview")
		_check(not is_instance_valid(indicator), "预览结束清理圆环")
		caster.free()
	scene.free()


func _charge_duration_fixture() -> Node:
	var body: String = _function_source(CHARGE, "get_charge_duration")
	body = body.replace("AbilityController", "Node").replace("Ability", "Node")
	body = body.replace("ability.cooldown", "float(ability.get(\"cooldown\"))")
	body = body.replace("controller.get_effective_cooldown(ability)", "float(controller.call(\"get_effective_cooldown\", ability))")
	var script: GDScript = _fixture("@tool\nextends Node\nvar charge_seconds: float = 3.5\nvar scale_charge_with_cooldown: bool = true\n" + body)
	return script.new() if script != null else null


func _check_charge_cooldown() -> void:
	var controller: Node = _tuning_fixture()
	var helper: Node = _charge_duration_fixture()
	var actor: GDScript = _fixture("@tool\nextends Node\nvar id: StringName = &\"112\"\nvar cooldown: float = 0.65\nvar stats_controller: Node\nvar rate: float = 0.0\nfunc get_stat(_key: String) -> float:\n\treturn rate\n")
	if controller == null or helper == null or actor == null:
		return
	var ability: Node = actor.new()
	var entity: Node = actor.new()
	entity.set("stats_controller", entity)
	controller.set("entity", entity)
	controller.set("abilities", [ability] as Array[Node])
	controller.add_child(ability)
	ability.add_child(helper)
	var cases: Array[Dictionary] = [
		{"rate": 0.0, "mods": {}, "expected": 3.5},
		{"rate": 0.2, "mods": {}, "expected": 2.8},
		{"rate": 0.5, "mods": {}, "expected": 1.75},
		{"rate": 0.2, "mods": {"id": {"target_ability_ids": [&"112"], "cooldown_multiplier": 0.5}}, "expected": 1.4},
		{"rate": 0.2, "mods": {"other": {"target_ability_ids": [&"other"], "cooldown_multiplier": 0.5}}, "expected": 2.8},
		{"rate": 0.2, "mods": {"exclude": {"excluded_slot_indices": [0], "cooldown_multiplier": 0.5}}, "expected": 2.8},
		{"rate": 0.2, "mods": {"flat": {"target_slot_indices": [0], "flat_reduction": 0.13}}, "expected": 2.1},
		{"rate": 0.0, "mods": {"slow": {"cooldown_multiplier": 2.0}}, "expected": 3.5},
		{"rate": 0.0, "mods": {"zero": {"cooldown_override": 0.0}}, "expected": 0.01},
	]
	for data: Dictionary in cases:
		entity.set("rate", data["rate"])
		controller.set("cooldown_modifiers", data["mods"])
		_check(is_equal_approx(float(helper.call("get_charge_duration")), float(data["expected"])), "蓄力复用真实冷却倍率：%s" % data)
	helper.set("scale_charge_with_cooldown", false)
	_check(helper.call("get_charge_duration") == 3.5, "未启用的其他蓄力技能保持原时长")
	helper.set("scale_charge_with_cooldown", true)
	ability.set("cooldown", 0.0)
	_check(helper.call("get_charge_duration") == 3.5, "零基础冷却不除零")
	entity.set("stats_controller", null)
	entity.free()
	controller.free()


func _check_input() -> void:
	var body: String = ""
	for function: String in ["release_ability_preview", "cancel_ability_preview", "trigger_held_ability_by_idx"]:
		body += _function_source(CONTROLLER, function)
	body = body.replace("Ability", "Node").replace("ability.has_cast_preview()", "ability.call(\"has_cast_preview\")")
	body = body.replace("ability.end_cast_preview()", "ability.call(\"end_cast_preview\")")
	body = body.replace("ability.preview_context", "ability.get(\"preview_context\")")
	var header: String = "@tool\nextends RefCounted\nvar previewing_ability: Node\nvar abilities: Array[Node] = []\nvar released: Array = []\nfunc trigger_ability(_ability: Node, ratio: float = 0.0) -> bool:\n\treleased.append(ratio)\n\treturn true\n"
	var script: GDScript = _fixture(header + body)
	var actor: GDScript = _fixture("@tool\nextends Node\nvar preview_context: RefCounted\nfunc has_cast_preview() -> bool:\n\treturn true\nfunc end_cast_preview() -> void:\n\tpreview_context = null\n")
	var ctx: GDScript = _fixture("@tool\nextends RefCounted\nvar charge_ratio: float = 0.75\n")
	if script == null or actor == null or ctx == null:
		return
	var helper: RefCounted = script.new()
	var ability: Node = actor.new()
	helper.set("abilities", [ability] as Array[Node])
	helper.call("trigger_held_ability_by_idx", 0)
	_check(helper.get("released").is_empty(), "蓄力分支按住不自动续放")
	ability.set("preview_context", ctx.new())
	helper.set("previewing_ability", ability)
	helper.call("release_ability_preview", ability)
	_check(helper.get("released") == [0.75] and ability.get("preview_context") == null, "松开先保存比例再清理预览")
	helper.call("release_ability_preview", ability)
	_check(helper.get("released").size() == 1, "同一次预览不重复释放")
	helper.set("previewing_ability", ability)
	ability.set("preview_context", ctx.new())
	helper.call("cancel_ability_preview")
	_check(helper.get("released").size() == 1 and ability.get("preview_context") == null, "取消不释放且清空比例")
	ability.free()


func _check_immunity() -> void:
	var body: String = ""
	for function: String in ["set_damage_type_immunity", "clear_damage_type_immunity", "is_damage_type_immune", "process_incoming_damage"]:
		body += _function_source(STATS, function)
	body = body.replace("DamageData", "Resource")
	var header: String = "@tool\nextends RefCounted\nvar damage_immunity_sources: Dictionary = {}\nfunc get_stat(_key: String) -> float:\n\treturn 0.0\nfunc _get_incoming_damage_taken_multiplier(_data: Resource) -> float:\n\treturn 1.3\n"
	var script: GDScript = _fixture(header + body)
	var data_script: GDScript = _fixture("@tool\nextends Resource\nvar final_damage: float = 100.0\nvar damage_types: Array[int] = []\nvar ignore_static_damage_reduction: bool = true\nvar ignore_damage_reduction_rate: bool = true\n")
	if script == null or data_script == null:
		return
	var helper: RefCounted = script.new()
	helper.call("set_damage_type_immunity", "passive", [2, 3] as Array[int])
	for damage_type: int in range(6):
		var data: Resource = data_script.new()
		data.set("damage_types", [damage_type] as Array[int])
		helper.call("process_incoming_damage", data)
		_check(data.get("final_damage") == (0.0 if damage_type in [2, 3] else 130.0), "免疫不被易伤/无视减伤抵消且不影响其他类型：%d" % damage_type)
	helper.call("set_damage_type_immunity", "other", [2] as Array[int])
	helper.call("clear_damage_type_immunity", "passive")
	_check(helper.call("is_damage_type_immune", [2] as Array[int]) and not helper.call("is_damage_type_immune", [3] as Array[int]), "来源独立移除")


func _check_beam() -> void:
	var beam: Node = (load("res://scenes/ability/manifest/guiren_charged_beam_manifest.tscn") as PackedScene).instantiate()
	_check(beam.get("lifetime") == 2.0 and beam.get("max_range") == 160.0, "激光持续2秒，缩短至160射程")
	_check(beam.get("tick_interval") == 0.2, "每0.2秒结算一次激光伤害")
	_check(beam.get("damage") == 2.5 and beam.get("damage_types") == [4], "基础闪电伤害减半至2.5")
	_check(beam.get("scaling_rule").get("lightning_formula") == "intelligence", "追加当前智力")
	_check(beam.get("caster_status") == null and not beam.get("can_crit"), "不锁移动且不暴击")
	_check(beam.get_child_count() == 3, "三层光束显示")
	beam.free()
	var body: String = _function_source("res://scripts/ability/manifest/sustained_directional_area_manifest.gd", "_physics_process")
	var header: String = "@tool\nextends RefCounted\nvar finished: bool = false\nvar cast_context: RefCounted = RefCounted.new()\nvar lifetime: float = 2.0\nvar elapsed: float = 0.0\nvar tick_timer: float = 0.0\nvar tick_interval: float = 0.2\nvar ticks: int = 0\nfunc _can_continue() -> bool:\n\treturn true\nfunc _update_aim() -> void:\n\tpass\nfunc _apply_tick() -> void:\n\tticks += 1\nfunc _finish() -> void:\n\tfinished = true\n"
	var script: GDScript = _fixture(header + body)
	if script != null:
		var helper: RefCounted = script.new()
		helper.call("_physics_process", 3.0)
		_check(helper.get("ticks") == 10 and helper.get("finished"), "低帧率只补生命周期内十次伤害")
		helper.call("_physics_process", 1.0)
		_check(helper.get("ticks") == 10, "结束后不额外结算")


func _function_source(path: String, name: String) -> String:
	var source: String = FileAccess.get_file_as_string(path)
	var start: int = source.find("func " + name + "(")
	var end: int = source.find("\nfunc ", start + 1)
	return source.substr(start, end - start if end >= 0 else -1).strip_edges() + "\n\n"


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
