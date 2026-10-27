## 编辑器内检查机动手甲绑定与隔离发射事件，不启动战斗场景、不读写玩家存档。
extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_resources()
	_check_launch_lifecycle()
	_check_stack_sources()
	_check_notification_contract()
	print("机动手甲编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_resources() -> void:
	var effect_script: Script = load("res://relic_effect/projectile_launch_add_status_effect.gd") as Script
	_check(effect_script != null and effect_script.reload(true) == OK, "新效果脚本解析")
	var relic: Resource = load("res://relics/level_3/085_机动手甲.tres")
	_check(relic != null, "机动手甲资源加载")
	if relic == null:
		return
	var basic: Array = relic.get("effects")
	var upgraded: Array = relic.get("great_effects")
	_check(basic.size() == 2 and upgraded.size() == 1, "基础/升级效果数量")
	if basic.size() != 2 or upgraded.size() != 1:
		return
	_check(basic[0].get("add_stats") == {"dexterity": 2}, "敏捷+2不变")
	_check(upgraded[0].get("add_derived_stats") == {"crit_chance": 0.05}, "升级暴击率+5%不变")
	_check(basic[1].get_script() == effect_script, "使用发射事件效果而非命中效果")
	var status: Resource = basic[1].get("status_data") as Resource
	_check(status != null and status.get("id") == &"mobile_gauntlet_crit", "独立暴击状态")
	if status == null:
		return
	_check(int(status.get("stack_mode")) == 1 and int(status.get("polarity")) == 1, "正面叠层状态")
	_check(float(status.get("duration")) < 0.0, "不按秒到期，跟随战斗实体生命周期")
	var status_effects: Array = status.get("effects")
	_check(status_effects.size() == 1, "单一暴击修饰效果")
	if status_effects.size() == 1:
		_check(status_effects[0].get("stat_name") == &"crit_chance" and is_equal_approx(float(status_effects[0].get("value_per_stack")), 0.001), "每颗+0.1个百分点")
	var database: Resource = load("res://custom_resource/default_keyword_database.tres")
	var keyword_ids: Array[String] = []
	for keyword: Resource in database.get("keywords"):
		keyword_ids.append(str(keyword.get("id")))
	for key: String in ["dexterity", "projectile", "crit_chance"]:
		_check(keyword_ids.has(key), "描述关键词：" + key)


## 使用生产效果原文，仅替换类型和总线为tool夹具，避免实例化Player/战斗节点。
func _check_launch_lifecycle() -> void:
	var source: String = FileAccess.get_file_as_string("res://relic_effect/projectile_launch_add_status_effect.gd")
	source = source.replace("\r\n", "\n")
	source = source.replace("class_name ProjectileLaunchAddStatusEffect\n", "")
	source = source.replace("extends RelicEffect", "@tool\nextends Resource\nvar bus: Node")
	source = source.replace("EventBus", "bus").replace("StatusData", "Resource")
	source = source.replace("RelicContext", "Resource").replace("AbilityContext", "Resource")
	source = source.replace("var actor: Entity = entry.owner as Entity", "var actor: Variant = entry.owner")
	source = source.replace("context.owner is Entity", "context.owner is Node2D")
	var fixture: GDScript = _compile_fixture(source, "发射效果原文夹具")
	if not fixture.can_instantiate():
		return
	var bus_script: GDScript = _compile_fixture("@tool\nextends Node\nsignal projectile_launched(projectile: Node2D, context: Resource, direction: Vector2)\n", "独立事件总线")
	var actor_script: GDScript = _compile_fixture("@tool\nextends Node2D\nvar is_dead: bool = false\nvar status_controller: Node\n", "独立拥有者")
	var status_script: GDScript = _compile_fixture("@tool\nextends Node\nvar total: int = 0\nfunc add_status(_data: Resource, _source: Node, _key: Variant, stacks: int, _duration: float) -> void:\n\ttotal += stacks\n", "状态接收器")
	var context_script: GDScript = _compile_fixture("@tool\nextends Resource\nvar owner: Node\nvar caster: Node2D\n", "上下文夹具")
	var bus: Node = bus_script.new()
	var actor: Node2D = actor_script.new()
	var receiver: Node = status_script.new()
	actor.set("status_controller", receiver)
	var equipment: Resource = context_script.new()
	equipment.set("owner", actor)
	var cast: Resource = context_script.new()
	cast.set("caster", actor)
	var effect: Resource = fixture.new()
	effect.set("bus", bus)
	effect.set("status_data", load("res://status/mobile_gauntlet_crit.tres"))
	_run_launch_cases(effect, bus, actor, receiver, equipment, cast)
	receiver.free()
	actor.free()
	bus.free()


func _run_launch_cases(effect: Resource, bus: Node, actor: Node2D, receiver: Node, equipment: Resource, cast: Resource) -> void:
	var projectile: Node2D = Node2D.new()
	effect.call("on_activate", equipment, "gear")
	effect.call("on_activate", equipment, "gear")
	bus.emit_signal("projectile_launched", projectile, cast, Vector2.RIGHT)
	_check(receiver.get("total") == 1, "重复激活不重复监听，未命中发射也加层")
	projectile.set_meta(&"extra_projectile", true)
	bus.emit_signal("projectile_launched", projectile, cast, Vector2.RIGHT)
	_check(receiver.get("total") == 2, "额外真实投射物计数")
	bus.emit_signal("projectile_launched", projectile, cast, Vector2.ZERO)
	var stranger: Node2D = Node2D.new()
	cast.set("caster", stranger)
	bus.emit_signal("projectile_launched", projectile, cast, Vector2.RIGHT)
	_check(receiver.get("total") == 2, "零方向/其他实体投射物不计数")
	cast.set("caster", actor)
	actor.set("is_dead", true)
	bus.emit_signal("projectile_launched", projectile, cast, Vector2.RIGHT)
	_check(receiver.get("total") == 2, "死亡后不累积")
	actor.set("is_dead", false)
	effect.call("on_deactivate", equipment, "gear")
	bus.emit_signal("projectile_launched", projectile, cast, Vector2.RIGHT)
	_check(receiver.get("total") == 2, "卸下停止积累且不清已得增益")
	_check(bus.get_signal_connection_list("projectile_launched").is_empty(), "无装备来源时断开总线")
	effect.call("on_activate", equipment, "gear")
	bus.emit_signal("projectile_launched", projectile, cast, Vector2.RIGHT)
	_check(receiver.get("total") == 3, "装备刷新后保留原进度并继续积累")
	effect.call("on_activate", equipment, "second_gear")
	bus.emit_signal("projectile_launched", projectile, cast, Vector2.RIGHT)
	_check(receiver.get("total") == 5, "两件装备各自生效")
	cast.set("caster", stranger)
	stranger.free()
	bus.emit_signal("projectile_launched", projectile, cast, Vector2.RIGHT)
	_check(receiver.get("total") == 5, "已释放施法者安全过滤")
	effect.call("on_deactivate", equipment, "gear")
	effect.call("on_deactivate", equipment, "second_gear")
	projectile.free()


## 使用真实叠层算法检查同id多来源累积，以及新战斗不继承旧实例。
func _check_stack_sources() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/status/status_instance.gd")
	source = source.replace("\r\n", "\n")
	source = source.replace("class_name StatusInstance\n", "").replace("extends RefCounted", "@tool\nextends RefCounted")
	source = source.replace("StatusData", "Resource").replace("StatusController", "Node")
	var fixture: GDScript = _compile_fixture(source, "状态叠层算法夹具")
	if not fixture.can_instantiate():
		return
	var data: Resource = load("res://status/mobile_gauntlet_crit.tres")
	var instance: RefCounted = fixture.new(data, null, null, null, "first", 1)
	instance.call("add_source_stacks", "first", 1)
	instance.call("add_source_stacks", "second", 1)
	_check(instance.get("stacks") == 3, "重复发射与多件装备合并层数")
	var next_battle: RefCounted = fixture.new(data, null, null, null, "first", 1)
	_check(next_battle.get("stacks") == 1, "状态资源不携带运行时层数")
	_check(data.get("duration") == -1.0, "不修改共享状态持续时间")


func _check_notification_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ability/core/ability_manifest.gd")
	_check(source.contains("if launch_notified or direction == Vector2.ZERO:") and source.contains("launch_notified = true"), "总线按每颗投射物去重")
	for path: String in ["projectile_manifest", "animated_projectile_manifest", "homing_firefly_manifest"]:
		var launcher: String = FileAccess.get_file_as_string("res://scripts/ability/manifest/" + path + ".gd")
		_check(launcher.contains("notify_projectile_launched(context,"), "实际发射链路：" + path)


func _compile_fixture(source: String, label: String) -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = source
	_check(script.reload() == OK, label)
	return script


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[失败] " + label)
