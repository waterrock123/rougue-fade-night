## 古树美术资源隔离检查：不运行战斗、不访问玩家存档。
extends SceneTree

const ANIMATIONS: Array[StringName] = [&"idle", &"attack", &"cast", &"relocate", &"die"]
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
	var scene: PackedScene = load("res://entity/enemy/mushroom_tree_boss.tscn") as PackedScene
	_check(scene != null, "Boss 场景加载")
	if scene == null:
		quit(1)
		return
	var boss: Node = scene.instantiate()
	var sprite: AnimatedSprite2D = boss.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check(sprite.sprite_frames.resource_path == "res://sprite_frames/mushroom_tree_boss_sprite_frames.tres", "接入独立动画资源")
	_check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "像素最近邻过滤")
	_check(boss.get("scale") == Vector2.ONE, "根节点缩放未改变")
	_check(boss.get_node("BodyCollisionShape2D").get("shape").get("radius") == 30.0, "身体碰撞未改变")
	_check(boss.get_node("Area2D/CollisionShape2D").get("shape").get("radius") == 48.0, "受击范围未改变")
	for name: StringName in ANIMATIONS:
		_check_animation(sprite.sprite_frames, name)
	boss.free()
	print("古树美术编辑器检查：%d项，失败%d项；未启动战斗。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_animation(frames: SpriteFrames, name: StringName) -> void:
	_check(frames.has_animation(name), "动作存在：" + name)
	if not frames.has_animation(name):
		return
	var count: int = frames.get_frame_count(name)
	_check(count >= 2, "动作具有真实多帧")
	_check(frames.get_animation_loop(name) == (name == &"idle"), "仅待机循环")
	var duration: float = 0.0
	var valid: bool = true
	for index: int in range(count):
		var texture: AtlasTexture = frames.get_frame_texture(name, index) as AtlasTexture
		if texture == null or texture.atlas == null:
			valid = false
			continue
		valid = valid and texture.region.size == Vector2(192, 192)
		valid = valid and texture.region.end.x <= texture.atlas.get_width()
		valid = valid and texture.atlas.resource_path == "res://assets/enemy/mushroom_tree_boss/padded/%s.png" % name
		duration += frames.get_frame_duration(name, index) / frames.get_animation_speed(name)
	_check(valid, "192像素留白画布与图集引用正确")
	var expected: float = 1.8 if name == &"attack" else 2.0
	_check(absf(duration - expected) < 0.01, "播放时长匹配动作流程：" + name)


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error(message)
