class_name AbilityManifest
extends Node2D

var launch_notified: bool = false
var source_element_tags: Array[StringName] = []
var source_cast_record: AbilityCastRecord


## 所有Manifest在激活时保存快照；覆写activate的子类也需要调用。
func capture_element_tags(context: AbilityContext) -> void:
	var captured: Array[StringName] = []
	if context != null:
		captured.assign(context.element_tags)
	source_element_tags = captured
	source_cast_record = context.cast_record if context != null else null


func stamp_damage_elements(data: DamageData) -> void:
	if data != null:
		data.skill_element_tags = source_element_tags.duplicate()
		data.cast_record = source_cast_record
		data.skill_damage_multiplier = source_cast_record.damage_multiplier if source_cast_record != null else 1.0


## 投射物移动前检测沿途的反弹盾，避免高速飞行跨过整个碰撞区域。
## 非投射物不会调用；没有护盾时只做一次空组查询。
func try_intercept_projectile_movement(movement: Vector2) -> bool:
	if not is_inside_tree():
		return false
	# 友方弹幕不需要遍历护盾，降低高速连射场景下的查询开销。
	var projectile_source: Variant = get("source")
	if not is_instance_valid(projectile_source) or not projectile_source is Entity:
		return false
	if not (projectile_source as Entity).is_enemy_side():
		return false
	for node: Node in get_tree().get_nodes_in_group("projectile_reflectors"):
		if node is OrbitingProjectileShield:
			if (node as OrbitingProjectileShield).try_intercept(self, global_position, global_position + movement):
				return true
	return false


## 各类投射物在确定方向后调用一次，供装备监听真实发射行为。
func notify_projectile_launched(context: AbilityContext, direction: Vector2) -> void:
	if launch_notified or direction == Vector2.ZERO:
		return
	launch_notified = true
	EventBus.projectile_launched.emit(self, context, direction.normalized())



func activate(context: AbilityContext):
	capture_element_tags(context)
	_activate(context)


func _activate(context: AbilityContext):
	pass
