## 编辑器隔离检查：验证树人的技能替换与状态配置，不启动游戏。
extends "res://scripts/utils/guiren_basic_attack_editor_check.gd"


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_tree_skill()
	_check_status_refresh()
	_check_apply_to_self()
	_check(checks >= 20, "所有检查分支完整执行")
	print("树皮护甲编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_tree_skill() -> void:
	var scene: PackedScene = load("res://entity/enemy/treepeople.tscn") as PackedScene
	_check(scene != null, "树人场景加载")
	if scene == null:
		return
	var tree: Node = scene.instantiate()
	var controller: Node = tree.get_node("AbilityController")
	_check(controller.has_node("RootEntangle"), "保留根须缠绕技能")
	_check(not controller.has_node("ThornArmor"), "树人不再携带荆棘反伤技能")
	var ability: Node = controller.get_node_or_null("TreeBarkArmor")
	_check(ability != null and controller.get_child_count() == 2, "树皮护甲替换旧技能，技能数量不变")
	if ability != null:
		_check(ability.get("cooldown") == 20.0 and ability.get("energy_cost") == 0.0, "沿用20秒冷却，无能量消耗")
		_check(ability.get_node("Animation").get("animation_name") == "attack", "继续使用已有施法动作")
		_check(ability.get_node("CastLock").get("lock_duration") == 0.35, "保留短暂施法定身")
		_check(ability.get_node("ApplyArmor").get("status_data").get("id") == &"tree_bark_armor", "技能施加新护甲状态")
	tree.free()


func _check_status_refresh() -> void:
	var data: Resource = load("res://status/tree_bark_armor.tres") as Resource
	_check(data != null, "护甲状态加载")
	if data == null:
		return
	_check(data.get("duration") == 8.0 and data.get("polarity") == 1, "8秒正向状态")
	_check(data.get("max_stacks") == 1 and data.get("stack_mode") == 0, "状态最多一层，重复只刷新")
	var effects: Array = data.get("effects")
	_check(effects.size() == 1, "仅包含一个属性加成，不附带反伤")
	if effects.size() == 1:
		var effect: Resource = effects[0]
		_check(effect.get_script().resource_path == "res://scripts/status/status_add_stat_effect.gd", "复用通用属性状态效果")
		_check(effect.get("stat_name") == &"static_damage_reduction" and effect.get("value_per_stack") == 4.0, "仅增加4点护甲，不是百分比减伤")
	var target: Node = Node.new()
	var instance: RefCounted = (load("res://scripts/status/status_instance.gd") as GDScript).new(data, null, target)
	instance.set("remaining_duration", 1.0)
	instance.call("set_source_stacks", &"tree_bark_armor", 5)
	instance.call("refresh_duration")
	_check(instance.get("stacks") == 1 and instance.get("remaining_duration") == 8.0, "实际状态实例刷新至8秒且不超出一层")
	target.free()


func _check_apply_to_self() -> void:
	var body: String = _function_source("res://scripts/ability/component/ability_apply_status_to_caster.gd", "_activate").strip_edges() + "\n"
	body = body.replace("context: AbilityContext", "context").replace(" as StatusController", " as Node")
	body = body.replace("var status_controller :=", "var status_controller: Node =").replace("var source_key :=", "var source_key: Variant =")
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar status_data\nvar stacks = 1\nvar duration_override = INF\n" + body)
	var recorder_script: GDScript = _fixture("@tool\nextends Node\nvar applied = []\nfunc add_status(data, source, key, stacks, duration):\n\tapplied.append([data, source, key, stacks, duration])\n")
	var actor_script: GDScript = _fixture("@tool\nextends Node\nvar controller\nfunc get_status_controller():\n\treturn controller\n")
	if script == null or recorder_script == null or actor_script == null:
		return
	var helper: RefCounted = script.new()
	var actor: Node = actor_script.new()
	var recorder: Node = recorder_script.new()
	actor.set("controller", recorder)
	helper.set("status_data", load("res://status/tree_bark_armor.tres"))
	helper.call("_activate", {"caster": actor, "ability": {"id": &"bark"}})
	var calls: Array = recorder.get("applied")
	_check(calls.size() == 1, "技能组件实际施加一次护甲状态")
	if calls.size() == 1:
		_check(calls[0][1] == actor and calls[0][3] == 1 and is_inf(calls[0][4]), "施加给树人自己，一层且沿用状态的8秒时长")
	actor.free()
	recorder.free()
