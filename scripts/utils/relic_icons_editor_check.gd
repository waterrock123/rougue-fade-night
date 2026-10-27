## 编辑器检查全部装备图标和本轮生成的透明PNG；不启动游戏、不读写玩家存档。
extends SceneTree

const NEW_ICON_DIR: String = "res://assets/ai art/装备icon/completion_20261012/"
var checked_relics: int = 0
var checked_images: int = 0
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
	_check_relic_directory("res://relics")
	_check_generated_images()
	print("装备图标编辑器检查：%d件装备、%d张新增图标，失败%d项；未启动游戏。" % [checked_relics, checked_images, failures])
	quit(0 if failures == 0 else 1)


func _check_relic_directory(path: String) -> void:
	for directory: String in DirAccess.get_directories_at(path):
		_check_relic_directory(path.path_join(directory))
	for filename: String in DirAccess.get_files_at(path):
		if filename.get_extension() != "tres":
			continue
		_check_relic(path.path_join(filename))


func _check_relic(path: String) -> void:
	checked_relics += 1
	var relic: Resource = load(path)
	_check(relic != null, "装备资源加载：" + path)
	if relic == null:
		return
	var icon: Texture2D = relic.get("icon") as Texture2D
	_check(icon != null, "图标绑定：" + path)
	if icon == null:
		return
	_check(icon.get_width() > 0 and icon.get_height() > 0, "图标尺寸：" + path)
	if icon is AtlasTexture:
		var atlas_icon: AtlasTexture = icon as AtlasTexture
		_check(atlas_icon.atlas != null, "图集源：" + path)
		if atlas_icon.atlas != null:
			var bounds: Rect2 = Rect2(Vector2.ZERO, atlas_icon.atlas.get_size())
			_check(bounds.encloses(atlas_icon.region), "图集裁切不越界：" + path)


func _check_generated_images() -> void:
	for filename: String in DirAccess.get_files_at(NEW_ICON_DIR):
		# 预览是多张图标的拼图，不属于实际绑定的32x32装备图标。
		if filename.get_extension() != "png" or not filename.left(3).is_valid_int():
			continue
		checked_images += 1
		var path: String = NEW_ICON_DIR + filename
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(image != null and not image.is_empty(), "PNG可解码：" + filename)
		if image == null or image.is_empty():
			continue
		_check(image.get_size() == Vector2i(32, 32), "32x32像素尺寸：" + filename)
		_check(image.detect_alpha() != Image.ALPHA_NONE, "透明背景：" + filename)
		var has_visible_pixel: bool = false
		for y: int in range(image.get_height()):
			for x: int in range(image.get_width()):
				has_visible_pixel = has_visible_pixel or image.get_pixel(x, y).a > 0.0
		_check(has_visible_pixel, "图标不是空白：" + filename)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("[失败] " + label)
