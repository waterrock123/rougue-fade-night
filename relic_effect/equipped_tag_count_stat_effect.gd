## 遗物效果：根据装备栏中带有指定 tag 的装备数量，动态提供属性修饰。
## 适合“每装备一件诅咒/火炎/饰品装备，获得若干一级属性”的通用效果。
class_name EquippedTagCountStatEffect
extends RelicEffect


@export var target_tag: RelicTag
@export var stat_bonuses_per_relic: Dictionary = {}
@export var exclude_own_relic: bool = true


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or target_tag == null:
		return

	var stats_controller: StatsController = _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	var count: int = _count_equipped_relics(relic_context)
	var modifiers: Array[Modifier] = _build_modifiers(count, str(effect_key))
	stats_controller.set_effect_modifiers(effect_key, modifiers)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var stats_controller: StatsController = _get_stats_controller(relic_context)
	if stats_controller == null:
		return

	stats_controller.clear_effect_modifiers(effect_key)


func _count_equipped_relics(relic_context: RelicContext) -> int:
	var equipment: Equipment = _get_equipment(relic_context)
	if equipment == null:
		return 0

	var count: int = 0
	for slot: Slot in equipment.equip_slots:
		if slot == null or slot.item == null:
			continue
		if exclude_own_relic and slot.item == relic_context.own_relic:
			continue
		if _relic_has_tag(slot.item, target_tag):
			count += 1

	return count


func _build_modifiers(count: int, effect_key: String) -> Array[Modifier]:
	var result: Array[Modifier] = []
	if count <= 0:
		return result

	for stat_name_variant in stat_bonuses_per_relic.keys():
		var stat_name: StringName = StringName(str(stat_name_variant))
		var bonus_per_relic: float = float(stat_bonuses_per_relic[stat_name_variant])
		var total_bonus: float = bonus_per_relic * float(count)
		if total_bonus != 0.0:
			result.append(Modifier.create_flat(stat_name, total_bonus, effect_key))

	return result


func _get_equipment(relic_context: RelicContext) -> Equipment:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null and relic_context.relic_controller.equipment_inventory != null:
		return relic_context.relic_controller.equipment_inventory
	if relic_context.owner is PlayerBuildProxy:
		var proxy: PlayerBuildProxy = relic_context.owner as PlayerBuildProxy
		if proxy.player_build != null:
			return proxy.player_build.player_equipment
	if relic_context.owner is Player:
		return (relic_context.owner as Player).player_equipment
	return null


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	if relic_context.owner is Entity:
		return (relic_context.owner as Entity).stats_controller
	if relic_context.owner != null:
		return relic_context.owner.get_node_or_null("StatsController") as StatsController
	return null


func _relic_has_tag(relic: Relic, tag: RelicTag) -> bool:
	if relic == null or tag == null:
		return false

	for relic_tag: RelicTag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == tag or relic_tag.tag_name == tag.tag_name:
			return true

	return false
