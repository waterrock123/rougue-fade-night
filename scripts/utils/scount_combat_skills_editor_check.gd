## 复用编辑器检查工具；只加载资源并隔离执行真实函数，不启动游戏或读写玩家存档。
extends "res://scripts/utils/guiren_element_synergy_editor_check.gd"

const SC_ACTIVE: Array[String] = ["121_piercing_shot", "122_sidestep_shot", "123_bounty_mark"]
const SC_PASSIVE: Array[String] = ["033_spent_rounds", "034_tactical_reload", "035_seize_opportunity", "036_pursuit_of_victory"]


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_scount_resources()
	_check_payments()
	_check_profiles()
	_check_limited_hits()
	_check_material_attacks()
	_check_bonus_volley()
	_check_critical_cooldowns()
	_check_slide()
	_check_mark()
	_check_target_bonus()
	_check_context_handoff()
	print("浪子新技能编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_scount_resources() -> void:
	var level: Node = (load("res://scenes/ability/level_up_controller.tscn") as PackedScene).instantiate()
	var rewards: Array = level.get("reward_pool").get("rewards")
	for folder: String in ["activate_skill", "passive_skill"]:
		var entries: Array[String] = SC_ACTIVE if folder == "activate_skill" else SC_PASSIVE
		for entry: String in entries:
			var data: Resource = load("res://%s/%s.tres" % [folder, entry]) as Resource
			_check(data != null, "资源加载：" + entry)
			if data == null:
				continue
			_check(data.get("id") == StringName(entry.left(3)) and data.get("allowed_character_ids") == [&"scount"], "编号与浪子归属：" + entry)
			var count: int = 0
			for reward: Resource in rewards:
				if "skill_data" in reward and reward.get("skill_data") == data:
					count += 1
			_check(count == (0 if data.get("is_upgrade_skill") else 1), "仅初始版本进入奖励池：" + entry)
			_check(data.get("icon") != null, "现有图标：" + entry)
			if folder == "activate_skill":
				var ability: Node = (data.get("ability_scene") as PackedScene).instantiate()
				_check(ability.get("cooldown") == data.get("base_cooldown") and ability.get("energy_cost") == data.get("base_energy_cost"), "场景冷却与能量一致")
				ability.free()
			elif not data.get("is_upgrade_skill"):
				_check(data.get("upgrade_options").size() == 1 and data.get("upgrade_options")[0].get("is_upgrade_skill"), "升级分支：" + entry)
	level.free()
	_check_projectile_resources()


func _check_projectile_resources() -> void:
	var bullet: Node = (load("res://scenes/ability/manifest/scount_piercing_shot_bullet_manifest.tscn") as PackedScene).instantiate()
	_check(bullet.get("damage") == 35.0 and bullet.get("max_hits") == 5 and bullet.get("ignore_target_armor"), "贯甲弹基础35、最多五次穿透、忽略固定减伤")
	_check(bullet.get("scaling_rule").get("ranged_formula") == "dexterity * 1.5", "贯甲弹敏捷1.5倍成长")
	bullet.free()
	var slide: Node = (load("res://scenes/ability/scount_sidestep_shot_ability.tscn") as PackedScene).instantiate()
	_check(slide.get_node("Slide").get("distance") == 90.0 and slide.get_node("Invulnerability").get("duration") == 0.15, "滑步距离与无敌帧")
	_check(slide.get_node("Slide/ThreeShots").get("shot_count") == 3 and slide.get_node("Slide/ThreeShots").get("shot_interval") == 0.07, "滑步后快速三连射")
	slide.free()
	var mark: Node = (load("res://scenes/ability/scount_bounty_mark_ability.tscn") as PackedScene).instantiate()
	_check(mark.get_node("Mark").get("battle_gold_limit") == 1 and mark.get_node("Mark").get("mark_duration") == 6.0, "赏金每场1金币，标记6秒")
	mark.free()


func _ctx() -> RefCounted:
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar caster: Node2D\nvar ability: Node\nvar cast_record: RefCounted\nvar locked_direction: Vector2 = Vector2.RIGHT\nvar charge_ratio: float = 0.0\nvar projectile_damage_multiplier: float = 1.0\nvar projectile_count_override: int = 0\nvar valid: bool = true\nfunc is_caster_action_valid() -> bool:\n\treturn valid and is_instance_valid(caster)\n")
	var context: RefCounted = script.new()
	context.set("cast_record", _record())
	return context


func _actor() -> Node2D:
	var script: GDScript = _fixture("@tool\nextends Node2D\nvar stats_controller: Node\nvar status_controller: Node\nvar is_dead: bool = false\nvar blocked: bool = false\nvar locks: Dictionary = {\"other\": true}\nfunc can_act() -> bool:\n\treturn not is_dead\nfunc can_be_targeted() -> bool:\n\treturn not is_dead\nfunc add_movement_lock(key: String) -> void:\n\tlocks[key] = true\nfunc remove_movement_lock(key: String) -> void:\n\tlocks.erase(key)\nfunc clear_terrain_motion_velocity() -> void:\n\tpass\nfunc move_direct_with_physics(motion: Vector2, _slide: bool) -> Vector2:\n\tif blocked:\n\t\treturn Vector2.ZERO\n\tposition += motion\n\treturn motion\n")
	return script.new()


func _payment_helper() -> RefCounted:
	var names: Array = ["can_pay_ability_cost", "pay_ability_cost", "_record_payment"]
	var body: String = _functions("res://scripts/ability/component/ability_consume_tagged_inventory_relic.gd", names)
	body = body.replace("AbilityContext", "RefCounted").replace("AmmoBox", "Node").replace("RelicController", "Node").replace("RelicConsumption.consume_slot", "_consume")
	body = body.replace("Slot", "Resource").replace("Relic", "Resource").replace("EventBus.call_deferred", "_update_later")
	var header: String = "@tool\nextends RefCounted\nvar allow_missing_material: bool = false\nvar required_tag_name: StringName = &\"弹药\"\nvar required_tag: Resource\nvar box: Node\nvar slot: Resource\nvar updates: int = 0\nvar consumed: int = 0\nfunc _find_available_ammo_box(_context: RefCounted) -> Node:\n\treturn box if box != null and box.charges > 0 else null\nfunc _find_target_slot(_context: RefCounted) -> Resource:\n\treturn slot\nfunc _resolve_relic_controller(_caster: Node2D) -> Node:\n\treturn null\nfunc _build_consume_key(_context: RefCounted, _relic: Resource) -> String:\n\treturn \"test\"\nfunc _consume(value: Resource, _caster: Node2D, _controller: Node, _key: String, _updates: bool) -> Resource:\n\tvar item: Resource = value.item\n\tvalue.item = null\n\tconsumed += 1\n\treturn item\nfunc _update_later(_method: String, _event: StringName) -> void:\n\tupdates += 1\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _check_payments() -> void:
	var helper: RefCounted = _payment_helper()
	if helper == null:
		return
	var context: RefCounted = _ctx()
	var caster: Node2D = _actor()
	context.set("caster", caster)
	_check(not helper.call("can_pay_ability_cost", context) and not helper.call("pay_ability_cost", context), "原眼镜蛇必需弹药成本保持不变")
	helper.set("allow_missing_material", true)
	_check(helper.call("can_pay_ability_cost", context) and helper.call("pay_ability_cost", context), "可选弹药缺失仍允许施法")
	_check(context.get("cast_record").get("material_payments").is_empty(), "空放不伪造材料支付")
	var slot_script: GDScript = _fixture("@tool\nextends Resource\nvar item: Resource\n")
	var slot: Resource = slot_script.new()
	slot.set("item", Resource.new())
	helper.set("slot", slot)
	for i: int in range(3):
		helper.call("can_pay_ability_cost", context)
	_check(slot.get("item") != null and helper.get("consumed") == 0, "预检查不提前消耗材料")
	_check(helper.call("pay_ability_cost", context) and slot.get("item") == null, "正式支付只消耗一件")
	_check(context.get("cast_record").get("material_payments").get(&"弹药") == 1 and helper.get("updates") == 3, "支付记录保留且三类刷新延后")
	_check_box_payment(helper, slot, context)
	caster.free()


func _check_box_payment(helper: RefCounted, slot: Resource, context: RefCounted) -> void:
	var box_script: GDScript = _fixture("@tool\nextends Node\nvar charges: int = 1\nfunc consume_ammo(_caster: Node2D, _tag: Resource, _name: StringName) -> bool:\n\tif charges <= 0:\n\t\treturn false\n\tcharges -= 1\n\treturn true\n")
	var box: Node = box_script.new()
	helper.set("box", box)
	slot.set("item", Resource.new())
	context.set("cast_record", _record())
	helper.call("pay_ability_cost", context)
	_check(box.get("charges") == 0 and slot.get("item") != null, "优先弹药箱、不消耗背包弹药")
	_check(context.get("cast_record").get("material_payments").get(&"弹药") == 1, "弹药箱计为实际支付")
	box.free()


func _check_profiles() -> void:
	var body: String = _functions("res://scripts/ability/component/ability_payment_projectile_profile.gd", ["_activate"]).replace("AbilityContext", "RefCounted")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar payment_tag: StringName = &\"弹药\"\nvar unpaid_damage_multiplier: float = 0.5\nvar paid_hit_limit: int = 5\nvar unpaid_hit_limit: int = 1\n" + body)
	if script == null:
		return
	var helper: RefCounted = script.new()
	var context: RefCounted = _ctx()
	helper.call("_activate", context)
	var record: RefCounted = context.get("cast_record")
	_check(record.get("damage_multiplier") == 0.5 and not record.get("projectile_options")["penetrate"] and record.get("projectile_options")["max_hits"] == 1, "无弹药完整伤害减半且不穿透")
	context.set("cast_record", _record())
	context.get("cast_record").get("material_payments")[&"弹药"] = 1
	helper.call("_activate", context)
	record = context.get("cast_record")
	_check(record.get("damage_multiplier") == 1.0 and record.get("projectile_options")["penetrate"] and record.get("projectile_options")["max_hits"] == 5, "支付后恢复全额伤害、五次穿透")
	_check_damage_multiplier()


func _check_limited_hits() -> void:
	var body: String = _functions("res://scripts/ability/manifest/limited_hit_projectile_manifest.gd", ["_on_area_2d_area_entered"])
	body = body.replace("super._on_area_2d_area_entered(area)", "_base_hit(area)")
	var header: String = "@tool\nextends Node\nvar max_hits: int = 5\nvar hits_used: int = 0\nvar hit_target_ids: Dictionary = {}\nfunc _base_hit(area: Area2D) -> void:\n\thit_target_ids[area.get_parent().get_instance_id()] = true\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return
	var helper: Node = script.new()
	var targets: Array[Node] = []
	for i: int in range(6):
		var target: Node = Node.new()
		var area: Area2D = Area2D.new()
		target.add_child(area)
		targets.append(target)
		helper.call("_on_area_2d_area_entered", area)
		helper.call("_on_area_2d_area_entered", area)
	_check(helper.get("hits_used") == 5 and helper.is_queued_for_deletion(), "最多五个不同目标，重复区域和第六目标不增加次数")
	helper.free()
	for target: Node in targets:
		target.free()


func _material_listener() -> RefCounted:
	var body: String = _functions(DIR + "material_basic_attack_listener.gd", ["_on_cast", "_reset_state"])
	body = body.replace("AbilityContext", "RefCounted")
	var header: String = "@tool\nextends RefCounted\nvar config: Resource\nvar caster: Node2D\nvar remaining_attacks: int = 0\nvar first_attack: bool = false\nvar status_updates: int = 0\nfunc _ready_for_event() -> bool:\n\treturn true\nfunc _sync_status() -> void:\n\tstatus_updates += 1\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _check_material_attacks() -> void:
	var helper: RefCounted = _material_listener()
	if helper == null:
		return
	var caster: Node2D = _actor()
	helper.set("caster", caster)
	helper.set("config", load("res://passive_skill/033_spent_rounds.tres").get("effects")[0])
	var context: RefCounted = _ctx()
	context.set("caster", caster)
	helper.call("_on_cast", context)
	_check(helper.get("remaining_attacks") == 0, "未消耗弹药不授予强化")
	context.get("cast_record").get("material_payments")[&"弹药"] = 1
	helper.call("_on_cast", context)
	helper.call("_on_cast", context)
	_check(helper.get("remaining_attacks") == 3, "重复获得刷新三次，不变为六次")
	for i: int in range(4):
		context.set("cast_record", _record())
		context.get("cast_record").set("is_basic_attack", true)
		helper.call("_on_cast", context)
		_check(is_equal_approx(context.get("cast_record").get("damage_multiplier"), 1.25 if i < 3 else 1.0), "只强化接下来三次整次普攻")
	helper.set("config", load("res://passive_skill/034_tactical_reload.tres").get("effects")[0])
	context.set("cast_record", _record())
	context.get("cast_record").get("material_payments")[&"弹药"] = 1
	helper.call("_on_cast", context)
	for i: int in range(2):
		context.set("cast_record", _record())
		context.get("cast_record").set("is_basic_attack", true)
		helper.call("_on_cast", context)
		_check(context.get("cast_record").get("projectile_count_bonus") == (1 if i == 0 else 0), "升级首发额外一颗，之后不加")
		_check(is_equal_approx(context.get("cast_record").get("damage_multiplier"), 1.4), "升级强化40%")
	helper.call("_reset_state")
	_check(helper.get("remaining_attacks") == 0, "战斗结束清理强化")
	caster.free()


func _cooldown_controller() -> Node:
	var body: String = _functions("res://scripts/ability/core/ability_controller.gd", ["reduce_remaining_cooldown_seconds"]).replace("Ability", "Node")
	var header: String = "@tool\nextends Node\nvar abilities: Array[Node] = []\nvar cooldowns: Dictionary = {}\nfunc is_basic_ability(ability: Node) -> bool:\n\treturn ability.basic\n"
	var script: GDScript = _fixture(header + body)
	return script.new()


func _check_bonus_volley() -> void:
	var body: String = _functions("res://scripts/ability/component/ability_spawn_manifest_volley.gd", ["_activate"])
	body = body.replace("AbilityContext", "RefCounted").replace("super._activate(context)", "shots += 1")
	var header: String = "@tool\nextends RefCounted\nvar base_projectile_count: int = 1\nvar bonus_projectile_count: int = 1\nvar attacks_before_bonus: int = 2\nvar attacks_since_bonus: int = 2\nvar side_offset: float = 0.0\nvar side_spacing: float = 5.0\nvar spread_angle_degrees: float = 2.5\nvar shots: int = 0\n"
	var script: GDScript = _fixture(header + body)
	if script == null:
		return
	var helper: RefCounted = script.new()
	var context: RefCounted = _ctx()
	var actor: Node2D = _actor()
	context.set("caster", actor)
	context.get("cast_record").set("projectile_count_bonus", 1)
	helper.call("_activate", context)
	_check(helper.get("shots") == 3, "战术装填额外一弹与基础攻击周期额外一弹相加")
	helper.set("shots", 0)
	context.get("cast_record").set("projectile_count_bonus", 0)
	helper.call("_activate", context)
	_check(helper.get("shots") == 1, "后续普通攻击不会残留额外子弹")
	actor.free()


func _critical_listener() -> RefCounted:
	var body: String = _functions(DIR + "critical_cooldown_listener.gd", ["_on_hit", "_longest_cooldown", "_process"])
	body = body.replace("DamageData", "RefCounted").replace("Ability", "Node")
	var header: String = "@tool\nextends RefCounted\nvar caster: Node2D\nvar controller: Node\nvar config: Resource\nvar interval_remaining: float = 0.0\nfunc _ready_for_event() -> bool:\n\treturn true\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _check_critical_cooldowns() -> void:
	var helper: RefCounted = _critical_listener()
	var controller: Node = _cooldown_controller()
	var ability_script: GDScript = _fixture("@tool\nextends Node\nvar basic: bool = false\nvar current_cooldown: float = 0.0\n")
	var data_script: GDScript = _fixture("@tool\nextends RefCounted\nvar source: Node2D\nvar target: Node2D\nvar is_crit: bool = true\nvar allow_skill_procs: bool = true\nvar final_damage: float = 10.0\n")
	if helper == null:
		controller.free()
		return
	var caster: Node2D = _actor()
	var enemy: Node2D = _actor()
	enemy.add_to_group("enemy")
	var skills: Array[Node] = [ability_script.new(), ability_script.new(), ability_script.new()]
	skills[0].set("basic", true)
	controller.set("abilities", skills)
	controller.set("cooldowns", {skills[0]: 20.0, skills[1]: 3.0, skills[2]: 5.0})
	helper.set("caster", caster)
	helper.set("controller", controller)
	helper.set("config", load("res://passive_skill/035_seize_opportunity.tres").get("effects")[0])
	var data: RefCounted = data_script.new()
	data.set("source", caster)
	data.set("target", enemy)
	helper.call("_on_hit", data)
	_check(controller.get("cooldowns")[skills[2]] == 4.0 and controller.get("cooldowns")[skills[0]] == 20.0, "削减最长非基础冷却整整1秒")
	helper.call("_on_hit", data)
	_check(controller.get("cooldowns")[skills[2]] == 4.0, "同次多弹暴击受0.6秒间隔限制")
	helper.call("_process", 0.6)
	helper.set("config", load("res://passive_skill/036_pursuit_of_victory.tres").get("effects")[0])
	helper.call("_on_hit", data)
	_check(controller.get("cooldowns")[skills[2]] == 2.5, "升级削减1.5秒")
	data.set("allow_skill_procs", false)
	helper.call("_process", 0.6)
	helper.call("_on_hit", data)
	_check(controller.get("cooldowns")[skills[1]] == 3.0, "次级联动暴击不递归减冷却")
	for ability: Node in skills:
		ability.free()
	controller.free()
	caster.free()
	enemy.free()


func _slide_helper() -> Node:
	var body: String = _functions("res://scripts/ability/component/ability_move_then_trigger.gd", ["_activate", "_physics_process", "_finish", "_exit_tree"])
	body = body.replace("AbilityContext", "RefCounted").replace(": Entity", ": Node2D")
	body = body.replace(": AbilityController", ": Node").replace(" as AbilityController", " as Node")
	body = body.replace("EventBus.is_battle_active", "battle_active").replace("child is AbilityComponent", "child.has_method(\"activate\")")
	var header: String = "@tool\nextends Node\nvar distance: float = 90.0\nvar duration: float = 0.2\nvar block_other_abilities: bool = true\nvar active_context: RefCounted\nvar elapsed: float = 0.0\nvar lock_key: String\nvar controller: Node\nvar battle_active: bool = true\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _check_slide() -> void:
	var helper: Node = _slide_helper()
	if helper == null:
		return
	var caster: Node2D = _actor()
	var context: RefCounted = _ctx()
	context.set("caster", caster)
	var child_script: GDScript = _fixture("@tool\nextends Node\nvar auto_activate: bool = true\nvar count: int = 0\nfunc activate(_context: RefCounted) -> void:\n\tcount += 1\n")
	var effect: Node = child_script.new()
	helper.add_child(effect)
	helper.call("_activate", context)
	helper.call("_physics_process", 0.1)
	_check(caster.position == Vector2(45, 0) and effect.get("count") == 0, "滑步中不提前开枪")
	helper.call("_physics_process", 0.1)
	_check(caster.position == Vector2(90, 0) and effect.get("count") == 1, "完成90距离后只触发一次子链")
	_check(caster.get("locks") == {"other": true}, "只解除自己的移动锁")
	helper.call("_activate", context)
	context.set("valid", false)
	helper.call("_physics_process", 0.2)
	_check(effect.get("count") == 1 and caster.get("locks").size() == 1, "控制或死亡取消位移与射击")
	context.set("valid", true)
	caster.set("blocked", true)
	helper.call("_activate", context)
	helper.call("_physics_process", 0.1)
	_check(effect.get("count") == 2 and caster.position == Vector2(90, 0), "撞墙停下并正常射击，不穿墙")
	helper.call("_activate", context)
	helper.set("battle_active", false)
	helper.call("_physics_process", 0.2)
	_check(effect.get("count") == 2, "战斗结束不补发后续射击")
	helper.free()
	caster.free()


func _mark_helper() -> Node:
	var names: Array = ["mark", "_target", "_clear_mark", "_on_enemy_killed", "_reset_battle"]
	var body: String = _functions("res://scripts/ability/core/bounty_mark_controller.gd", names)
	body = body.replace("Entity", "Node2D").replace("StatusData", "Resource").replace("RunStats", "Resource")
	body = body.replace("BountyMarkVisual.new()", "Node2D.new()").replace("FloatText.show_screen_tip", "_tip")
	var header: String = "@tool\nextends Node\nvar caster: Node2D\nvar source_key: String = \"mark\"\nvar target_ref: WeakRef\nvar current_status: Resource\nvar remaining: float = 0.0\nvar reward_gold: int = 1\nvar reward_limit: int = 1\nvar gold_earned: int = 0\nvar rewarded_targets: Dictionary = {}\nvar mark_visual: Node2D\nvar stats: Resource\nfunc _resolve_run_stats() -> Resource:\n\treturn stats\nfunc _tip(_text: String) -> void:\n\tpass\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _check_mark() -> void:
	var helper: Node = _mark_helper()
	if helper == null:
		return
	var caster: Node2D = _actor()
	var first: Node2D = _actor()
	var second: Node2D = _actor()
	var stats_script: GDScript = _fixture("@tool\nextends Resource\nvar gold: int = 0\n")
	var modifiers_script: GDScript = _fixture("@tool\nextends Node\nvar modifiers: Dictionary = {}\nfunc set_outgoing_damage_bonus_modifier(key: String, data: Dictionary) -> void:\n\tmodifiers[key] = data\nfunc clear_outgoing_damage_bonus_modifier(key: String) -> void:\n\tmodifiers.erase(key)\n")
	var modifiers: Node = modifiers_script.new()
	caster.set("stats_controller", modifiers)
	helper.set("caster", caster)
	helper.set("stats", stats_script.new())
	helper.call("mark", first, null, 6.0, 0.15, 1, 1)
	_check(modifiers.get("modifiers")["mark"]["required_target_id"] == first.get_instance_id(), "增伤只登记指定目标")
	helper.call("mark", second, null, 6.0, 0.15, 1, 1)
	_check(helper.call("_target") == second and first.get_child_count() == 1, "重新标记替换旧目标并排队清理旧标记")
	helper.call("_on_enemy_killed", first, caster)
	_check(helper.get("stats").get("gold") == 0, "击杀旧目标不领奖")
	helper.call("_on_enemy_killed", second, caster)
	_check(helper.get("stats").get("gold") == 1 and helper.call("_target") == null, "击杀当前目标得1金币且移除标记")
	helper.call("mark", first, null, 6.0, 0.15, 1, 1)
	helper.call("_on_enemy_killed", first, caster)
	_check(helper.get("stats").get("gold") == 1, "重施技能仍受每场1金币限制")
	helper.call("_reset_battle")
	helper.call("mark", first, null, 6.0, 0.15, 1, 1)
	helper.set("remaining", 0.0)
	helper.call("_on_enemy_killed", first, caster)
	_check(helper.get("stats").get("gold") == 1, "超时击杀没有赏金")
	helper.call("mark", first, null, 6.0, 0.15, 1, 1)
	helper.call("_on_enemy_killed", first, second)
	_check(helper.get("stats").get("gold") == 1, "非标记者击杀不领奖")
	helper.call("mark", first, null, 6.0, 0.15, 1, 1)
	helper.call("_on_enemy_killed", first, caster)
	_check(helper.get("stats").get("gold") == 2, "下一场重置奖励额度")
	_check(modifiers.get("modifiers").is_empty(), "击杀和清理移除增伤")
	helper.free()
	caster.free()
	first.free()
	second.free()
	modifiers.free()


func _check_target_bonus() -> void:
	var body: String = _functions("res://scripts/stats/stats_controller.gd", ["_outgoing_damage_modifier_matches"]).replace("DamageData", "Resource")
	var script: GDScript = _fixture("@tool\nextends RefCounted\n" + body)
	var data_script: GDScript = _fixture("@tool\nextends Resource\nvar target: Node\nvar source_ability_id: StringName\nvar source_ability_slot_index: int = 0\nvar tags: Array[String] = []\nvar damage_types: Array[int] = []\n")
	if script == null or data_script == null:
		return
	var helper: RefCounted = script.new()
	var first: Node = Node.new()
	var second: Node = Node.new()
	var data: Resource = data_script.new()
	data.set("target", first)
	var filter: Dictionary = {"required_target_id": first.get_instance_id()}
	_check(helper.call("_outgoing_damage_modifier_matches", data, filter), "标记目标享受加成")
	data.set("target", second)
	_check(not helper.call("_outgoing_damage_modifier_matches", data, filter), "其他目标不享受标记加成")
	_check(helper.call("_outgoing_damage_modifier_matches", data, {}), "旧出伤修正不受新目标过滤影响")
	first.free()
	second.free()


func _check_context_handoff() -> void:
	var body: String = _functions("res://scripts/ability/core/ability.gd", ["pay_activation_costs", "activate"])
	body = body.replace("Entity", "Node2D").replace("AbilityContext", "RefCounted")
	body = body.replace(": AbilityController", ": Node").replace(" as AbilityController", " as Node")
	body = body.replace("RefCounted.new(entity, self)", "_new_context(entity)")
	var header: String = "@tool\nextends Node\nvar last_context: RefCounted\nfunc _new_context(_entity: Node2D) -> RefCounted:\n\treturn RefCounted.new()\nfunc _get_activation_cost_components() -> Array[Node]:\n\tvar result: Array[Node] = []\n\tfor child: Node in get_children():\n\t\tresult.append(child)\n\treturn result\nfunc _activate_components(context: RefCounted) -> void:\n\tlast_context = context\n"
	var script: GDScript = _fixture(header + body)
	var cost_script: GDScript = _fixture("@tool\nextends Node\nfunc pay_ability_cost(context: RefCounted) -> bool:\n\tcontext.cast_record.material_payments[&\"弹药\"] = 1\n\treturn true\n")
	if script == null or cost_script == null:
		return
	var ability: Node = script.new()
	ability.add_child(cost_script.new())
	var actor: Node2D = _actor()
	var context: RefCounted = _ctx()
	context.set("caster", actor)
	_check(ability.call("pay_activation_costs", actor, context), "真实成本入口可写入上下文")
	ability.call("activate", actor, 0.0, context)
	_check(ability.get("last_context") == context and context.get("cast_record").get("material_payments").get(&"弹药") == 1, "支付与正式施法使用同一上下文，不丢失弹药结果")
	ability.free()
	actor.free()
