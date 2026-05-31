## 遗物效果：拥有者造成伤害后，按概率给受击目标添加状态。
## 可按技能栏位、伤害标签、伤害类型、目标已有状态筛选，适合麻痹戒指/中毒/燃烧等装备词条。
class_name OutgoingDamageStatusChanceEffect
extends RelicEffect


@export var status_data: StatusData
@export_range(0.0, 1.0, 0.01) var chance: float = 0.05
@export var stacks: int = 1
## 状态持续时间覆盖。INF 表示使用 StatusData 默认 duration。
@export var duration_override: float = INF
## 如果填写，只有指定技能栏位造成的伤害才触发。例如 [0] 表示基础攻击。
@export var target_slot_indices: Array[int] = []
## 如果填写，只有 DamageData.tags 中包含全部标签时才会触发。
@export var required_tags: Array[String] = []
## 如果填写，只有 DamageData.damage_types 中包含全部类型时才会触发。
@export var required_damage_types: Array[int] = []
## 如果填写，受击目标必须已经拥有这些状态才会触发。
@export var required_target_status_ids: Array[StringName] = []

var active_connections: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner(relic_context)
	if owner == null or status_data == null:
		return
	if active_connections.has(str(effect_key)):
		return

	var callback := Callable(self, "_on_damage_dealt").bind(relic_context, str(effect_key))
	if not owner.damage_dealt.is_connected(callback):
		owner.damage_dealt.connect(callback)
		active_connections[str(effect_key)] = {
			"owner": owner,
			"callable": callback,
		}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if not active_connections.has(key):
		return

	var entry := active_connections[key] as Dictionary
	var owner := entry.get("owner") as Entity
	var callback := entry.get("callable") as Callable
	if owner != null and owner.damage_dealt.is_connected(callback):
		owner.damage_dealt.disconnect(callback)
	active_connections.erase(key)


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
	if not _target_status_matches(damage_data.target):
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
	if not target_slot_indices.is_empty() and not target_slot_indices.has(damage_data.source_ability_slot_index):
		return false

	for required_tag in required_tags:
		if not damage_data.tags.has(required_tag):
			return false

	for required_damage_type in required_damage_types:
		if not damage_data.damage_types.has(required_damage_type):
			return false

	return true


func _target_status_matches(target: Entity) -> bool:
	if required_target_status_ids.is_empty():
		return true
	if target == null:
		return false

	var status_controller := target.get_status_controller()
	if status_controller == null:
		return false

	for status_id in required_target_status_ids:
		if not status_controller.has_status(status_id):
			return false
	return true


func _get_owner(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
