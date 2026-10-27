## 编辑器检查：只加载资源和重新解析脚本，不启动游戏，也不读写玩家存档。
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
	_check_wolf_milk()
	_check_reincarnation()
	print("狼奶/轮回肠编辑器检查：%d项，失败%d项；不包含运行时效果测试。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_wolf_milk() -> void:
	var relic: Resource = load("res://relics/level_5/121_狼奶.tres")
	if not _check_relic(relic, "121"):
		return
	var effects: Array = relic.get("effects")
	var upgraded: Array = relic.get("great_effects")
	_check(effects.size() == 1 and upgraded.size() == 1, "狼奶基础与升级各一条使用效果")
	if effects.size() != 1 or upgraded.size() != 1:
		return
	_check(effects[0].get("ignore_when_relic_levelup") == true, "升级狼奶不重复执行基础策略")
	for index: int in range(2):
		var status: Resource = (effects[0] if index == 0 else upgraded[0]).get("status_data")
		_check(status != null, "狼奶状态加载")
		if status == null:
			continue
		var policy_effects: Array = status.get("effects")
		_check(float(status.get("duration")) < 0.0 and not bool(status.get("dispellable")), "策略持续整场且不可净化")
		_check(policy_effects.size() == 1, "策略单一职责")
		if policy_effects.size() == 1:
			_check(int(policy_effects[0].get("mode")) == index + 1, "战斗保留/本局永久模式")


func _check_reincarnation() -> void:
	var relic: Resource = load("res://relics/level_5/122_轮回肠.tres")
	if not _check_relic(relic, "122"):
		return
	var effects: Array = relic.get("effects")
	var upgraded: Array = relic.get("great_effects")
	_check(effects.size() == 1 and upgraded.size() == 1, "轮回肠重置与冷却分离")
	if effects.size() != 1 or upgraded.size() != 1:
		return
	_check(effects[0].get_script().resource_path == "res://relic_effect/use_reset_base_stats_effect.gd", "复用基础属性重置效果")
	var status: Resource = upgraded[0].get("status_data")
	_check(status != null, "升级施法状态加载")
	if status == null:
		return
	_check(float(status.get("duration")) == 10.0, "升级持续10秒")
	var cooldown_effects: Array = status.get("effects")
	_check(cooldown_effects.size() == 1, "独立冷却修正效果")
	if cooldown_effects.size() == 1:
		var effect: Resource = cooldown_effects[0]
		_check(is_equal_approx(float(effect.get("cooldown_override")), 0.01), "固定0.01秒冷却")
		_check(bool(effect.get("reset_current_cooldowns")), "施加时清空旧冷却")
		_check(effect.get("excluded_slot_indices").is_empty(), "包括基础攻击和装备技能")


func _check_relic(relic: Resource, expected_id: String) -> bool:
	_check(relic != null, "遗物资源加载：" + expected_id)
	if relic == null:
		return false
	_check(str(relic.get("id")) == expected_id and int(relic.get("level")) == 5, "编号和等阶：" + expected_id)
	_check(bool(relic.get("is_consumable")), "可以作为消耗品使用：" + expected_id)
	return true


func _check_scripts() -> void:
	var paths: Array[String] = [
		"custom_resource/player_bulid.gd", "custom_resource/run_start_up.gd",
		"scripts/autoload/save_manager.gd", "scripts/run/run.gd",
		"scripts/stats/stats_controller.gd", "scripts/stats/temporary_stat_gain_policy.gd",
		"scripts/stats/modifier.gd", "scripts/stats/modifier_node.gd", "scripts/stats/modifier_handler.gd",
		"scripts/status/status_controller.gd", "scripts/status/status_instance.gd",
		"scripts/status/status_add_stat_effect.gd", "scripts/status/status_add_stats_effect.gd",
		"scripts/status/status_ability_cooldown_effect.gd", "scripts/status/status_temporary_stat_gain_policy_effect.gd",
		"scripts/ability/core/ability_controller.gd", "relic_effect/use_reset_base_stats_effect.gd",
		"relic_effect/use_add_stats_effect.gd", "relic_effect/use_add_derived_stats_effect.gd",
		"relic_effect/ability_cast_stacking_stats_effect.gd", "relic_effect/damage_dealt_stacking_stats_effect.gd",
		"relic_effect/consumable_use_stats_effect.gd", "relic_effect/fresh_vegetable_consumable_effect.gd",
		"scripts/skill/passive_damage_chance_primary_stats_effect.gd", "relic_effect/add_status_effect.gd",
		"scripts/skill/passive_add_status_effect.gd", "scripts/skill/passive_full_equipment_armor_effect.gd",
		"scripts/skill/passive_full_equipment_stats_and_armor_effect.gd",
		"scripts/tag_effect/tag_battle_win_persistent_status_effect.gd",
	]
	for path: String in paths:
		var script: Script = load("res://" + path) as Script
		_check(script != null and script.reload(true) == OK, "脚本解析：" + path)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("[失败] " + label)
