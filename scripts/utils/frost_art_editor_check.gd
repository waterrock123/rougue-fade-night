## 冰原动画的编辑器检查；不启动游戏、不运行敌人 AI、不改存档。
extends SceneTree

var checks: int = 0
var failures: int = 0
const ENEMIES: Array[String] = ["frost_fang_hound", "frost_crystal_sentinel", "frost_shell_beast"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Engine.is_editor_hint():
		quit(1)
		return
	await create_timer(3.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	for id: String in ENEMIES:
		_check_enemy(id)
	_check_animation_names()
	print("冰原美术检查：%d项，失败%d项；未启动战斗。" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_enemy(id: String) -> void:
	var scene: PackedScene = load("res://entity/enemy/%s.tscn" % id) as PackedScene
	_check(scene != null, id + " 场景可加载")
	if scene == null:
		return
	var node: Node = scene.instantiate()
	var sprite: AnimatedSprite2D = node.get_node("AnimatedSprite2D") as AnimatedSprite2D
	var frames: SpriteFrames = sprite.sprite_frames
	_check(frames.resource_path == "res://sprite_frames/%s_sprite_frames.tres" % id, "使用独立新动画而非原怪物占位")
	_check(sprite.modulate == Color.WHITE and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "原色显示与最近邻过滤")
	_check(not node.get("sprite_faces_left_by_default"), "右朝向素材不反向翻转")
	_check(node.get_node("BodyCollisionShape2D").get("shape") != null, "原身体碰撞仍保留")
	_check(node.get_node("Area2D/CollisionShape2D").get("shape") != null, "原受击碰撞仍保留")
	for name: StringName in [&"idle", &"walk", &"attack", &"die"]:
		_check_animation(frames, id, name)
	node.free()


func _check_animation(frames: SpriteFrames, id: String, name: StringName) -> void:
	_check(frames.has_animation(name), id + " 动画存在：" + name)
	if not frames.has_animation(name):
		return
	var count: int = frames.get_frame_count(name)
	_check(count >= 2, "真实多帧动画")
	_check(frames.get_animation_loop(name) == (name in [&"idle", &"walk"]), "循环与死亡释放逻辑一致")
	var valid: bool = true
	var duration: float = 0.0
	for index: int in range(count):
		var texture: AtlasTexture = frames.get_frame_texture(name, index) as AtlasTexture
		if texture == null or texture.atlas == null:
			valid = false
			continue
		valid = valid and texture.region.size == Vector2(32, 32)
		valid = valid and texture.region.position.x + 32 <= texture.atlas.get_width()
		valid = valid and texture.atlas.resource_path == "res://assets/enemy/%s/%s.png" % [id, name]
		duration += frames.get_frame_duration(name, index) / frames.get_animation_speed(name)
	_check(valid, "逐帧图集路径和32像素画布正确")
	_check(duration > 0.0 and duration <= 2.05, "播放时长有效")


func _check_animation_names() -> void:
	var scene: PackedScene = load("res://scenes/ability/frost_sentinel_volley.tscn") as PackedScene
	var ability: Node = scene.instantiate()
	_check(ability.get_node("Animation").get("animation_name") == "attack", "哨兵技能调用新攻击动画")
	ability.free()
	var frames: SpriteFrames = load("res://sprite_frames/frost_fang_hound_sprite_frames.tres") as SpriteFrames
	var duration: float = 0.0
	for index: int in range(frames.get_frame_count(&"attack")):
		duration += frames.get_frame_duration(&"attack", index) / frames.get_animation_speed(&"attack")
	_check(absf(duration - 0.65) < 0.01, "猎犬扑咬播放加速与物理冲刺窗口衔接")


func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error(message)
