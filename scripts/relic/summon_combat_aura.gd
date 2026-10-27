## 单只召唤物的周期状态光环；死亡仅通知管理器，清场 queue_free 不触发爆炸。
class_name SummonCombatAura
extends Node

var manager: SummonCombatAuraRunner
var elapsed: float = 0.0
var pet: SummonPet


func _ready() -> void:
	pet = get_parent() as SummonPet
	if pet != null:
		pet.died.connect(_on_pet_died)


func _process(delta: float) -> void:
	if not is_instance_valid(manager) or not manager.can_work() or not is_instance_valid(pet) or pet.is_dead:
		return
	elapsed += delta
	var interval: float = maxf(manager.settings.aura_interval, 0.05)
	if elapsed < interval:
		return
	elapsed = fmod(elapsed, interval)
	var config: SummonCombatAuraEffect = manager.settings
	if config.aura_status == null:
		return
	var key: String = "%s_pet_%s" % [manager.source_key, pet.get_instance_id()]
	for enemy: Entity in find_enemies(pet, pet.global_position, config.aura_radius):
		if is_instance_valid(enemy) and is_instance_valid(enemy.status_controller):
			enemy.status_controller.add_status(config.aura_status, manager.actor, key,
				config.aura_stacks, config.aura_duration_override)


func _on_pet_died(_entity: Entity) -> void:
	if is_instance_valid(manager) and not pet.is_queued_for_deletion():
		manager.request_explosion(pet.global_position)


## 不依赖敌人受击区域数量，按 enemy 组精确过滤；不会误伤地图物体或友军。
static func find_enemies(caster: Entity, position: Vector2, radius: float) -> Array[Entity]:
	var result: Array[Entity] = []
	if not is_instance_valid(caster) or not caster.is_inside_tree():
		return result
	for node: Node in caster.get_tree().get_nodes_in_group("enemy"):
		var enemy: Entity = node as Entity
		if enemy == null or enemy.is_dead or enemy.is_queued_for_deletion() or not enemy.can_be_targeted():
			continue
		if enemy.global_position.distance_squared_to(position) <= radius * radius:
			result.append(enemy)
	return result


func _exit_tree() -> void:
	if is_instance_valid(pet) and pet.died.is_connected(_on_pet_died):
		pet.died.disconnect(_on_pet_died)
