## 编辑器隔离测试：不启动正式游戏、不读写玩家存档或仓库。
extends "res://scripts/utils/basic_tutorial_editor_check.gd"

const EQUIPMENT_ROOM: String = "res://scripts/hub/equipment_tutorial_room.gd"


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
	_check_equipment_progress()
	_check_chapter_profile()
	_check_equipment_lessons()
	_check_fixed_shelf()
	_check_chapter_resources()
	await _check_panel_layout()
	await _check_observation_layout()
	await _check_chapter_layout()
	print("教学章节编辑器检查：%d项，失败%d项；未启动游戏、未写玩家存档。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_equipment_progress() -> void:
	var progress: RefCounted = (load("res://scripts/hub/equipment_tutorial_progress.gd") as GDScript).new()
	var completed: Array[int] = [0]
	progress.connect("completed", func() -> void: completed[0] += 1)
	progress.call("record_bag_opened")
	progress.call("record_equipment", true, true)
	progress.call("confirm_observation", true, true, true)
	_check(progress.get("stage") == 0, "不能跳过购买直接过关")
	progress.call("record_purchase", false)
	_check(progress.get("stage") == 0, "购买别的装备不算教学购买")
	progress.call("record_purchase", true)
	_check(progress.get("stage") == 1, "真实购买后才提示打开背包")
	progress.call("record_bag_opened")
	_check(progress.get("stage") == 2, "实际打开背包后进入穿戴")
	progress.call("record_equipment", false, true)
	_check(progress.get("stage") == 2, "只增加属性但没穿戴不通过")
	progress.call("record_equipment", true, false)
	_check(progress.get("stage") == 2, "穿戴后属性未生效不通过")
	progress.call("record_equipment", true, true)
	_check(progress.get("stage") == 3, "穿戴与属性同时生效才进入观察")
	progress.call("confirm_observation", true, true, false)
	_check(progress.get("stage") == 3, "关闭属性面板时不能确认观察")
	progress.call("record_equipment", false, false)
	_check(progress.get("stage") == 2, "观察前卸下装备会退回穿戴步骤")
	progress.call("record_equipment", true, true)
	progress.call("confirm_observation", true, false, true)
	_check(progress.get("stage") == 3, "确认时再次验证真实属性，不能伪报生效")
	progress.call("confirm_observation", true, true, true)
	progress.call("confirm_observation", true, true, true)
	_check(progress.get("stage") == 4 and completed[0] == 1, "完成一次后不重复结算")


func _chapter_profile_manager() -> RefCounted:
	var source: String = ""
	for method: String in ["has_completed_basic_tutorial", "record_basic_tutorial_completion", "has_completed_tutorial_chapter", "record_tutorial_chapter_completion"]:
		source += _function_source("res://scripts/autoload/profile_manager.gd", method) + "\n"
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar profile_data: Resource\nvar writes: int = 0\nvar save_ok: bool = true\nfunc save_profile() -> bool:\n\twrites += 1\n\treturn save_ok\n" + source)
	return script.new() if script != null else null


func _check_chapter_profile() -> void:
	var manager: RefCounted = _chapter_profile_manager()
	if manager == null:
		return
	var profile: Resource = (load("res://scripts/profile/profile_data.gd") as GDScript).new()
	profile.call("load_from_dictionary", {"completed_basic_tutorial_character_ids": ["warrior"]})
	manager.set("profile_data", profile)
	_check(manager.call("has_completed_tutorial_chapter", &"warrior", &"basic"), "旧版基础教学记录在章节菜单中仍已完成")
	_check(not manager.call("has_completed_tutorial_chapter", &"warrior", &"equipment"), "旧档新增章节默认未完成")
	_check(manager.call("record_tutorial_chapter_completion", &"warrior", &"equipment"), "装备入门可独立保存完成")
	_check(not manager.call("has_completed_tutorial_chapter", &"wizard", &"equipment"), "章节进度按当前角色独立")
	manager.call("record_tutorial_chapter_completion", &"warrior", &"equipment")
	_check(manager.get("writes") == 1, "重复完成章节不重复落盘")
	var saved: Dictionary = profile.call("to_dictionary")
	var restored: Resource = profile.get_script().new()
	restored.call("load_from_dictionary", saved)
	_check(restored.get("completed_tutorial_chapter_ids").get("warrior") == ["equipment"], "章节进度可序列化还原")
	manager.set("save_ok", false)
	_check(not manager.call("record_tutorial_chapter_completion", &"wizard", &"equipment"), "保存失败返回失败")
	_check(not manager.call("has_completed_tutorial_chapter", &"wizard", &"equipment"), "保存失败回滚新增角色章节")
	_check(manager.call("has_completed_tutorial_chapter", &"warrior", &"equipment"), "失败不破坏已有章节记录")
	_check(profile.get("relic_warehouse_entries").is_empty() and profile.get("completed_event_ids").is_empty(), "章节不触发仓库或剧情奖励")
	restored.call("load_from_dictionary", {"completed_tutorial_chapter_ids": {"": ["bad"], "wizard": 42, "scount": ["equipment", "equipment"]}})
	_check(not restored.get("completed_tutorial_chapter_ids").has(""), "忽略损坏记录的空角色id")
	_check(restored.get("completed_tutorial_chapter_ids").get("scount") == ["equipment"], "重复章节加载时去重")


func _check_equipment_lessons() -> void:
	var catalog: Resource = load("res://custom_resource/equipment_tutorial_lessons.tres") as Resource
	_check(catalog != null, "装备教学配置可加载")
	if catalog == null:
		return
	var live_catalog: Resource = catalog.get_script().new()
	live_catalog.get("lessons").assign(catalog.get("lessons"))
	live_catalog.set("fallback_lesson", catalog.get("fallback_lesson"))
	var expected: Array[StringName] = [&"strength", &"dexterity", &"intelligence"]
	var ids: Array[String] = ["warrior", "scount", "wizard"]
	for index: int in range(ids.size()):
		var character: Resource = load("res://character_resource/%s/%s.tres" % [ids[index], ids[index]]) as Resource
		var lesson: Resource = live_catalog.call("resolve", character)
		_check(lesson != null and lesson.get("stat_key") == expected[index], "为当前角色选择相应属性装备：" + ids[index])
		_check_relic_stat_effect(lesson, character)
	var future: Resource = (load("res://custom_resource/chararcter.gd") as GDScript).new()
	future.set("id", &"future")
	_check(live_catalog.call("resolve", future) == catalog.get("fallback_lesson"), "未知角色可使用通用装备入门")


func _check_relic_stat_effect(lesson: Resource, character: Resource) -> void:
	# 保留生产版属性重算逻辑，只移除向编辑器自动加载节点发信号的一行。
	var recompute: String = _function_source("res://scripts/stats/stats_controller.gd", "recompute_stats").replace("EventBus.attribute_update.emit()", "pass")
	var stats_script: GDScript = _fixture("@tool\nextends StatsController\n" + recompute)
	var controller_script: GDScript = _fixture("@tool\nextends RelicController\nvar test_stats: StatsController\nfunc get_stats_controller() -> StatsController:\n\treturn test_stats\n")
	if stats_script == null or controller_script == null:
		return
	var stats: Node = stats_script.new()
	stats.set("stats_data", character.get("start_stats").duplicate(true))
	stats.call("recompute_stats")
	var key: StringName = lesson.get("stat_key")
	var baseline: float = stats.call("get_stat", key)
	var controller: Node = controller_script.new()
	controller.set("test_stats", stats)
	var original: Resource = lesson.get("relic")
	var relic: Resource = original.duplicate(true)
	_check(original != relic and original.get("icon") != null, "教学装备深复制且有现成图标")
	var effects: Array = relic.get("effects")
	_check(effects.size() == 1, "示例装备只有简单穿戴加成")
	var effect: Resource = effects[0].get_script().new()
	effect.set("add_stats", effects[0].get("add_stats").duplicate(true))
	var owner: Node = Node.new()
	var context: RefCounted = (load("res://custom_resource/relic_context.gd") as GDScript).new(relic, owner, controller, "lesson", relic.get("effects"), "effects", "activate")
	effect.call("on_activate", context, "lesson")
	_check(is_equal_approx(float(stats.call("get_stat", key)), baseline + float(lesson.get("stat_increase"))), "正式装备效果能使目标属性准确增加")
	effect.call("on_deactivate", context, "lesson")
	_check(is_equal_approx(float(stats.call("get_stat", key)), baseline), "卸下装备准确撤销属性加成")
	controller.free()
	stats.free()
	owner.free()


func _check_fixed_shelf() -> void:
	var body: String = _function_source("res://scripts/hub/tutorial_shop_controller.gd", "_roll_slots")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar shop: Resource\nvar lesson_relic: Resource\n" + body)
	if script == null:
		return
	var helper: RefCounted = script.new()
	var shop: Resource = (load("res://scripts/rest_period/shop/shop.gd") as GDScript).new()
	shop.set("slot_count", 1)
	var original: Resource = load("res://relics/level_1/003_树枝.tres") as Resource
	var item: Resource = original.duplicate(true)
	helper.set("shop", shop)
	helper.set("lesson_relic", item)
	helper.call("_roll_slots", 0)
	_check(shop.get("current_slot").size() == 1 and shop.get("current_slot")[0].get("item") == item, "固定货架只提供一件当前教学装备")
	_check(original.get("price") == item.get("price"), "教学不修改正式装备价格")
	var source: String = FileAccess.get_file_as_string("res://scripts/hub/tutorial_shop_controller.gd")
	_check(not source.contains("func buy_relic"), "购买仍复用正式二次确认与付款链路")
	for method: String in ["refresh", "refresh_for_free", "frezee", "level_up"]:
		_check(_function_source("res://scripts/hub/tutorial_shop_controller.gd", method).contains("pass"), "入门章不开放额外操作：" + method)


func _check_chapter_resources() -> void:
	var menu: PackedScene = load("res://scenes/hub/tutorial_chapter_panel.tscn") as PackedScene
	_check(menu != null, "章节选择场景可加载")
	var instance: Node = menu.instantiate()
	var ids: Dictionary = {}
	for chapter: Resource in instance.get("chapters"):
		_check(not ids.has(chapter.get("chapter_id")), "章节编号不重复")
		ids[chapter.get("chapter_id")] = true
		_check(load(chapter.get("scene_path")) is PackedScene, "章节入口指向可加载场景")
	_check(ids.has(&"basic") and ids.has(&"equipment") and ids.has(&"merge"), "三个章节都可独立进入，无顺序锁定")
	instance.free()
	var room: String = FileAccess.get_file_as_string(EQUIPMENT_ROOM)
	_check(not room.contains("SaveManager") and not room.contains("apply_new_run_modifiers"), "装备章不进入正式存档或仓库开局流程")
	_check(room.contains("TutorialBuildFactory.create_build(startup, null)"), "装备章使用清空装备和被动的独立角色副本")
	var hub: String = _function_source("res://scripts/hub/main_home_map.gd", "_enter_tutorial_chapter")
	_check(hub.contains("TrainingRoom.selected_character = hub_player.character"), "从大厅传递实时选择的角色")
	_check(hub.contains("previous_character") and hub.contains("if error != OK"), "切换失败恢复角色并允许重新选择")


func _tool_panel(path: String, class_line: String) -> Node:
	var scene: PackedScene = load(path) as PackedScene
	var node: Node = scene.instantiate()
	var original_script: Script = node.get_script() as Script
	var exported: Dictionary = {}
	for property: Dictionary in original_script.get_script_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE:
			exported[property["name"]] = node.get(property["name"])
	var source: String = original_script.source_code.replace(class_line + "\n", "")
	# 菜单初始化只替换完成进度查询，不接触真实 ProfileManager 或玩家档案。
	source = source.replace("ProfileManager.has_completed_tutorial_chapter(character.id, chapter.chapter_id)", "false")
	var script: GDScript = _fixture("@tool\n" + source)
	node.set_script(script)
	# 替换成可在编辑器执行的脚本会重置导出字段，必须还原场景真实配置。
	for key: String in exported:
		node.set(key, exported[key])
	root.add_child(node)
	return node


func _check_observation_layout() -> void:
	var panel: Node = _tool_panel("res://scenes/hub/basic_tutorial_panel.tscn", "class_name BasicTutorialPanel")
	var screen: Control = panel.get_node("Root") as Control
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1920, 1080)
	panel.set("chapter_title", "装备入门")
	panel.call("show_step", "浪子", 3, "查看属性变化", "装备已经生效。查看左侧属性面板的【敏捷】，确认穿戴前后的变化，再点击下方确认。", "背包用于存放，装备栏用于穿戴。")
	panel.call("set_progress", "敏捷：10 → 11（穿戴后 +1）")
	panel.call("set_confirmation", "我看到了属性变化", true)
	for frame: int in range(4):
		await process_frame
	var rect: Rect2 = (panel.get_node("Root/Panel") as Control).get_global_rect()
	_check(rect.end.y < 770.0, "观察步骤面板不覆盖底部商店")
	_check(rect.position.x > 1345.0 and rect.end.x <= 1920.0, "面板不遮挡中间背包且不超出屏幕")
	var confirm: Button = panel.get_node("Root/Panel/Margin/Content/ConfirmButton") as Button
	_check(confirm.visible and not confirm.disabled and rect.encloses(confirm.get_global_rect()), "属性确认按钮显示在面板内部")
	var target: Control = Control.new()
	screen.add_child(target)
	target.position = Vector2(100, 100)
	target.size = Vector2(120, 40)
	panel.call("set_focus_target", target)
	var focus: Panel = panel.get_node("Root/FocusFrame") as Panel
	_check(focus.visible and focus.get_global_rect().encloses(target.get_global_rect()), "教学边框定位到实际目标区域")
	_check(focus.mouse_filter == Control.MOUSE_FILTER_IGNORE, "高亮框不拦截购买或拖拽")
	target.hide()
	await process_frame
	_check(not focus.visible, "目标隐藏后不残留错位高亮")
	panel.free()


func _check_chapter_layout() -> void:
	var node: Control = _tool_panel("res://scenes/hub/tutorial_chapter_panel.tscn", "class_name TutorialChapterPanel") as Control
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.size = Vector2(1920, 1080)
	var character: Resource = load("res://character_resource/wizard/wizard.tres") as Resource
	node.call("configure", character)
	for frame: int in range(4):
		await process_frame
	var body: Control = node.get_node("Panel") as Control
	_check(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(body.get_global_rect()), "章节菜单大小在1920×1080屏幕内")
	var list: VBoxContainer = node.get_node("Panel/Margin/Content/Scroll/ChapterList") as VBoxContainer
	_check(list.get_child_count() == 3, "菜单实际生成三个可点击章节")
	var requested: Array[StringName] = []
	node.connect("chapter_requested", func(chapter: Resource) -> void: requested.append(chapter.get("chapter_id")))
	for button: Button in list.get_children():
		_check(not button.disabled, "存在场景的章节可直接进入")
		button.pressed.emit()
	_check(requested == [&"basic", &"equipment", &"merge"], "每个按钮发出各自章节而非同一场景")
	var closes: Array[int] = [0]
	node.connect("closed", func() -> void: closes[0] += 1)
	node.call("close_panel")
	node.call("close_panel")
	_check(closes[0] == 1, "关闭菜单只恢复大厅输入一次")
	await process_frame
