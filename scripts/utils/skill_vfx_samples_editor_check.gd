## 仅编辑器资源与隔离函数检查；不启动战斗、不读写存档、不调用API。
extends "res://scripts/utils/guiren_element_synergy_editor_check.gd"

const SAMPLE_DIR: String = "res://assets/特效/skill_vfx_samples_20261018/"
const VISUAL_SCRIPT: String = "res://scripts/ability/manifest/radial_skill_visual.gd"


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_check_frames()
	_check_sigil()
	_check_scene_bindings()
	_check_visual_timing()
	_check_animation_playback()
	print("技能特效样例编辑器检查：%d项，失败%d项；未启动游戏、未调用API。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_frames() -> void:
	var frames: SpriteFrames = load("res://sprite_frames/skill_vfx_samples_20261018.tres") as SpriteFrames
	_check(frames != null, "生成动画资源加载")
	if frames == null:
		return
	for name: StringName in [&"frost_burst", &"guard_spark"]:
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE_DIR + str(name) + ".frames.json"))
		var texture: Texture2D = load(SAMPLE_DIR + str(name) + ".png") as Texture2D
		var image: Image = texture.get_image() if texture != null else null
		_check(image != null and frames.has_animation(name), "图集与动画存在")
		if image == null:
			continue
		var count: int = metadata["durations_ms"].size()
		_check(image.get_size() == Vector2i(96 * count, 96) and frames.get_frame_count(name) == count, "保留96像素固定画布与真实帧数")
		_check(not frames.get_animation_loop(name), "特效不循环")
		var seconds: float = 0.0
		for i: int in range(count):
			var atlas: AtlasTexture = frames.get_frame_texture(name, i) as AtlasTexture
			_check(atlas != null and atlas.region == Rect2(i * 96, 0, 96, 96), "动画帧正确对应原图集")
			seconds += frames.get_frame_duration(name, i) / frames.get_animation_speed(name)
		_check(is_equal_approx(seconds, 2.0), "导入资源保持原始2秒时长")
		_check_alpha_edges(image, count)


func _check_alpha_edges(image: Image, count: int) -> void:
	var last_visible: int = 0
	for frame: int in range(count):
		var clipped: bool = false
		var pixels: int = 0
		for y: int in range(96):
			for x: int in range(96):
				var alpha: float = image.get_pixel(frame * 96 + x, y).a
				if alpha > 0.5:
					pixels += 1
					clipped = clipped or x == 0 or y == 0 or x == 95 or y == 95
		_check(not clipped, "无可见像素触碰帧边缘")
		if pixels > 0:
			last_visible += 1
		if frame == count - 1:
			_check(pixels == 0, "末帧完全消散")
	_check(last_visible > 1, "确有多帧可见变化而非静态候选冒充动画")


func _check_sigil() -> void:
	var texture: Texture2D = load(SAMPLE_DIR + "sigil.png") as Texture2D
	var image: Image = texture.get_image() if texture != null else null
	_check(image != null and image.get_size() == Vector2i(32, 32), "符文是32像素原生静态素材")
	if image == null:
		return
	var transparent: int = 0
	var clear_center: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a < 0.01:
				transparent += 1
				if x >= 12 and x < 20 and y >= 12 and y < 20:
					clear_center += 1
	_check(transparent > 300 and image.get_pixel(0, 0).a == 0.0, "符文有真实透明背景")
	_check(clear_center >= 32 and image.get_pixel(16, 16).a == 0.0, "符文中心大半镂空，不是实心圆盘")


func _check_scene_bindings() -> void:
	var frost: Node = (load("res://scenes/ability/manifest/guiren_frost_star_ring_manifest.tscn") as PackedScene).instantiate()
	_check(frost.get("radius") == 100.0 and frost.get("damage") == 20.0 and frost.get("status_duration") == 0.8, "冰环伤害范围与冻结时间未变")
	_check(frost.get_node("VisualRoot/Sprite2D") is AnimatedSprite2D and not frost.get("draw_area_fill"), "冰环绑定动画，不再用实心圆盖住角色")
	_check(frost.get_node("VisualRoot").get("playback_seconds") <= 0.3, "冰环动画不会被原有尾声提前裁掉")
	frost.free()
	var circle: Node = (load("res://scenes/ability/manifest/guiren_lightning_circle_manifest.tscn") as PackedScene).instantiate()
	_check(circle.get("pulse_count") == 4 and circle.get("initial_delay") == 1.0 and circle.get("damage") == 8.0, "雷阵仍为原有四次伤害、首次1秒")
	_check(circle.get_node("VisualRoot/Sprite2D").get("texture") != null and not circle.get("draw_area_fill"), "雷阵已绑定镂空符文")
	circle.free()
	var guard: Node = (load("res://scenes/ability/warrior_iron_counter_ability.tscn") as PackedScene).instantiate()
	_check(guard.has_node("Guard/PrecisionSpark") and guard.get_node("Guard/PrecisionSpark").get("forward_offset") == 28.0, "精准火花位于防御子链正前方")
	_check(guard.get_node("Guard").get("perfect_seconds") == 0.25 and guard.get_node("Guard/Damage").get("damage") == 25.0, "精准窗口与反击伤害不变")
	guard.free()
	var spark: Node = (load("res://scenes/ability/manifest/perfect_guard_spark_manifest.tscn") as PackedScene).instantiate()
	_check(spark.get("playback_seconds") == 0.22 and spark.get("animation_name") == &"guard_spark", "火花压缩为0.22秒独立视觉")
	spark.free()


func _visual_fixture() -> Node2D:
	var body: String = _functions(VISUAL_SCRIPT, ["_fit_radius", "_configure_animation", "_process", "_update_opacity"])
	var header: String = "@tool\nextends Node2D\nvar area: Node\nvar sprite: Node2D\nvar art_radius: float = 35.0\nvar animation_name: StringName = &\"frost_burst\"\nvar playback_seconds: float = 0.28\nvar idle_opacity: float = 0.8\nvar pulse_opacity: float = 0.2\nvar rotation_speed: float = 0.08\nvar seen_pulses: int = 0\nvar pulse_remaining: float = 0.0\n"
	var script: GDScript = _fixture(header + body)
	return script.new() if script != null else null


func _area_fixture() -> Node:
	var script: GDScript = _fixture("@tool\nextends Node\nvar radius: float = 100.0\nvar active: bool = false\nvar emitted: int = 1\nvar initial_delay: float = 0.0\nvar pulse_count: int = 1\nvar pulse_interval: float = 1.0\nvar elapsed: float = 0.0\n")
	return script.new() if script != null else null


func _check_visual_timing() -> void:
	var visual: Node2D = _visual_fixture()
	var area: Node = _area_fixture()
	if visual == null or area == null:
		return
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = load("res://sprite_frames/skill_vfx_samples_20261018.tres") as SpriteFrames
	visual.set("area", area)
	visual.set("sprite", sprite)
	visual.call("_fit_radius")
	visual.call("_configure_animation", sprite)
	_check(sprite.scale.is_equal_approx(Vector2.ONE * (100.0 / 35.0)), "贴图按可见半径匹配真实范围")
	_check(is_equal_approx(sprite.speed_scale, 2.0 / 0.28), "只加快动画，不修改伤害计时")
	visual.call("_process", 0.016)
	_check(not visual.visible, "技能尚未激活时隐藏贴图")
	area.set("active", true)
	visual.call("_process", 0.016)
	_check(visual.get("seen_pulses") == 1 and sprite.is_playing(), "第一次真实脉冲开始播放")
	sprite.frame = 5
	visual.call("_process", 0.016)
	_check(sprite.frame == 5, "同次脉冲不逐帧重置动画")
	area.set("elapsed", 0.3)
	visual.call("_process", 0.016)
	_check(sprite.modulate.a <= 0.001, "尾声结束前淡出，不留下常驻动画")
	sprite.free()
	area.free()
	visual.call("_process", 0.016)
	_check(not visual.visible, "目标已释放后安全停止表现")
	visual.free()


func _check_animation_playback() -> void:
	var body: String = _functions("res://scripts/ability/manifest/animated_ability_manifest.gd", ["_animation_seconds"])
	var script: GDScript = _fixture("@tool\nextends RefCounted\nvar animated_sprite: AnimatedSprite2D\nvar animation_name: StringName = &\"guard_spark\"\n" + body)
	if script == null:
		return
	var helper: RefCounted = script.new()
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = load("res://sprite_frames/skill_vfx_samples_20261018.tres") as SpriteFrames
	helper.set("animated_sprite", sprite)
	_check(is_equal_approx(helper.call("_animation_seconds"), 2.0), "通用动画时长读取尊重原始相对帧时长")
	helper.set("animation_name", &"missing")
	_check(helper.call("_animation_seconds") == 0.0, "不存在的动画安全返回")
	sprite.free()
