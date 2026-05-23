## 遗物效果：释放主动技能后，按概率给自己添加一个状态。
## 适合“瞌睡虫：释放主动技能后有概率睡着”这类带副作用的装备。
class_name ActiveSkillSelfStatusChanceEffect
extends RelicEffect

@export var status_data: StatusData
@export_range(0.0, 1.0, 0.01) var chance: float = 0.1
@export var stacks: int = 1
## 状态持续时间覆盖。INF 表示使用 StatusData 默认 duration。
@export var duration_override: float = INF

var _active_connections: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner(relic_context)
	if owner == null or status_data == null:
		return
	if _active_connections.has(str(effect_key)):
		return

	var ability_controller := owner.get_node_or_null("AbilityController") as AbilityController
	if ability_controller == null:
		return

	var callback := Callable(self, "_on_ability_triggered").bind(relic_context, str(effect_key))
	if not ability_controller.ability_triggered.is_connected(callback):
		ability_controller.ability_triggered.connect(callback)
		_active_connections[str(effect_key)] = {
			"controller": ability_controller,
			"callable": callback,
		}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if not _active_connections.has(key):
		return

	var entry := _active_connections[key] as Dictionary
	var ability_controller := entry.get("controller") as AbilityController
	var callback := entry.get("callable") as Callable
	if ability_controller != null and ability_controller.ability_triggered.is_connected(callback):
		ability_controller.ability_triggered.disconnect(callback)
	_active_connections.erase(key)


func _on_ability_triggered(_ability: Ability, caster: Entity, relic_context: RelicContext, effect_key: String) -> void:
	if caster == null or relic_context == null or caster != relic_context.owner:
		return
	if randf() > chance:
		return

	var status_controller := caster.get_status_controller()
	if status_controller == null:
		return

	status_controller.add_status(status_data, caster, effect_key, stacks, duration_override)


func _get_owner(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
