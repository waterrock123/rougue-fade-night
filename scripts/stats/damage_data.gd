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

var can_crit: bool = true
var is_crit: bool = false
var crit_multiplier: float = 1.5

var tags: Array[String] = []


# 构造一次完整的伤害事件数据。
# 这份数据会在“伤害来源 -> 攻击者属性修正 -> 防御者减伤 -> 扣血”这条链路中一路传递。
static func create(
	damage: float,
	damage_type_list: Array[int] = [],
	damage_tags: Array[String] = [],
	damage_source: Entity = null,
	damage_target: Entity = null,
	allow_crit: bool = true,
	damage_scaling_rule: DamageScalingRule = null
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
	return data


# 统一给飘字/UI读取最终显示伤害。
func get_display_damage() -> float:
	return final_damage
