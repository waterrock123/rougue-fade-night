## 遗物效果：战斗开始时消耗背包内第一个指定 tag 装备，并转换为电力层数。
## 当前用于“发电机”：消耗第一个原料，按原料等阶获得电力；升级态会在本场战斗内继续周期产电。
class_name BattleStartConsumeMaterialPowerEffect
extends RelicEffect

## 被消耗的材料标签。发电机应配置为“原料”。
@export var material_tag: RelicTag
## 要给予的状态。发电机应配置为 power.tres。
@export var power_status: StatusData
## 每 1 阶原料转换成多少层电力。
@export var power_stacks_per_relic_level: int = 6

@export_group("Level Up")
## 升级态且成功消耗材料后，是否启动周期产电。
@export var levelup_enable_periodic_power: bool = true
## 升级态周期产电间隔。
@export var levelup_power_interval: float = 3.0
## 升级态每次额外获得的电力层数。
@export var levelup_power_stacks_per_tick: int = 1

var pending_battle_callbacks: Dictionary = {}
var active_records: Dictionary = {}


## 装备生效时等待战斗开始；如果已经在战斗中激活，则立即尝试触发。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or material_tag == null or power_status == null:
		return

	var key: String = str(effect_key)
	if active_records.has(key) or pending_battle_callbacks.has(key):
		return

	if EventBus.is_battle_active:
		_start_battle_effect(relic_context, key)
		return

	var callback: Callable = Callable(self, "_start_battle_effect").bind(relic_context, key)
	pending_battle_callbacks[key] = callback
	EventBus.battle_started.connect(callback, CONNECT_ONE_SHOT)


## 装备失效或离场时，停止周期产电，并移除这件装备来源提供的剩余电力。
func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	_disconnect_pending_callback(key)
	_stop_active_record(key)


func _start_battle_effect(relic_context: RelicContext, key: String) -> void:
	pending_battle_callbacks.erase(key)

	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or not is_instance_valid(owner) or owner.is_dead:
		return

	var player_build: PlayerBuild = _get_player_build(relic_context, owner)
	if player_build == null or player_build.player_inventory == null:
		return

	var material_slot: Slot = _find_first_material_slot(player_build.player_inventory)
	if material_slot == null or material_slot.item == null:
		return

	var consumed_relic: Relic = material_slot.item
	var power_stacks: int = _calculate_power_stacks(consumed_relic)

	# 统一走 RelicConsumption，让被消耗的原料有机会触发自己的 on_consumed 效果。
	RelicConsumption.consume_slot(
		material_slot,
		owner,
		relic_context.relic_controller,
		"%s_material_%s" % [key, consumed_relic.id],
		false
	)
	EventBus.inventory_update.emit()

	if power_stacks > 0:
		_add_power(owner, key, power_stacks)

	active_records[key] = {
		"owner": owner,
		"timer": null,
		"timer_callback": Callable(),
	}

	if _should_start_levelup_periodic_power(relic_context):
		_start_periodic_power_timer(key)


func _start_periodic_power_timer(key: String) -> void:
	if not active_records.has(key):
		return

	var record: Dictionary = active_records[key] as Dictionary
	var owner: Entity = record.get("owner") as Entity
	if owner == null or not is_instance_valid(owner) or not owner.is_inside_tree():
		active_records.erase(key)
		return

	var timer: Timer = Timer.new()
	timer.one_shot = false
	timer.wait_time = max(levelup_power_interval, 0.05)
	timer.autostart = false

	var callback: Callable = Callable(self, "_on_periodic_power_timeout").bind(key)
	timer.timeout.connect(callback)
	owner.add_child(timer)
	timer.start()

	record["timer"] = timer
	record["timer_callback"] = callback
	active_records[key] = record


func _on_periodic_power_timeout(key: String) -> void:
	if not active_records.has(key):
		return
	if not EventBus.is_battle_active:
		return

	var record: Dictionary = active_records[key] as Dictionary
	var owner: Entity = record.get("owner") as Entity
	if owner == null or not is_instance_valid(owner) or owner.is_dead:
		_stop_active_record(key)
		return

	_add_power(owner, key, levelup_power_stacks_per_tick)


func _add_power(owner: Entity, source_key: String, stacks: int) -> void:
	if owner == null or stacks <= 0:
		return

	var status_controller: StatusController = owner.get_status_controller()
	if status_controller == null:
		return

	# 使用同一个 source_key，方便技能消耗电力，也方便装备失效时清理剩余层数。
	status_controller.add_status(power_status, owner, source_key, stacks)


func _stop_active_record(key: String) -> void:
	if not active_records.has(key):
		return

	var record: Dictionary = active_records[key] as Dictionary
	var timer: Timer = record.get("timer") as Timer
	var timer_callback: Callable = record.get("timer_callback") as Callable
	if timer != null and is_instance_valid(timer):
		if timer_callback.is_valid() and timer.timeout.is_connected(timer_callback):
			timer.timeout.disconnect(timer_callback)
		timer.stop()
		timer.queue_free()

	var owner: Entity = record.get("owner") as Entity
	if owner != null and is_instance_valid(owner):
		var status_controller: StatusController = owner.get_status_controller()
		if status_controller != null and power_status != null:
			status_controller.remove_status_source(power_status.id, key)

	active_records.erase(key)


func _disconnect_pending_callback(key: String) -> void:
	if not pending_battle_callbacks.has(key):
		return

	var callback: Callable = pending_battle_callbacks[key] as Callable
	if callback.is_valid() and EventBus.battle_started.is_connected(callback):
		EventBus.battle_started.disconnect(callback)
	pending_battle_callbacks.erase(key)


func _find_first_material_slot(inventory: Inventory) -> Slot:
	if inventory == null:
		return null

	# 按背包格子顺序查找，符合“按照顺序消耗第一个原料”的描述。
	for slot in inventory.slots:
		if slot == null or slot.item == null:
			continue
		if _relic_has_tag(slot.item, material_tag):
			return slot

	return null


func _calculate_power_stacks(relic: Relic) -> int:
	if relic == null:
		return 0

	return max(relic.level, 0) * max(power_stacks_per_relic_level, 0)


func _should_start_levelup_periodic_power(relic_context: RelicContext) -> bool:
	if not levelup_enable_periodic_power:
		return false
	if levelup_power_stacks_per_tick <= 0:
		return false
	if relic_context == null or relic_context.own_relic == null:
		return false

	return relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP


func _relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false

	for relic_tag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == target_tag:
			return true
		if not relic_tag.tag_name.is_empty() and relic_tag.tag_name == target_tag.tag_name:
			return true

	return false


func _get_player_build(relic_context: RelicContext, owner: Entity) -> PlayerBuild:
	if relic_context != null and relic_context.relic_controller != null:
		if relic_context.relic_controller.player_build != null:
			return relic_context.relic_controller.player_build
	if owner != null and owner.stats_controller != null:
		return owner.stats_controller.player_build
	return null


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
