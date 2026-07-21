## 遗物效果：附近敌人死亡时恢复能量。
## 适合“吸收逝者余波”“附近击杀回蓝”这类需要监听敌人死亡位置的装备。
class_name NearbyEnemyDeathEnergyEffect
extends RelicEffect

## 敌人死亡时，与持有者距离不超过该值才触发。小于等于 0 表示不检查距离。
@export var trigger_radius: float = 240.0
## 每次触发恢复多少能量。
@export var energy_gain: float = 2.0
## 勾选后只有玩家侧单位击杀敌人才触发；关闭时只要附近敌人死亡就触发。
@export var require_player_side_killer: bool = false
## 持有者死亡后是否停止触发。
@export var require_owner_alive: bool = true

var active_records: Dictionary = {}


## 装备生效时注册到全局敌人死亡信号。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or energy_gain <= 0.0:
		return

	active_records[str(effect_key)] = {
		"owner": owner,
	}

	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)


## 装备失效时移除监听记录；没有任何实例后断开全局信号。
func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_records.erase(str(effect_key))
	if active_records.is_empty() and EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)


func _on_enemy_killed(enemy: Entity, killer: Entity) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if require_player_side_killer and not _is_player_side_entity(killer):
		return

	for record_key in active_records.keys().duplicate():
		var record: Dictionary = active_records.get(record_key, {}) as Dictionary
		var owner: Entity = record.get("owner") as Entity
		if owner == null or not is_instance_valid(owner):
			active_records.erase(record_key)
			continue
		if require_owner_alive and owner.is_dead:
			continue
		if not _is_enemy_near_owner(owner, enemy):
			continue

		_restore_energy(owner, energy_gain)

	if active_records.is_empty() and EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)


func _is_enemy_near_owner(owner: Entity, enemy: Entity) -> bool:
	if trigger_radius <= 0.0:
		return true
	return owner.global_position.distance_to(enemy.global_position) <= trigger_radius


func _restore_energy(owner: Entity, amount: float) -> void:
	if owner == null or amount <= 0.0:
		return

	var max_energy_value: float = owner.max_energy
	if owner.stats_controller != null:
		max_energy_value = owner.stats_controller.get_stat(&"max_energy", owner.max_energy)
	if max_energy_value <= 0.0:
		return

	owner.current_energy = min(owner.current_energy + amount, max_energy_value)
	owner.max_energy = max_energy_value
	if owner.stats_controller != null:
		owner.stats_controller.current_energy = owner.current_energy
		owner.stats_controller.sync_runtime_resources()

	if owner.is_in_group("player"):
		EventBus.player_energy_changed.emit(owner.current_energy, max_energy_value)


func _is_player_side_entity(entity: Entity) -> bool:
	return entity != null and is_instance_valid(entity) and entity.is_player_side()


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
