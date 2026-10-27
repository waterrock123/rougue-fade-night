## 编辑器校验装备/场景/脚本，以及隔离调用减伤结算函数的纯数值测试；不启动游戏、不读写玩家存档。
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
	_check_scripts()
	_check_resources()
	_check_incoming_math()
	_check_bypass_sources()
	_check_timer_reconfigure()
	print("超级火花手镯编辑器检查：%d项，失败%d项；不包含运行时巡航/命中与GPU视觉测试。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_scripts() -> void:
	for path: String in ["relic_effect/periodic_orbiting_manifest_effect.gd", "scripts/relic/periodic_orbiting_manifest_runner.gd", "scripts/ability/manifest/orbiting_projectile_manifest.gd", "relic_effect/outgoing_defense_bypass_effect.gd", "scripts/stats/stats_controller.gd", "scripts/stats/damage_data.gd"]:
		var script: Script = load("res://" + path) as Script
		_check(script != null and script.reload(true) == OK, "脚本解析：" + path)


func _check_resources() -> void:
	var relic: Resource = load("res://relics/level_6/118_超级火花手镯.tres")
	_check(relic != null, "装备加载")
	if relic == null:
		return
	_check(relic.get("id") == "118" and int(relic.get("level")) == 6, "编号与等阶")
	var basic: Array = relic.get("effects")
	var upgraded: Array = relic.get("great_effects")
	_check(basic.size() == 1 and upgraded.size() == 1, "周期生成/无视护甲分开")
	if basic.size() != 1 or upgraded.size() != 1:
		return
	_check(basic[0].get("interval") == 30.0 and basic[0].get("manifest_lifetime") == 5.0, "30秒周期/5秒寿命")
	_check(basic[0].get("damage") == 150.0, "150基础伤害")
	_check(upgraded[0].get("ignore_static_damage_reduction") and not upgraded[0].get("ignore_damage_reduction_rate"), "只跳过固定减伤")
	var scene: PackedScene = basic[0].get("manifest_scene") as PackedScene
	_check(scene != null, "火花场景")
	if scene != null:
		var state: SceneState = scene.get_state()
		var properties: Dictionary = {}
		for index: int in range(state.get_node_property_count(0)):
			properties[str(state.get_node_property_name(0, index))] = state.get_node_property_value(0, index)
		_check(properties.get("orbit_radius") == 90.0 and properties.get("orbit_speed") == 12.0, "高速90半径巡航")
		_check(properties.get("hit_interval") == 0.4 and not properties.get("can_hit_map_objects"), "命中节流/不伤地图物件")
		_check(not properties.get("enable_smart_dash"), "只巡航不自动突刺")
	var texture: Texture2D = load("res://assets/shockwavespritesheets/spark.png") as Texture2D
	_check(texture != null and texture.get_width() >= 96 and texture.get_height() >= 32, "现有火花素材与裁切有效")
	_check(load("res://shaders/energy_sprite_tint.gdshader") != null, "火花着色Shader资源")
	var database: Resource = load("res://custom_resource/default_keyword_database.tres")
	var armor_exists: bool = false
	for keyword: Resource in database.get("keywords"):
		armor_exists = armor_exists or keyword.get("id") == &"armor"
	_check(armor_exists, "护甲关键词")


## 从生产脚本抽取同一函数正文，构建只含固定输入的tool夹具，避免运行StatsController节点生命周期。
func _check_incoming_math() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stats/stats_controller.gd")
	var start: int = source.find("func process_incoming_damage(")
	var finish: int = source.find("\nfunc ", start + 1)
	_check(start >= 0 and finish > start, "找到实际承伤结算函数")
	if start < 0 or finish <= start:
		return
	var body: String = source.substr(start, finish - start).replace("damage_data: DamageData", "damage_data: Resource").replace("-> DamageData", "-> Resource")
	var fixture: GDScript = GDScript.new()
	fixture.source_code = "@tool\nextends RefCounted\nfunc get_stat(key: String) -> float:\n\treturn 10.0 if key == 'static_damage_reduction' else 0.5\nfunc _get_incoming_damage_taken_multiplier(_data: Resource) -> float:\n\treturn 1.3\n" + body
	_check(fixture.reload() == OK, "承伤数值夹具编译")
	if not fixture.can_instantiate():
		return
	var instance: RefCounted = fixture.new()
	var data_fixture: GDScript = _make_damage_fixture()
	for row: Array in [[false, false, 117.0], [true, false, 123.5], [true, true, 247.0]]:
		var damage: Resource = data_fixture.new()
		damage.set("final_damage", 190.0)
		damage.set("ignore_static_damage_reduction", row[0])
		damage.set("ignore_damage_reduction_rate", row[1])
		var result: Resource = instance.call("process_incoming_damage", damage) as Resource
		_check(result != null and is_equal_approx(float(result.get("final_damage")), row[2]), "固定/百分比减伤与易伤组合")


func _make_damage_fixture() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "@tool\nextends Resource\nvar final_damage: float = 190.0\nvar ignore_static_damage_reduction: bool = false\nvar ignore_damage_reduction_rate: bool = false\nvar source: RefCounted\nvar target: RefCounted\nvar tags: Array[String] = []\nvar damage_types: Array[int] = []\nvar source_ability_id: StringName = &''\nvar source_ability_slot_index: int = -1\n"
	_check(script.reload() == OK, "独立伤害数据夹具")
	return script


func _check_bypass_sources() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/stats/stats_controller.gd")
	var methods: String = ""
	for name: String in ["set_outgoing_defense_bypass_modifier", "clear_outgoing_defense_bypass_modifier", "_apply_outgoing_defense_bypass", "_outgoing_damage_modifier_matches"]:
		var start: int = source.find("func " + name + "(")
		var finish: int = source.find("\nfunc ", start + 1)
		_check(start >= 0 and finish > start, "穿透函数：" + name)
		if start < 0 or finish <= start:
			return
		methods += source.substr(start, finish - start).replace("damage_data: DamageData", "damage_data: Resource") + "\n"
	var fixture: GDScript = GDScript.new()
	fixture.source_code = "@tool\nextends RefCounted\nvar outgoing_defense_bypass_modifiers: Dictionary = {}\n" + methods
	_check(fixture.reload() == OK, "穿透来源/筛选夹具")
	if not fixture.can_instantiate():
		return
	var instance: RefCounted = fixture.new()
	var data_fixture: GDScript = _make_damage_fixture()
	instance.call("set_outgoing_defense_bypass_modifier", "bracelet", {"ignore_static_damage_reduction": true})
	var damage: Resource = data_fixture.new()
	damage.set("source", RefCounted.new())
	damage.set("target", RefCounted.new())
	instance.call("_apply_outgoing_defense_bypass", damage)
	_check(damage.get("ignore_static_damage_reduction") and not damage.get("ignore_damage_reduction_rate"), "出伤标记只跳过护甲")
	damage.set("ignore_static_damage_reduction", false)
	damage.set("target", damage.get("source"))
	instance.call("_apply_outgoing_defense_bypass", damage)
	_check(not damage.get("ignore_static_damage_reduction"), "不改变自伤成本")
	instance.call("clear_outgoing_defense_bypass_modifier", "bracelet")
	damage.set("target", RefCounted.new())
	instance.call("_apply_outgoing_defense_bypass", damage)
	_check(not damage.get("ignore_static_damage_reduction"), "卸下清理来源")
	instance.call("set_outgoing_defense_bypass_modifier", "filtered", {"ignore_static_damage_reduction": true, "required_tags": ["projectile"]})
	instance.call("_apply_outgoing_defense_bypass", damage)
	_check(not damage.get("ignore_static_damage_reduction"), "标签不匹配不穿透")
	var tags: Array[String] = ["projectile"]
	damage.set("tags", tags)
	instance.call("_apply_outgoing_defense_bypass", damage)
	_check(damage.get("ignore_static_damage_reduction"), "标签匹配穿透")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[失败] " + label)


## 只调用实际configure函数正文，检查装备刷新保留倒计时；不创建游戏运行器节点。
func _check_timer_reconfigure() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/relic/periodic_orbiting_manifest_runner.gd")
	var start: int = source.find("func configure(")
	var finish: int = source.find("\nfunc ", start + 1)
	_check(start >= 0 and finish > start, "找到计时初始化函数")
	if start < 0 or finish <= start:
		return
	var body: String = source.substr(start, finish - start).replace("effect: PeriodicOrbitingManifestEffect", "effect: Resource").replace("owner_entity: Entity", "owner_entity: RefCounted")
	var fixture: GDScript = GDScript.new()
	fixture.source_code = "@tool\nextends RefCounted\nvar settings: Resource\nvar actor: RefCounted\nvar equipped: bool = false\nvar remaining: float = -1.0\n" + body
	_check(fixture.reload() == OK, "计时刷新夹具")
	if not fixture.can_instantiate():
		return
	var data: GDScript = GDScript.new()
	data.source_code = "@tool\nextends Resource\nvar interval: float = 30.0\n"
	_check(data.reload() == OK, "周期配置夹具")
	var instance: RefCounted = fixture.new()
	var effect: Resource = data.new()
	var actor: RefCounted = RefCounted.new()
	instance.call("configure", effect, actor)
	_check(instance.get("remaining") == 30.0, "首次等待完整30秒")
	instance.set("remaining", 7.25)
	instance.call("configure", effect, actor)
	_check(instance.get("remaining") == 7.25, "普通装备刷新不重置倒计时")
