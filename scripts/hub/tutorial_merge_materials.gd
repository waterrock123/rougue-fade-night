@tool
class_name TutorialMergeMaterials
extends RefCounted


## 与真实 PlayerBuild 合成阈值一致；先检查容量再写入，失败不留下半套材料。
static func seed(build: PlayerBuild, material: Relic) -> bool:
	if build == null or material == null or build.player_inventory == null or build.player_equipment == null:
		return false
	var required: int = maxi(material.upgrade_merge_count, 2)
	var bag_slots: Array[Slot] = []
	for slot: Slot in build.player_inventory.slots:
		if _accepts_material(slot, material) and not slot.is_locked:
			bag_slots.append(slot)
	var equipped_slot: Slot
	for slot: Slot in build.player_equipment.equip_slots:
		if _accepts_material(slot, material):
			equipped_slot = slot
			break
	# 除预置的 required-2 件外，还给最后购买的一件保留正常背包空格。
	if equipped_slot == null or bag_slots.size() < required - 1:
		return false
	equipped_slot.item = material.duplicate(true) as Relic
	for index: int in range(required - 2):
		bag_slots[index].item = material.duplicate(true) as Relic
	return true


static func _accepts_material(slot: Slot, material: Relic) -> bool:
	if slot == null or slot.item != null:
		return false
	for tag: RelicTag in material.tags:
		if tag != null and slot.limit_tag.has(tag.tag_name):
			return false
	return true


static func count(build: PlayerBuild, relic_id: String, upgraded: bool) -> int:
	var total: int = 0
	var groups: Array = [build.player_equipment.equip_slots, build.player_inventory.slots]
	for slots: Array in groups:
		for slot: Slot in slots:
			if slot == null or slot.item == null or slot.item.id != relic_id:
				continue
			if (slot.item.leveltip == Relic.LevelTip.LEVELUP) == upgraded:
				total += 1
	return total
