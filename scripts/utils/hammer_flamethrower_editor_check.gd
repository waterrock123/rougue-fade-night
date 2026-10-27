## 纯编辑器资源接线检查，不运行非tool脚本的技能方法，不启动主场景、不写存档。
## 编辑器的运行时节点是占位对象，所以这里只检查导出数据与场景结构，不伪报运行时测试通过。
extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_wait_for_editor")


func _wait_for_editor() -> void:
	if not Engine.is_editor_hint():
		printerr("此校验只允许编辑器模式运行。")
		quit(1)
		return
	# 命令行脚本比编辑器Autoload注册更早加载，先等编辑器初始化，避免伪报单例不存在。
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_run_checks()


func _run_checks() -> void:
	if not Engine.is_editor_hint():
		printerr("此校验只允许编辑器模式运行。")
		quit(1)
		return
	var hammer: Resource = load("res://relics/level_5/141_异星战锤.tres")
	var gun: Resource = load("res://relics/level_4/136_喷火器.tres")
	_check(hammer != null and gun != null, "装备资源加载")
	if hammer == null or gun == null:
		quit(1)
		return
	_check(hammer.get("id") == "141", "战锤身份")
	_check(str(hammer.get("tooltip")).contains("持续至战斗结束"), "战锤临时提升描述")
	_test_hammer(hammer)
	_test_channel(gun)
	print("异星战锤/喷火器编辑器资源接线检查：%d 项，失败 %d 项。不包含运行时物理与输入测试。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_hammer(hammer: Resource) -> void:
	var effects: Array = hammer.get("effects")
	var upgraded: Array = hammer.get("great_effects")
	_check(effects.size() == 3 and upgraded.size() == 1, "战锤效果数量")
	if effects.size() != 3 or upgraded.size() != 1:
		return
	_check(effects[0].get("add_stats").get("strength") == 5, "战锤基础力量")
	_check(effects[1].get("add_derived_stats").get("poise_damage_multiplier") == 0.5, "战锤削韧倍率")
	var gain: Resource = effects[2]
	var status: Resource = gain.get("status_data")
	_check(gain.get("duration_override") == -1.0 and status.get("stack_mode") == 1, "战斗内叠层状态")
	_check(status.get("effects")[0].get("stat_name") == &"strength", "力量状态属性")
	_check(upgraded[0].get("damage") == 0.0 and upgraded[0].get("source_stat") == &"strength" and upgraded[0].get("stat_multiplier") == 5.0, "力量500%公式配置")
	_check(upgraded[0].get("poise_damage") == 0.0, "升级追加伤害不再削韧")


func _test_channel(gun: Resource) -> void:
	var effects: Array = gun.get("effects")
	var upgraded: Array = gun.get("great_effects")
	_check(effects.size() == 1 and upgraded.size() == 1, "喷火器效果数量")
	if effects.size() != 1 or upgraded.size() != 1:
		return
	var skill: Resource = effects[0].get("skill_data")
	_check(skill.get("id") == &"111" and skill.get("slot_type") == &"equipment", "装备专属技能")
	_check(upgraded[0].get("flat_bonus") == 2.0 and upgraded[0].get("required_damage_types").has(2), "升级火焰伤害加成")
	var ability: Node = skill.get("ability_scene").instantiate()
	var spawn: Node = ability.get_node("SpawnStream")
	var stream: Node = spawn.get("manifest_scene").instantiate()
	_check(spawn.get("set_as_child") and stream.get("max_range") == 120.0 and stream.get("lifetime") == 5.0, "持续领域跟随与范围")
	_check(stream.get("damage") == 10.0 and stream.get("tick_interval") == 0.2 and stream.get("hit_status").get("id") == &"burn", "火焰跳伤与燃烧")
	var channel: Resource = stream.get("caster_status")
	var slow: Resource = channel.get("effects")[0]
	_check(slow.get("stat_name") == &"move_speed" and slow.get("value_per_stack") == -0.5 and slow.get("modifier_type") == 1, "减速配置")
	var blocker: Resource = channel.get("effects")[1]
	_check(blocker.get("block_basic_attack") and blocker.get("ability_ids").has(&"111"), "仅限制基础攻击与再次开启")
	_check(stream.get_node_or_null("Flames") is CPUParticles2D and stream.get_node_or_null("WeaponSprite2D") is Sprite2D, "火焰视觉与武器美术节点")
	stream.free()
	ability.free()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
