## 仅在编辑器中检查配置、资源副本隔离和脚本解析，不启动游戏、不修改玩家存档。
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
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_scripts()
	_check_relic()
	_check_conditions()
	print("混沌发生器编辑器检查：%d项，失败%d项。不包含运行时随机/合成/技能释放测试。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_scripts() -> void:
	var paths: Array[String] = [
		"relic_effect/relic_effect.gd", "custom_resource/relic.gd", "custom_resource/player_bulid.gd",
		"scripts/autoload/event_bus.gd", "scripts/run/run.gd", "scripts/run/run_stats.gd",
		"scripts/relic/relic_gain_runtime_helper.gd", "relic_effect/map_object_generation_multiplier_effect.gd",
		"relic_effect/gain_random_world_condition_effect.gd", "relic_effect/gain_redistribute_primary_stats_effect.gd",
		"relic_effect/gain_reroll_active_skills_effect.gd", "scripts/world_condition/world_condition_controller.gd",
		"event_room/campfire_room.gd", "scripts/skill/passive_battle_end_upgrade_left_relic_effect.gd",
		"scripts/scenes/play_scene.gd", "scripts/utils/skill_overview_panel.gd",
	]
	for path: String in paths:
		var script: Script = load("res://" + path) as Script
		_check(script != null and script.reload(true) == OK, "脚本解析：" + path)


func _check_relic() -> void:
	var relic: Resource = load("res://relics/level_5/137_混沌发生器.tres")
	_check(relic != null, "装备资源加载")
	if relic == null:
		return
	_check(relic.get("id") == "137" and int(relic.get("level")) == 5, "装备编号与等阶")
	var basic: Array = relic.get("effects")
	var upgraded: Array = relic.get("great_effects")
	_check(basic.size() == 2 and upgraded.size() == 2, "地图/天气/属性/技能独立分工")
	if basic.size() != 2 or upgraded.size() != 2:
		return
	_check(basic[0].get("feature_tag") == &"" and float(basic[0].get("generation_bonus")) == 1.0, "全部特殊物体+100%")
	_check(basic[1].get("include_weather") and basic[1].get("include_environment"), "允许触发天气或环境")
	_check(upgraded[0].get("stat_names").size() == 7, "七项一级属性重分配")
	_check(upgraded[1].get("respect_character_ownership"), "遵守技能归属")
	_check(upgraded[1].get("preserve_upgrade_stage"), "保留初始/升级阶段")
	_check(upgraded[1].get("skill_folder") == "res://activate_skill", "读取现有主动技能目录")
	var keys: Dictionary = {}
	for effect: Resource in [basic[1], upgraded[0], upgraded[1]]:
		var key: String = str(effect.get("once_key"))
		_check(not key.is_empty() and not keys.has(key), "独立的一次性进度键：" + key)
		keys[key] = true
	_check_copy_isolation(relic)
	_check_keywords(str(relic.get("tooltip")))


func _check_copy_isolation(template: Resource) -> void:
	var first: Resource = template.duplicate(true)
	var second: Resource = template.duplicate(true)
	# 编辑器的非tool脚本默认字典只读；显式设置副本，检查存储隔离而不执行游戏脚本。
	var counters: Dictionary = first.get("effect_counters").duplicate(true)
	first.set("effect_counters", counters)
	counters["editor_check"] = 1
	_check(not second.get("effect_counters").has("editor_check"), "不同装备实例去重记录互不污染")
	_check(not template.get("effect_counters").has("editor_check"), "不污染资源模板")
	_check(first.get("effects")[1] != second.get("effects")[1], "独立效果资源副本")


func _check_keywords(description: String) -> void:
	var database: Resource = load("res://custom_resource/default_keyword_database.tres")
	var ids: Array[String] = []
	for keyword: Resource in database.get("keywords"):
		ids.append(str(keyword.get("id")))
	var regex: RegEx = RegEx.new()
	regex.compile("\\{([^{}]+)\\}")
	for match_result: RegExMatch in regex.search_all(description):
		_check(ids.has(match_result.get_string(1)), "描述关键词：" + match_result.get_string(1))


func _check_conditions() -> void:
	for path: String in ["res://world_conditions/weather/money_rain.tres", "res://world_conditions/environment/darkness.tres"]:
		var condition: Resource = load(path)
		_check(condition != null, "现有非默认天气/环境资源")
		if condition != null:
			_check(float(condition.get("roll_weight")) > 0.0, "可以被权重抽取")
			_check(int(condition.get("min_duration_rooms")) > 0, "持续房间配置")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("[失败] " + label)
