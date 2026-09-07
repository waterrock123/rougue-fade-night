## 破韧后对目标周围其他敌人造成范围伤害的通用遗物效果。
## 伤害可以由持有者任意属性按倍率计算，并明确把 DamageData.source 设为持有者。
class_name PoiseBreakAreaDamageEffect
extends PoiseBreakRelicEffect


@export_group("范围")
@export var radius: float = 120.0
@export var exclude_broken_enemy: bool = true

@export_group("伤害")
@export var base_damage: float = 0.0
@export var source_stat: StringName = &"strength"
@export var stat_multiplier: float = 2.0
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var tags: Array[String] = ["relic", "poise_break", "area", "melee", "melee_effect"]
@export var can_crit: bool = false
## 范围追加伤害默认不削韧，防止一次破韧引发连锁破韧循环。
@export var poise_damage: float = 0.0


## 扫描被破韧目标周围的同阵营敌人，延迟结算每个范围命中。
func apply_poise_break_effect(
	owner: Entity,
	broken_enemy: Entity,
	_damage_data: DamageData,
	_effect_key: String,
	_is_levelup: bool
) -> void:
	var resolved_damage: float = _get_damage(owner)
	if resolved_damage <= 0.0 or radius <= 0.0:
		return
	if broken_enemy.get_tree() == null:
		return

	for node: Node in broken_enemy.get_tree().get_nodes_in_group("enemy"):
		if not (node is Entity):
			continue
		var target: Entity = node as Entity
		if target == broken_enemy and exclude_broken_enemy:
			continue
		if target.is_dead or not target.is_enemy_side():
			continue
		if target.global_position.distance_to(broken_enemy.global_position) > radius:
			continue

		var area_damage: DamageData = DamageData.create(
			resolved_damage,
			damage_types,
			tags,
			owner,
			target,
			can_crit,
			null,
			&"",
			-1,
			poise_damage
		)
		target.call_deferred("apply_damage", area_damage)


func _get_damage(owner: Entity) -> float:
	var result: float = base_damage
	if owner != null and owner.stats_controller != null and source_stat != &"":
		result += owner.stats_controller.get_stat(source_stat) * stat_multiplier
	return maxf(result, 0.0)
