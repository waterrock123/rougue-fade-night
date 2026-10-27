## 统计装备栏与背包中指定标签的不同装备，提供带上限的投射物总伤害与暴击率。
## 直接使用SkillContext，可同时运行于战斗角色和修整期构筑代理，不把局外面板漏掉。
class_name PassiveTaggedRelicBonusEffect
extends PassiveSkillEffect

@export var tag_name: StringName = &"弹药"
@export var damage_per_kind: float = 0.05
@export var max_damage_bonus: float = 0.25
@export var crit_per_kind: float = 0.0
@export var max_crit_bonus: float = 0.0
@export var required_damage_tags: Array[String] = ["projectile"]
var contexts: Dictionary = {}
var cached_counts: Dictionary = {}
var cast_callbacks: Dictionary = {}
var refresh_pending: bool = false


func apply(context: SkillContext) -> void:
	if context == null or not is_instance_valid(context.stats_controller):
		return
	remove(context)
	var key: String = _key(context)
	contexts[key] = context
	if not EventBus.inventory_update.is_connected(_queue_refresh):
		EventBus.inventory_update.connect(_queue_refresh)
		EventBus.equipment_update.connect(_queue_refresh)
	if is_instance_valid(context.ability_controller):
		var callback: Callable = _before_cast.bind(key)
		cast_callbacks[key] = callback
		context.ability_controller.cast_prepared.connect(callback)
	_refresh_context(context)


func remove(context: SkillContext) -> void:
	if context == null:
		return
	var key: String = _key(context)
	var callback: Callable = cast_callbacks.get(key, Callable())
	if is_instance_valid(context.ability_controller) and callback.is_valid():
		if context.ability_controller.cast_prepared.is_connected(callback):
			context.ability_controller.cast_prepared.disconnect(callback)
	cast_callbacks.erase(key)
	contexts.erase(key)
	cached_counts.erase(key)
	if is_instance_valid(context.stats_controller):
		context.stats_controller.clear_outgoing_damage_bonus_modifier(context.effect_key)
		context.stats_controller.clear_effect_modifiers(context.effect_key)
	if contexts.is_empty() and EventBus.inventory_update.is_connected(_queue_refresh):
		EventBus.inventory_update.disconnect(_queue_refresh)
		EventBus.equipment_update.disconnect(_queue_refresh)


func _queue_refresh() -> void:
	if refresh_pending:
		return
	refresh_pending = true
	_flush_refresh.call_deferred()


func _flush_refresh() -> void:
	refresh_pending = false
	for context: SkillContext in contexts.values():
		_refresh_context(context)


func _before_cast(_cast: AbilityContext, key: String) -> void:
	var context: SkillContext = contexts.get(key) as SkillContext
	if context != null:
		# 成本支付后再统计，刚消耗掉的最后一种弹药不会继续强化本次子弹。
		_refresh_context(context)


func _refresh_context(context: SkillContext) -> void:
	if not is_instance_valid(context.stats_controller):
		return
	var count: int = _unique_count(context.player_build)
	var key: String = _key(context)
	if int(cached_counts.get(key, -1)) == count:
		return
	cached_counts[key] = count
	var damage_bonus: float = minf(count * maxf(damage_per_kind, 0.0), maxf(max_damage_bonus, 0.0))
	var crit_bonus: float = minf(count * maxf(crit_per_kind, 0.0), maxf(max_crit_bonus, 0.0))
	context.stats_controller.set_outgoing_damage_bonus_modifier(context.effect_key, {
		"required_tags": required_damage_tags.duplicate(),
		"total_damage_percent_bonus": damage_bonus,
	})
	var modifiers: Array[Modifier] = []
	if crit_bonus > 0.0:
		modifiers.append(Modifier.create_flat(&"crit_chance", crit_bonus, context.effect_key))
	context.stats_controller.set_effect_modifiers(context.effect_key, modifiers)


func _unique_count(build: PlayerBuild) -> int:
	if build == null:
		return 0
	var seen: Dictionary = {}
	if build.player_inventory != null:
		for slot: Slot in build.player_inventory.slots:
			if slot != null:
				_record_relic(slot.item, seen)
	if build.player_equipment != null:
		for slot: Slot in build.player_equipment.equip_slots:
			if slot != null:
				_record_relic(slot.item, seen)
	return seen.size()


func _record_relic(relic: Relic, seen: Dictionary) -> void:
	if relic == null or relic.id.is_empty():
		return
	for tag: RelicTag in relic.tags:
		if tag != null and StringName(tag.tag_name) == tag_name:
			seen[relic.id] = true
			return


func _key(context: SkillContext) -> String:
	var controller_id: int = context.stats_controller.get_instance_id() if is_instance_valid(context.stats_controller) else 0
	return "%d:%s" % [controller_id, str(context.effect_key)]
