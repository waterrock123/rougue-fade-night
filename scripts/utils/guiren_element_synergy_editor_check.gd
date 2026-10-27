## 编辑器资源扫描与真实函数隔离测试，不启动主场景，不读写玩家存档。
extends SceneTree

const ACTIVE: Array[String] = ["117_frost_star_ring", "118_lightning_circle", "119_arcane_step", "120_biphasic_collapse"]
const PASSIVE: Array[String] = ["025_element_weaving", "026_rainbow_weaving", "027_undying_embers", "028_spreading_embers", "029_thunder_echo", "030_thunder_resonance", "031_composed_casting", "032_elegant_ritual"]
const DIR: String = "res://scripts/skill/"
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
	_check_cast_record()
	_check_event_filters()
	_check_next_cast()
	_check_rotation()
	_check_hit_status()
	_check_chain_counter()
	_check_channel_reward()
	_check_schedules()
	_check_blink()
	_check_damage_multiplier()
	_check_routes()
	print("贵人元素联动编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_resources() -> void:
	var scene: PackedScene = load("res://scenes/ability/level_up_controller.tscn") as PackedScene
	_check(scene != null, "奖励场景加载")
	if scene == null:
		return
	var level: Node = scene.instantiate()
	var rewards: Array = level.get("reward_pool").get("rewards")
	var database: Resource = load("res://custom_resource/default_keyword_database.tres") as Resource
	var known: Dictionary = {}
	for word: Resource in database.get("keywords"):
		known[str(word.get("id"))] = true
	var token: RegEx = RegEx.create_from_string("\\{([A-Za-z_]+)\\}")
	for folder: String in ["activate_skill", "passive_skill"]:
		var names: Array[String] = ACTIVE if folder == "activate_skill" else PASSIVE
		for name: String in names:
			var data: Resource = load("res://%s/%s.tres" % [folder, name]) as Resource
			_check(data != null, "加载：" + name)
			if data == null:
				continue
			_check(data.get("id") == StringName(name.left(3)) and data.get("allowed_character_ids") == [&"wizard"], "编号与角色归属：" + name)
			var count: int = 0
			for reward: Resource in rewards:
				if "skill_data" in reward and reward.get("skill_data") == data:
					count += 1
			_check(count == (0 if data.get("is_upgrade_skill") else 1), "仅初始技能进池：" + name)
			for match_result: RegExMatch in token.search_all(str(data.get("desc"))):
				_check(known.has(match_result.get_string(1)), "关键词可解释：" + match_result.get_string(1))
			if folder == "activate_skill":
				_check_active(data)
			elif not data.get("is_upgrade_skill"):
				_check(data.get("upgrade_options").size() == 1 and data.get("upgrade_options")[0].get("is_upgrade_skill"), "升级分支：" + name)
	level.free()


func _check_active(data: Resource) -> void:
	var ability: Node = (data.get("ability_scene") as PackedScene).instantiate()
	_check(ability.get("energy_cost") == data.get("base_energy_cost") and ability.get("cooldown") == data.get("base_cooldown"), "场景消耗冷却一致")
	_check(data.get("icon") != null and not data.get("element_tags").is_empty(), "元素与现有图标")
	if ability.has_node("Target"):
		_check(ability.get_node("Target").get("max_range") == ability.get_node("Indicator").get("radius"), "实际落点与预览范围相同")
	if ability.has_node("Channel"):
		_check(ability.get_node("Channel").get("channel_seconds") == 1.0, "双相崩解吟唱1秒")
	ability.free()


func _record() -> RefCounted:
	var source: String = FileAccess.get_file_as_string("res://scripts/ability/core/ability_cast_record.gd")
	var script: GDScript = _fixture("@tool\n" + source.replace("class_name AbilityCastRecord\n", ""))
	return script.new() if script != null else null


func _check_cast_record() -> void:
	var record: RefCounted = _record()
	_check(record.call("claim_once", "embers", 10), "同次施法首命中允许附加")
	_check(not record.call("claim_once", "embers", 10), "重复脉冲或分裂弹不重复附加")
	_check(record.call("claim_once", "embers", 11), "不同目标独立")
	_check(record.call("claim_once", "thunder", 10), "不同被动独立")
	_check(_record().call("claim_once", "embers", 10), "新施法重新计数")


func _check_event_filters() -> void:
	var body: String = _functions(DIR + "skill_combat_listener.gd", ["_ready_for_event", "_eligible_hit"])
	body = body.replace("DamageData", "RefCounted")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar caster: Node\nvar bound: bool = true\nvar battle_enabled: bool = true\n" + body)
	var actor_script: GDScript = _fixture("@tool\nextends Node\nvar is_dead: bool = false\n")
	var hit_script: GDScript = _fixture("@tool\nextends RefCounted\nvar source: Node\nvar target: Node\nvar final_damage: float = 10.0\nvar allow_skill_procs: bool = true\nvar cast_record: RefCounted\n")
	if script == null or actor_script == null or hit_script == null:
		return
	var helper: RefCounted = script.new()
	var actor: Node = actor_script.new()
	var target: Node = actor_script.new()
	var hit: RefCounted = hit_script.new()
	helper.set("caster", actor)
	hit.set("source", actor)
	hit.set("target", target)
	hit.set("cast_record", _record())
	_check(not helper.call("_eligible_hit", hit), "地图物件不计为敌人命中")
	target.add_to_group("enemy")
	_check(helper.call("_eligible_hit", hit), "敌人有效技能命中允许触发")
	hit.set("allow_skill_procs", false)
	_check(not helper.call("_eligible_hit", hit), "真实过滤器阻止次级连锁递归")
	hit.set("allow_skill_procs", true)
	hit.get("cast_record").set("is_basic_attack", true)
	_check(not helper.call("_eligible_hit", hit), "真实过滤器排除基础攻击")
	hit.get("cast_record").set("is_basic_attack", false)
	hit.set("final_damage", 0.0)
	_check(not helper.call("_eligible_hit", hit), "无伤害不参与有效命中")
	hit.set("final_damage", 10.0)
	helper.set("battle_enabled", false)
	_check(not helper.call("_eligible_hit", hit), "战斗结束不继续触发")
	actor.free()
	target.free()


func _ability() -> Node:
	var script: GDScript = _fixture("@tool\nextends Node\nvar energy_cost: float = 12.0\nvar skill_data: Resource\n")
	return script.new() if script != null else null


func _context() -> RefCounted:
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar cast_record: RefCounted\nvar ability: Node\nvar element_tags: Array[StringName] = []\n")
	var context: RefCounted = script.new()
	context.set("cast_record", _record())
	return context


func _controller() -> RefCounted:
	var names: Array = ["set_next_cast_modifier", "clear_next_cast_modifier", "is_basic_ability", "get_modified_energy_cost", "prepare_cast_context"]
	var body: String = _functions("res://scripts/ability/core/ability_controller.gd", names)
	body = body.replace("AbilityContext", "RefCounted").replace("Ability", "Node")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nsignal cast_prepared(context: RefCounted)\nvar abilities: Array[Node] = []\nvar next_cast_modifiers: Dictionary = {}\n" + body)
	return script.new() if script != null else null


func _check_next_cast() -> void:
	var controller: RefCounted = _controller()
	var basic: Node = _ability()
	var spell: Node = _ability()
	controller.set("abilities", [basic, spell] as Array[Node])
	controller.call("set_next_cast_modifier", "ritual", {"energy_reduction": 5.0, "damage_multiplier": 1.25})
	for i: int in range(3):
		_check(controller.call("get_modified_energy_cost", spell) == 7.0, "反复预检查不会用掉优惠")
	_check(controller.get("next_cast_modifiers").size() == 1, "未释放时仍保存优惠")
	var context: RefCounted = _context()
	context.set("ability", basic)
	controller.call("prepare_cast_context", context)
	_check(controller.get("next_cast_modifiers").size() == 1 and context.get("cast_record").get("damage_multiplier") == 1.0, "基础攻击不使用优惠")
	context.set("ability", spell)
	controller.call("prepare_cast_context", context)
	_check(controller.get("next_cast_modifiers").is_empty() and context.get("cast_record").get("damage_multiplier") == 1.25, "下一次真实非基础施法消费且快照伤害")
	_check(controller.call("get_modified_energy_cost", spell) == 12.0, "用过后恢复原价")
	controller.call("set_next_cast_modifier", "ritual", {"energy_reduction": 5.0})
	controller.call("set_next_cast_modifier", "ritual", {"energy_reduction": 5.0})
	_check(controller.call("get_modified_energy_cost", spell) == 7.0, "同来源优惠不可叠加")
	spell.set("energy_cost", 3.0)
	_check(controller.call("get_modified_energy_cost", spell) == 0.0, "优惠不产生负消耗")
	controller.call("clear_next_cast_modifier", "ritual")
	_check(controller.get("next_cast_modifiers").is_empty(), "移除被动或结束战斗可清理优惠")
	basic.free()
	spell.free()


func _check_rotation() -> void:
	var body: String = _functions(DIR + "element_rotation_listener.gd", ["_on_cast", "is_different_rotation", "_reset_state"])
	body = body.replace("AbilityContext", "RefCounted")
	var header: String = "@tool\nextends RefCounted\nvar previous_elements: Array[StringName] = []\nvar config: Resource\nvar refunded: float = 0.0\nfunc _eligible_cast(context: RefCounted) -> bool:\n\treturn not context.cast_record.is_basic_attack\nfunc _refund_energy(amount: float) -> void:\n\trefunded += amount\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return
	var listener: RefCounted = script.new()
	listener.set("config", load("res://passive_skill/025_element_weaving.tres").get("effects")[0])
	var context: RefCounted = _context()
	context.set("element_tags", [&"fire"] as Array[StringName])
	listener.call("_on_cast", context)
	listener.call("_on_cast", context)
	_check(listener.get("refunded") == 0.0, "首发与相同元素不触发")
	context.set("element_tags", [&"lightning"] as Array[StringName])
	listener.call("_on_cast", context)
	_check(listener.get("refunded") == 3.0 and is_equal_approx(context.get("cast_record").get("damage_multiplier"), 1.2), "当前第二次技能伤害+20%并返还3")
	context.set("element_tags", [&"lightning", &"fire"] as Array[StringName])
	listener.call("_on_cast", context)
	_check(listener.get("refunded") == 3.0, "共享任一元素不算交替")
	context.set("element_tags", [] as Array[StringName])
	listener.call("_on_cast", context)
	context.set("element_tags", [&"magic"] as Array[StringName])
	listener.call("_on_cast", context)
	_check(listener.get("refunded") == 3.0, "无元素中断连段")
	context.get("cast_record").set("is_basic_attack", true)
	context.set("element_tags", [&"ice"] as Array[StringName])
	listener.call("_on_cast", context)
	_check(listener.get("previous_elements") == [&"magic"], "普通攻击不会改变轮转记录")
	listener.call("_reset_state")
	_check(listener.get("previous_elements").is_empty(), "战斗间不保留元素轮转")


func _hit() -> RefCounted:
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar cast_record: RefCounted\nvar target: Node\nvar eligible: bool = true\nvar elements: Array[StringName] = [&\"fire\"]\nfunc has_skill_element(element: StringName) -> bool:\n\treturn elements.has(element)\n")
	var hit: RefCounted = script.new()
	hit.set("cast_record", _record())
	return hit


func _target() -> Node:
	var script: GDScript = _fixture("@tool\nextends Node2D\nvar current_health: float = 100.0\n")
	return script.new()


func _check_hit_status() -> void:
	var body: String = _functions(DIR + "element_hit_status_listener.gd", ["_on_hit"]).replace("DamageData", "RefCounted")
	var header: String = "@tool\nextends RefCounted\nvar config: Resource\nvar source_key: String = \"embers\"\nvar applied: int = 0\nfunc _eligible_hit(data: RefCounted) -> bool:\n\treturn data.eligible\nfunc _apply_status(_target: Node, stacks: int) -> void:\n\tapplied += stacks\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return
	var listener: RefCounted = script.new()
	listener.set("config", load("res://passive_skill/027_undying_embers.tres").get("effects")[0])
	var hit: RefCounted = _hit()
	var first: Node = _target()
	var second: Node = _target()
	hit.set("target", first)
	for i: int in range(10):
		listener.call("_on_hit", hit)
	_check(listener.get("applied") == 1, "同次火焰技能同目标十次伤害只附加1层")
	hit.set("target", second)
	listener.call("_on_hit", hit)
	_check(listener.get("applied") == 2, "另一目标独立附加")
	hit.set("cast_record", _record())
	listener.call("_on_hit", hit)
	_check(listener.get("applied") == 3, "第二次施法可再次附加")
	hit.set("eligible", false)
	listener.call("_on_hit", hit)
	_check(listener.get("applied") == 3, "闪避、零伤害、次级联动等不触发")
	first.free()
	second.free()


func _check_chain_counter() -> void:
	var body: String = _functions(DIR + "element_hit_chain_listener.gd", ["_on_hit", "_reset_state"]).replace("DamageData", "RefCounted")
	var header: String = "@tool\nextends RefCounted\nvar config: Resource\nvar source_key: String = \"thunder\"\nvar hit_count: int = 0\nvar chains: int = 0\nfunc _eligible_hit(data: RefCounted) -> bool:\n\treturn data.eligible\nfunc _chain_from(_target: Node) -> void:\n\tchains += 1\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return
	var listener: RefCounted = script.new()
	listener.set("config", load("res://passive_skill/029_thunder_echo.tres").get("effects")[0])
	var hit: RefCounted = _hit()
	hit.set("elements", [&"lightning"] as Array[StringName])
	for i: int in range(2):
		listener.call("_on_hit", hit)
	_check(listener.get("chains") == 0, "两次命中不放电")
	listener.call("_on_hit", hit)
	_check(listener.get("chains") == 1, "第三次命中放电")
	for i: int in range(6):
		listener.call("_on_hit", hit)
	_check(listener.get("chains") == 1, "同次群攻多次达阈值也最多一次")
	hit.set("cast_record", _record())
	for i: int in range(3):
		listener.call("_on_hit", hit)
	_check(listener.get("chains") == 2, "下一次施法重新允许放电")
	listener.call("_reset_state")
	_check(listener.get("hit_count") == 0, "结束清理命中计数")


func _check_schedules() -> void:
	var body: String = _functions("res://scripts/ability/manifest/timed_radial_area_manifest.gd", ["_advance"])
	var header: String = "@tool\nextends Node\nvar elapsed: float = 0.0\nvar emitted: int = 0\nvar next_pulse: float = 1.0\nvar pulse_count: int = 4\nvar pulse_interval: float = 1.0\nvar pulse_glow: float = 0.0\nvar times: Array[float] = []\nfunc _apply_pulse() -> void:\n\ttimes.append(elapsed)\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return
	var helper: Node = script.new()
	helper.call("_advance", 0.99)
	_check(helper.get("emitted") == 0, "雷阵第一秒前不跳伤害")
	helper.call("_advance", 0.01)
	helper.call("_advance", 1.0)
	helper.call("_advance", 1.0)
	helper.call("_advance", 1.0)
	_check(helper.get("emitted") == 4 and helper.get("times") == [1.0, 2.0, 3.0, 4.0], "雷阵准确四跳")
	helper.free()
	var manifest: Node = (load("res://scenes/ability/manifest/guiren_lightning_circle_manifest.tscn") as PackedScene).instantiate()
	_check(manifest.get("status_only_last_pulse") and manifest.get("hit_status").get("id") == &"paralysis", "仅末跳带麻痹")
	manifest.free()
	manifest = (load("res://scenes/ability/manifest/guiren_biphasic_lightning_manifest.tscn") as PackedScene).instantiate()
	_check(manifest.get("initial_delay") == 0.4 and manifest.get("status_chance") == 0.3, "第二段延迟与麻痹概率")
	manifest.free()
	manifest = (load("res://scenes/ability/manifest/guiren_frost_star_ring_manifest.tscn") as PackedScene).instantiate()
	_check(manifest.get("status_duration") == 0.8 and manifest.get("hit_status").get("id") == &"freeze", "寒星环冻结独立持续时间")
	manifest.free()


func _check_blink() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ability/component/ability_teleport_to_cursor.gd")
	_check(source.contains(".limit_length(maxf(max_distance, 0.0))") and source.contains("is_world_position_in_playable_region"), "折跃限距与地图边界检查")
	_check(source.contains("caster.test_move") and source.contains("has_sight"), "折跃使用角色物理形状和沿线墙体检查")
	var status: Resource = load("res://status/arcane_step_guard.tres") as Resource
	_check(status.get("duration") == 1.0 and status.get("effects")[0].get("percent_bonus") == -0.2, "落地1秒减伤20%")
	_check_blink_destinations()


func _blink_helper() -> RefCounted:
	var body: String = _functions("res://scripts/ability/component/ability_teleport_to_cursor.gd", ["resolve_destination", "_is_safe"])
	body = body.replace("Entity", "Node2D").replace("SkillCombatQuery.has_sight", "_has_sight")
	var header: String = "@tool\nextends RefCounted\nvar max_distance: float = 160.0\nvar sample_step: float = 4.0\nvar sight: bool = true\nfunc _has_sight(_caster: Node2D, _start: Vector2, _end: Vector2) -> bool:\n\treturn sight\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _check_blink_destinations() -> void:
	var helper: RefCounted = _blink_helper()
	var actor_script: GDScript = _fixture("@tool\nextends Node2D\nvar wall_x: float = INF\nfunc test_move(_from: Transform2D, motion: Vector2) -> bool:\n\treturn global_position.x + motion.x >= wall_x\n")
	var map_script: GDScript = _fixture("@tool\nextends Node\nvar edge_x: float = INF\nfunc is_world_position_in_playable_region(point: Vector2) -> bool:\n\treturn point.x < edge_x\n")
	if helper == null or actor_script == null or map_script == null:
		return
	var caster: Node2D = actor_script.new()
	var map: Node = map_script.new()
	_check(helper.call("resolve_destination", caster, map, Vector2(500, 0)) == Vector2(160, 0), "远鼠标最多瞬移160")
	caster.set("wall_x", 83.0)
	_check(helper.call("resolve_destination", caster, map, Vector2(160, 0)) == Vector2(80, 0), "角色形状撞墙则落在墙前")
	caster.set("wall_x", INF)
	map.set("edge_x", 45.0)
	_check(helper.call("resolve_destination", caster, map, Vector2(160, 0)) == Vector2(44, 0), "地图边界外不可到达")
	helper.set("sight", false)
	_check(helper.call("resolve_destination", caster, map, Vector2(160, 0)) == Vector2.ZERO, "沿线被挡时不瞬移")
	caster.free()
	map.free()


func _check_channel_reward() -> void:
	var body: String = _functions(DIR + "channel_reward_listener.gd", ["_on_channel_completed", "_reset_state"])
	body = body.replace("AbilityContext", "RefCounted").replace("StatusData", "Resource")
	var header: String = "@tool\nextends RefCounted\nvar caster: Node\nvar controller: RefCounted\nvar config: Resource\nvar source_key: String = \"ritual\"\nvar eligible: bool = true\nfunc _eligible_cast(_context: RefCounted) -> bool:\n\treturn eligible\n"
	var script: GDScript = _fixture(header + body)
	var actor_script: GDScript = _fixture("@tool\nextends Node\nvar status_controller: Node\n")
	var status_script: GDScript = _fixture("@tool\nextends Node\nvar applied: int = 0\nvar removed: int = 0\nfunc add_status(_data: Resource, _source: Node, _key: String) -> void:\n\tapplied += 1\nfunc remove_status_source(_id: StringName, _key: String) -> void:\n\tremoved += 1\n")
	if script == null or actor_script == null or status_script == null:
		return
	var helper: RefCounted = script.new()
	var actor: Node = actor_script.new()
	var statuses: Node = status_script.new()
	actor.set("status_controller", statuses)
	helper.set("caster", actor)
	helper.set("controller", _controller())
	helper.set("config", load("res://passive_skill/032_elegant_ritual.tres").get("effects")[0])
	helper.set("eligible", false)
	helper.call("_on_channel_completed", _context())
	_check(statuses.get("applied") == 0, "不合格的完成事件不获得吟唱奖励")
	helper.set("eligible", true)
	helper.call("_on_channel_completed", _context())
	helper.call("_on_channel_completed", _context())
	var pending: Dictionary = helper.get("controller").get("next_cast_modifiers")
	_check(statuses.get("applied") == 2 and pending.size() == 1, "成功完成获得护甲且重复刷新优惠")
	_check(pending["ritual"]["energy_reduction"] == 5.0 and pending["ritual"]["damage_multiplier"] == 1.25, "优雅仪式优惠及增伤参数")
	helper.call("_reset_state")
	_check(statuses.get("removed") == 1 and pending.is_empty(), "移除或结束时清理护甲及保留施法")
	statuses.free()
	actor.free()


func _check_damage_multiplier() -> void:
	var body: String = _functions("res://scripts/stats/stats_controller.gd", ["process_outgoing_damage"]).replace("DamageData", "Resource")
	var header: String = "@tool\nextends RefCounted\nfunc _get_outgoing_damage_bonus(_data: Resource) -> float:\n\treturn 20.0\nfunc _get_total_outgoing_damage_percent_bonus(_data: Resource) -> float:\n\treturn 0.0\nfunc get_stat(_name: StringName, default_value: float = 0.0) -> float:\n\treturn default_value\nfunc _apply_outgoing_defense_bypass(_data: Resource) -> void:\n\tpass\n"
	var script: GDScript = _fixture(header + body)
	var data_script: GDScript = _fixture("@tool\nextends Resource\nvar base_damage: float = 30.0\nvar final_damage: float = 0.0\nvar skill_damage_multiplier: float = 1.2\nvar can_crit: bool = false\nvar is_crit: bool = false\nvar crit_multiplier: float = 1.5\nvar poise_damage_multiplier: float = 1.0\n")
	if script == null or data_script == null:
		return
	var helper: RefCounted = script.new()
	var data: Resource = data_script.new()
	helper.call("process_outgoing_damage", data)
	_check(is_equal_approx(data.get("final_damage"), 60.0), "20%强化包含30基础与20属性成长，而非只放大基础")


func _check_routes() -> void:
	for file: String in ["ability_spawn_manifest_fan", "ability_spawn_manifest_radial", "ability_spawn_manifest_random_around_target", "ability_sustained_projectile_fan", "ability_scatter_landing_areas", "ability_radial_gap_volley"]:
		var body: String = FileAccess.get_file_as_string("res://scripts/ability/component/%s.gd" % file)
		_check(body.contains("cast_record = context.cast_record"), "分裂弹共享真实施法去重记录：" + file)
	var channel: String = FileAccess.get_file_as_string("res://scripts/ability/component/ability_channel.gd")
	_check(channel.find("channel_completed.emit") > channel.find("if not completed"), "只在吟唱成功后发完成事件")
	var chain: String = FileAccess.get_file_as_string(DIR + "element_hit_chain_listener.gd")
	_check(chain.contains("data.allow_skill_procs = false"), "连锁伤害禁止递归技能联动")
	_check(chain.contains("visited.append(target.get_instance_id())"), "连锁不重复命中同一敌人")


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
