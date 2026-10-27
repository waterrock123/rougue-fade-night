## 战斗实体取目标：继承圆形/扇形搜索，额外排除地图物件。ENTITY模式可用于不分敌我的攻击。
class_name AbilityGetCombatTargets
extends AbilityGetTarget

## 新技能可开启视线过滤；默认关闭，保留已有范围技能的行为。
@export var require_line_of_sight: bool = false


func check_colliders_around_position(context: AbilityContext, search_radius: float) -> Array[Entity]:
	var targets: Array[Entity] = super.check_colliders_around_position(context, search_radius)
	if not require_line_of_sight:
		return targets
	var result: Array[Entity] = []
	for target: Entity in targets:
		if SkillCombatQuery.has_sight(context.caster, _get_search_origin(context), target.global_position):
			result.append(target)
	return result


func _matches_target_mode(caster: Entity, target: Entity) -> bool:
	return not target.is_in_group("map_object") and (target.is_player_side() or target.is_enemy_side()) and super._matches_target_mode(caster, target)
