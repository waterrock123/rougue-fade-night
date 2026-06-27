## 技能预览挂载物组件。
## 按住技能键进入预览时生成一个视觉 Manifest，并持续跟随施法者和瞄准方向；预览结束时通知它播放消失动画。
@tool
class_name AbilityPreviewAttachedManifest
extends AbilityComponent

@export var manifest_scene: PackedScene
@export var set_as_child: bool = false
@export var forward_offset: float = 24.0
@export var side_offset: float = 0.0
@export var rotate_to_aim_direction: bool = true
@export var wait_appear_before_aim: bool = true
@export var mirror_when_aim_left: bool = true
@export var visual_z_index: int = 100

var preview_context: AbilityContext
var manifest_instance: Node2D
var can_aim_manifest := false


func _ready() -> void:
	# 这个组件只服务“按住预览”，不参与正式释放时的自动组件链。
	auto_activate = false
	set_process(false)


func begin_preview(context: AbilityContext) -> void:
	if context == null or context.caster == null or manifest_scene == null:
		return

	preview_context = context
	_spawn_manifest()
	set_process(true)
	_update_manifest_transform()


func end_preview() -> void:
	set_process(false)
	preview_context = null
	_request_manifest_disappear()


func _process(_delta: float) -> void:
	if preview_context == null or not preview_context.is_caster_action_valid():
		end_preview()
		return

	_update_manifest_transform()


func _exit_tree() -> void:
	if manifest_instance != null and is_instance_valid(manifest_instance):
		manifest_instance.queue_free()
	manifest_instance = null


func _spawn_manifest() -> void:
	_request_manifest_disappear()
	can_aim_manifest = not wait_appear_before_aim

	manifest_instance = manifest_scene.instantiate() as Node2D
	if manifest_instance == null:
		return

	var parent_node := _get_manifest_parent()
	parent_node.add_child(manifest_instance)
	manifest_instance.z_index = visual_z_index
	_connect_manifest_appear_signal()
	if manifest_instance.has_method("play_appear"):
		manifest_instance.play_appear()
	elif wait_appear_before_aim:
		can_aim_manifest = true


func _update_manifest_transform() -> void:
	if manifest_instance == null or not is_instance_valid(manifest_instance):
		return
	if preview_context == null or preview_context.caster == null:
		return

	var caster := preview_context.caster
	var direction := _get_aim_direction()
	var right := Vector2(-direction.y, direction.x)
	var offset := direction * forward_offset + right * side_offset
	if set_as_child:
		# 作为施法者子节点时使用本地坐标，确保出现/消失动画期间也能自然跟随角色移动。
		manifest_instance.position = offset
	else:
		manifest_instance.global_position = caster.global_position + offset

	if wait_appear_before_aim and not can_aim_manifest:
		_refresh_appear_finished_state()

	if rotate_to_aim_direction and can_aim_manifest:
		manifest_instance.global_rotation = direction.angle()

	if mirror_when_aim_left and can_aim_manifest:
		var scale_y := -1.0 if direction.x < 0.0 else 1.0
		manifest_instance.scale = Vector2(1.0, scale_y)


func _request_manifest_disappear() -> void:
	if manifest_instance == null:
		return
	if not is_instance_valid(manifest_instance):
		manifest_instance = null
		return

	if manifest_instance.has_method("request_disappear"):
		manifest_instance.request_disappear()
	else:
		manifest_instance.queue_free()
	manifest_instance = null
	can_aim_manifest = false


func _get_aim_direction() -> Vector2:
	if preview_context == null or preview_context.caster == null:
		return Vector2.RIGHT

	var caster := preview_context.caster
	var direction := caster.global_position.direction_to(caster.get_global_mouse_position())
	if direction == Vector2.ZERO:
		direction = caster.get_facing_direction()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	return direction.normalized()


func _get_visual_root() -> Node:
	if get_tree() == null:
		return self
	var root := get_tree().current_scene
	return root if root != null else get_tree().root


func _get_manifest_parent() -> Node:
	if set_as_child and preview_context != null and preview_context.caster != null:
		return preview_context.caster

	return _get_visual_root()


func _connect_manifest_appear_signal() -> void:
	if manifest_instance == null:
		return
	if not wait_appear_before_aim:
		return
	if not manifest_instance.has_signal("appear_finished"):
		return

	var callback := Callable(self, "_on_manifest_appear_finished")
	if not manifest_instance.is_connected("appear_finished", callback):
		manifest_instance.connect("appear_finished", callback)


func _refresh_appear_finished_state() -> void:
	if manifest_instance == null or not is_instance_valid(manifest_instance):
		return
	if not manifest_instance.has_method("has_finished_appear_animation"):
		can_aim_manifest = true
		return

	can_aim_manifest = bool(manifest_instance.has_finished_appear_animation())


func _on_manifest_appear_finished() -> void:
	can_aim_manifest = true
