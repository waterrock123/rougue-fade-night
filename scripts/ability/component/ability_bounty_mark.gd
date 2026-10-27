## 选择鼠标附近敌人并交给角色上的标记管理器；管理器不随技能栏重建而重置单场奖励额度。
class_name AbilityBountyMark
extends AbilityComponent

@export var target_range: float = 300.0
@export var cursor_radius: float = 40.0
@export var mark_duration: float = 6.0
@export var damage_bonus: float = 0.15
@export var bounty_gold: int = 1
@export var battle_gold_limit: int = 1
@export var mark_status: StatusData


func can_pay_ability_cost(context: AbilityContext) -> bool:
	return _find_target(context) != null


func get_ability_cost_block_reason(_context: AbilityContext) -> String:
	return "鼠标附近没有可标记的敌人"


func _find_target(context: AbilityContext) -> Entity:
	var cursor: Vector2 = context.caster.get_global_mouse_position()
	var nearest: Entity
	var best: float = cursor_radius * cursor_radius
	for target: Entity in SkillCombatQuery.enemies_within(context.caster, context.caster.global_position, target_range):
		var distance: float = cursor.distance_squared_to(target.global_position)
		if distance <= best:
			best = distance
			nearest = target
	return nearest


func _activate(context: AbilityContext) -> void:
	var target: Entity = _find_target(context)
	if target == null:
		return
	var key: String = "bounty_mark_%s" % context.ability.id
	var runtime: BountyMarkController = context.caster.get_node_or_null(NodePath(key)) as BountyMarkController
	if runtime == null:
		runtime = BountyMarkController.new()
		runtime.name = key
		context.caster.add_child(runtime)
		runtime.bind(context.caster, key)
	runtime.mark(target, mark_status, mark_duration, damage_bonus, bounty_gold, battle_gold_limit)
