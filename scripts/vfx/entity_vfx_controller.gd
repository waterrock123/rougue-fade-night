## 实体视觉特效管理器。负责把状态/技能产生的持续特效挂到统一锚点，避免各系统直接操作场景树。
class_name EntityVFXController
extends Node

@export var anchor_path: NodePath = ^"../VFXAnchor"

var active_vfx: Dictionary = {}


# 播放一个带 key 的持续特效；同 key 已存在时默认复用，避免重复叠出一堆光环。
func play_vfx(key: Variant, vfx_scene: PackedScene, refresh_existing: bool = false) -> Node2D:
	if key == null or vfx_scene == null:
		return null

	var normalized_key := str(key)
	if active_vfx.has(normalized_key):
		var old_vfx = active_vfx[normalized_key]
		if old_vfx != null and is_instance_valid(old_vfx):
			if not refresh_existing:
				return old_vfx as Node2D
			old_vfx.queue_free()

	var vfx := vfx_scene.instantiate() as Node2D
	if vfx == null:
		return null

	var anchor := _get_anchor()
	anchor.add_child(vfx)
	vfx.position = Vector2.ZERO
	active_vfx[normalized_key] = vfx
	return vfx


# 停止指定 key 的持续特效。
func stop_vfx(key: Variant) -> void:
	if key == null:
		return

	var normalized_key := str(key)
	var vfx = active_vfx.get(normalized_key)
	if vfx != null and is_instance_valid(vfx):
		# 有生命周期动画的特效优先播放 end，再由特效自己释放；没有该方法才直接释放。
		if vfx.has_method("finish_vfx"):
			vfx.finish_vfx()
		else:
			vfx.queue_free()
	active_vfx.erase(normalized_key)


# 清理所有持续特效，常用于切场景或实体死亡。
func clear_all_vfx() -> void:
	for key in active_vfx.keys():
		stop_vfx(key)


func _get_anchor() -> Node:
	var anchor := get_node_or_null(anchor_path)
	if anchor != null:
		return anchor
	return get_parent()
