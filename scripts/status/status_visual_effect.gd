## 状态视觉效果。
## 状态存在期间播放一个挂在实体身上的 VFX；如果 VFX 支持 finish_vfx()，状态结束时会先播放收尾动画。
class_name StatusVisualEffect
extends StatusEffect

@export var vfx_scene: PackedScene
@export var attach_to_anchor: bool = true
@export var refresh_existing: bool = false

@export_group("Lifecycle")
## 限时状态快结束时，提前通知 VFX 播放 end 动画，而不是等状态彻底移除才突然消失。
@export var play_end_before_remove: bool = true
@export var end_lead_time: float = 0.35

var spawned_vfx: Dictionary = {}
var ending_vfx_keys: Dictionary = {}


# 状态生效时生成视觉特效，优先交给实体的 VFXController 管理。
func on_apply(instance: StatusInstance) -> void:
	if instance == null or instance.target == null or vfx_scene == null:
		return

	var key := _get_effect_key(instance)
	ending_vfx_keys.erase(key)

	var vfx_controller := instance.target.get_node_or_null("VFXController")
	if vfx_controller != null and vfx_controller.has_method("play_vfx"):
		vfx_controller.play_vfx(key, vfx_scene, refresh_existing)
		return

	var parent := _resolve_fallback_parent(instance.target)
	if parent == null:
		return

	if spawned_vfx.has(key) and is_instance_valid(spawned_vfx[key]):
		if refresh_existing:
			_finish_node_vfx(spawned_vfx[key])
		else:
			return

	var vfx := vfx_scene.instantiate() as Node2D
	if vfx == null:
		return

	parent.add_child(vfx)
	vfx.position = Vector2.ZERO
	spawned_vfx[key] = vfx


func on_tick(instance: StatusInstance, _delta: float) -> void:
	if not play_end_before_remove:
		return
	if instance == null or not instance.is_temporary():
		return
	if instance.remaining_duration > end_lead_time:
		return

	var key := _get_effect_key(instance)
	if ending_vfx_keys.has(key):
		return

	ending_vfx_keys[key] = true
	_finish_vfx(instance, key)


# 状态结束时移除视觉特效；带生命周期的 VFX 会先播 end 动画。
func on_remove(instance: StatusInstance) -> void:
	if instance == null or instance.target == null:
		return

	var key := _get_effect_key(instance)
	_finish_vfx(instance, key)
	ending_vfx_keys.erase(key)


func _finish_vfx(instance: StatusInstance, key: String) -> void:
	var vfx_controller := instance.target.get_node_or_null("VFXController")
	if vfx_controller != null and vfx_controller.has_method("stop_vfx"):
		vfx_controller.stop_vfx(key)
		return

	var vfx = spawned_vfx.get(key)
	if vfx != null and is_instance_valid(vfx):
		_finish_node_vfx(vfx)
	spawned_vfx.erase(key)


func _finish_node_vfx(vfx: Node) -> void:
	if vfx.has_method("finish_vfx"):
		vfx.finish_vfx()
	else:
		vfx.queue_free()


func _resolve_fallback_parent(target: Node) -> Node:
	if attach_to_anchor:
		var anchor := target.get_node_or_null("VFXAnchor")
		if anchor != null:
			return anchor
	return target


func _get_effect_key(instance: StatusInstance) -> String:
	return "%s_visual" % instance.get_effect_key()
