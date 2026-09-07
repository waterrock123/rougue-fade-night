class_name DamageData
extends Resource

enum DamageType {
	PHYSICAL,
	RANGED,
	FIRE,
	ICE,
	LIGHTNING,
	POISON,
}

var source: Entity
var target: Entity

var base_damage: float = 0.0
var final_damage: float = 0.0

var damage_types: Array[int] = []
var scaling_rule: DamageScalingRule
var source_ability_id: StringName = &""
var source_ability_slot_index: int = -1
## 本次攻击造成的削韧值；0 表示不削韧，小于 0 时才使用目标默认公式。
## 通用伤害默认不削韧，只有明确的技能、投射物或重击来源应主动填写正数。
var poise_damage: float = 0.0
## 攻击方在伤害生成时的削韧倍率快照，避免后续目标结算时再次依赖攻击者节点。
var poise_damage_multiplier: float = 1.0

var can_crit: bool = true
var is_crit: bool = false
var is_miss: bool = false
var crit_multiplier: float = 1.5

var tags: Array[String] = []

const DAMAGE_TYPE_COLORS := {
	DamageType.PHYSICAL: Color.WHITE,
	DamageType.RANGED: Color.WHITE,
	DamageType.FIRE: Color(1.0, 0.25, 0.08, 1.0),
	DamageType.ICE: Color(0.55, 0.9, 1.0, 1.0),
	DamageType.LIGHTNING: Color(0.8, 0.75, 1.0, 1.0),
	DamageType.POISON: Color(0.35, 1.0, 0.35, 1.0),
}


# 构造一次完整的伤害事件数据。
# 这份数据会在“伤害来源 -> 攻击者属性修正 -> 防御者减伤 -> 扣血”这条链路中一路传递。
static func create(
	damage: float,
	damage_type_list: Array[int] = [],
	damage_tags: Array[String] = [],
	damage_source: Entity = null,
	damage_target: Entity = null,
	allow_crit: bool = true,
	damage_scaling_rule: DamageScalingRule = null,
	damage_source_ability_id: StringName = &"",
	damage_source_ability_slot_index: int = -1,
	damage_poise_damage: float = 0.0,
	damage_poise_multiplier: float = 1.0
) -> DamageData:
	var data := DamageData.new()
	data.base_damage = damage
	data.final_damage = damage
	data.damage_types = damage_type_list.duplicate()
	data.tags = damage_tags.duplicate()
	data.source = damage_source
	data.target = damage_target
	data.can_crit = allow_crit
	data.scaling_rule = damage_scaling_rule
	data.source_ability_id = damage_source_ability_id
	data.source_ability_slot_index = damage_source_ability_slot_index
	data.poise_damage = damage_poise_damage
	data.poise_damage_multiplier = maxf(damage_poise_multiplier, 0.0)
	return data


# 统一给飘字/UI读取最终显示伤害。
func get_display_damage() -> float:
	return final_damage


# 根据伤害类型混合飘字颜色。
# 暴击颜色由 Entity 单独覆盖；这里专注处理普通伤害的物理、冰、火、毒等视觉区分。
func get_damage_type_color(default_color: Color = Color.WHITE) -> Color:
	if damage_types.is_empty():
		return default_color

	var unique_types: Array[int] = []
	for damage_type in damage_types:
		if not unique_types.has(damage_type):
			unique_types.append(damage_type)

	var mixed_color := Color(0.0, 0.0, 0.0, 0.0)
	var color_count := 0
	for damage_type in unique_types:
		var type_color := DAMAGE_TYPE_COLORS.get(damage_type, default_color) as Color
		mixed_color += type_color
		color_count += 1

	if color_count <= 0:
		return default_color

	mixed_color /= float(color_count)
	mixed_color.a = 1.0
	return mixed_color
