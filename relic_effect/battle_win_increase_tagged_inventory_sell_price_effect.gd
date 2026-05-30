## 战斗胜利时提升背包内指定 tag 遗物售价的通用效果。
## 适合“小罐盐”升级效果，也可复用于“锻造/腌制/打磨”类局内经济装备。
class_name BattleWinIncreaseTaggedInventorySellPriceEffect
extends RelicEffect

## 只处理拥有这个 tag 的遗物。
@export var target_tag: RelicTag
## 每次战斗胜利最多处理几件。
@export var max_relic_count: int = 2
## 每件遗物增加的出售价格。
@export var sell_price_bonus: int = 1
## 是否把装备栏也纳入范围。小罐盐描述是“背包内”，默认不包含装备栏。
@export var include_equipment: bool = false

var active_contexts: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if target_tag == null or sell_price_bonus == 0:
		return

	var key := str(effect_key)
	active_contexts[key] = relic_context
	if not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	active_contexts.erase(str(effect_key))
	if active_contexts.is_empty() and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)


func _on_battle_rewards_resolving() -> void:
	var contexts := active_contexts.duplicate()
	active_contexts.clear()
	if EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)

	for key in contexts.keys():
		var relic_context := contexts[key] as RelicContext
		_apply_sell_price_bonus(relic_context)


func _apply_sell_price_bonus(relic_context: RelicContext) -> void:
	var player_build := _get_player_build(relic_context)
	if player_build == null:
		return

	var changed_count := 0
	for slot in _get_candidate_slots(player_build):
		if slot == null or slot.item == null:
			continue
		if not _relic_has_tag(slot.item, target_tag):
			continue

		slot.item.sell_price += sell_price_bonus
		changed_count += 1
		if changed_count >= max_relic_count:
			break

	if changed_count > 0:
		EventBus.inventory_update.emit()
		EventBus.equipment_update.emit()


func _get_candidate_slots(player_build: PlayerBuild) -> Array[Slot]:
	var result: Array[Slot] = []
	if player_build.player_inventory != null:
		for slot in player_build.player_inventory.slots:
			result.append(slot)

	if include_equipment and player_build.player_equipment != null:
		for slot in player_build.player_equipment.equip_slots:
			result.append(slot)

	return result


func _get_player_build(relic_context: RelicContext) -> PlayerBuild:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build
	if relic_context.owner is Entity:
		var stats_controller := (relic_context.owner as Entity).stats_controller
		if stats_controller != null:
			return stats_controller.player_build
	return null


func _relic_has_tag(relic: Relic, target: RelicTag) -> bool:
	if relic == null or target == null:
		return false

	for relic_tag in relic.tags:
		if relic_tag == null:
			continue
		if relic_tag == target:
			return true
		if not relic_tag.tag_name.is_empty() and relic_tag.tag_name == target.tag_name:
			return true
	return false
