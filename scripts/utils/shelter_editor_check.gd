## 只做编辑器资源配置、脚本解析及场景接线检查，不启动游戏、不写玩家存档。
extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_wait_for_editor")


func _wait_for_editor() -> void:
	if not Engine.is_editor_hint():
		printerr("此检查只允许编辑器模式运行。")
		quit(1)
		return
	# 编辑器Autoload注册完成后再加载游戏脚本，避免初始化先后顺序造成伪报错。
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_run_checks()


func _run_checks() -> void:
	var relic: Resource = load("res://relics/level_4/127_战时个人避难所.tres")
	_check(relic != null, "避难所资源加载")
	if relic == null:
		quit(1)
		return
	_check(relic.get("id") == "127" and relic.get("level") == 4, "装备编号和等阶保持不变")
	var effects: Array = relic.get("effects")
	var upgraded: Array = relic.get("great_effects")
	_check(effects.size() == 3 and upgraded.size() == 1, "基础与升级效果分工")
	if effects.size() == 3 and upgraded.size() == 1:
		_check(effects[0].get("add_stats").get("speed") == -4, "速度-4")
		_check(effects[1].get("add_derived_stats").get("damage_reduction_rate") == 0.2, "减伤增加20个百分点")
		_check(effects[2].get("recovery_count") == -1, "死亡全部回收策略")
		_check(upgraded[0].get("slot_count") == 3, "升级解锁3个背包格")
		_check(upgraded[0].get_script().resource_path == "res://relic_effect/add_inventory_slots_effect.gd", "复用临时背包容量效果")
	_check(str(relic.get("tooltip")).contains("背包格子"), "修正装备描述")
	_check_description_keywords(str(relic.get("tooltip")))
	_check_flow_scripts()
	print("避难所编辑器配置检查：%d项，失败%d项。不包含运行时死亡、仓库写入及UI交互测试。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_description_keywords(description: String) -> void:
	var database: Resource = load("res://custom_resource/default_keyword_database.tres")
	var ids: Array[String] = []
	for keyword: Resource in database.get("keywords"):
		ids.append(str(keyword.get("id")))
	var regex: RegEx = RegEx.new()
	regex.compile("\\{([^{}]+)\\}")
	for result: RegExMatch in regex.search_all(description):
		_check(ids.has(result.get_string(1)), "描述关键词存在：" + result.get_string(1))


func _check_flow_scripts() -> void:
	for path: String in ["res://scripts/run/run.gd", "res://custom_resource/player_bulid.gd", "res://scripts/ui/death_screen.gd"]:
		var script: Script = load(path) as Script
		# 编辑器禁用非tool脚本实例化，can_instantiate不能用作解析成功的依据。
		_check(script != null and script.reload(true) == OK, "脚本重新解析：" + path)
	var scene: PackedScene = load("res://scenes/ui/victory_relic_selection_panel.tscn") as PackedScene
	_check(scene != null, "共用装备保留界面加载")
	if scene == null:
		return
	# 不加入场景树，不运行非tool UI的_ready，只检查原生节点与唯一名称接线。
	var panel: Node = scene.instantiate()
	_check(panel.get_node_or_null("%TitleLabel") is Label, "死亡/胜利结算标题接线")
	var list: ItemList = panel.get_node_or_null("%RelicList") as ItemList
	_check(list != null and list.select_mode == ItemList.SELECT_MULTI, "原多选装备交互保持不变")
	panel.free()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("[失败] " + label)
