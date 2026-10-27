## 贵人动画隔离校验：不添加玩家到场景树、不运行战斗、不读取玩家存档。
extends SceneTree

const DIRECTORY: String = "res://assets/人物角色素材/guiren_05/"
const NAMES: Array[StringName] = [&"idle", &"run", &"attack", &"cast", &"die"]
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	# 延迟加载项目类，避免 --editor --script 在自动加载单例注册前提前编译 Player。
	var character: Resource = load("res://character_resource/wizard/wizard.tres") as Resource
	_check(character != null and character.get("id") == &"wizard", "原角色资源及编号保留")
	if character == null or character.get("visual_data") == null:
		_check(false, "贵人已关联视觉资源")
		quit(1)
		return
	var visual: Resource = character.get("visual_data") as Resource
	_check(visual.resource_path == "res://character_resource/wizard/wizard_visual_data.tres", "独立视觉配置")
	_check(not visual.get("show_weapon"), "贴图已有法杖，不叠加默认武器")
	_check(not visual.get("default_facing_left") and visual.get("visual_scale") == Vector2.ONE, "默认朝右且不缩放身体")
	for name: StringName in NAMES:
		_check_animation(visual.get("sprite_frames") as SpriteFrames, name)
	_check_player_binding(character)
	_check_hub_binding(character)
	print("贵人美术编辑器检查：%d项，失败%d项；未启动游戏。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_animation(frames: SpriteFrames, name: StringName) -> void:
	_check(frames != null and frames.has_animation(name), "动画存在：" + name)
	if frames == null or not frames.has_animation(name):
		return
	_check(frames.get_frame_count(name) >= 2, "真实多帧动作：" + name)
	_check(frames.get_animation_loop(name) == (name in [&"idle", &"run"]), "循环配置：" + name)
	var valid: bool = true
	var duration: float = 0.0
	for index: int in range(frames.get_frame_count(name)):
		var texture: AtlasTexture = frames.get_frame_texture(name, index) as AtlasTexture
		if texture == null or texture.atlas == null:
			valid = false
			continue
		valid = valid and texture.region.size == Vector2(49, 49)
		valid = valid and texture.region.end.x <= texture.atlas.get_width()
		valid = valid and texture.atlas.resource_path == DIRECTORY + str(name) + ".png"
		duration += frames.get_frame_duration(name, index) / frames.get_animation_speed(name)
	_check(valid, "API输出的49像素固定画布与本角色图集引用：" + name)
	var expected: float = 0.5 if name == &"attack" else (1.0 if name == &"run" else 2.0)
	_check(absf(duration - expected) < 0.01, "播放时长与普攻冷却匹配：" + name)


func _check_player_binding(character: Resource) -> void:
	var scene: PackedScene = load("res://scenes/player.tscn") as PackedScene
	var player: Node = scene.instantiate()
	# 编辑器中的非 tool 游戏脚本是占位实例，只检查节点、脚本与接口引用，不调用游戏方法。
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var weapon: Node2D = player.get_node("Weapon") as Node2D
	var script: Script = player.get_script() as Script
	_check(script != null and script.reload(true) == OK, "战斗 Player 脚本解析")
	_check(sprite != null and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "战斗精灵节点与像素过滤")
	_check(weapon != null, "武器显示配置的目标节点存在")
	var source: String = FileAccess.get_file_as_string(script.resource_path)
	_check(source.contains("animated_sprite.sprite_frames = character_visual_data.sprite_frames"), "战斗角色读取独立动画配置")
	_check(source.contains("character_visual_data.show_weapon"), "战斗角色读取武器显隐配置")
	_check(character.get("visual_data").get("default_animation") == &"idle", "绑定默认动作存在")
	player.free()


func _check_hub_binding(character: Resource) -> void:
	var scene: PackedScene = load("res://scenes/hub/hub_player.tscn") as PackedScene
	var player: Node = scene.instantiate()
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var script: Script = player.get_script() as Script
	_check(script != null and script.reload(true) == OK, "大厅 Player 脚本解析")
	_check(sprite != null and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "大厅精灵节点与像素过滤")
	var source: String = FileAccess.get_file_as_string(script.resource_path)
	_check(source.contains("animated_sprite.sprite_frames = visual_data.sprite_frames"), "大厅读取同一角色动画配置")
	_check(source.contains("_play_animation_if_needed(&\"run\")"), "大厅已有移动动作接口")
	_check(not character.get("visual_data").get("default_facing_left"), "角色默认右朝向与大厅翻转约定一致")
	player.free()


func _check(passed: bool, description: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error(description)
