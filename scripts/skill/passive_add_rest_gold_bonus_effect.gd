class_name PassiveAddRestGoldBonusEffect
extends PassiveSkillEffect

# 每次进入修整期时额外获得的金币。
@export var bonus_gold: int = 1


func apply(context: SkillContext) -> void:
	if context.run_stats == null:
		return

	context.run_stats.add_rest_period_gold_bonus(bonus_gold)


func remove(_context: SkillContext) -> void:
	pass
