class_name StatusInstance
extends RefCounted

var status_data: StatusData
var controller: StatusController
var target: Node
var source: Node
var source_key: Variant
# 记录每个来源各自贡献了多少层，避免同 id 状态在卸载时互相误删。
var source_stacks: Dictionary = {}
var stacks: int = 1
var remaining_duration: float = -1.0
var duration_revision: int = 0
var duration_adjusted_effect_revisions: Dictionary = {}


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
	_recalculate_stacks()


func has_no_sources() -> bool:
	return source_stacks.is_empty() or stacks <= 0


func is_temporary() -> bool:
	return remaining_duration > 0.0


func refresh_duration(duration_override: float = INF) -> void:
	if status_data == null:
		return
	remaining_duration = status_data.duration if is_inf(duration_override) else duration_override
	duration_revision += 1


func _recalculate_stacks() -> void:
	var total := 0
	for stack_count in source_stacks.values():
		total += int(stack_count)

	if status_data != null:
		total = min(total, max(status_data.max_stacks, 1))
	stacks = max(total, 0)


func _normalize_source_key(stack_source_key: Variant) -> String:
	if stack_source_key == null:
		return "__default__"
	return str(stack_source_key)
