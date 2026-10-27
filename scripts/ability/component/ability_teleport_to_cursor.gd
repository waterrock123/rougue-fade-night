## 朝鼠标进行限距瞬移，沿线逐步检查地图可达区域、墙体与角色自身碰撞形状。
## 被墙或地图边界阻挡时落在障碍前，不会传送到场外或把角色嵌进墙里。
class_name AbilityTeleportToCursor
extends AbilityComponent

@export var max_distance: float = 160.0
@export var sample_step: float = 4.0


func _activate(context: AbilityContext) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	var caster: Entity = context.caster
	var start: Vector2 = caster.global_position
	var map: Node = get_tree().get_first_node_in_group("battle_map")
	var destination: Vector2 = resolve_destination(caster, map, camera.get_global_mouse_position())
	caster.global_position = destination
	caster.velocity = Vector2.ZERO
	SkillCombatQuery.show_link(caster, start, destination, Color(0.7, 0.5, 1.0, 0.7))


func resolve_destination(caster: Entity, map: Node, desired: Vector2) -> Vector2:
	var start: Vector2 = caster.global_position
	var offset: Vector2 = (desired - start).limit_length(maxf(max_distance, 0.0))
	var destination: Vector2 = start
	var count: int = maxi(int(ceil(offset.length() / maxf(sample_step, 1.0))), 1)
	for i: int in range(1, count + 1):
		var candidate: Vector2 = start + offset * (float(i) / float(count))
		if not _is_safe(caster, map, start, candidate):
			break
		destination = candidate
	return destination


func _is_safe(caster: Entity, map: Node, start: Vector2, candidate: Vector2) -> bool:
	if map != null and map.has_method("is_world_position_in_playable_region"):
		if not bool(map.call("is_world_position_in_playable_region", candidate)):
			return false
	if not SkillCombatQuery.has_sight(caster, start, candidate):
		return false
	# test_move使用实体独立的BodyCollisionShape2D及World mask，不检测受击Area。
	return not caster.test_move(caster.global_transform, candidate - start)
