## 遗物效果：指定 tag 的套装效果处于激活状态时，周期性治疗拥有者。
## 如果当前场景里没有 TagEffectController，则按 fallback_required_count 做兜底判断。
class_name TagActivePeriodicHealEffect
extends RelicEffect


@export var target_tag: RelicTag
@export var fallback_required_count: int = 3
@export var interval: float = 10.0
@export var heal_stat: StringName = &"constitution"
@export var heal_multiplier: float = 0.5
@export var minimum_heal: float = 0.0

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or target_tag == null or interval <= 0.0:
		return

	var key: String = str(effect_key)
	active_contexts[key] = relic_context
	_schedule_next_tick(key)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))


func _schedule_next_tick(effect_key: String) -> void:
	var relic_context: RelicContext = active_contexts.get(effect_key) as RelicContext
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null:
		active_contexts.erase(effect_key)
		return

	var tree: SceneTree = owner.get_tree()
	if tree == null:
		active_contexts.erase(effect_key)
		return

	var timer: SceneTreeTimer = tree.create_timer(interval)
	timer.timeout.connect(Callable(self, "_on_timer_timeout").bind(effect_key))


func _on_timer_timeout(effect_key: String) -> void:
	if not active_contexts.has(effect_key):
		return

	var relic_context: RelicContext = active_contexts.get(effect_key) as RelicContext
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or owner.is_dead:
		active_contexts.erase(effect_key)
		return

	if _is_target_tag_effect_active(owner, relic_context):
		var heal_amount: float = _get_heal_amount(owner)
		if heal_amount > 0.0:
			owner.apply_heal(heal_amount)

	_schedule_next_tick(effect_key)


func _is_target_tag_effect_active(owner: Entity, relic_context: RelicContext) -> bool:
	var controller: TagEffectController = _find_tag_effect_controller(owner)
	if controller != null:
		for snapshot_value in controller.get_snapshots():
			var snapshot: Dictionary = snapshot_value as Dictionary
			var tag: RelicTag = snapshot.get("tag") as RelicTag
			if not _is_same_tag(tag, target_tag):
				continue
			if bool(snapshot.get("is_active", false)) or bool(snapshot.get("is_completed", false)):
				return true
		return false

	return _count_tag_relics_for_fallback(relic_context) >= fallback_required_count


func _count_tag_relics_for_fallback(relic_context: RelicContext) -> int:
	var equipment: Equipment = _get_equipment(relic_context)
	if equipment == null:
		return 0

	var seen_ids: Array[String] = []
	for slot: Slot in equipment.equip_slots:
		if slot == null or slot.item == null:
			continue

		var relic: Relic = slot.item
		if not relic.id.is_empty() and seen_ids.has(relic.id):
			continue
		if _relic_has_tag(relic, target_tag):
			seen_ids.append(relic.id)

	return seen_ids.size()


func _get_heal_amount(owner: Entity) -> float:
	var stat_value: float = 0.0
	if owner.stats_controller != null:
		stat_value = owner.stats_controller.get_stat(heal_stat)

	return max(stat_value * heal_multiplier, minimum_heal)


func _find_tag_effect_controller(owner: Entity) -> TagEffectController:
	if owner == null:
		return null

	var node: Node = owner
	while node != null:
		if node is TagEffectController:
			return node as TagEffectController
		var child: Node = node.get_node_or_null("TagEffectController")
		if child is TagEffectController:
			return child as TagEffectController
		child = node.get_node_or_null("BattleTagEffectController")
		if child is TagEffectController:
			return child as TagEffectController
		node = node.get_parent()

	return null


func _get_equipment(relic_context: RelicContext) -> Equipment:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null and relic_context.relic_controller.equipment_inventory != null:
		return relic_context.relic_controller.equipment_inventory
	if relic_context.owner is Player:
		return (relic_context.owner as Player).player_equipment
	return null


func _relic_has_tag(relic: Relic, tag: RelicTag) -> bool:
	if relic == null or tag == null:
		return false

	for relic_tag: RelicTag in relic.tags:
		if _is_same_tag(relic_tag, tag):
			return true

	return false


func _is_same_tag(a: RelicTag, b: RelicTag) -> bool:
	if a == null or b == null:
		return false
	return a == b or a.tag_name == b.tag_name


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
