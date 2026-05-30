## 装备“消耗”工具。
## 用具、主动技能、被动技能如果要销毁某件装备并触发“被消耗时”效果，都应该走这里。
class_name RelicConsumption
extends RefCounted

const DEFAULT_REASON := "consumed"


## 消耗一个 Slot 中的遗物，并清空该格子。
## owner/relic_controller 用来给被消耗遗物构造 RelicContext，方便它把奖励发回玩家构筑或运行时实体。
static func consume_slot(
	slot: Slot,
	owner: Node,
	relic_controller: RelicController = null,
	consume_key: String = "",
	emit_updates: bool = true
) -> Relic:
	if slot == null or slot.item == null:
		return null

	var relic = slot.item
	slot.item = null
	consume_relic(relic, owner, relic_controller, consume_key)

	if emit_updates:
		EventBus.inventory_update.emit()
		EventBus.equipment_update.emit()
		EventBus.attribute_update.emit()

	return relic


## 只触发某件遗物的“被消耗时”效果，不负责从任何容器移除。
## 少数特殊流程如果已经先移除了遗物，可以直接调用这个函数。
static func consume_relic(
	relic: Relic,
	owner: Node,
	relic_controller: RelicController = null,
	consume_key: String = ""
) -> void:
	if relic == null:
		return

	var final_key = consume_key
	if final_key.is_empty():
		final_key = "consumed_%s_%s" % [relic.id, Time.get_ticks_msec()]

	relic.consume_relic(owner, relic_controller, final_key)
	EventBus.relic_removed.emit(relic, DEFAULT_REASON)
