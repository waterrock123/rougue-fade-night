## 真实函数的编辑器隔离回归，不启动游戏，不读写真实存档、仓库或随机数。
extends "res://scripts/utils/tutorial_chapters_editor_check.gd"

const CORE_SHOP: String = "res://scripts/rest_period/shop_controller.gd"
const MERGE_SHOP: String = "res://scripts/hub/merge_tutorial_shop.gd"
const BUILD_PATH: String = "res://custom_resource/player_bulid.gd"
var pipeline_script: GDScript
var build_script: GDScript
var inventory_script: GDScript
var bus_script: GDScript
var stats_script: GDScript


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
	_check_merge_progress()
	_prepare_pipeline_fixtures()
	_check_merge_pipeline()
	_check_material_capacity()
	_check_late_material_return()
	await _check_panel_layout()
	await _check_observation_layout()
	await _check_chapter_layout()
	print("合成教学与前两章编辑器检查：%d项，失败%d项；未启动游戏、未写真实存档。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_merge_progress() -> void:
	var script: GDScript = load("res://scripts/hub/merge_tutorial_progress.gd") as GDScript
	for merge_first: bool in [true, false]:
		var state: RefCounted = script.new()
		var finished: Array[int] = [0]
		state.connect("completed", func() -> void: finished[0] += 1)
		state.call("record_purchase", false)
		state.call("confirm_upgrade", true, true, true)
		_check(state.get("stage") == 0, "不购买不能跳过合成")
		state.call("record_merge" if merge_first else "record_purchase", true)
		_check(state.get("stage") == 0, "购买与合成都确认后才推进")
		state.call("record_purchase" if merge_first else "record_merge", true)
		_check(state.get("stage") == 1, "兼容合成与购买完成的不同信号顺序")
		state.call("record_reward", true, true, true)
		_check(state.get("stage") == 1, "未看升级说明不能跳过直接领奖")
		state.call("confirm_upgrade", true, true, false)
		_check(state.get("stage") == 1, "背包未打开时不能确认观察")
		state.call("confirm_upgrade", true, true, true)
		state.call("record_reward", true, false, true)
		_check(state.get("stage") == 2, "扣钱领取不能当作免费奖励")
		state.call("record_reward", true, true, false)
		_check(state.get("stage") == 2, "货架没恢复不能当作领取完成")
		state.call("record_reward", true, true, true)
		_check(state.get("stage") == 3, "领取且恢复后等待玩家观察确认")
		state.call("confirm_restored", false)
		_check(state.get("stage") == 3, "确认完成时再次核对货架")
		state.call("confirm_restored", true)
		state.call("confirm_restored", true)
		_check(state.get("stage") == 4 and finished[0] == 1, "完成结算仅触发一次")


func _prepare_pipeline_fixtures() -> void:
	# 使用生产版购买、背包添加和跨栏合成函数，只将全局通知转发到局部测试总线。
	bus_script = _fixture("@tool\nextends Node\nsignal relic_upgraded(relic, receiver)\nsignal relic_merged_to_levelup(relic)\nsignal inventory_update()\nsignal equipment_update()\nsignal relic_added(relic, receiver)\nsignal buy_equipment(relic)\nsignal relic_purchase_preprocess(relic)\nsignal relic_purchased(relic)\nsignal free_relic_choice_changed()\n")
	var merge_body: String = _function_source(BUILD_PATH, "_try_merge_relic_id") + _function_source(BUILD_PATH, "add_relic")
	merge_body = merge_body.replace("EventBus", "test_bus").replace("AudioController.play_ui_sound(&\"level_up_item\")", "pass").replace("AudioController.play_ui_sound(&\"get_item\")", "pass")
	build_script = _fixture("@tool\nextends PlayerBuild\nvar test_bus: Node\n" + merge_body)
	var add_body: String = _function_source("res://scripts/package_system/inventory.gd", "add_relic").replace("EventBus", "test_bus")
	inventory_script = _fixture("@tool\nextends Inventory\nvar test_bus: Node\n" + add_body)
	var queue_body: String = _function_source("res://scripts/run/run_stats.gd", "queue_free_relic_choice").replace("EventBus", "test_bus")
	stats_script = _fixture("@tool\nextends RunStats\nvar test_bus: Node\n" + queue_body)
	pipeline_script = _fixture(_pipeline_source())


func _pipeline_source() -> String:
	var body: String = ""
	var core_methods: Array[String] = ["buy_relic", "_buy_free_choice_relic", "_on_buy_equipment", "_get_player_build", "_pay_relic_cost", "_try_start_free_relic_choice", "_begin_free_relic_choice", "_end_free_relic_choice", "_save_shop_state", "_restore_shop_state", "_duplicate_slot_array", "_duplicate_bool_array", "_clear_shop_slots_for_free_choice", "_roll_free_choice_slots"]
	for method: String in core_methods:
		var source: String = _function_source(CORE_SHOP, method)
		if method in ["buy_relic", "_save_shop_state", "_roll_free_choice_slots"]:
			source = source.replace("func " + method + "(", "func _production" + method + "(")
		body += source + "\n"
	for method: String in ["buy_relic", "set_reward_enabled", "_roll_free_choice_slots", "_get_available_relics_by_level", "_pick_random_relic", "_save_shop_state", "has_restored_shelf", "_shelf_snapshot", "_owns_relic"]:
		body += _function_source(MERGE_SHOP, method).replace("super.buy_relic", "_productionbuy_relic").replace("super._save_shop_state", "_production_save_shop_state").replace("super._roll_free_choice_slots", "_production_roll_free_choice_slots") + "\n"
	# 让候选副本可在编辑器执行 Relic 的价格初始化方法，仍复制同一份导出数据。
	body = body.replace("candidates[reward_index % candidates.size()].duplicate(true) as Relic", "_live_relic(candidates[reward_index % candidates.size()])")
	var feedback_stub: String = "var feedback_messages: Array[String] = []\nfunc _show_shop_tip(message: String, _key: String) -> void:\n\tfeedback_messages.append(message)\n" + _function_source(CORE_SHOP, "_purchase_failure_reason")
	return _pipeline_header() + _live_relic_source() + feedback_stub + body.replace("EventBus", "test_bus")


func _live_relic_source() -> String:
	return "func _live_relic(source: Relic) -> Relic:\n\tvar relic: Relic = source.get_script().new()\n\tfor property: Dictionary in source.get_script().get_script_property_list():\n\t\tif int(property[\"usage\"]) & PROPERTY_USAGE_STORAGE:\n\t\t\tvar value: Variant = source.get(property[\"name\"])\n\t\t\tif value is Array or value is Dictionary:\n\t\t\t\tvalue = value.duplicate(true)\n\t\t\trelic.set(property[\"name\"], value)\n\treturn relic\n"


func _pipeline_header() -> String:
	return "@tool\nextends RefCounted\nsignal tutorial_shop_changed()\nconst FREE_CHOICE_SLOT_COUNT: int = 3\nvar test_bus: Node\nvar shop: Shop\nvar run_stats: RunStats\nvar tutorial_config: MergeTutorialConfig\nvar lesson_relic: Relic\nvar shop_slots: Array[Node] = []\nvar money_token: Node\nvar is_free_choice_active: bool = false\nvar free_choice_level: int = -1\nvar free_choice_slot_indices: Array[int] = []\nvar suppress_free_choice_start: bool = false\nvar saved_shop_slots: Array[Slot] = []\nvar saved_frozen_slots: Array[bool] = []\nvar material_purchased: bool = false\nvar reward_enabled: bool = false\nvar reward_index: int = 0\nvar selected_reward: Relic\nvar reward_was_free: bool = false\nvar expected_shelf: Array[Dictionary] = []\nfunc _sync_shop_ui() -> void:\n\tpass\nfunc _update_shop_ui() -> void:\n\tpass\nfunc _clear_pending_purchase() -> void:\n\tpass\nfunc _save_run_if_available() -> void:\n\tpass\nfunc _trigger_relic_gain_effects(_relic, _key) -> void:\n\tpass\nfunc _refresh_run_ui_if_available() -> void:\n\tpass\nfunc _get_available_relics() -> Array[Relic]:\n\treturn []\n"


func _new_pipeline(material: Resource) -> Dictionary:
	var bus: Node = bus_script.new()
	var build: Resource = build_script.new()
	var inventory: Resource = inventory_script.new()
	inventory.set("test_bus", bus)
	for index: int in range(8):
		inventory.get("slots").append((load("res://scripts/package_system/slot.gd") as GDScript).new())
	var equipment: Resource = (load("res://scripts/package_system/equipment.gd") as GDScript).new()
	equipment.get("equip_slots").append((load("res://scripts/package_system/slot.gd") as GDScript).new())
	build.set("test_bus", bus)
	build.set("player_inventory", inventory)
	build.set("player_equipment", equipment)
	var stats: Resource = stats_script.new()
	stats.set("test_bus", bus)
	stats.set("player_build", build)
	var shop: Resource = (load("res://scripts/rest_period/shop/shop.gd") as GDScript).new()
	shop.set("slot_count", 3)
	shop.call("ensure_slot_count")
	stats.set("shop", shop)
	stats.call("set_gold", int(material.get("price")) + 3)
	var helper: RefCounted = pipeline_script.new()
	helper.set("test_bus", bus)
	helper.set("shop", shop)
	helper.set("run_stats", stats)
	helper.set("lesson_relic", material)
	helper.set("tutorial_config", load("res://custom_resource/merge_tutorial_config.tres"))
	bus.connect("buy_equipment", Callable(helper, "_on_buy_equipment"))
	bus.connect("free_relic_choice_changed", Callable(helper, "_try_start_free_relic_choice"))
	bus.connect("relic_merged_to_levelup", func(_relic: Resource) -> void: stats.call("queue_free_relic_choice", stats.call("get_free_relic_choice_level_for_now")))
	var slot_script: GDScript = _fixture("@tool\nextends Node\nfunc set_frozen(_value) -> void:\n\tpass\nfunc clear_relic() -> void:\n\tpass\n")
	for index: int in range(3):
		helper.get("shop_slots").append(slot_script.new())
	return {"helper": helper, "build": build, "stats": stats, "shop": shop, "bus": bus}


func _check_merge_pipeline() -> void:
	if pipeline_script == null or build_script == null or inventory_script == null or stats_script == null:
		return
	var catalog: Resource = load("res://custom_resource/equipment_tutorial_lessons.tres") as Resource
	for lesson: Resource in catalog.get("lessons"):
		for required: int in [2, 3, 5]:
			var original: Resource = lesson.get("relic")
			var material: Resource = original.duplicate(true)
			material.set("upgrade_merge_count", required)
			var pipeline: Dictionary = _new_pipeline(material)
			_check_pipeline_result(pipeline, material, required)
			_check(original.get("leveltip") == 0 and original.get("upgrade_merge_count") == 3, "测试不修改角色正式装备资源")
			for node: Node in pipeline["helper"].get("shop_slots"):
				node.free()
			pipeline["bus"].free()


func _check_pipeline_result(data: Dictionary, material: Resource, required: int) -> void:
	var materials: GDScript = load("res://scripts/hub/tutorial_merge_materials.gd") as GDScript
	var build: Resource = data["build"]
	var helper: RefCounted = data["helper"]
	var shop: Resource = data["shop"]
	_check(materials.call("seed", build, material), "预置N-1材料，N=%d" % required)
	_check(materials.call("count", build, material.get("id"), false) == required - 1, "材料总数按资源门槛生成")
	_check(build.get("player_equipment").get("equip_slots")[0].get("item") != null, "确有一件穿戴材料参与合成")
	shop.get("current_slot")[0].set("item", material)
	var config: Resource = helper.get("tutorial_config")
	for index: int in range(1, 3):
		shop.get("current_slot")[index].set("item", config.get("ordinary_extras")[index - 1].duplicate(true))
	helper.call("buy_relic", 1)
	_check(data["stats"].get("gold") == int(material.get("price")) + 3, "错误商品不可花掉教学金币")
	helper.call("buy_relic", 0)
	_check(materials.call("count", build, material.get("id"), false) == 0, "真实购买与合成消耗全部未升级材料")
	_check(materials.call("count", build, material.get("id"), true) == 1, "合成后只剩一件升级态")
	_check(build.get("player_equipment").get("equip_slots")[0].get("item").get("level") == material.get("level"), "装备等阶不随升级态增加")
	_check(helper.get("is_free_choice_active") and helper.get("free_choice_level") == 2, "真实合成队列打开商店等级+1的免费三选一")
	var ids: Dictionary = {}
	for slot: Resource in shop.get("current_slot"):
		var reward: Resource = slot.get("item")
		_check(reward != null and reward.get("price") == 0 and reward.get("level") == 2, "免费候选零售价且同等阶")
		ids[reward.get("id")] = true
	_check(ids.size() == 3, "固定候选不重复，玩家真有三个选择")
	_check_reward_pipeline(data)


func _check_reward_pipeline(data: Dictionary) -> void:
	var helper: RefCounted = data["helper"]
	helper.call("buy_relic", 1)
	_check(helper.get("is_free_choice_active") and helper.get("selected_reward") == null, "确认升级说明前不能提前领取")
	helper.call("set_reward_enabled", true)
	var gold: int = data["stats"].get("gold")
	helper.call("buy_relic", 1)
	_check(not helper.get("is_free_choice_active"), "领取后真实退出三选一")
	_check(helper.get("selected_reward") != null and helper.get("reward_was_free"), "领取成功且未扣钱")
	_check(data["stats"].get("gold") == gold, "奖励领取不消耗剩余教学金币")
	_check(helper.call("has_restored_shelf"), "普通商品、价格、升级态和冻结状态完整恢复")
	_check(data["shop"].get("current_slot")[0].get("item") == null, "购买过的材料格不复活")
	var total: int = 0
	for slot: Resource in data["build"].get("player_inventory").get("slots"):
		if slot.get("item") != null:
			total += 1
	_check(total == 1, "背包只收到一件免费装备，其余两件消失")
	helper.call("buy_relic", 2)
	_check(data["stats"].get("gold") == gold, "三选一结束后不能再领第二件")
	var changed: Resource = data["shop"].get("current_slot")[1].get("item")
	changed.set("price", int(changed.get("price")) + 1)
	_check(not helper.call("has_restored_shelf"), "仅商品名相同但价格错误也不能伪报恢复")


func _check_material_capacity() -> void:
	if pipeline_script == null:
		return
	var material: Resource = (load("res://relics/level_1/003_树枝.tres") as Resource).duplicate(true)
	material.set("upgrade_merge_count", 100)
	var pipeline: Dictionary = _new_pipeline(material)
	var materials: GDScript = load("res://scripts/hub/tutorial_merge_materials.gd") as GDScript
	_check(not materials.call("seed", pipeline["build"], material), "合成门槛超出可用格时明确失败")
	_check(materials.call("count", pipeline["build"], material.get("id"), false) == 0, "准备失败不留下半套材料")
	for node: Node in pipeline["helper"].get("shop_slots"):
		node.free()
	pipeline["bus"].free()


func _check_late_material_return() -> void:
	if pipeline_script == null:
		return
	var material: Resource = (load("res://relics/level_1/003_树枝.tres") as Resource).duplicate(true)
	var pipeline: Dictionary = _new_pipeline(material)
	var build: Resource = pipeline["build"]
	var helper: RefCounted = pipeline["helper"]
	var materials: GDScript = load("res://scripts/hub/tutorial_merge_materials.gd") as GDScript
	materials.call("seed", build, material)
	var equipped_slot: Resource = build.get("player_equipment").get("equip_slots")[0]
	var held: Resource = equipped_slot.get("item")
	equipped_slot.set("item", null)
	var slots: Array = pipeline["shop"].get("current_slot")
	slots[0].set("item", material)
	var config: Resource = helper.get("tutorial_config")
	for index: int in range(1, 3):
		slots[index].set("item", config.get("ordinary_extras")[index - 1].duplicate(true))
	helper.call("buy_relic", 0)
	_check(not helper.get("is_free_choice_active"), "材料拿在鼠标上时不会伪造合成或奖励")
	equipped_slot.set("item", held)
	build.call("check_relic_merges")
	_check(helper.get("is_free_choice_active"), "买完后再放回装备栏仍能合成并打开免费奖励")
	_check(materials.call("count", build, material.get("id"), true) == 1, "延迟放回材料也只生成一件升级态")
	var body: String = _function_source("res://scripts/hub/merge_tutorial_room.gd", "_refresh_tutorial_progress")
	_check(body.contains("check_relic_merges()"), "教学库存变化后实际调用跨栏合成检查")
	for node: Node in helper.get("shop_slots"):
		node.free()
	pipeline["bus"].free()
