## 编辑器资源与原函数隔离回归；不启动修整期，不读取或写入真实存档。
extends "res://scripts/utils/guiren_basic_attack_editor_check.gd"

const RUN_STATS_SCRIPT: String = "res://scripts/run/run_stats.gd"
const KEEPER_UI_SCRIPT: String = "res://scripts/rest_period/shop_keeper_token.gd"


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	for path: String in [RUN_STATS_SCRIPT, KEEPER_UI_SCRIPT, "res://scripts/rest_period/rest_period.gd", "res://scripts/autoload/save_manager.gd"]:
		var script: Script = load(path) as Script
		_check(script != null and script.reload(true) == OK, "脚本解析：" + path)
	_check_character_shops()
	_check_repair()
	_check_dialogues()
	_check_entry_order()
	print("修整期商店初始化编辑器检查：%d项，失败%d项；未启动游戏、未访问玩家存档。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_character_shops() -> void:
	for id: String in ["warrior", "scount", "wizard"]:
		var data: Resource = load("res://character_resource/%s/%s.tres" % [id, id]) as Resource
		_check(data != null, "角色资源加载：" + id)
		if data == null:
			continue
		var shop: Resource = data.get("start_shop") as Resource
		var config: Resource = data.get("start_shop_config") as Resource
		var pool: Array = data.get("shop_keeper_pool")
		_check(shop != null and config != null, "角色有起始商店和等级配置：" + id)
		_check(not pool.is_empty() and not pool.has(null), "商人池有效：" + id)
		if shop != null:
			_check(shop.get("shopkeeper") != null, "默认商人有效：" + id)
		if config != null:
			_check(not config.get("level_data").is_empty(), "商店等级配置可用：" + id)


func _repair_fixture() -> RefCounted:
	var body: String = _function_source(RUN_STATS_SCRIPT, "ensure_shop_runtime")
	body = body.replace("ShopKeeper", "Resource").replace("ShopConfig", "Resource").replace("Shop", "Resource")
	body = body.replace("initial_shop.shopkeeper", "initial_shop.get(\"shopkeeper\")")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar picked_character\nvar shop\nvar shop_config\n" + body)
	return script.new() if script != null else null


func _check_repair() -> void:
	var helper: RefCounted = _repair_fixture()
	if helper == null:
		return
	var wizard: Resource = load("res://character_resource/wizard/wizard.tres") as Resource
	helper.set("picked_character", wizard)
	helper.call("ensure_shop_runtime")
	var shop: Resource = helper.get("shop") as Resource
	var config: Resource = helper.get("shop_config") as Resource
	_check(shop != null and shop.get("shopkeeper") != null and config != null, "旧局空商店完整恢复")
	_check(shop != wizard.get("start_shop") and config != wizard.get("start_shop_config"), "运行时资源独立复制")
	shop.set("level", 3)
	var slots: Array = shop.get("current_slot")
	var first_slot: Resource = slots[0]
	var frozen: Array[bool] = [true, false, true, false]
	shop.set("frozen_slots", frozen)
	shop.set("shopkeeper", null)
	helper.set("shop_config", null)
	helper.call("ensure_shop_runtime")
	_check(helper.get("shop") == shop and shop.get("level") == 3, "补商人不会替换商店或重置等级")
	_check(shop.get("current_slot")[0] == first_slot and shop.get("frozen_slots") == frozen, "现有商品格引用和冻结状态保留")
	var chosen_keeper: Resource = wizard.get("shop_keeper_pool")[1]
	shop.set("shopkeeper", chosen_keeper)
	helper.call("ensure_shop_runtime")
	_check(shop.get("shopkeeper") == chosen_keeper and helper.get("shop_config") != null, "不会覆盖已选择商人，重复调用安全")
	helper.set("picked_character", null)
	helper.call("ensure_shop_runtime")
	_check(helper.get("shop") == shop, "无角色时不破坏已有商店")


func _check_dialogues() -> void:
	var body: String = _function_source(KEEPER_UI_SCRIPT, "_get_shop_keeper")
	for method: String in ["speak_enter", "speak_buy", "speak_sell"]:
		body += _function_source(KEEPER_UI_SCRIPT, method)
	body = body.replace("ShopKeeper", "Resource")
	for field: String in ["enter_rest_period_dialogues", "buy_relic_dialogues", "sell_relic_dialogues"]:
		body = body.replace("keeper." + field, "keeper.get(\"%s\")" % field)
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar shop\nvar spoken: Array = []\nfunc _speak_from_pool(pool: Resource) -> void:\n\tspoken.append(pool)\n" + body)
	if script == null:
		return
	var ui: RefCounted = script.new()
	for method: String in ["speak_enter", "speak_buy", "speak_sell"]:
		ui.call(method)
	_check(ui.get("spoken").is_empty(), "商店为空时三类对白都不访问空商人")
	var wizard: Resource = load("res://character_resource/wizard/wizard.tres") as Resource
	var shop: Resource = wizard.get("start_shop").duplicate(true) as Resource
	shop.set("shopkeeper", null)
	ui.set("shop", shop)
	for method: String in ["speak_enter", "speak_buy", "speak_sell"]:
		ui.call(method)
	_check(ui.get("spoken").is_empty(), "商人为空时三类对白安全跳过")
	shop.set("shopkeeper", wizard.get("shop_keeper_pool")[0])
	for method: String in ["speak_enter", "speak_buy", "speak_sell"]:
		ui.call(method)
	var spoken: Array = ui.get("spoken")
	_check(spoken.size() == 3 and not spoken.has(null), "有商人时三类对白仍使用对应语料池")


func _check_entry_order() -> void:
	var ready: String = _function_source("res://scripts/rest_period/rest_period.gd", "_ready")
	_check(ready.find("ensure_shop_runtime()") < ready.find("bind_run_stats(run_stats)"), "修复数据先于UI绑定")
	_check(ready.find("bind_shop_runtime(") < ready.find("_play_enter_dialogue()"), "商店初始化完成后才播放开场对白")
	var load_body: String = _function_source("res://scripts/autoload/save_manager.gd", "build_run_stats_from_save")
	_check(load_body.find("result.picked_character =") < load_body.find("result.ensure_shop_runtime()"), "续档先恢复角色，再补齐商店")
	_check(not _function_source(RUN_STATS_SCRIPT, "ensure_shop_runtime").contains("RunRng"), "缺失数据修复不额外消耗种子随机数")
