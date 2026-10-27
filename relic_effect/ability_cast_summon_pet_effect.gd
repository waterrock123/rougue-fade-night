## 成功释放主动技能时，按概率召唤限时友方单位。
## 召唤上限、伤害快照及升级态死亡奖励均可配置，可用于其他召唤装备。
class_name AbilityCastSummonPetEffect
extends RelicEffect

@export var pet_scene: PackedScene
@export_range(0.0, 1.0) var summon_chance: float = 0.2
@export var exclude_basic_attack: bool = true
@export_range(1, 20) var max_alive_pets: int = 3
@export var lifetime: float = 30.0
@export var spawn_radius: float = 40.0
## 在召唤时把主人属性加成写入召唤物的直接伤害组件，不随主人后续属性变化。
@export var bonus_damage_stat: StringName = &"intelligence"
@export var bonus_damage_ratio: float = 0.5
## 实际死亡时调用这些效果的 on_use；主动清理不会触发。
@export var upgraded_death_effects: Array[RelicEffect] = []


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not context.owner is Entity:
		return
	var actor: Entity = context.owner as Entity
	var runner: AbilityCastSummonRunner = actor.get_node_or_null(_runner_name(effect_key)) as AbilityCastSummonRunner
	if runner == null:
		runner = AbilityCastSummonRunner.new()
		runner.name = _runner_name(effect_key)
		actor.add_child(runner)
	runner.configure(self, context)


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var runner: AbilityCastSummonRunner = context.owner.get_node_or_null(_runner_name(effect_key)) as AbilityCastSummonRunner
	if runner != null:
		runner.request_cleanup()


func _runner_name(effect_key) -> String:
	return "CastSummon_%s_%s" % [get_instance_id(), String(effect_key).validate_node_name()]
