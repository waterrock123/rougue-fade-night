## 受到伤害时给伤害来源施加状态的通用遗物效果。
## 适合“玻璃碎片造成流血”“毒刺反给中毒”等被击触发型装备复用。
class_name DamageTakenApplyStatusToSourceEffect
extends RelicEffect

## 要施加给攻击者的状态。
@export var status_data: StatusData
## 每次触发施加的层数。
@export var stacks: int = 1
## 本次状态持续时间覆盖。INF 表示使用 StatusData 的默认 duration。
@export var duration_override: float = INF
## 只有实际扣血时才触发，避免被闪避或无敌时也反挂状态。
@export var require_positive_damage: bool = true
## 忽略这些入站伤害标签，避免流血、灼烧、反伤等持续伤害反复触发自己。
@export var ignored_incoming_tags: Array[String] = ["status", "bleed", "burn", "retaliation", "reflect"]

var active_connections: Dictionary = {}


## 装备生效时监听拥有者受伤信号。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null or status_data == null:
		return

	var key := str(effect_key)
	if active_connections.has(key):
		return

	var callback := Callable(self, "_on_owner_damage_taken").bind(relic_context, key)
	owner.damage_taken.connect(callback)
	active_connections[key] = {
		"owner": owner,
		"callback": callback,
	}


## 卸下装备时断开监听，防止全局信号残留。
func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if not active_connections.has(key):
		return

	var entry := active_connections[key] as Dictionary
	var owner := entry.get("owner") as Entity
	var callback := entry.get("callback") as Callable
	if owner != null and is_instance_valid(owner) and owner.damage_taken.is_connected(callback):
		owner.damage_taken.disconnect(callback)

	active_connections.erase(key)


func _on_owner_damage_taken(damage_data: DamageData, relic_context: RelicContext, effect_key: String) -> void:
	if not _can_apply_status(damage_data, relic_context):
		return

	var attacker := damage_data.source
	var status_controller := attacker.get_status_controller()
	if status_controller == null:
		status_controller = attacker.get_node_or_null("StatusController") as StatusController
	if status_controller == null:
		return

	var source_key := "%s_%s" % [effect_key, status_data.id]
	status_controller.add_status(status_data, relic_context.owner, source_key, stacks, duration_override)


func _can_apply_status(damage_data: DamageData, relic_context: RelicContext) -> bool:
	if damage_data == null or relic_context == null or status_data == null:
		return false
	if require_positive_damage and damage_data.final_damage <= 0.0:
		return false
	if _has_ignored_tag(damage_data):
		return false
	if damage_data.source == null or not is_instance_valid(damage_data.source):
		return false
	if damage_data.source == relic_context.owner:
		return false
	if damage_data.source.is_dead:
		return false
	return true


func _has_ignored_tag(damage_data: DamageData) -> bool:
	for tag in ignored_incoming_tags:
		if damage_data.tags.has(tag):
			return true
	return false


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
