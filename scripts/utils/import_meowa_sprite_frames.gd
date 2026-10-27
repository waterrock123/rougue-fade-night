## 开发期导入已拆帧的Meowa动画图集。保留WebP原始帧时长，不把多个外观候选冒充动画。
extends SceneTree


func _initialize() -> void:
	call_deferred("_import_frames")


func _import_frames() -> void:
	if not Engine.is_editor_hint():
		printerr("请使用--editor运行导入器，不启动游戏。")
		quit(1)
		return
	await create_timer(2.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() not in [2, 3] or not args[0].begins_with("res://assets/") or not args[1].begins_with("res://"):
		quit(1)
		return
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	# 第三个参数可指定 Boss 等特殊角色的动作；省略时兼容原有四动作流程。
	var names: PackedStringArray = args[2].split(",", false) if args.size() == 3 else PackedStringArray(["idle", "walk", "attack", "die"])
	for name: StringName in names:
		if not _add_animation(frames, args[0], name):
			quit(1)
			return
	var error: Error = ResourceSaver.save(frames, args[1])
	print("SpriteFrames导入结果：", error, "，", args[1])
	quit(0 if error == OK else 1)


func _add_animation(frames: SpriteFrames, directory: String, name: StringName) -> bool:
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(str(name) + ".frames.json")))
	var atlas: Texture2D = load(directory.path_join(str(name) + ".png")) as Texture2D
	if not metadata is Dictionary or atlas == null:
		printerr("缺少动画图集或元数据：" + str(name))
		return false
	var duration: float = 0.0
	for milliseconds: Variant in metadata["durations_ms"]:
		duration += float(milliseconds) / 1000.0
	# 可显式将动画适配技能时间轴；未指定时完整保留原始帧时长。
	var playback_duration: float = float(metadata.get("playback_duration_seconds", duration))
	if playback_duration <= 0.0:
		printerr("动画播放时长必须大于零：" + str(name))
		return false
	frames.add_animation(name)
	frames.set_animation_loop(name, name in [&"idle", &"walk", &"run"])
	frames.set_animation_speed(name, 8.0 * duration / playback_duration)
	for index: int in range(metadata["durations_ms"].size()):
		var texture: AtlasTexture = AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(index * int(metadata["width"]), 0, metadata["width"], metadata["height"])
		frames.add_frame(name, texture, float(metadata["durations_ms"][index]) * 8.0 / 1000.0)
	return true
