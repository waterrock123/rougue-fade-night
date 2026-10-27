## 限时召唤物的寿命组件。到期走实体死亡链路，队列释放则不算死亡。
class_name SummonLifetime
extends Node

@export var lifetime: float = 30.0
var elapsed: float = 0.0


func _process(delta: float) -> void:
	var pet: Entity = get_parent() as Entity
	if pet == null or pet.is_dead or not EventBus.is_battle_active:
		return
	elapsed += delta
	if lifetime <= 0.0 or elapsed < lifetime:
		return
	set_process(false)
	pet.current_health = 0.0
	if pet.stats_controller != null:
		pet.stats_controller.current_health = 0.0
	pet._die()
