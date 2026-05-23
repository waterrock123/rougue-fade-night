class_name TagEffectRuntimeHelper
extends RefCounted


static func get_context_key(context: TagEffectContext) -> String:
	if context == null:
		return ""

	var owner_id := 0
	if context.effect_owner != null:
		owner_id = context.effect_owner.get_instance_id()
	return "%s:%s" % [str(owner_id), context.effect_key]


static func relic_has_tag(relic: Relic, target_tag: RelicTag) -> bool:
	if relic == null or target_tag == null:
		return false

	for relic_tag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == target_tag:
			return true
		if not relic_tag.tag_name.is_empty() and relic_tag.tag_name == target_tag.tag_name:
			return true

	return false


static func count_equipped_unique_relics_with_tag(player_build: PlayerBuild, target_tag: RelicTag) -> int:
	if player_build == null or player_build.player_equipment == null:
		return 0

	var seen_ids: Array[String] = []
	for slot in player_build.player_equipment.equip_slots:
		if slot == null or slot.item == null:
			continue
		if slot.item.id.is_empty() or seen_ids.has(slot.item.id):
			continue
		if relic_has_tag(slot.item, target_tag):
			seen_ids.append(slot.item.id)

	return seen_ids.size()


static func get_status_controller(owner: Node) -> StatusController:
	if owner == null:
		return null
	if owner.has_method("get_status_controller"):
		return owner.get_status_controller()
	return owner.get_node_or_null("StatusController") as StatusController


static func get_owner_entity(context: TagEffectContext) -> Entity:
	if context == null:
		return null
	return context.effect_owner as Entity
