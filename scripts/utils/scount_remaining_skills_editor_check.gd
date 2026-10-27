## 仅编辑器资源检查与真实函数隔离测试，不启动主场景、不读写玩家存档。
extends "res://scripts/utils/scount_combat_skills_editor_check.gd"

const MOVEMENT: String = "res://scripts/skill/movement_basic_attack_listener.gd"
const CENSUS: String = "res://scripts/skill/passive_tagged_relic_bonus_effect.gd"
const BOUNCE: String = "res://scripts/ability/manifest/bouncing_projectile_manifest.gd"


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_remaining_resources()
	_check_movement_charge()
	_check_movement_input_filter()
	_check_unique_ammo()
	_check_ammo_caps_and_cache()
	_check_bounce_damage()
	_check_bounce_selector()
	_check_bounce_recovery()
	print("浪子剩余技能编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_remaining_resources() -> void:
	var level: Node = (load("res://scenes/ability/level_up_controller.tscn") as PackedScene).instantiate()
	var rewards: Array = level.get("reward_pool").get("rewards")
	for spec: Array in [["activate_skill", "124_bouncing_shot"], ["passive_skill", "037_guerrilla_shooter"], ["passive_skill", "038_roaming_hunter"], ["passive_skill", "039_hidden_magazine"], ["passive_skill", "040_arsenal_connoisseur"]]:
		var data: Resource = load("res://%s/%s.tres" % [spec[0], spec[1]]) as Resource
		_check(data != null, "加载：" + spec[1])
		if data == null:
			continue
		_check(data.get("id") == StringName(str(spec[1]).left(3)) and data.get("allowed_character_ids") == [&"scount"], "编号与浪子归属")
		_check(data.get("icon") != null, "现有图标可用")
		var count: int = 0
		for reward: Resource in rewards:
			if "skill_data" in reward and reward.get("skill_data") == data:
				count += 1
		_check(count == (0 if data.get("is_upgrade_skill") else 1), "仅初始技能进入奖励池")
		if spec[0] == "passive_skill" and not data.get("is_upgrade_skill"):
			_check(data.get("upgrade_options").size() == 1 and data.get("upgrade_options")[0].get("is_upgrade_skill"), "升级分支正确")
	level.free()
	var ability: Node = (load("res://scenes/ability/scount_bouncing_shot_ability.tscn") as PackedScene).instantiate()
	_check(ability.get("energy_cost") == 10.0 and ability.get("cooldown") == 6.0 and ability.has_node("Indicator"), "跳弹10能量、6秒冷却、按住瞄准")
	ability.free()
	var bullet: Node = (load("res://scenes/ability/manifest/scount_bouncing_bullet_manifest.tscn") as PackedScene).instantiate()
	_check(bullet.get("max_targets") == 4 and bullet.get("damage_retention") == 0.8 and bullet.get("bounce_radius") == 140.0, "四目标、每跳保留80%、半径140")
	_check(bullet.get("damage") == 16.0 and bullet.get("scaling_rule").get("ranged_formula") == "dexterity * 0.7", "16+敏捷0.7倍远程成长")
	bullet.free()
	var speed: Resource = load("res://status/hunting_stride.tres") as Resource
	_check(speed.get("duration") == 2.0 and speed.get("effects")[0].get("value_per_stack") == 0.2, "游猎本能移速20%持续2秒")


func _movement_helper(upgraded: bool = false) -> RefCounted:
	var body: String = _functions(MOVEMENT, ["_process", "_advance_movement", "_on_cast", "_reset_state"])
	body = body.replace("AbilityContext", "RefCounted").replace("StatusData", "Resource")
	var header: String = "@tool\nextends RefCounted\nvar caster: Node2D\nvar config: Resource\nvar move_time: float = 0.0\nvar shot_ready: bool = false\nvar active: bool = true\nvar applied: Array = []\nvar removed: Array = []\nfunc _ready_for_event() -> bool:\n\treturn active\nfunc _apply_status(status: Resource) -> void:\n\tif status != null:\n\t\tapplied.append(status.id)\nfunc _remove_status(status: Resource) -> void:\n\tif status != null:\n\t\tremoved.append(status.id)\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return null
	var helper: RefCounted = script.new()
	var path: String = "038_roaming_hunter" if upgraded else "037_guerrilla_shooter"
	helper.set("config", load("res://passive_skill/%s.tres" % path).get("effects")[0])
	return helper


func _check_movement_charge() -> void:
	var helper: RefCounted = _movement_helper(true)
	if helper == null:
		return
	var caster: Node2D = _actor()
	helper.set("caster", caster)
	helper.call("_advance_movement", 0.6, true)
	helper.call("_advance_movement", 0.1, false)
	_check(helper.get("move_time") == 0.0 and not helper.get("shot_ready"), "移动不足1秒中断则重新积累")
	helper.call("_advance_movement", 0.99, true)
	_check(not helper.get("shot_ready"), "不足1秒不提前就绪")
	helper.call("_advance_movement", 0.01, true)
	_check(helper.get("shot_ready") and helper.get("applied") == [&"roaming_hunter_ready"], "连续1秒获得就绪状态")
	var context: RefCounted = _ctx()
	context.set("caster", caster)
	helper.call("_on_cast", context)
	_check(helper.get("shot_ready"), "其他主动技能不消耗强化")
	context.get("cast_record").set("is_basic_attack", true)
	context.get("cast_record").set("damage_multiplier", 1.4)
	helper.call("_on_cast", context)
	_check(is_equal_approx(context.get("cast_record").get("damage_multiplier"), 2.1), "整次普攻50%增伤可与战术装填相乘")
	_check(not helper.get("shot_ready") and helper.get("move_time") == 0.0, "使用后清空就绪并重新积累")
	_check(helper.get("applied").has(&"hunting_stride"), "升级在强化攻击后给予移速状态")
	context.set("cast_record", _record())
	context.get("cast_record").set("is_basic_attack", true)
	helper.call("_on_cast", context)
	_check(context.get("cast_record").get("damage_multiplier") == 1.0, "下一次普通攻击不会继续享受旧强化")
	helper.call("_reset_state")
	_check(helper.get("removed").has(&"hunting_stride"), "战斗结束或卸下时清理移速来源")
	caster.free()


func _check_movement_input_filter() -> void:
	var helper: RefCounted = _movement_helper()
	var script: GDScript = _fixture("@tool\nextends Node2D\nvar is_moving: bool = true\nvar has_movement_input: bool = false\n")
	if helper == null or script == null:
		return
	var actor: Node2D = script.new()
	helper.set("caster", actor)
	helper.call("_process", 2.0)
	_check(not helper.get("shot_ready"), "冰面自然滑行或纯击退不积累")
	actor.set("has_movement_input", true)
	actor.set("is_moving", false)
	helper.call("_process", 2.0)
	_check(not helper.get("shot_ready"), "按键顶墙但没实际移动不积累")
	actor.set("is_moving", true)
	helper.call("_process", 1.0)
	_check(helper.get("shot_ready"), "自主输入与实际移动共同满足才就绪")
	actor.set("is_moving", false)
	helper.call("_process", 5.0)
	_check(helper.get("shot_ready") and helper.get("applied").size() == 1, "就绪后停下仍保留，且不重复叠层")
	helper.call("_reset_state")
	helper.set("active", false)
	actor.set("is_moving", true)
	helper.call("_process", 2.0)
	_check(not helper.get("shot_ready"), "非战斗阶段不积累")
	actor.free()


func _census_helper() -> RefCounted:
	var body: String = _functions(CENSUS, ["_unique_count", "_record_relic", "_refresh_context", "_key", "_before_cast"])
	body = body.replace("SkillContext", "RefCounted").replace("AbilityContext", "RefCounted").replace("PlayerBuild", "Resource")
	body = body.replace("RelicTag", "Resource").replace("Relic", "Resource").replace("Slot", "Resource")
	body = body.replace("Array[Modifier]", "Array[Dictionary]").replace("Modifier.create_flat", "_flat")
	var header: String = "@tool\nextends RefCounted\nvar tag_name: StringName = &\"弹药\"\nvar contexts: Dictionary = {}\nvar cached_counts: Dictionary = {}\nvar damage_per_kind: float = 0.05\nvar max_damage_bonus: float = 0.25\nvar crit_per_kind: float = 0.0\nvar max_crit_bonus: float = 0.0\nvar required_damage_tags: Array[String] = [\"projectile\"]\nfunc _flat(stat: StringName, amount: float, key: Variant) -> Dictionary:\n\treturn {\"stat\": stat, \"amount\": amount, \"key\": key}\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _tagged_relic(id: String, tag_name: String = "弹药") -> Resource:
	var tag_script: GDScript = _fixture("@tool\nextends Resource\nvar tag_name: String\n")
	var relic_script: GDScript = _fixture("@tool\nextends Resource\nvar id: String\nvar tags: Array[Resource] = []\nvar is_level_up: bool = false\nvar is_temporary: bool = false\n")
	var tag: Resource = tag_script.new()
	tag.set("tag_name", tag_name)
	var relic: Resource = relic_script.new()
	relic.set("id", id)
	relic.set("tags", [tag] as Array[Resource])
	return relic


func _build_fixture(inventory_items: Array, equipped_items: Array) -> Resource:
	var slot_script: GDScript = _fixture("@tool\nextends Resource\nvar item: Resource\n")
	var inventory_script: GDScript = _fixture("@tool\nextends Resource\nvar slots: Array[Resource] = []\nvar equip_slots: Array[Resource] = []\n")
	var build_script: GDScript = _fixture("@tool\nextends Resource\nvar player_inventory: Resource\nvar player_equipment: Resource\n")
	var build: Resource = build_script.new()
	var inventory: Resource = inventory_script.new()
	var equipment: Resource = inventory_script.new()
	for item: Resource in inventory_items:
		var slot: Resource = slot_script.new()
		slot.set("item", item)
		inventory.get("slots").append(slot)
	for item: Resource in equipped_items:
		var slot: Resource = slot_script.new()
		slot.set("item", item)
		equipment.get("equip_slots").append(slot)
	build.set("player_inventory", inventory)
	build.set("player_equipment", equipment)
	return build


func _check_unique_ammo() -> void:
	var helper: RefCounted = _census_helper()
	if helper == null:
		return
	var normal: Resource = _tagged_relic("ammo_a")
	var upgraded: Resource = _tagged_relic("ammo_a")
	upgraded.set("is_level_up", true)
	var temporary: Resource = _tagged_relic("ammo_b")
	temporary.set("is_temporary", true)
	var other: Resource = _tagged_relic("tool", "用具")
	var build: Resource = _build_fixture([normal, upgraded, temporary, other, null], [normal, _tagged_relic("ammo_c")])
	_check(helper.call("_unique_count", build) == 3, "装备栏与背包并计，重复和升级态去重，临时装备有效")
	build.get("player_inventory").get("slots")[2].set("item", null)
	_check(helper.call("_unique_count", build) == 2, "临时弹药消失后减少种类")
	_check(helper.call("_unique_count", null) == 0, "无构筑时安全返回零")


func _check_ammo_caps_and_cache() -> void:
	var helper: RefCounted = _census_helper()
	if helper == null:
		return
	var stats_script: GDScript = _fixture("@tool\nextends Node\nvar damage: Dictionary\nvar modifiers: Array = []\nvar updates: int = 0\nfunc set_outgoing_damage_bonus_modifier(_key: Variant, data: Dictionary) -> void:\n\tdamage = data\nfunc set_effect_modifiers(_key: Variant, value: Array) -> void:\n\tmodifiers = value\n\tupdates += 1\n")
	var ctx_script: GDScript = _fixture("@tool\nextends RefCounted\nvar player_build: Resource\nvar stats_controller: Node\nvar effect_key: String = \"ammo_bonus\"\n")
	var stats: Node = stats_script.new()
	var context: RefCounted = ctx_script.new()
	var items: Array[Resource] = []
	for i: int in range(12):
		items.append(_tagged_relic("ammo_%d" % i))
	context.set("player_build", _build_fixture(items, []))
	context.set("stats_controller", stats)
	helper.call("_refresh_context", context)
	_check(stats.get("damage")["total_damage_percent_bonus"] == 0.25 and stats.get("modifiers").is_empty(), "初始版伤害上限25%，没有暴击率")
	for i: int in range(5):
		helper.call("_refresh_context", context)
	_check(stats.get("updates") == 1, "计数不变时缓存避免反复重算属性")
	helper.set("max_damage_bonus", 0.4)
	helper.set("crit_per_kind", 0.01)
	helper.set("max_crit_bonus", 0.08)
	helper.get("cached_counts").clear()
	helper.call("_refresh_context", context)
	_check(stats.get("damage")["total_damage_percent_bonus"] == 0.4 and stats.get("modifiers")[0]["amount"] == 0.08, "升级版伤害上限40%，暴击率上限8%")
	var key: String = helper.call("_key", context)
	helper.get("contexts")[key] = context
	context.set("player_build", _build_fixture([items[0]], []))
	helper.call("_before_cast", _ctx(), key)
	_check(stats.get("damage")["total_damage_percent_bonus"] == 0.05 and stats.get("modifiers")[0]["amount"] == 0.01, "正式施法前重算刚消耗的弹药，伤害和暴击率均下降")
	context.set("player_build", _build_fixture([], []))
	helper.call("_refresh_context", context)
	_check(stats.get("damage")["total_damage_percent_bonus"] == 0.0 and stats.get("modifiers").is_empty(), "全部移除后不残留加成")
	_check(stats.get("damage")["required_tags"] == ["projectile"], "只增强投射物，不增强抛射或近战")
	stats.free()


func _bounce_actor() -> Node2D:
	var script: GDScript = _fixture("@tool\nextends Node2D\nvar is_dead: bool = false\nvar neutral: bool = false\nvar damages: Array[float] = []\nfunc can_be_targeted() -> bool:\n\treturn not is_dead\nfunc is_neutral_bounty_elite() -> bool:\n\treturn neutral\nfunc apply_damage(data: RefCounted) -> void:\n\tdamages.append(data.skill_damage_multiplier)\n")
	return script.new()


func _bounce_helper() -> Node2D:
	var names: Array = ["_resolve_contact", "_create_hit_damage", "_valid_contact", "_select_next_target", "_aim_at"]
	var body: String = _functions(BOUNCE, names).replace("Entity", "Node2D").replace("DamageData", "RefCounted")
	body = body.replace("super._create_hit_damage", "_base_damage").replace("EventBus.is_battle_active", "battle_active")
	body = body.replace("not is_inside_tree()", "not active_tree").replace("AudioController.play", "_sound")
	var header: String = "@tool\nextends Node2D\nvar source: Node2D\nvar hits_used: int = 0\nvar contact_pending: bool = true\nvar max_targets: int = 4\nvar bounce_radius: float = 140.0\nvar arrival_radius: float = 5.0\nvar damage_retention: float = 0.8\nvar hit_target_ids: Dictionary = {}\nvar bounce_target: WeakRef\nvar current_dir: Vector2 = Vector2.RIGHT\nvar current_distance: float = 0.0\nvar max_distance: float = 600.0\nvar battle_active: bool = true\nvar active_tree: bool = true\nvar hit_sound: Variant\nvar pool: Array[Node2D] = []\nvar data_script: GDScript\nfunc _get_valid_source() -> Node2D:\n\treturn source\nfunc _matches_target_group(_target: Node) -> bool:\n\treturn true\nfunc _base_damage(_target: Node2D, _source: Node2D) -> RefCounted:\n\treturn data_script.new()\nfunc _notify_resolution(_reason: StringName) -> void:\n\tpass\nfunc _sound(_clip: Variant, _point: Vector2) -> void:\n\tpass\nfunc _find_bounce_target() -> Node2D:\n\tfor target: Node2D in pool:\n\t\tif _valid_contact(target):\n\t\t\treturn target\n\treturn null\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return null
	var helper: Node2D = script.new()
	helper.set("data_script", _fixture("@tool\nextends RefCounted\nvar skill_damage_multiplier: float = 1.0\n"))
	return helper


func _check_bounce_damage() -> void:
	var helper: Node2D = _bounce_helper()
	if helper == null:
		return
	var source: Node2D = _bounce_actor()
	helper.set("source", source)
	var targets: Array[Node2D] = []
	for i: int in range(5):
		var target: Node2D = _bounce_actor()
		target.position = Vector2(20 + i * 15, 0)
		targets.append(target)
	helper.set("pool", targets)
	for i: int in range(5):
		helper.call("_resolve_contact", weakref(targets[i]))
		if i < 4:
			_check(targets[i].get("damages").size() == 1 and is_equal_approx(targets[i].get("damages")[0], pow(0.8, i)), "第%d次命中完整伤害倍率衰减" % (i + 1))
	_check(helper.get("hits_used") == 4 and targets[4].get("damages").is_empty(), "最多四个不同敌人，第五个不受伤")
	_check(helper.is_queued_for_deletion(), "第四次命中后释放")
	_check(helper.get("max_distance") == 145.0, "弹跳使用独立路程，不受首段已飞距离截断")
	helper.free()
	for target: Node2D in targets:
		target.free()
	source.free()


func _check_bounce_selector() -> void:
	var body: String = _functions(BOUNCE, ["_find_bounce_target"]).replace("Entity", "Node2D")
	body = body.replace("SkillCombatQuery.enemies_within", "_visible_targets")
	var header: String = "@tool\nextends Node2D\nvar source: Node2D\nvar hit_target_ids: Dictionary = {}\nvar bounce_radius: float = 140.0\nvar pool: Array[Node2D] = []\nvar excluded_seen: Array[int] = []\nfunc _get_valid_source() -> Node2D:\n\treturn source\nfunc _visible_targets(_source: Node2D, _point: Vector2, _radius: float, excluded: Array[int]) -> Array[Node2D]:\n\texcluded_seen = excluded\n\treturn pool\nfunc _valid_contact(target: Node2D) -> bool:\n\treturn not hit_target_ids.has(target.get_instance_id()) and target.can_be_targeted()\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return
	var helper: Node2D = script.new()
	var first: Node2D = _bounce_actor()
	var neutral: Node2D = _bounce_actor()
	neutral.set("neutral", true)
	var next: Node2D = _bounce_actor()
	helper.get("hit_target_ids")[first.get_instance_id()] = true
	helper.set("pool", [first, neutral, next] as Array[Node2D])
	_check(helper.call("_find_bounce_target") == next, "跳过旧目标和未激活的中立悬赏怪")
	_check(helper.get("excluded_seen").has(first.get_instance_id()), "查询时传递已命中排除列表")
	helper.set("pool", [] as Array[Node2D])
	_check(helper.call("_find_bounce_target") == null, "无可见候选时不强行弹射")
	var actual_query: String = FileAccess.get_file_as_string("res://scripts/skill/skill_combat_query.gd")
	_check(actual_query.contains("if has_sight(source, origin, target.global_position)"), "真实候选查询检查墙体视线")
	helper.free()
	first.free()
	neutral.free()
	next.free()


func _check_bounce_recovery() -> void:
	var helper: Node2D = _bounce_helper()
	if helper == null:
		return
	var source: Node2D = _bounce_actor()
	var target: Node2D = _bounce_actor()
	helper.set("source", source)
	helper.set("pool", [target] as Array[Node2D])
	helper.get("hit_target_ids")[target.get_instance_id()] = true
	_check(not helper.call("_valid_contact", target), "重复命中被去重")
	helper.get("hit_target_ids").clear()
	target.add_to_group("map_object")
	_check(not helper.call("_valid_contact", target), "跳弹不攻击地图物件")
	target.remove_from_group("map_object")
	var vanished: Node2D = _bounce_actor()
	var vanished_ref: WeakRef = weakref(vanished)
	vanished.free()
	helper.call("_resolve_contact", vanished_ref)
	_check(helper.get("hits_used") == 0 and helper.get("bounce_target").get_ref() == target, "排队结算前目标释放时安全重选，不转型已释放对象")
	helper.set("battle_active", false)
	helper.call("_resolve_contact", weakref(target))
	_check(helper.is_queued_for_deletion() and target.get("damages").is_empty(), "战斗结束后不补发伤害")
	helper.free()
	source.free()
	target.free()
