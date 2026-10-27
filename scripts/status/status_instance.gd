class_name StatusInstance
extends RefCounted

var status_data: StatusData
var controller: StatusController
var target: Node
var source: Node
var source_key: Variant
# 记录每个来源各自贡献了多少层，避免同 id 状态在卸载时互相误删。
var source_stacks: Dictionary = {}
## 是否为战斗获得的临时属性来源；装备/被动常驻来源显式标记false。
var attribute_gain_sources: Dictionary = {}
var stacks: int = 1
var remaining_duration: float = -1.0
var duration_revision: int = 0
var duration_adjusted_effect_revisions: Dictionary = {}
## 从存储箱恢复不是一次新的奖励，持续时间和一次性副作用应保留原结算结果。
var restoring_from_storage: bool = false


func _init(
	new_status_data: StatusData,
	new_controller: StatusController,
	new_target: Node,
	new_source: Node = null,
	new_source_key: Variant = null,
	initial_stacks: int = 1,
	duration_override: float = INF
) -> void:
	status_data = new_status_data
	controller = new_controller
	target = new_target
	source = new_source
	source_key = new_source_key
	if status_data != null:
		remaining_duration = status_data.duration if is_inf(duration_override) else duration_override
	set_source_stacks(new_source_key, initial_stacks)


func get_status_id() -> StringName:
	if status_data == null:
		return &""
	return status_data.id


func get_effect_key(effect_index: int = -1) -> String:
	# 效果 key 只跟状态 id 相关，让同 id 的多来源状态合并成一条总效果。
	var base_key := "status_%s" % String(get_status_id())
	if effect_index >= 0:
		return "%s_effect_%s" % [base_key, effect_index]
	return base_key


func set_source_stacks(stack_source_key: Variant, amount: int) -> void:
	# REPLACE/REFRESH 模式会覆盖当前来源的层数，但不影响其他来源。
	var normalized_key := _normalize_source_key(stack_source_key)
	source_stacks[normalized_key] = max(amount, 0)
	_recalculate_stacks()


func add_source_stacks(stack_source_key: Variant, amount: int) -> void:
	# ADD_STACK 模式会在当前来源上继续累加层数。
	var normalized_key := _normalize_source_key(stack_source_key)
	var current_amount := int(source_stacks.get(normalized_key, 0))
	source_stacks[normalized_key] = max(current_amount + max(amount, 1), 0)
	_recalculate_stacks()


func remove_source(stack_source_key: Variant) -> void:
	source_stacks.erase(_normalize_source_key(stack_source_key))
	attribute_gain_sources.erase(_normalize_source_key(stack_source_key))
	_recalculate_stacks()


func consume_stacks(amount: int) -> int:
	var remaining_amount: int = max(amount, 0)
	if remaining_amount <= 0:
		return 0

	var consumed_amount: int = 0
	for stack_source_key in source_stacks.keys().duplicate():
		if remaining_amount <= 0:
			break

		var current_amount: int = int(source_stacks.get(stack_source_key, 0))
		if current_amount <= 0:
			source_stacks.erase(stack_source_key)
			continue

		var consume_amount: int = min(current_amount, remaining_amount)
		current_amount -= consume_amount
		remaining_amount -= consume_amount
		consumed_amount += consume_amount

		if current_amount <= 0:
			source_stacks.erase(stack_source_key)
		else:
			source_stacks[stack_source_key] = current_amount

	_recalculate_stacks()
	return consumed_amount


func has_no_sources() -> bool:
	return source_stacks.is_empty() or stacks <= 0


func is_temporary() -> bool:
	return remaining_duration > 0.0


func refresh_duration(duration_override: float = INF) -> void:
	if status_data == null:
		return
	remaining_duration = status_data.duration if is_inf(duration_override) else duration_override
	duration_revision += 1


func add_duration(
	duration_override: float = INF,
	added_stacks: int = 1,
	max_duration_override: float = -1.0,
	scale_with_stacks: bool = true
) -> void:
	if status_data == null:
		return

	var base_duration: float = status_data.duration if is_inf(duration_override) else duration_override
	if base_duration <= 0.0:
		return

	var added_duration: float = base_duration
	if scale_with_stacks:
		added_duration *= float(max(added_stacks, 1))

	var current_duration: float = max(remaining_duration, 0.0)
	remaining_duration = current_duration + added_duration

	var duration_cap: float = max_duration_override
	if duration_cap <= 0.0:
		duration_cap = status_data.duration
	if duration_cap > 0.0:
		remaining_duration = min(remaining_duration, duration_cap)

	duration_revision += 1


func _recalculate_stacks() -> void:
	for key: String in attribute_gain_sources.keys():
		if not source_stacks.has(key):
			attribute_gain_sources.erase(key)
	var total := 0
	for stack_count in source_stacks.values():
		total += int(stack_count)

	if status_data != null:
		total = min(total, max(status_data.max_stacks, 1))
	stacks = max(total, 0)


func set_attribute_gain_source(stack_source_key: Variant, eligible: bool) -> void:
	attribute_gain_sources[_normalize_source_key(stack_source_key)] = eligible


## 达到状态层数上限时优先保留常驻来源，不能把被上限截掉的新增层数转成永久奖励。
func get_attribute_gain_stacks() -> int:
	var permanent_count: int = 0
	for key: String in source_stacks:
		if not bool(attribute_gain_sources.get(key, true)):
			permanent_count += int(source_stacks[key])
	return maxi(stacks - permanent_count, 0)


func _normalize_source_key(stack_source_key: Variant) -> String:
	if stack_source_key == null:
		return "__default__"
	return str(stack_source_key)
