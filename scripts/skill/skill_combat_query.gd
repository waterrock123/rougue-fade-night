## 技能联动共用的敌方查询，只在命中、脉冲等事件时调用，不逐帧全场扫描。
class_name SkillCombatQuery
extends RefCounted


static func enemies_within(source: Entity, origin: Vector2, radius: float, excluded: Array[int] = []) -> Array[Entity]:
	var result: Array[Entity] = []
	if not is_instance_valid(source) or not source.is_inside_tree():
		return result
	var groups: Array[StringName] = [&"enemy"]
	if not source.is_player_side():
		groups.assign([&"player", &"player_ally", &"summon_pet"])
	for group: StringName in groups:
		for candidate: Node in source.get_tree().get_nodes_in_group(group):
			if not candidate is Entity or candidate == source or candidate.is_queued_for_deletion():
				continue
			var target: Entity = candidate as Entity
			if result.has(target) or excluded.has(target.get_instance_id()) or not target.can_be_targeted():
				continue
			if origin.distance_squared_to(target.global_position) > radius * radius:
				continue
			if has_sight(source, origin, target.global_position):
				result.append(target)
	result.sort_custom(func(a: Entity, b: Entity) -> bool: return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	return result


static func has_sight(source: Entity, start: Vector2, end: Vector2) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, end, 1)
	query.collide_with_areas = false
	return source.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## 仅负责连锁光线视觉；伤害仍由调用方生成DamageData。
static func show_link(source: Entity, start: Vector2, end: Vector2, color: Color) -> void:
	if not is_instance_valid(source) or not source.is_inside_tree():
		return
	var line: Line2D = Line2D.new()
	line.width = 1.5
	line.default_color = color
	line.points = PackedVector2Array([Vector2.ZERO, (end - start) * 0.45 + Vector2(3, -4), end - start])
	source.get_tree().root.add_child(line)
	line.global_position = start
	var tween: Tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.22)
	tween.tween_callback(line.queue_free)
