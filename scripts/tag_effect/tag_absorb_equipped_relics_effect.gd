## Tag 套装效果：一次性生成特殊遗物，并吸收当前装备栏中指定 tag 的遗物效果。
## 适合“指环王：获得特殊饰品，摧毁并吸收当前装备的所有饰品效果”。
class_name TagAbsorbEquippedRelicsEffect
extends TagEffect

@export var special_relic: Relic
@export var absorbed_relic_name_prefix: String = "吸收："


func on_activate(context: TagEffectContext) -> void:
	if context == null or context.player_build == null:
		return
	if special_relic == null or tag == null:
		return
	if context.is_once_completed():
		return

	var equipment := context.player_build.player_equipment
	if equipment == null:
		return

	var absorbed_relics := _collect_equipped_tag_relics(equipment)
	if absorbed_relics.size() < required_count:
		return

	var created_relic := _build_absorbed_relic(absorbed_relics)
	_remove_absorbed_relics(equipment)

	if context.player_build.add_relic(created_relic):
		context.mark_once_completed()
		EventBus.equipment_update.emit()
		EventBus.inventory_update.emit()


func _collect_equipped_tag_relics(equipment: Equipment) -> Array[Relic]:
	var result: Array[Relic] = []
	var seen_ids: Array[String] = []

	for slot in equipment.equip_slots:
		if slot == null or slot.item == null:
			continue

		var relic := slot.item
		if seen_ids.has(relic.id):
			continue
		if _relic_has_tag(relic):
			seen_ids.append(relic.id)
			result.append(relic)

	return result


func _remove_absorbed_relics(equipment: Equipment) -> void:
	for slot in equipment.equip_slots:
		if slot == null or slot.item == null:
			continue
		if _relic_has_tag(slot.item):
			EventBus.relic_removed.emit(slot.item, "destroyed")
			slot.item = null


func _build_absorbed_relic(absorbed_relics: Array[Relic]) -> Relic:
	var created := special_relic.duplicate(true) as Relic
	created.effects.clear()
	created.great_effects.clear()
	created.tooltip = ""
	created.desc = "这件饰品吸收了多个饰品的效果。"

	var absorbed_names: Array[String] = []
	for relic in absorbed_relics:
		if relic == null:
			continue

		absorbed_names.append(relic.relic_name)
		for effect in relic.effects:
			if effect != null:
				created.effects.append(effect.duplicate(true) as RelicEffect)
		if relic.leveltip == Relic.LevelTip.LEVELUP:
			for effect in relic.great_effects:
				if effect != null:
					created.effects.append(effect.duplicate(true) as RelicEffect)

	created.tooltip = "%s%s" % [absorbed_relic_name_prefix, "、".join(absorbed_names)]
	return created


func _relic_has_tag(relic: Relic) -> bool:
	if relic == null:
		return false

	for relic_tag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == tag:
			return true
		if not relic_tag.tag_name.is_empty() and relic_tag.tag_name == tag.tag_name:
			return true

	return false
