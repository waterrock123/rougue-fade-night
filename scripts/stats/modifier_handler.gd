class_name ModifierHandler
extends Node

var stats_controller: StatsController
var runtime_modifiers: Array[Modifier] = []


# 节点进入场景树后，延迟刷新一次修饰器列表。
# 这样可以确保所有子节点都已经准备好。
func _ready() -> void:
	call_deferred("_refresh_stats")


# 绑定对应的 StatsController。
# 后续只要修饰器变化，就通过它触发属性重算。
func bind_stats_controller(controller: StatsController) -> void:
	stats_controller = controller
	_refresh_stats()


# 添加运行时修饰器。
# 这种方式适合技能、装备效果或临时 buff 在代码里动态加入。
func add_runtime_modifier(modifier: Modifier) -> void:
	if modifier == null:
		return

	runtime_modifiers.append(modifier)
	_refresh_stats()


# 移除一个运行时修饰器，并刷新最终属性。
func remove_runtime_modifier(modifier: Modifier) -> void:
	if modifier == null:
		return

	runtime_modifiers.erase(modifier)
	_refresh_stats()


# 收集当前所有有效修饰器：
# 1. 代码动态添加的 runtime_modifiers
# 2. 挂在本节点下的 ModifierNode 子节点
func get_all_modifiers() -> Array[Modifier]:
	var result: Array[Modifier] = runtime_modifiers.duplicate()

	for child in get_children():
		if child is ModifierNode:
			var modifier_node := child as ModifierNode
			if modifier_node.is_modifier_enabled():
				result.append(modifier_node.build_modifier())

	return result


# 监听子节点增删或顺序变化。
# 一旦结构发生变化，就自动刷新修饰器并通知 StatsController 重算。
func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		call_deferred("_refresh_stats")


# 每帧推进限时修饰器的持续时间。
# 只要有修饰器失效，就重新刷新整套属性。
func _process(delta: float) -> void:
	var should_refresh := false

	for modifier in runtime_modifiers:
		if modifier != null and modifier.tick(delta):
			should_refresh = true

	runtime_modifiers = runtime_modifiers.filter(
		func(modifier: Modifier) -> bool:
			return modifier != null and modifier.is_active()
	)

	for child in get_children():
		if child is ModifierNode:
			var modifier_node := child as ModifierNode
			if modifier_node.enabled and modifier_node.duration > 0.0:
				modifier_node.duration = max(modifier_node.duration - delta, 0.0)
				if modifier_node.duration == 0.0:
					modifier_node.enabled = false
					should_refresh = true

	if should_refresh:
		_refresh_stats()


# 把当前全部修饰器同步给 StatsController，
# 由 StatsController 负责最终属性计算。
func _refresh_stats() -> void:
	if stats_controller == null:
		return

	stats_controller.set_modifiers(get_all_modifiers())
