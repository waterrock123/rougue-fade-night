## 有限穿透投射物，可按本次施法的支付快照覆盖穿透次数。
## 固定减伤穿透是本次伤害数据的一部分，不修改敌人护甲，也不绕过百分比减伤。
class_name LimitedHitProjectileManifest
extends ProjectileManifest

@export var max_hits: int = 5
@export var ignore_target_armor: bool = false
var hits_used: int = 0


func activate(context: AbilityContext) -> void:
	var options: Dictionary = context.cast_record.projectile_options
	max_hits = maxi(int(options.get("max_hits", max_hits)), 1)
	is_penetrate = bool(options.get("penetrate", is_penetrate))
	hit_each_target_once = true
	super.activate(context)


func _on_area_2d_area_entered(area: Area2D) -> void:
	if is_queued_for_deletion() or hits_used >= max_hits:
		return
	var previous: int = hit_target_ids.size()
	super._on_area_2d_area_entered(area)
	if hit_target_ids.size() > previous:
		hits_used += 1
		if hits_used >= max_hits:
			queue_free()


func _create_hit_damage(target: Entity, valid_source: Entity) -> DamageData:
	var data: DamageData = super._create_hit_damage(target, valid_source)
	data.ignore_static_damage_reduction = ignore_target_armor
	return data
