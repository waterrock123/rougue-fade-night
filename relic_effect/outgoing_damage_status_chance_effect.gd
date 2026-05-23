## 遗物效果：拥有者造成伤害后，按概率给受击目标添加状态。
## 适合“造成伤害概率睡眠/中毒/燃烧”等装备词条。
class_name OutgoingDamageStatusChanceEffect
extends RelicEffect

@export var status_data: StatusData
@export_range(0.0, 1.0, 0.01) var chance: float = 0.05
@export var stacks: int = 1
## 状态持续时间覆盖。INF 表示使用 StatusData 默认 duration。
@export var duration_override: float = INF
## 如果填写，只有 DamageData.tags 中包含全部标签时才会触发。
@export var required_tags: Array[String] = []
## 如果填写，只有 DamageData.damage_types 中包含全部类型时才会触发。
@export var required_damage_types: Array[int] = []

var _active_connections: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner(relic_context)
	if owner == null or status_data == null:
		return
	if _active_connections.has(str(effect_key)):
		return

	var callback := Callable(self, "_on_damage_dealt").bind(relic_context, str(effect_key))
	if not owner.damage_dealt.is_connected(callback):
		owner.damage_dealt.connect(callback)
		_active_connections[str(effect_key)] = {
			"owner": owner,
			"callable": callback,
		}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if not _active_connections.has(key):
		return

	var entry := _active_connections[key] as Dictionary
	var owner := entry.get("owner") as Entity
	var callback := entry.get("callable") as Callable
	if owner != null and owner.damage_dealt.is_connected(callback):
		owner.damage_dealt.disconnect(callback)
	_active_connections.erase(key)


func _on_damage_dealt(damage_data: DamageData, relic_context: RelicContext, effect_key: String) -> void:
	if damage_data == null or relic_context == null:
		return
	if damage_data.final_damage <= 0.0:
		return
	if damage_data.target == null or not is_instance_valid(damage_data.target):
		return
	if damage_data.target == relic_context.owner:
		return
	if not _damage_matches(damage_data):
		return
	if randf() > chance:
		return

	var target := damage_data.target
	var status_controller := target.get_status_controller()
	if status_controller == null:
		return

	var source_key := "%s_%s" % [effect_key, status_data.id]
	status_controller.add_status(status_data, relic_context.owner, source_key, stacks, duration_override)


func _damage_matches(damage_data: DamageData) -> bool:
	for required_tag in required_tags:
		if not damage_data.tags.has(required_tag):
			return false

	for required_damage_type in required_damage_types:
		if not damage_data.damage_types.has(required_damage_type):
			return false

	return true


func _get_owner(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
