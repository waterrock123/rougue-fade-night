## 当这件装备自身拥有指定标签时，将其转换为另一件装备。背包与装备栏均可触发，不检查其他装备的标签。
class_name SelfTagTransformRelicEffect
extends RelicEffect

@export var required_tag: RelicTag
## 用路径避免两件装备相互引用时出现循环资源；目标资源在满足条件时才加载。
@export_file("*.tres") var result_relic_path: String
@export var preserve_upgrade: bool = true

var contexts: Dictionary = {}
var refresh_pending: bool = false


func on_activate(context: RelicContext, effect_key) -> void:
	if context == null or not is_instance_valid(context.owner):
		return
	var key: String = "%d:%s" % [context.owner.get_instance_id(), str(effect_key)]
	contexts[key] = context
	if not EventBus.inventory_update.is_connected(_request_refresh):
		EventBus.inventory_update.connect(_request_refresh)
	if not EventBus.equipment_update.is_connected(_request_refresh):
		EventBus.equipment_update.connect(_request_refresh)
	_request_refresh()


func on_deactivate(context: RelicContext, effect_key) -> void:
	if context != null and is_instance_valid(context.owner):
		contexts.erase("%d:%s" % [context.owner.get_instance_id(), str(effect_key)])
	if contexts.is_empty():
		if EventBus.inventory_update.is_connected(_request_refresh):
			EventBus.inventory_update.disconnect(_request_refresh)
		if EventBus.equipment_update.is_connected(_request_refresh):
			EventBus.equipment_update.disconnect(_request_refresh)


func _request_refresh() -> void:
	if refresh_pending:
		return
	refresh_pending = true
	_refresh.call_deferred()


func _refresh() -> void:
	refresh_pending = false
	# 延迟到本轮装备效果刷新结束，避免一边遍历装备，一边替换资源导致漏激活或重复激活。
	for context: RelicContext in contexts.values().duplicate():
		if not is_instance_valid(context.owner) or not _matches(context.own_relic):
			continue
		var build: PlayerBuild = _get_build(context)
		if build != null:
			_transform_in_build(build, context.own_relic)


func _matches(relic: Relic) -> bool:
	if relic == null or required_tag == null:
		return false
	for tag: RelicTag in relic.tags:
		if tag != null and (tag == required_tag or tag.tag_name == required_tag.tag_name):
			return true
	return false


func _transform_in_build(build: PlayerBuild, original: Relic) -> void:
	var slots: Array[Slot] = []
	if build.player_inventory != null:
		slots.append_array(build.player_inventory.slots)
	if build.player_equipment != null:
		slots.append_array(build.player_equipment.equip_slots)
	for slot: Slot in slots:
		if slot == null or slot.item != original:
			continue
		var template: Relic = load(result_relic_path) as Relic
		if template == null or template.id == original.id:
			return
		var result: Relic = template.duplicate(true) as Relic
		if preserve_upgrade:
			result.leveltip = original.leveltip
		result.is_temporary = original.is_temporary
		result.temporary_source_key = original.temporary_source_key
		result.accumulated_stat_bonuses = original.accumulated_stat_bonuses.duplicate(true)
		if result.is_temporary:
			result.relic_name = "临时" + result.relic_name
		slot.item = result
		# 转换不是“新获得”或“合成升级”，不额外触发获得奖励或免费三选一。
		EventBus.inventory_update.emit()
		EventBus.equipment_update.emit()
		return


func _get_build(context: RelicContext) -> PlayerBuild:
	if is_instance_valid(context.relic_controller) and context.relic_controller.player_build != null:
		return context.relic_controller.player_build
	if context.owner is Entity:
		var entity: Entity = context.owner as Entity
		return entity.stats_controller.player_build if entity.stats_controller != null else null
	return null
