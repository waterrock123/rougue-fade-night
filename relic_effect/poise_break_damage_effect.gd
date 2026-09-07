## 破韧后对被破韧目标追加伤害的通用遗物效果。
## 可配置普通/升级伤害与命中次数，适合铁牙签、处决刃等单体破韧收益。
class_name PoiseBreakDamageEffect
extends PoiseBreakRelicEffect


@export_group("伤害")
@export var damage: float = 20.0
## 小于 0 时沿用普通伤害。
@export var levelup_damage: float = -1.0
@export_range(1, 20, 1) var hit_count: int = 1
## 小于 1 时沿用普通命中次数。
@export var levelup_hit_count: int = -1
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var tags: Array[String] = ["relic", "poise_break", "melee", "melee_effect"]
@export var can_crit: bool = false
## 破韧追加伤害默认不再削韧，避免形成递归触发链。
@export var poise_damage: float = 0.0


## 根据遗物升级态决定伤害和次数，并在当前伤害事件结束后结算。
func apply_poise_break_effect(
	owner: Entity,
	broken_enemy: Entity,
	_damage_data: DamageData,
	_effect_key: String,
	is_levelup: bool
) -> void:
	var resolved_damage: float = damage
	var resolved_hit_count: int = maxi(hit_count, 1)
	if is_levelup:
		if levelup_damage >= 0.0:
			resolved_damage = levelup_damage
		if levelup_hit_count >= 1:
			resolved_hit_count = levelup_hit_count
	if resolved_damage <= 0.0:
		return

	for _hit_index: int in range(resolved_hit_count):
		var hit_data: DamageData = DamageData.create(
			resolved_damage,
			damage_types,
			tags,
			owner,
			broken_enemy,
			can_crit,
			null,
			&"",
			-1,
			poise_damage
		)
		broken_enemy.call_deferred("apply_damage", hit_data)
