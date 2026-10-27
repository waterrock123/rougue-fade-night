## 只做编辑器脚本/资源/动画配置校验，不实例化游戏实体，不修改玩家存档。
extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_check_all")


func _check_all() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_scripts()
	_check_relic()
	_check_zombie()
	print("肯塔基全家桶编辑器检查：%d项，失败%d项；不包含运行时战斗验证。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_scripts() -> void:
	for path: String in ["scripts/entity/free_for_all_enemy.gd", "scripts/entity/enemy.gd", "scripts/ability/component/ability_get_targets.gd", "scripts/ability/component/ability_get_combat_targets.gd", "scripts/ability/component/ability_lock_ai_target_direction.gd", "relic_effect/use_spawn_actors_effect.gd", "relic_effect/use_reset_ability_cooldowns_effect.gd", "scripts/utils/meowa_api_client.gd", "scripts/utils/meowa_animation_tool.gd", "scripts/utils/import_meowa_sprite_frames.gd"]:
		var script: Script = load("res://" + path) as Script
		_check(script != null and script.reload(true) == OK, "脚本解析：" + path)


func _check_relic() -> void:
	var relic: Resource = load("res://relics/level_5/129_肯塔基全家桶.tres")
	_check(relic != null, "装备资源加载")
	if relic == null:
		return
	_check(relic.get("id") == "129" and int(relic.get("level")) == 5 and relic.get("is_consumable"), "五阶129号消耗品")
	var basic: Array = relic.get("effects")
	var upgraded: Array = relic.get("great_effects")
	_check(basic.size() == 3 and upgraded.size() == 1, "基础三效果与升级状态分工")
	if basic.size() != 3 or upgraded.size() != 1:
		return
	_check(basic[0].get("heal_missing_percent") == 1.0, "恢复全部已损生命")
	_check(basic[1].get("include_basic_attack"), "冷却刷新包含基础攻击")
	_check(basic[2].get("actor_scene") != null and int(basic[2].get("spawn_count")) == 2, "两只僵尸")
	_check(basic[2].get("safe_search_radius_cells") > 0, "地图安全生成")
	var status: Resource = upgraded[0].get("status_data")
	_check(status != null and status.get("duration") < 0 and int(status.get("polarity")) == 1, "战斗内正向增益")
	if status != null:
		var stats: Dictionary = status.get("effects")[0].get("stat_values")
		_check(stats.get("strength") == 5 and stats.get("constitution") == 5, "力量体质各加5")
	var database: Resource = load("res://custom_resource/default_keyword_database.tres")
	var keys: Array[String] = []
	for keyword: Resource in database.get("keywords"):
		keys.append(str(keyword.get("id")))
	var regex: RegEx = RegEx.new()
	regex.compile("\\{([^{}]+)\\}")
	for found: RegExMatch in regex.search_all(str(relic.get("tooltip"))):
		_check(keys.has(found.get_string(1)), "关键词：" + found.get_string(1))


func _check_zombie() -> void:
	var scene: PackedScene = load("res://entity/enemy/zombie.tscn") as PackedScene
	_check(scene != null, "僵尸场景加载")
	var ability: PackedScene = load("res://scenes/ability/zombie_basic_attack.tscn") as PackedScene
	_check(ability != null, "普通攻击场景加载")
	if ability != null:
		var state: SceneState = ability.get_state()
		for node: int in range(state.get_node_count()):
			if state.get_node_name(node) == &"HitFrameTrigger":
				for property: int in range(state.get_node_property_count(node)):
					if state.get_node_property_name(node, property) == &"frame_events":
						_check(state.get_node_property_value(node, property)[0].get("frame") == 4, "命中对齐第5帧")
	var frames: SpriteFrames = load("res://sprite_frames/zombie_sprite_frames.tres") as SpriteFrames
	_check(frames != null, "四套逐帧资源加载")
	if frames == null:
		return
	for name: StringName in [&"idle", &"walk", &"attack", &"die"]:
		_check(frames.has_animation(name) and frames.get_frame_count(name) > 1, "真实多帧动画：" + str(name))
		_check(frames.get_animation_loop(name) == (name in [&"idle", &"walk"]), "循环/非循环：" + str(name))
		var duration: float = 0.0
		for index: int in range(frames.get_frame_count(name)):
			var texture: Texture2D = frames.get_frame_texture(name, index)
			_check(texture != null and texture.get_size() == Vector2(32, 32), "32像素帧：" + str(name))
			duration += frames.get_frame_duration(name, index) / frames.get_animation_speed(name)
		_check(is_equal_approx(duration, 1.0 if name == &"attack" else 2.0), "保持源动画时长：" + str(name))


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("[失败] " + label)
