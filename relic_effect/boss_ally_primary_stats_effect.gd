## Boss 战中给其他玩家和玩家盟友提供一级属性快照加成，不强化自身或敌人。
class_name BossAllyPrimaryStatsEffect
extends RelicEffect

@export var primary_ratio: float = 0.3
@export var flat_bonus: float = 0.0

var auras: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not (context.owner is Entity):
		return
	var caster: Entity = context.owner as Entity
	var key: String = "%d:%s" % [caster.get_instance_id(), str(effect_key)]
	if auras.has(key) and is_instance_valid(auras[key]):
		return
	var aura: BossAllyStatsAura = BossAllyStatsAura.new()
	aura.caster = caster
	aura.source_key = key
	aura.primary_ratio = primary_ratio
	aura.flat_bonus = flat_bonus
	auras[key] = aura
	caster.add_child(aura)


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var key: String = "%d:%s" % [context.owner.get_instance_id(), str(effect_key)]
	var value: Variant = auras.get(key)
	if is_instance_valid(value):
		var aura: BossAllyStatsAura = value as BossAllyStatsAura
		aura.stop()
		aura.queue_free()
	auras.erase(key)
