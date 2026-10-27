class_name StatusController
extends Node

signal status_changed()
signal status_stacks_consumed(status_id: StringName, consumed_amount: int)

var statuses: Dictionary = {}
## source_key -> 剩余可拦截次数。不同来源的拦截次数可以同时存在。
var negative_status_blockers: Dictionary = {}

@onready var stats_controller: StatsController = get_node_or_null("../StatsController") as StatsController
@onready var target: Node = get_parent()


func _process(delta: float) -> void:
	if statuses.is_empty():
		return

	for status_id in statuses.keys().duplicate():
		var instance := statuses[status_id] as StatusInstance
		if instance == null:
			continue

		_tick_status(instance, delta)


# 添加一个状态。
# 同 id 的状态会合并成一个 StatusInstance，但会按 source_key 记录不同来源的层数。
func add_status(
	status_data: StatusData,
	source: Node = null,
	source_key: Variant = null,
	stacks: int = 1,
	duration_override: float = INF,
	ignore_negative_blocker: bool = false,
	attribute_gain_eligible: bool = true
) -> StatusInstance:
	if status_data == null or status_data.id == &"":
		return null
	if status_data.is_negative() and not ignore_negative_blocker and _consume_negative_status_blocker():
		# 被拦截的负面状态不会创建实例，也不会触发“状态已施加”事件。
		return null

	var status_id := status_data.id
	var existing := statuses.get(status_id) as StatusInstance
	if existing != null:
		_reapply_status(existing, source, source_key, stacks, duration_override, attribute_gain_eligible)
		_emit_status_applied(status_id, source, stacks)
		status_changed.emit()
		return existing

	var instance := StatusInstance.new(status_data, self, target, source, source_key, stacks, duration_override)
	instance.set_attribute_gain_source(source_key, attribute_gain_eligible)
	statuses[status_id] = instance
	_apply_effects(instance)
	_emit_status_applied(status_id, source, stacks)
	status_changed.emit()
	return instance


func remove_status(status_id: StringName) -> void:
	var instance := statuses.get(status_id) as StatusInstance
	if instance == null:
		return

	_remove_effects(instance)
	statuses.erase(status_id)
	status_changed.emit()


## 尝试净化一个状态。规则型、不可驱散状态会保留；系统清理仍使用 remove_status。
func dispel_status(status_id: StringName) -> bool:
	var instance := statuses.get(status_id) as StatusInstance
	if instance == null or instance.status_data == null or not instance.status_data.dispellable:
		return false
	remove_status(status_id)
	return true


# 只移除某一个来源贡献的层数。
# 例如两件装备都提供 armor，卸下一件时只移除那一件装备对应的护甲层数。
func remove_status_source(status_id: StringName, source_key: Variant) -> void:
	var instance := statuses.get(status_id) as StatusInstance
	if instance == null:
		return

	_remove_effects(instance)
	instance.remove_source(source_key)
	if instance.has_no_sources():
		statuses.erase(status_id)
	else:
		_apply_effects(instance)
	status_changed.emit()


func has_status(status_id: StringName) -> bool:
	return statuses.has(status_id)


func get_status(status_id: StringName) -> StatusInstance:
	return statuses.get(status_id) as StatusInstance


func consume_status_stacks(status_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0

	var instance := statuses.get(status_id) as StatusInstance
	if instance == null:
		return 0

	# 消耗层数前先撤下旧效果，扣完层数后再按剩余层数重放，避免带属性效果的状态残留。
	_remove_effects(instance)
	var consumed_amount: int = instance.consume_stacks(amount)
	if instance.has_no_sources():
		statuses.erase(status_id)
	else:
		_apply_effects(instance)

	if consumed_amount > 0:
		status_stacks_consumed.emit(status_id, consumed_amount)
		status_changed.emit()
	return consumed_amount


func clear_all_statuses() -> void:
	for status_id in statuses.keys().duplicate():
		remove_status(status_id)


## 恢复已结算过的状态，不再次触发净化拦截、获得状态奖励或临时属性转永久。
func restore_stored_status(data: StatusData, stacks: int, remaining: float, effect_states: Array = []) -> StatusInstance:
	if data == null or data.id == &"" or stacks <= 0 or remaining <= 0.0:
		return null
	var instance: StatusInstance = get_status(data.id)
	var key: String = "status_storage_%s" % String(data.id)
	if instance == null:
		instance = StatusInstance.new(data, self, target, null, key, stacks, remaining)
		statuses[data.id] = instance
	else:
		_remove_effects(instance)
		if data.stack_mode == StatusData.StackMode.ADD_STACK:
			instance.add_source_stacks(key, stacks)
		else:
			instance.set_source_stacks(key, stacks)
		instance.remaining_duration = maxf(instance.remaining_duration, remaining)
	instance.set_attribute_gain_source(key, false)
	instance.restoring_from_storage = true
	_apply_effects(instance)
	for index: int in range(mini(effect_states.size(), instance.status_data.effects.size())):
		var effect: StatusEffect = instance.status_data.effects[index]
		if effect != null and effect_states[index] is Dictionary:
			effect.restore_storage_state(instance, effect_states[index])
	instance.restoring_from_storage = false
	status_changed.emit()
	return instance


## 只清理属性增减状态中的临时来源，混合了装备护甲来源的状态不会把装备层数一并删除。
func clear_temporary_attribute_statuses() -> void:
	for status_id: StringName in statuses.keys().duplicate():
		var instance: StatusInstance = statuses[status_id]
		var has_attribute_effect: bool = false
		for effect: StatusEffect in instance.status_data.effects:
			if effect is StatusAddStatEffect or effect is StatusAddStatsEffect:
				has_attribute_effect = true
		if not has_attribute_effect:
			continue
		for source_key: String in instance.source_stacks.keys().duplicate():
			if bool(instance.attribute_gain_sources.get(source_key, true)):
				remove_status_source(status_id, source_key)


## 为指定来源登记可以拦截的负面状态次数。
func add_negative_status_blocker(source_key: Variant, charges: int) -> void:
	var key: String = str(source_key)
	if key.is_empty() or charges <= 0:
		return
	negative_status_blockers[key] = max(int(negative_status_blockers.get(key, 0)), charges)


## 移除指定来源的负面状态拦截次数。
func remove_negative_status_blocker(source_key: Variant) -> void:
	negative_status_blockers.erase(str(source_key))


func _consume_negative_status_blocker() -> bool:
	for key_variant in negative_status_blockers.keys().duplicate():
		var key: String = str(key_variant)
		var remaining: int = int(negative_status_blockers.get(key, 0))
		if remaining <= 0:
			negative_status_blockers.erase(key)
			continue

		remaining -= 1
		if remaining <= 0:
			negative_status_blockers.erase(key)
		else:
			negative_status_blockers[key] = remaining
		return true

	return false


func get_stats_controller() -> StatsController:
	if stats_controller == null:
		stats_controller = get_node_or_null("../StatsController") as StatsController
	return stats_controller


func _reapply_status(
	instance: StatusInstance,
	source: Node,
	source_key: Variant,
	added_stacks: int,
	duration_override: float = INF,
	attribute_gain_eligible: bool = true
) -> void:
	if instance.status_data == null:
		return

	# 先撤掉旧效果，再按新的总层数重新应用，避免属性修饰器残留。
	_remove_effects(instance)
	instance.source = source
	instance.source_key = source_key

	match instance.status_data.stack_mode:
		StatusData.StackMode.ADD_STACK:
			instance.add_source_stacks(source_key, added_stacks)
		StatusData.StackMode.REPLACE:
			instance.set_source_stacks(source_key, added_stacks)
		StatusData.StackMode.REFRESH:
			instance.set_source_stacks(source_key, added_stacks)
	instance.set_attribute_gain_source(source_key, attribute_gain_eligible)

	if instance.status_data.add_duration_on_reapply:
		instance.add_duration(
			duration_override,
			added_stacks,
			instance.status_data.max_duration,
			instance.status_data.duration_add_scales_with_stacks
		)
	elif instance.status_data.refresh_duration_on_reapply:
		instance.refresh_duration(duration_override)

	_apply_effects(instance)


func _tick_status(instance: StatusInstance, delta: float) -> void:
	if instance.status_data == null:
		return

	for effect in instance.status_data.effects:
		if effect != null:
			effect.on_tick(instance, delta)

	if instance.is_temporary():
		instance.remaining_duration = max(instance.remaining_duration - delta, 0.0)
		if instance.remaining_duration <= 0.0:
			remove_status(instance.get_status_id())


func _apply_effects(instance: StatusInstance) -> void:
	if instance.status_data == null:
		return

	for effect in instance.status_data.effects:
		if effect != null:
			effect.on_apply(instance)


func _remove_effects(instance: StatusInstance) -> void:
	if instance.status_data == null:
		return

	for effect in instance.status_data.effects:
		if effect != null:
			effect.on_remove(instance)


func _emit_status_applied(status_id: StringName, source: Node, stacks: int) -> void:
	# 统一广播状态进入/刷新事件，让遗物、被动、事件房间无需侵入 StatusController 内部逻辑。
	if EventBus == null:
		return

	EventBus.status_applied.emit(target, status_id, source, max(stacks, 0))
