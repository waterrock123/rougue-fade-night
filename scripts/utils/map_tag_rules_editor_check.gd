## 仅编辑器隔离回归：检查真实资源和函数，不启动关卡，不访问真实玩家存档。
extends "res://scripts/utils/guiren_basic_attack_editor_check.gd"


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_scripts()
	_check_rules()
	_check_objects()
	_check_status_roundtrip()
	_check_restore()
	_check_periodic_state()
	_check_stored_negative_control()
	_check_art_and_keywords()
	_check_checkpoint()
	_check_save_roundtrip()
	_check_bounty_bonus()
	print("地图标签与状态存储箱编辑器检查：%d项，失败%d项；未启动游戏、未访问玩家存档。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_scripts() -> void:
	for path: String in ["custom_resource/map_tag_runtime_modifier.gd", "scripts/battlemap/map_tag_battle_rules.gd", "scripts/battlemap/map_tag_battle_controller.gd", "scripts/battlemap/status_storage_box.gd", "scripts/status/status_storage_codec.gd", "scripts/status/status_controller.gd", "scripts/battlemap/feast_table.gd", "scripts/battlemap/map_relic_pickup.gd", "scripts/scenes/play_scene.gd", "scripts/autoload/save_manager.gd", "scenes/ui/map_tag_config_panel.gd", "scripts/entity/enemy_spawner.gd"]:
		var script: Script = load("res://" + path) as Script
		_check(script != null and script.reload(true) == OK, "解析：" + path)


func _stats_with_tags(names: Array[String]) -> Resource:
	var stats: Resource = (load("res://scripts/run/run_stats.gd") as GDScript).new() as Resource
	var database: Resource = load("res://custom_resource/default_map_tag_influence_database.tres") as Resource
	for title: String in names:
		for influence: Resource in database.influences:
			if influence != null and influence.tag != null and influence.tag.tag_name == title:
				stats.enabled_map_tag_keys.append(influence.tag.resource_path)
	return stats


func _check_rules() -> void:
	var stats: Resource = _stats_with_tags(["疗愈", "疗愈", "凶器", "历战", "历战", "守御", "灵动敏锐", "饰品", "智慧", "智慧"])
	var rules: GDScript = load("res://scripts/battlemap/map_tag_battle_rules.gd") as GDScript
	var database: Resource = _live_database()
	var values: Dictionary = rules.call("build_values", stats, database)
	for key: String in {"heart_heal_bonus": 2.0, "extra_bounty_chance": 0.03, "bounty_gold_bonus": 1.0, "destroy_armor_chance": 0.1, "road_speed_bonus": 0.05, "cargo_extra_chance": 0.05, "star_max_energy": 2.0}:
		var expected: Dictionary = {"heart_heal_bonus": 2.0, "extra_bounty_chance": 0.03, "bounty_gold_bonus": 1.0, "destroy_armor_chance": 0.1, "road_speed_bonus": 0.05, "cargo_extra_chance": 0.05, "star_max_energy": 2.0}
		_check(is_equal_approx(float(values.get(key, -1.0)), expected[key]), "标签数值/不叠加：" + key)
	_check(rules.call("build_values", _stats_with_tags([])).is_empty(), "未启用标签不提供效果")
	var panel: Node = (load("res://scenes/ui/map_tag_config_panel.gd") as GDScript).new() as Node
	panel.run_stats = stats
	panel.influence_database = database
	var lines: Array[String] = panel.call("_get_aggregate_summary_lines", stats.get_enabled_map_tag_keys(), {})
	_check(lines.size() == 7, "汇总合并同类，历战仅一条")
	_check("\n".join(lines).contains("200%"), "双疗愈显示200%而非翻倍到400%")
	panel.free()


func _check_objects() -> void:
	var scene_root: Node = (load("res://scenes/battlemap/feast_table.tscn") as PackedScene).instantiate()
	var table: Node = _fixture("@tool\nextends \"res://scripts/battlemap/feast_table.gd\"\nfunc _roll_seeded_float_range(from: float, to: float) -> float:\n\treturn lerpf(from, to, 0.25)\n").new() as Node
	table.reward_count = scene_root.get("reward_count")
	scene_root.free()
	var stats: Resource = _stats_with_tags([])
	stats.shop = (load("res://scripts/rest_period/shop/shop.gd") as GDScript).new()
	stats.shop.level = 2
	table.fallback_relic_pool = _live_resource(table.fallback_relic_pool)
	var candidates: Array = table.call("_get_candidate_relics", stats)
	_check(not candidates.is_empty(), "佳肴池存在不高于商店等级的装备")
	for relic: Resource in candidates:
		_check(relic.level <= 2 and table.call("_relic_has_tag", relic, table.reward_tag), "佳肴池过滤等阶与标签：" + relic.relic_name)
	_check(table.reward_count == 2, "佳肴桌配置两件奖励")
	table.bind_run_stats(stats)
	_check(table.get("prepicked_reward_relics").size() == 2, "实际预抽两件佳肴，击碎时无需再扫描池子")
	table.free()
	var box: Node = (load("res://scenes/battlemap/status_storage_box.tscn") as PackedScene).instantiate()
	_check(box is Area2D and box.has_node("StateLabel") and box.has_node("VisualRoot/Sprite2D"), "状态箱场景节点")
	_check(box.get("collision_mask") == 2, "状态箱监测玩家实际物理层")
	box.free()
	var spawner: Node = (load("res://scripts/battlemap/object_spawner_from_tile_map.gd") as GDScript).new() as Node
	spawner.random_spawn_profile = _live_resource(load("res://custom_resource/default_map_object_spawn_profile.tres"))
	spawner.run_stats = _stats_with_tags(["佳肴", "佳肴", "存量", "存量"])
	spawner.map_tag_influence_database = _live_database()
	spawner.object_database = _live_resource(load("res://custom_resource/default_map_object_database.tres"))
	spawner.object_database.entries = spawner.object_database.entries.duplicate()
	for index: int in range(spawner.object_database.entries.size()):
		spawner.object_database.entries[index] = _live_resource(spawner.object_database.entries[index])
	var profile: Resource = spawner.random_spawn_profile
	profile.rules = profile.rules.duplicate()
	for index: int in range(profile.rules.size()):
		profile.rules[index] = _live_resource(profile.rules[index])
	spawner.call("_apply_enabled_map_tag_object_modifiers", profile)
	for rule: Resource in profile.rules:
		if rule.object_id == &"feast_table":
			_check(is_equal_approx(rule.chance, 0.04), "两份佳肴增加4%概率")
		if rule.object_id == &"status_storage_box":
			_check(rule.chance == 1.0 and rule.min_count == 1 and rule.max_count == 1 and not rule.allow_generation_scaling, "状态箱固定一个，不放大数量")
	spawner.free()


func _sample_status() -> Resource:
	var data: Resource = (load("res://scripts/status/status_data.gd") as GDScript).new() as Resource
	data.id = &"storage_dynamic_test"
	data.status_name = "存储测试"
	data.duration = 20.0
	data.max_stacks = 20
	data.stack_mode = 1
	data.polarity = 1
	var effect: Resource = (load("res://scripts/status/status_add_stats_effect.gd") as GDScript).new() as Resource
	effect.stat_values = {&"strength": 3.0, &"max_energy": 2.0}
	data.effects.append(effect)
	var cooldown: Resource = (load("res://scripts/status/status_ability_cooldown_effect.gd") as GDScript).new() as Resource
	cooldown.target_slot_indices.assign([0, 2])
	cooldown.target_ability_ids.assign([&"105"])
	data.effects.append(cooldown)
	return data


func _check_status_roundtrip() -> void:
	var data: Resource = _sample_status()
	var instance: RefCounted = (load("res://scripts/status/status_instance.gd") as GDScript).new(data, null, null, null, null, 3, 7.25) as RefCounted
	var codec: GDScript = load("res://scripts/status/status_storage_codec.gd") as GDScript
	var snapshot: Dictionary = codec.call("capture", instance)
	var from_json: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
	var restored: Resource = codec.call("decode_resource", from_json.data) as Resource
	_check(restored != null and restored.id == data.id and restored != data, "动态状态经JSON完整恢复，资源独立")
	_check(restored.effects.size() == 2 and restored.effects[0].get_script().resource_path.ends_with("status_add_stats_effect.gd"), "内嵌效果恢复为原有类型")
	var cooldown: Resource = restored.effects[1] as Resource
	_check(cooldown.target_slot_indices == [0, 2] and cooldown.target_ability_ids == [&"105"], "导出类型数组正确恢复")
	_check(int(from_json.stacks) == 3 and float(from_json.duration) == 7.25, "层数和剩余秒数准确保存")
	instance.remaining_duration = -1.0
	_check(codec.call("capture", instance).is_empty(), "无倒计时的战斗状态不储存")
	instance.remaining_duration = 0.0
	_check(codec.call("capture", instance).is_empty(), "到期状态不储存")
	_check(codec.call("decode_resource", {"script": "res://scripts/run/run.gd"}) == null, "拒绝把其他脚本当状态恢复")


func _check_restore() -> void:
	var target: Node = (load("res://scripts/entity/entity.gd") as GDScript).new() as Node
	var stats: Node = _fixture("@tool\nextends \"res://scripts/stats/stats_controller.gd\"\nfunc recompute_stats() -> void:\n\tpass\n").new() as Node
	stats.stats_data = (load("res://custom_resource/stats_data.gd") as GDScript).new()
	stats.recompute_stats()
	var controller: Node = (load("res://scripts/status/status_controller.gd") as GDScript).new() as Node
	controller.target = target
	controller.stats_controller = stats
	var data: Resource = _sample_status()
	# 不需要冷却控制器，保留属性效果即可。
	data.effects.resize(1)
	var instance: RefCounted = controller.call("restore_stored_status", data, 3, 7.25) as RefCounted
	_check(instance != null and instance.stacks == 3 and instance.remaining_duration == 7.25, "实际恢复函数应用层数和剩余时间")
	_check(instance.get_attribute_gain_stacks() == 0, "恢复不重新进入狼奶属性转永久奖励")
	_check(not instance.restoring_from_storage, "恢复标记仅在应用期间存在")
	var snapshot: Dictionary = (load("res://scripts/status/status_storage_codec.gd") as GDScript).call("capture", instance)
	_check(not snapshot.is_empty(), "实际恢复的状态可以再次存入")
	controller.clear_all_statuses()
	_check(stats.effect_modifiers.is_empty(), "状态移入箱子后属性修饰完全移除")
	controller.free()
	stats.free()
	target.free()


func _check_checkpoint() -> void:
	var checkpoint: RefCounted = (load("res://scripts/run/event_entry_checkpoint.gd") as GDScript).new() as RefCounted
	var initial: Dictionary = {"current_room": {"row": 1, "column": 2}, "run_stats": {"current_floor_index": 0, "stored_map_statuses": [{"stacks": 2, "duration": 7.25}]}}
	checkpoint.capture(initial)
	initial.run_stats.stored_map_statuses.clear()
	var result: Dictionary = checkpoint.build_save_data({"row": 1, "column": 2}, 0, "map.tscn")
	_check(result.run_stats.stored_map_statuses.size() == 1, "未胜利退出后箱子取回也回退，避免跨战斗复制")
	var source: String = FileAccess.get_file_as_string("res://scripts/autoload/save_manager.gd")
	_check(source.contains('"stored_map_statuses": run_stats.stored_map_statuses.duplicate(true)'), "状态仓进入正式存档序列化")
	_check(source.contains('result.stored_map_statuses.append(entry.duplicate(true))'), "读档深拷贝恢复状态仓")


## 编辑器 .tres 默认是只读占位实例；只在内存复制配置，不把生产脚本改成 @tool。
func _live_resource(source: Resource) -> Resource:
	var script: GDScript = source.get_script() as GDScript
	var result: Resource = script.new() as Resource
	for property: Dictionary in script.get_script_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			result.set(property.name, source.get(property.name))
	return result


func _live_database() -> Resource:
	var original: Resource = load("res://custom_resource/default_map_tag_influence_database.tres")
	var result: Resource = _live_resource(original)
	result.influences = result.influences.duplicate()
	for index: int in range(result.influences.size()):
		var influence: Resource = _live_resource(result.influences[index])
		for field: String in ["runtime_modifiers", "object_spawn_modifiers", "terrain_spawn_modifiers"]:
			var entries: Array = influence.get(field).duplicate()
			for item: int in range(entries.size()):
				entries[item] = _live_resource(entries[item])
			influence.set(field, entries)
		result.influences[index] = influence
	return result


func _check_periodic_state() -> void:
	var data: Resource = (load("res://scripts/status/status_data.gd") as GDScript).new() as Resource
	data.id = &"stored_periodic"
	data.duration = 10.0
	var effect: Resource = (load("res://scripts/status/status_periodic_heal_effect.gd") as GDScript).new() as Resource
	data.effects.append(effect)
	var original: RefCounted = (load("res://scripts/status/status_instance.gd") as GDScript).new(data, null, null, null, null, 1, 6.4) as RefCounted
	effect.tick_timers[original.get_effect_key()] = 0.7
	var codec: GDScript = load("res://scripts/status/status_storage_codec.gd") as GDScript
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(codec.call("capture", original)))
	var restored_data: Resource = codec.call("decode_resource", snapshot.data) as Resource
	var controller: Node = (load("res://scripts/status/status_controller.gd") as GDScript).new() as Node
	var restored: RefCounted = controller.call("restore_stored_status", restored_data, 1, snapshot.duration, snapshot.effect_states) as RefCounted
	_check(restored != null and is_equal_approx(float(restored.remaining_duration), 6.4), "周期状态总剩余时间暂停")
	_check(is_equal_approx(float(restored_data.effects[0].tick_timers.get(restored.get_effect_key(), 0.0)), 0.7), "距下一次跳疗的进度也暂停，不可反复存取重置")
	controller.clear_all_statuses()
	controller.free()


func _check_art_and_keywords() -> void:
	for name: String in ["feast_table", "status_storage_box"]:
		var scene: Node = (load("res://scenes/battlemap/%s.tscn" % name) as PackedScene).instantiate()
		var sprite: Sprite2D = scene.get_node("VisualRoot/Sprite2D") as Sprite2D
		_check(sprite.texture != null and sprite.texture.get_size() == Vector2(32, 32), "已绑定32像素素材：" + name)
		_check(scene.get("texture_filter") == CanvasItem.TEXTURE_FILTER_NEAREST, "像素最近邻过滤：" + name)
		var image: Image = sprite.texture.get_image()
		_check(image != null and image.detect_alpha() != Image.ALPHA_NONE, "素材带透明背景：" + name)
		scene.free()
	var database: Resource = load("res://custom_resource/default_keyword_database.tres")
	for key: String in ["feast_table", "status_storage_box", "temporary_heart", "temporary_star", "bounty_elite"]:
		var count: int = 0
		for keyword: Resource in database.keywords:
			if str(keyword.id) == key:
				count += 1
		_check(count == 1, "关键词存在且唯一：" + key)


func _check_stored_negative_control() -> void:
	var stats: Node = _fixture("@tool\nextends \"res://scripts/stats/stats_controller.gd\"\nfunc recompute_stats() -> void:\n\tpass\n").new() as Node
	stats.final_stats = {&"constitution": 100.0}
	var controller: Node = (load("res://scripts/status/status_controller.gd") as GDScript).new() as Node
	controller.stats_controller = stats
	controller.add_negative_status_blocker("wool", 2)
	var data: Resource = (load("res://scripts/status/status_data.gd") as GDScript).new() as Resource
	data.id = &"stored_freeze_test"
	data.duration = 8.0
	data.polarity = 2
	var effect: Resource = (load("res://scripts/status/status_control_effect.gd") as GDScript).new() as Resource
	effect.lock_actions = false
	data.effects.append(effect)
	var instance: RefCounted = controller.call("restore_stored_status", data, 1, 2.0) as RefCounted
	_check(instance != null and instance.remaining_duration == 2.0, "取回冻结不重复按体质缩短剩余时间")
	_check(controller.negative_status_blockers.get("wool", 0) == 2, "取回负面状态不消耗羊毛拦截次数")
	_check(instance.status_data.polarity == 2, "负面状态分类保留")
	controller.clear_all_statuses()
	controller.free()
	stats.free()


func _check_save_roundtrip() -> void:
	# 仅调用纯序列化入口，绝不调用 save_run/load_save_data 或写盘函数。
	var manager: Node = (load("res://scripts/autoload/save_manager.gd") as GDScript).new() as Node
	var stats: Resource = _stats_with_tags([])
	stats.stored_map_statuses.append({"data": {}, "stacks": 3, "duration": 7.25})
	var first: StringName = stats.call("allocate_map_status_id", &"map_guard")
	var serialized: Dictionary = manager.call("_serialize_run_stats", stats)
	var json_copy: Dictionary = JSON.parse_string(JSON.stringify({"run_stats": serialized}))
	var restored: Resource = manager.call("build_run_stats_from_save", json_copy) as Resource
	_check(restored != null and restored.stored_map_statuses.size() == 1, "真实存档序列化/反序列化保留状态仓")
	_check(float(restored.stored_map_statuses[0].duration) == 7.25 and int(restored.stored_map_statuses[0].stacks) == 3, "经正式存档JSON往返保留层数和剩余秒数")
	_check(restored.call("allocate_map_status_id", &"map_guard") != first, "重启读档后的新护甲不会与存储旧层同名")
	serialized.stored_map_statuses.clear()
	_check(stats.stored_map_statuses.size() == 1 and restored.stored_map_statuses.size() == 1, "存档快照与读档状态仓不共享数组")
	manager.free()


func _check_bounty_bonus() -> void:
	var rules: Node = (load("res://scripts/battlemap/map_tag_battle_controller.gd") as GDScript).new() as Node
	rules.values = {"bounty_gold_bonus": 1.0}
	var enemy: Node = (load("res://scripts/entity/enemy.gd") as GDScript).new() as Node
	enemy.bounty_gold = 8
	rules.call("apply_bounty_bonus", enemy)
	_check(enemy.bounty_gold == 9, "历战给悬赏怪增加1金币，不区分装备/事件来源")
	rules.call("apply_bounty_bonus", enemy)
	_check(enemy.bounty_gold == 9, "同一只悬赏怪重复登记不能重复增加赏金")
	enemy.free()
	rules.free()
