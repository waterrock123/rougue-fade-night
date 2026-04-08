class_name AbilityController
extends Node


var abilities: Array[Ability] = []
var cooldowns: Dictionary = {}

var entity: Entity

func _ready():
	
	for child in get_children():
		if child is Ability:
			abilities.push_back(child)
	entity = get_parent()


func trigger_ability_by_idx(idx: int):
	if abilities.size() == 0:
		return
		
	var ability = abilities.get(idx)
	
	trigger_ability(ability)

func _process(delta: float) -> void:
	for ability in abilities:
		if cooldowns.get(ability,0.0) > 0.0:
			var cooldown = max(0.0,cooldowns[ability]-delta)
			cooldowns[ability]=cooldown
			ability.current_cooldown = cooldown
		
		ability.can_be_casted = _can_be_cast(ability)

func _can_be_cast(ability: Ability):
	var cd = cooldowns.get(ability,0.0)
	
	return cd == 0 and ability.energy_cost <= entity.current_energy




func trigger_ability(ability: Ability):
	
	if ability == null:
		return
	if cooldowns.get(ability,0.0)>0.0:
		return
		
	if entity.current_energy < ability.energy_cost:
		return
	entity.spend_energy(ability.energy_cost)
	ability.activate(entity)
	
	cooldowns[ability] = ability.cooldown
