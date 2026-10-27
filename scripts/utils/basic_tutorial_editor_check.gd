## 仅在编辑器内执行真实状态机、临时构筑和预览信号测试，不启动游戏、不写玩家存档。
extends "res://scripts/utils/guiren_basic_attack_editor_check.gd"

const PROGRESS_PATH: String = "res://scripts/hub/basic_tutorial_progress.gd"
const CONTROLLER_PATH: String = "res://scripts/ability/core/ability_controller.gd"


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_progress()
	_check_characters()
	_check_preview_events()
	_check_damage_filter()
	_check_profile()
	_check_scene_wiring()
	await _check_panel_layout()
	print("新手教学编辑器检查：%d项，失败%d项；未启动游戏、未写存档。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_progress() -> void:
	var progress: RefCounted = (load(PROGRESS_PATH) as GDScript).new()
	var completions: Array[int] = [0]
	progress.connect("completed", func() -> void: completions[0] += 1)
	progress.call("record_basic_hit")
	progress.call("record_movement", 0.0, true)
	_check(progress.get("stage") == 0, "不能原地或越序通过移动教学")
	progress.call("record_movement", 32.0, false)
	progress.call("record_movement", 16.0, true)
	_check(progress.get("stage") == 1, "实际移动并到达标记才进入基础攻击")
	for index: int in range(2):
		progress.call("record_basic_hit")
	_check(progress.get("stage") == 1, "不足三次命中不推进")
	progress.call("record_basic_hit")
	_check(progress.get("stage") == 2, "三次基础攻击命中进入瞄准")
	progress.call("begin_preview")
	progress.call("tick_preview", 0.1)
	progress.call("release_preview")
	progress.call("authorize_cast", 10)
	progress.call("record_aim_hit", 10)
	_check(progress.get("stage") == 2, "点按不能代替按住瞄准")
	_check_release_progress(progress, completions)


func _check_release_progress(progress: RefCounted, completions: Array[int]) -> void:
	progress.call("begin_preview")
	progress.call("tick_preview", 0.36)
	_check(progress.get("stage") == 3, "按住足够时间后提示松开")
	progress.call("cancel_preview")
	_check(progress.get("stage") == 2, "取消预览不算释放")
	progress.call("begin_preview")
	progress.call("tick_preview", 0.36)
	progress.call("release_preview")
	progress.call("authorize_cast", 11)
	progress.call("begin_preview")
	progress.call("tick_preview", 0.36)
	progress.call("release_preview")
	progress.call("authorize_cast", 12)
	progress.call("record_aim_hit", 11)
	_check(progress.get("stage") == 3, "旧弹体不能代替当前瞄准释放")
	progress.call("record_aim_hit", 12)
	progress.call("record_aim_hit", 12)
	_check(progress.get("stage") == 4 and completions[0] == 1, "真实命中后完成且只结算一次")


func _check_characters() -> void:
	# 仅将编辑器资源占位符转换成可调用的条目，构筑仍走生产版 RunStartup 和工厂。
	var startup_script: GDScript = _fixture("@tool\nextends RunStartup\nfunc _duplicate_resource(value: Resource):\n\tif value == null:\n\t\treturn null\n\tif value is SkillEntry:\n\t\tvar entry: SkillEntry = SkillEntry.new()\n\t\tentry.skill_data = value.skill_data.duplicate(true)\n\t\tentry.is_equipped = value.is_equipped\n\t\treturn entry\n\treturn value.duplicate(true)\n")
	var catalog: Resource = load("res://custom_resource/basic_tutorial_lessons.tres") as Resource
	var factory: GDScript = load("res://scripts/hub/tutorial_build_factory.gd") as GDScript
	if startup_script == null or catalog == null:
		return
	var ids: Array[String] = ["warrior", "scount", "wizard"]
	var skills: Array[StringName] = [&"103", &"121", &"113"]
	var lessons: Array = catalog.get("lessons")
	for index: int in range(ids.size()):
		var id: String = ids[index]
		var character: Resource = load("res://character_resource/%s/%s.tres" % [id, id]) as Resource
		var startup: Resource = startup_script.new()
		startup.set("picked_character", character)
		var lesson: Resource = lessons[index]
		_check(lesson.get("character_id") == StringName(id), "专属教学配置：" + id)
		_check(lesson.get("aim_skill").get("id") == skills[index], "角色教学技能：" + id)
		var original_basic: Resource = character.get("start_skill").get("skill_data")
		var original_flag: bool = original_basic.get("is_basic_attack")
		var build: Resource = factory.call("create_build", startup, lesson)
		_check_build(build, character, original_basic, original_flag)
		_check_aim_scene(lesson.get("aim_skill"))
	_check(catalog.get("fallback_lesson").get("aim_skill").get("id") == &"106", "新角色回退通用冰锥，不替换角色")


func _check_build(build: Resource, character: Resource, original_basic: Resource, original_flag: bool) -> void:
	_check(build != null, "创建角色教学临时构筑")
	if build == null:
		return
	var entries: Array = build.get("owned_active_skills")
	_check(entries.size() == 2, "只携带自己的基础攻击和一项教学技能")
	if entries.size() == 2:
		_check(entries[0].get("skill_data").get("id") == original_basic.get("id"), "保留当前角色基础攻击")
		_check(entries[0].get("skill_data").get("is_basic_attack"), "教学副本正确标识基础攻击")
		_check(entries[0].get("skill_data") != original_basic, "基础攻击不是角色原始资源")
		_check(entries[0].get("slot_index") == 0 and entries[1].get("slot_index") == 1, "基础攻击及瞄准技能槽位正确")
	_check(original_basic.get("is_basic_attack") == original_flag, "原始角色基础攻击标记未被修改")
	_check(build.get("owned_passive_skills").is_empty(), "不带入被动技能干扰教学")
	_check(build.get("player_stats") != character.get("start_stats"), "属性数据独立副本")
	_check(build.get("player_stats").get("base_max_energy") >= 50.0, "贵人等消耗能量的角色可正常练习")
	for pair: Array in [["player_inventory", "slots"], ["player_equipment", "equip_slots"]]:
		var resource: Resource = build.get(pair[0])
		if resource == null:
			continue
		for slot: Resource in resource.get(pair[1]):
			_check(slot == null or slot.get("item") == null, "教学不携带正式装备")


func _check_aim_scene(skill: Resource) -> void:
	var scene: PackedScene = skill.get("ability_scene") as PackedScene
	var ability: Node = scene.instantiate()
	var indicators: Array[Node] = ability.find_children("*", "", true, false)
	var found: bool = false
	for component: Node in indicators:
		var script: Script = component.get_script() as Script
		if script != null and script.resource_path.ends_with("ability_area_indicator.gd"):
			found = true
	_check(found, "教学技能具备真实范围指示组件")
	ability.free()


func _check_preview_events() -> void:
	var source: String = ""
	for method: String in ["begin_ability_preview", "release_ability_preview", "cancel_ability_preview"]:
		source += _function_source(CONTROLLER_PATH, method) + "\n"
	source = source.replace(": Ability", ": Node").replace(": Entity", ": Node")
	var header: String = "@tool\nextends RefCounted\nsignal ability_preview_started(ability, caster)\nsignal ability_preview_released(ability, caster)\nsignal ability_preview_cancelled(ability, caster)\nvar entity: Node\nvar previewing_ability: Node\nvar events: Array[String] = []\nvar castable: bool = true\nfunc _can_be_cast(_ability) -> bool:\n\treturn castable\nfunc _show_ability_block_reason(_ability) -> void:\n\tpass\nfunc trigger_ability(_ability, _charge: float = 0.0) -> bool:\n\tevents.append(\"cast\")\n\treturn true\n"
	header += "func request_player_cast(ability, charge: float = 0.0) -> bool:\n\treturn trigger_ability(ability, charge)\n"
	var script: GDScript = _fixture(header + source)
	var actor_script: GDScript = _fixture("@tool\nextends Node\nvar is_dead: bool = false\nvar preview_context: RefCounted\nvar with_preview: bool = true\nfunc has_cast_preview() -> bool:\n\treturn with_preview\nfunc begin_cast_preview(_caster) -> void:\n\tpass\nfunc end_cast_preview() -> void:\n\tpass\n")
	if script == null or actor_script == null:
		return
	var helper: RefCounted = script.new()
	var actor: Node = actor_script.new()
	var skill: Node = actor_script.new()
	helper.set("entity", actor)
	var events: Array[String] = helper.get("events")
	helper.connect("ability_preview_started", func(_ability, _caster) -> void: events.append("start"))
	helper.connect("ability_preview_released", func(_ability, _caster) -> void: events.append("release"))
	helper.connect("ability_preview_cancelled", func(_ability, _caster) -> void: events.append("cancel"))
	helper.call("begin_ability_preview", skill)
	helper.call("release_ability_preview", skill)
	_check(helper.get("events") == ["start", "release", "cast"], "松开信号在实际施法前发出，支持瞬时命中判定")
	helper.get("events").clear()
	helper.call("begin_ability_preview", skill)
	helper.call("cancel_ability_preview")
	_check(helper.get("events") == ["start", "cancel"], "取消指示器不释放技能")
	helper.get("events").clear()
	helper.set("castable", false)
	helper.call("begin_ability_preview", skill)
	_check(helper.get("events").is_empty(), "冷却或消耗不足不开始教学预览")
	skill.free()
	actor.free()


func _check_profile() -> void:
	var profile: Resource = (load("res://scripts/profile/profile_data.gd") as GDScript).new()
	profile.call("load_from_dictionary", {})
	_check(profile.get("completed_basic_tutorial_character_ids").is_empty(), "旧档没有教学字段时兼容")
	profile.get("completed_basic_tutorial_character_ids").append(&"warrior")
	var saved: Dictionary = profile.call("to_dictionary")
	var restored: Resource = profile.get_script().new()
	restored.call("load_from_dictionary", saved)
	_check(restored.get("completed_basic_tutorial_character_ids") == [&"warrior"], "完成教学按角色保存")
	_check(not restored.get("completed_basic_tutorial_character_ids").has(&"wizard"), "完成一个角色不影响另一个角色")
	var source: String = ""
	for method: String in ["has_completed_basic_tutorial", "record_basic_tutorial_completion"]:
		source += _function_source("res://scripts/autoload/profile_manager.gd", method) + "\n"
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar profile_data: Resource\nvar writes: int = 0\nvar save_ok: bool = true\nfunc save_profile() -> bool:\n\twrites += 1\n\treturn save_ok\n" + source)
	if script == null:
		return
	var manager: RefCounted = script.new()
	manager.set("profile_data", restored)
	_check(manager.call("record_basic_tutorial_completion", &"scount"), "新角色教学可记录完成")
	manager.call("record_basic_tutorial_completion", &"scount")
	_check(manager.get("writes") == 1, "重复完成不重复写盘")
	manager.set("save_ok", false)
	_check(not manager.call("record_basic_tutorial_completion", &"wizard"), "写盘失败可被识别")
	_check(not manager.call("has_completed_basic_tutorial", &"wizard"), "失败回滚，不能伪报已保存")
	_check(restored.get("completed_event_ids").is_empty(), "教学不完成剧情、不发放剧情奖励")


func _check_damage_filter() -> void:
	var source: String = _function_source("res://scripts/hub/basic_tutorial_controller.gd", "_on_damage_dealt").replace("data: DamageData", "data: RefCounted")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar player: Node\nvar dummy: Node\nvar basic_ability: RefCounted\nvar aim_ability: RefCounted\nvar progress: RefCounted = preload(\"res://scripts/hub/basic_tutorial_progress.gd\").new()\nfunc _update_progress_text() -> void:\n\tpass\n" + source)
	var data_script: GDScript = _fixture("@tool\nextends RefCounted\nvar source: Node\nvar target: Node\nvar id: StringName\nvar source_ability_id: StringName\nvar final_damage: float = 1.0\nvar is_miss: bool = false\nvar cast_record: RefCounted\n")
	if script == null or data_script == null:
		return
	var helper: RefCounted = script.new()
	var player: Node = Node.new()
	var dummy: Node = Node.new()
	var basic: RefCounted = data_script.new()
	var aim: RefCounted = data_script.new()
	basic.set("id", &"basic")
	aim.set("id", &"aim")
	helper.set("player", player)
	helper.set("dummy", dummy)
	helper.set("basic_ability", basic)
	helper.set("aim_ability", aim)
	var progress: RefCounted = helper.get("progress")
	progress.set("stage", 1)
	var data: RefCounted = data_script.new()
	data.set("source", player)
	data.set("target", dummy)
	data.set("source_ability_id", &"basic")
	data.set("is_miss", true)
	helper.call("_on_damage_dealt", data)
	_check(progress.get("basic_hits") == 0, "闪避不算基础攻击命中")
	data.set("is_miss", false)
	data.set("target", player)
	helper.call("_on_damage_dealt", data)
	_check(progress.get("basic_hits") == 0, "打错目标不能推进教学")
	data.set("target", dummy)
	helper.call("_on_damage_dealt", data)
	_check(progress.get("basic_hits") == 1, "玩家真实命中指定假人才计数")
	player.free()
	dummy.free()


func _check_panel_layout() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/hub/basic_tutorial_panel.gd").replace("class_name BasicTutorialPanel\n", "")
	var script: GDScript = _fixture("@tool\n" + source)
	if script == null:
		return
	var panel: Node = (load("res://scenes/hub/basic_tutorial_panel.tscn") as PackedScene).instantiate()
	panel.set_script(script)
	root.add_child(panel)
	var control: Control = panel.get_node("Root") as Control
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.size = Vector2(1920, 1080)
	panel.call("show_step", "浪子", 2, "按住技能键，观察范围", "本次临时提供【贯甲射击】。\n贯甲射击沿直线发射。没有弹药也能释放，但伤害减半且不穿透；这次教学不要求准备弹药。", "按住：鼠标右键 / 2")
	for frame: int in range(4):
		await process_frame
	var body: Control = panel.get_node("Root/Panel") as Control
	var rect: Rect2 = body.get_global_rect()
	_check(rect.position.x >= 0.0 and rect.end.x <= 1920.0 and rect.end.y <= 1080.0, "1920×1080教学面板不超出屏幕")
	var buttons: Control = body.get_node("Margin/Content/Buttons") as Control
	_check(rect.encloses(buttons.get_global_rect()), "重新练习与退出按钮均在面板内")
	_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "面板外不遮挡战斗鼠标操作")
	panel.free()


func _check_scene_wiring() -> void:
	for path: String in ["res://scenes/hub/basic_tutorial_room.tscn", "res://scenes/hub/basic_tutorial_panel.tscn", "res://scenes/hub/tutorial_world_marker.tscn", "res://scenes/battlemap/templates/sample_03_中央竞技场.tscn"]:
		_check(load(path) is PackedScene, "场景可加载：" + path)
	var hub: String = FileAccess.get_file_as_string("res://scenes/hub/main_home_map.tscn")
	_check(hub.contains("[node name=\"TutorialButton\"") and hub.contains("新手教学"), "大厅具有独立教学入口")
	var training: String = _function_source("res://scripts/hub/training_room.gd", "_save_current_run")
	_check(training.contains("pass"), "教学继承训练容器，不覆盖局内存档")
	var room: String = FileAccess.get_file_as_string("res://scripts/hub/basic_tutorial_room.gd")
	_check(not room.contains("SaveManager") and not room.contains("apply_new_run_modifiers"), "不消耗仓库装备或应用局外加成")
