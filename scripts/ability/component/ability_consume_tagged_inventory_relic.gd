## 主动技能额外成本组件：释放前要求背包里存在指定 tag 的遗物，并在释放时消耗其中一件。
## 适合眼镜蛇大炮这类“需要弹药/材料才能释放”的技能；消耗行为统一走 RelicConsumption，便于触发遗物的 consumed 效果。
class_name AbilityConsumeTaggedInventoryRelic
extends AbilityComponent

@export var required_tag: RelicTag
@export var required_tag_name: StringName = &""
@export var consume_locked_slots: bool = true
@export var missing_message: String = "缺少必要材料，无法释放技能"
@export var consume_key_prefix: String = "ability_cost"
@export_group("地图补给")
## 开启后，技能会优先尝试消耗附近弹药箱的次数；没有可用弹药箱时才消耗背包装备。
@export var use_map_ammo_box: bool = true
@export var ammo_box_group: StringName = &"ammo_box"


func can_pay_ability_cost(context: AbilityContext) -> bool:
	if _find_available_ammo_box(context) != null:
		return true

	return _find_target_slot(context) != null


func get_ability_cost_block_reason(_context: AbilityContext) -> String:
	return missing_message


func pay_ability_cost(context: AbilityContext) -> bool:
	var ammo_box: AmmoBox = _find_available_ammo_box(context)
	if ammo_box != null and ammo_box.consume_ammo(context.caster, required_tag, required_tag_name):
		return true

	var target_slot: Slot = _find_target_slot(context)
	if target_slot == null or target_slot.item == null:
		return false
	if context == null or context.caster == null:
		return false

	var relic_controller: RelicController = _resolve_relic_controller(context.caster)
	var consume_key: String = _build_consume_key(context, target_slot.item)
	var consumed_relic: Relic = RelicConsumption.consume_slot(
		target_slot,
		context.caster,
		relic_controller,
		consume_key,
		true
	)
	return consumed_relic != null


func _activate(_context: AbilityContext) -> void:
	# 这个组件只负责释放前成本，不参与普通 AbilityComponent 自动执行链。
	pass


func _find_target_slot(context: AbilityContext) -> Slot:
	if context == null or context.caster == null:
		return null

	var inventory: Inventory = _resolve_inventory(context.caster)
	if inventory == null:
		return null

	for slot_index in range(inventory.slots.size()):
		if not consume_locked_slots and inventory.is_slot_locked_for_use(slot_index):
			continue

		var slot: Slot = inventory.slots[slot_index]
		if slot == null or slot.item == null:
			continue
		if _relic_has_required_tag(slot.item):
			return slot

	return null


func _find_available_ammo_box(context: AbilityContext) -> AmmoBox:
	if not use_map_ammo_box:
		return null
	if context == null or context.caster == null:
		return null
	if not context.caster.is_inside_tree():
		return null

	var best_box: AmmoBox
	var best_distance: float = INF
	var boxes: Array = context.caster.get_tree().get_nodes_in_group(String(ammo_box_group))
	for node in boxes:
		var ammo_box: AmmoBox = node as AmmoBox
		if ammo_box == null:
			continue
		if not ammo_box.can_supply_ammo(context.caster, required_tag, required_tag_name):
			continue

		var distance: float = context.caster.global_position.distance_to(ammo_box.global_position)
		if distance < best_distance:
			best_distance = distance
			best_box = ammo_box

	return best_box


func _resolve_inventory(caster: Entity) -> Inventory:
	if caster == null:
		return null

	var inventory_value: Variant = caster.get("player_inventory")
	if inventory_value is Inventory:
		return inventory_value as Inventory

	return null


func _resolve_relic_controller(caster: Entity) -> RelicController:
	if caster == null:
		return null

	return caster.get_node_or_null("RelicController") as RelicController


func _relic_has_required_tag(relic: Relic) -> bool:
	if relic == null:
		return false

	for tag in relic.tags:
		var relic_tag: RelicTag = tag as RelicTag
		if relic_tag == null:
			continue
		if _tag_matches(relic_tag):
			return true

	return false


func _tag_matches(relic_tag: RelicTag) -> bool:
	if relic_tag == null:
		return false

	if required_tag != null:
		if relic_tag == required_tag:
			return true
		if not relic_tag.resource_path.is_empty() and relic_tag.resource_path == required_tag.resource_path:
			return true

	if required_tag_name != &"" and StringName(relic_tag.tag_name) == required_tag_name:
		return true

	return false


func _build_consume_key(context: AbilityContext, relic: Relic) -> String:
	var ability_id := "ability"
	if context != null and context.ability != null:
		ability_id = String(context.ability.id)

	var relic_id := "relic"
	if relic != null and not relic.id.is_empty():
		relic_id = relic.id

	return "%s_%s_%s_%s" % [consume_key_prefix, ability_id, relic_id, Time.get_ticks_msec()]
