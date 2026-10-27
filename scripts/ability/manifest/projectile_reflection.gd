## 真正反转投射物的阵营和方向；不发 projectile_launched，避免触发再次发射奖励。
class_name ProjectileReflection
extends RefCounted


static func can_reflect(projectile: AbilityManifest, reflector: Entity) -> bool:
	if not is_instance_valid(projectile) or projectile.is_queued_for_deletion() or not is_instance_valid(reflector):
		return false
	if not projectile is ProjectileManifest and not projectile is AnimatedProjectileManifest:
		return false
	var tags: Array = projectile.get("tags")
	if not tags.has("projectile"):
		return false
	var source_value: Variant = projectile.get("source")
	if not is_instance_valid(source_value):
		return false
	var source: Entity = source_value as Entity
	if source == null or not source.is_enemy_side() or source == reflector:
		return false
	if projectile is AnimatedProjectileManifest and (projectile as AnimatedProjectileManifest).is_hit_finishing:
		return false
	var direction: Vector2 = projectile.get("current_dir")
	return direction != Vector2.ZERO


static func reflect(projectile: AbilityManifest, reflector: Entity) -> bool:
	if not can_reflect(projectile, reflector):
		return false
	_freeze_original_scaling(projectile)
	var direction: Vector2 = projectile.get("current_dir")
	projectile.set("source", reflector)
	projectile.set("current_dir", -direction.normalized())
	projectile.set("source_ability_id", &"")
	projectile.set("source_ability_slot_index", -1)
	projectile.set("current_distance", 0.0)
	# 反弹后直线返回，不再被原追踪/回旋逻辑带回玩家。
	projectile.set("runtime_homing_turn_speed", 0.0)
	projectile.global_rotation = (-direction).angle()
	if projectile is ProjectileManifest:
		var plain: ProjectileManifest = projectile as ProjectileManifest
		plain.target_group = "enemy"
		plain.is_returning = false
		plain.return_to_source_after_max_distance = false
		plain.hit_target_ids.clear()
		plain.resolution_notified = false
	else:
		(projectile as AnimatedProjectileManifest).target_group = &"enemy"
	return true


static func _freeze_original_scaling(projectile: AbilityManifest) -> void:
	var old_source: Entity = projectile.get("source") as Entity
	var scaling: DamageScalingRule = projectile.get("scaling_rule") as DamageScalingRule
	if scaling != null and is_instance_valid(old_source.stats_controller):
		var base_damage: float = float(projectile.get("damage"))
		var types: Array[int] = projectile.get("damage_types")
		var data := DamageData.create(base_damage, types, [], old_source, null, false, scaling)
		projectile.set("damage", base_damage + scaling.get_bonus_damage(old_source.stats_controller, data))
	# 保留原炮弹的伤害与穿透/状态配置，不额外吃玩家的一级属性公式。
	var frozen := DamageScalingRule.new()
	frozen.enabled = false
	projectile.set("scaling_rule", frozen)
