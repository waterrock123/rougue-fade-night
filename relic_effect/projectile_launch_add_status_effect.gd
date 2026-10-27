## 每实际发射一颗自己的投射物，获得指定层数的状态；无需命中或造成伤害。
## 已获得的战斗增益由状态系统管理，装备刷新/卸下只停止监听，不撤销已积累的层数。
class_name ProjectileLaunchAddStatusEffect
extends RelicEffect

## 每次发射时赋予拥有者的状态，具体属性与叠层规则在状态资源中配置。
@export var status_data: StatusData
@export_range(1, 100, 1) var stacks: int = 1
## INF 使用状态资源默认持续时间；负数表示保留至当前战斗实体清理。
@export var duration_override: float = INF

var contexts: Dictionary = {}


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not (context.owner is Entity):
		return
	contexts["%s:%s" % [context.owner.get_instance_id(), effect_key]] = context
	if not EventBus.projectile_launched.is_connected(_on_launched):
		EventBus.projectile_launched.connect(_on_launched)


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context != null and is_instance_valid(context.owner):
		contexts.erase("%s:%s" % [context.owner.get_instance_id(), effect_key])
	_prune_invalid_contexts()
	if contexts.is_empty() and EventBus.projectile_launched.is_connected(_on_launched):
		EventBus.projectile_launched.disconnect(_on_launched)


func _on_launched(projectile: Node2D, context: AbilityContext, direction: Vector2) -> void:
	if status_data == null or context == null or not is_instance_valid(projectile):
		return
	if direction == Vector2.ZERO or not is_instance_valid(context.caster):
		return
	# 发射通知已在 AbilityManifest 中按投射物去重；额外子弹也是真实发射，应正常计数。
	for key: Variant in contexts.keys():
		var entry: RelicContext = contexts.get(key) as RelicContext
		if entry == null or not is_instance_valid(entry.owner):
			contexts.erase(key)
			continue
		if entry.owner != context.caster:
			continue
		var actor: Entity = entry.owner as Entity
		if actor.is_dead or not is_instance_valid(actor.status_controller):
			continue
		actor.status_controller.add_status(status_data, actor, key, stacks, duration_override)


func _prune_invalid_contexts() -> void:
	for key: Variant in contexts.keys():
		var entry: RelicContext = contexts.get(key) as RelicContext
		if entry == null or not is_instance_valid(entry.owner):
			contexts.erase(key)
