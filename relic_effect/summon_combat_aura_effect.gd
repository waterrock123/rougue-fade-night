## 为自身召唤的友方单位提供范围状态光环，可选实际死亡时的范围伤害。
## 不修改召唤物的 AI 或技能，后续出现的召唤物也会自动获得光环。
class_name SummonCombatAuraEffect
extends RelicEffect

@export var aura_status: StatusData
@export var aura_stacks: int = 1
@export var aura_duration_override: float = INF
@export var aura_radius: float = 80.0
@export var aura_interval: float = 1.0
@export var explode_on_death: bool = false
@export var explosion_radius: float = 120.0
@export var explosion_damage: float = 120.0
@export var explosion_damage_types: Array[int] = [DamageData.DamageType.FIRE]
@export var explosion_visual: PackedScene


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not context.owner is Entity:
		return
	var actor: Entity = context.owner as Entity
	var runner: SummonCombatAuraRunner = actor.get_node_or_null(_node_name(effect_key)) as SummonCombatAuraRunner
	if runner == null:
		runner = SummonCombatAuraRunner.new()
		runner.name = _node_name(effect_key)
		actor.add_child(runner)
	runner.configure(self, actor, String(effect_key))


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var runner: SummonCombatAuraRunner = context.owner.get_node_or_null(_node_name(effect_key)) as SummonCombatAuraRunner
	if runner != null:
		runner.request_cleanup()


func _node_name(effect_key) -> String:
	return "SummonAura_%s_%s" % [get_instance_id(), String(effect_key).validate_node_name()]
