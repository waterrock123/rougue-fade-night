## 编辑器资源与纯函数/隔离函数检查，不启动游戏，不读写存档。
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
	_check_matching()
	_check_resources()
	_check_snapshot()
	_check_equipped_query()
	_check_save_arrays()
	_check_routes()
	print("技能元素编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_matching() -> void:
	var raw: Array[StringName] = [&" Fire ", &"fire", &"MAGIC", &""]
	var tags: Array[StringName] = SkillElementTags.normalized(raw)
	_check(tags == [&"fire", &"magic"] and raw.size() == 4, "统一标识、去重、忽略空白且不改原数组")
	_check(SkillElementTags.has_tag(tags, &" FIRE "), "单元素查询统一大小写")
	_check(not SkillElementTags.has_tag(tags, &""), "空元素不是有效元素")
	var wanted: Array[StringName] = [&"fire", &"lightning"]
	_check(SkillElementTags.matches(tags, wanted), "任一匹配")
	_check(not SkillElementTags.matches(tags, wanted, true), "全部匹配拒绝缺少元素")
	var empty: Array[StringName] = []
	_check(SkillElementTags.matches(tags, empty) and SkillElementTags.matches(tags, empty, true), "空筛选不过滤")
	var filter: Resource = (load("res://scripts/skill/skill_element_filter.gd") as GDScript).new()
	filter.set("required_elements", wanted)
	_check(filter.call("matches_elements", tags), "筛选资源任一匹配")
	filter.set("require_all", true)
	_check(not filter.call("matches_elements", tags), "筛选资源全部匹配")
	filter.set("require_all", false)
	filter.set("excluded_elements", [&"magic"] as Array[StringName])
	_check(not filter.call("matches_elements", tags), "排除元素优先")
	_check(SkillElementTags.has_tag([&"wind"] as Array[StringName], &"wind"), "新元素无需修改枚举")


func _check_resources() -> void:
	var specs: Array = [["106_ice_piton", &"ice"], ["107_snake_big_gun", &"poison"], ["111_flamethrower", &"fire"], ["112_basic_guiren_attack", &"magic"], ["113_fireball", &"fire"], ["114_lightning_arrow", &"lightning"], ["115_shield_spell", &"magic"], ["116_haste_spell", &"magic"]]
	for spec: Array in specs:
		var resource: Resource = load("res://activate_skill/%s.tres" % spec[0]) as Resource
		_check(resource != null and resource.get("element_tags") == [spec[1]], "元素配置：" + spec[0])
	var ordinary: Resource = load("res://activate_skill/108_basic_scount_attack.tres") as Resource
	_check(ordinary.get("element_tags").is_empty(), "没有填写元素的技能保持无元素")
	var fire: Resource = load("res://activate_skill/113_fireball.tres") as Resource
	_check(fire.get("tags").has(&"projectile") and fire.get("tags").has(&"aoe"), "普通tags没有被替换")
	var shield: Node = (load("res://scenes/ability/guiren_shield_spell_ability.tscn") as PackedScene).instantiate()
	_check(shield.get_node("Channel/GrantShield").get("status_data").get("id") == &"shield_spell", "魔力身份不改变护盾术效果")
	shield.free()


func _skill_script() -> GDScript:
	return _fixture("@tool\nextends Resource\nvar element_tags: Array[StringName] = []\nvar is_basic_attack: bool = false\n" + _functions("res://scripts/skill/active_skill_data.gd", ["get_element_tags", "has_element_tag", "matches_element_tags"]))


func _ability_script() -> GDScript:
	return _fixture("@tool\nextends Node\nvar runtime_slot_index: int = 1\nvar skill_data: Resource\nvar fallback_element_tags: Array[StringName] = []\n" + _functions("res://scripts/ability/core/ability.gd", ["get_element_tags", "has_element_tag", "matches_element_tags"]))


func _check_snapshot() -> void:
	var skill_script: GDScript = _skill_script()
	var ability_script: GDScript = _ability_script()
	var body: String = _functions("res://scripts/ability/core/ability_context.gd", ["_init", "has_element_tag", "matches_element_tags", "stamp_damage_elements"])
	body = body.replace("Entity", "Node").replace("Ability", "Node").replace("DamageData", "Resource")
	var ctx_script: GDScript = _fixture("@tool\nextends RefCounted\nvar caster: Node\nvar ability: Node\nvar cast_record: Dictionary = {\"is_basic_attack\": false, \"damage_multiplier\": 1.0}\nvar element_tags: Array[StringName] = []\nvar caster_action_version: int = 0\n" + body)
	if skill_script == null or ability_script == null or ctx_script == null:
		return
	var skill: Resource = skill_script.new()
	skill.set("element_tags", [&"fire", &"magic"] as Array[StringName])
	var ability: Node = ability_script.new()
	ability.set("skill_data", skill)
	ability.set("fallback_element_tags", [&"ice"] as Array[StringName])
	_check(ability.call("get_element_tags") == [&"fire", &"magic"], "资源优先于场景后备")
	var context: RefCounted = ctx_script.new(null, ability)
	var copy: Array = ability.call("get_element_tags")
	copy.clear()
	_check(skill.get("element_tags").size() == 2, "查询返回副本")
	skill.set("element_tags", [&"ice"] as Array[StringName])
	_check(context.call("has_element_tag", &"fire") and ability.call("has_element_tag", &"ice"), "释放后修改原技能不改变快照")
	skill.set("element_tags", [] as Array[StringName])
	_check(ability.call("get_element_tags").is_empty(), "有资源但空元素时不使用场景后备")
	ability.set("skill_data", null)
	_check(ability.call("has_element_tag", &"ice"), "无资源的敌人技能使用后备元素")
	ability.free()
	_check(context.call("has_element_tag", &"magic"), "原技能实例释放后仍可读取快照")
	_check_manifest_snapshot(context)


func _check_manifest_snapshot(context: RefCounted) -> void:
	var body: String = _functions("res://scripts/ability/core/ability_manifest.gd", ["capture_element_tags", "stamp_damage_elements"])
	body = body.replace("AbilityContext", "RefCounted").replace("DamageData", "Resource")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar source_cast_record: Variant\nvar source_element_tags: Array[StringName] = []\n" + body)
	var data_body: String = _functions("res://scripts/stats/damage_data.gd", ["has_skill_element", "matches_skill_elements"])
	var data_script: GDScript = _fixture("@tool\nextends Resource\nvar cast_record: Variant\nvar skill_damage_multiplier: float = 1.0\nvar skill_element_tags: Array[StringName] = []\nvar damage_types: Array[int] = [1]\nvar tags: Array[String] = [\"projectile\"]\n" + data_body)
	if script == null or data_script == null:
		return
	var manifest: RefCounted = script.new()
	manifest.call("capture_element_tags", context)
	context.get("element_tags").clear()
	var data: Resource = data_script.new()
	manifest.call("stamp_damage_elements", data)
	_check(data.call("has_skill_element", &"fire") and data.call("has_skill_element", &"magic"), "Manifest继承独立快照并写入伤害")
	_check(data.get("damage_types") == [1] and data.get("tags") == ["projectile"], "元素不会改伤害类型和普通标签")
	manifest.get("source_element_tags").clear()
	_check(data.call("has_skill_element", &"fire"), "伤害快照不与弹体共用数组")
	manifest.set("source_element_tags", [&"fire"] as Array[StringName])
	manifest.call("capture_element_tags", null)
	_check(manifest.get("source_element_tags").is_empty(), "无技能上下文不产生虚构元素")
	context.set("element_tags", [&"lightning"] as Array[StringName])
	context.call("stamp_damage_elements", data)
	_check(data.call("has_skill_element", &"lightning"), "直接伤害组件也能写入上下文元素")


func _check_equipped_query() -> void:
	var body: String = _functions("res://scripts/ability/core/ability_controller.gd", ["get_abilities_with_elements"]).replace("Ability", "Node")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar abilities: Array[Node] = []\n" + body)
	var ability_script: GDScript = _ability_script()
	var skill_script: GDScript = _skill_script()
	if script == null or ability_script == null or skill_script == null:
		return
	var controller: RefCounted = script.new()
	var abilities: Array[Node] = []
	for elements: Array in [[&"magic"], [&"fire"], [&"magic", &"fire"]]:
		var data: Resource = skill_script.new()
		var typed_elements: Array[StringName] = []
		typed_elements.assign(elements)
		data.set("element_tags", typed_elements)
		data.set("is_basic_attack", abilities.is_empty())
		var ability: Node = ability_script.new()
		ability.set("skill_data", data)
		abilities.append(ability)
	controller.set("abilities", abilities)
	var fire: Array[StringName] = [&"fire"]
	var magic: Array[StringName] = [&"magic"]
	_check(controller.call("get_abilities_with_elements", fire).size() == 2, "统计当前携带的火元素技能")
	_check(controller.call("get_abilities_with_elements", magic, false, false).size() == 1, "可排除基础攻击")
	_check(controller.call("get_abilities_with_elements", [&"fire", &"magic"] as Array[StringName], true).size() == 1, "全部元素筛选")
	for ability: Node in abilities:
		ability.free()


func _check_save_arrays() -> void:
	var path: String = "res://scripts/autoload/save_manager.gd"
	var body: String = _functions(path, ["_to_string_name_array", "_string_name_array_to_strings"])
	var script: GDScript = _fixture("@tool\nextends RefCounted\n" + body)
	if script == null:
		return
	var helper: RefCounted = script.new()
	var tags: Array[StringName] = [&"fire", &"magic"]
	var saved: Array = helper.call("_string_name_array_to_strings", tags)
	var json: Variant = JSON.parse_string(JSON.stringify({"element_tags": saved}))
	_check(helper.call("_to_string_name_array", json["element_tags"]) == tags, "元素数组JSON转换可往返")
	var source: String = FileAccess.get_file_as_string(path)
	_check(source.contains('result["element_tags"]') and source.contains('active_data.element_tags ='), "备用技能存档链路包含新字段")
	_check(helper.call("_to_string_name_array", {}).is_empty(), "旧数据无元素安全为空")


func _check_routes() -> void:
	for file: String in ["projectile_manifest", "animated_projectile_manifest", "animated_hitbox_manifest", "ground_periodic_damage_manifest", "homing_firefly_manifest", "thrown_arc_impact_manifest", "fire_rain_zone_manifest", "orbiting_sword_manifest", "landing_status_area_manifest"]:
		var source: String = FileAccess.get_file_as_string("res://scripts/ability/manifest/%s.gd" % file)
		_check(source.contains("capture_element_tags(context)") and source.contains("stamp_damage_elements("), "覆写激活的实体继承并传递元素：" + file)
	for file: String in ["ability_spawn_manifest_fan", "ability_spawn_manifest_radial", "ability_spawn_manifest_random_around_target", "ability_sustained_projectile_fan", "ability_scatter_landing_areas", "ability_radial_gap_volley"]:
		var source: String = FileAccess.get_file_as_string("res://scripts/ability/component/%s.gd" % file)
		_check(source.contains("element_tags = context.element_tags.duplicate()"), "分裂上下文继承快照：" + file)


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
