class_name OutgoingDamageRandomStatusChanceEffect
extends RelicEffect

## 造成伤害后按概率从状态池中随机挑一个施加给目标。
## 当前用于“附魔子弹”：投射物命中时随机附加冻结、麻痹、灼烧或流血。

@export var status_pool: Array[StatusData] = []
@export_range(0.0, 1.0, 0.01) var chance: float = 0.02
## 小于 0 时升级态仍使用 chance；大于等于 0 时升级态使用该概率。
@export_range(-1.0, 1.0, 0.01) var levelup_chance: float = -1.0
@export var stacks: int = 1
@export var duration_override: float = INF
@export var target_slot_indices: Array[int] = []
@export var required_tags: Array[String] = []
@export var required_damage_types: Array[int] = []
@export var required_target_status_ids: Array[StringName] = []

var active_connections: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner(relic_context)
	if owner == null or status_pool.is_empty():
		return

	var key: String = str(effect_key)
	if active_connections.has(key):
		return

	var callback: Callable = Callable(self, "_on_damage_dealt").bind(relic_context, key)
	if not owner.damage_dealt.is_connected(callback):
		owner.damage_dealt.connect(callback)
		active_connections[key] = {
			"owner": owner,
			"callable": callback,
		}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	if not active_connections.has(key):
		return

	var entry: Dictionary = active_connections[key] as Dictionary
	var owner: Entity = entry.get("owner") as Entity
	var callback: Callable = entry.get("callable") as Callable
	if owner != null and is_instance_valid(owner) and owner.damage_dealt.is_connected(callback):
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
	if randf() > _get_chance(relic_context):
		return

	var status_data: StatusData = _pick_status_data()
	if status_data == null:
		return

	var status_controller: StatusController = damage_data.target.get_status_controller()
	if status_controller == null:
		return

	var source_key: String = "%s_%s" % [effect_key, String(status_data.id)]
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

	var status_controller: StatusController = target.get_status_controller()
	if status_controller == null:
		return false

	for status_id in required_target_status_ids:
		if not status_controller.has_status(status_id):
			return false
	return true


func _pick_status_data() -> StatusData:
	if status_pool.is_empty():
		return null

	var index: int = randi_range(0, status_pool.size() - 1)
	return status_pool[index]


func _get_chance(relic_context: RelicContext) -> float:
	if relic_context != null and relic_context.own_relic != null:
		if relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP and levelup_chance >= 0.0:
			return clamp(levelup_chance, 0.0, 1.0)
	return clamp(chance, 0.0, 1.0)


func _get_owner(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
