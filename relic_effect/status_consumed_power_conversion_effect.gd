@tool
class_name StatusConsumedPowerConversionEffect
extends RelicEffect

## 监听指定状态被消耗，并把消耗过程转化为奖励。
## 当前用于“电磁转化器”：消耗电力后返还少量电力，并概率获得本场战斗内随机一级属性。

const DEFAULT_RANDOM_PRIMARY_STATS: Array[StringName] = [
	&"strength",
	&"dexterity",
	&"intelligence",
	&"constitution",
	&"speed",
	&"charm",
	&"luck",
]

@export var watched_status_id: StringName = &"power"
@export var refund_status_data: StatusData
@export var refund_stacks: int = 1
@export var ignore_when_relic_levelup: bool = false

@export_group("Random Stat")
@export_range(0.0, 1.0, 0.01) var random_stat_chance: float = 0.05
@export var random_primary_stats: Array[StringName] = DEFAULT_RANDOM_PRIMARY_STATS
@export var random_stat_amount: float = 1.0
@export var random_stat_status_name: String = "电磁转化"
@export_multiline var random_stat_status_desc: String = "本场战斗中获得随机一级属性提升。"
@export var random_stat_status_icon: Texture2D
@export var roll_per_consumed_stack: bool = false

var _active_records: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if _should_ignore_for_levelup_relic(relic_context):
		return

	var owner_entity: Entity = _get_owner_entity(relic_context)
	if owner_entity == null:
		return

	var status_controller: StatusController = owner_entity.get_status_controller()
	if status_controller == null:
		return

	var key: String = str(effect_key)
	if _active_records.has(key):
		return

	var callback: Callable = Callable(self, "_on_status_stacks_consumed").bind(owner_entity, key)
	status_controller.status_stacks_consumed.connect(callback)
	_active_records[key] = {
		"controller": status_controller,
		"callback": callback,
		"trigger_count": 0,
		"stat_status_sources": [],
	}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	if not _active_records.has(key):
		return

	var record: Dictionary = _active_records[key] as Dictionary
	var controller_candidate = record.get("controller", null)
	var callback: Callable = record.get("callback") as Callable
	var status_controller: StatusController = null
	if controller_candidate != null and is_instance_valid(controller_candidate) and controller_candidate is StatusController:
		status_controller = controller_candidate as StatusController

	if status_controller != null and callback.is_valid():
		if status_controller.status_stacks_consumed.is_connected(callback):
			status_controller.status_stacks_consumed.disconnect(callback)

	_clear_refunded_status(status_controller, key)
	_clear_random_stat_statuses(status_controller, record, key)
	_active_records.erase(key)


func _on_status_stacks_consumed(
	status_id: StringName,
	consumed_amount: int,
	owner_entity: Entity,
	effect_key: String
) -> void:
	if status_id != watched_status_id:
		return
	if consumed_amount <= 0:
		return
	if owner_entity == null or not is_instance_valid(owner_entity) or owner_entity.is_dead:
		return
	if not EventBus.is_battle_active:
		return
	if not _active_records.has(effect_key):
		return

	var status_controller: StatusController = owner_entity.get_status_controller()
	if status_controller == null:
		return

	_refund_status(status_controller, owner_entity, effect_key)
	_try_grant_random_stats(status_controller, owner_entity, consumed_amount, effect_key)


func _refund_status(status_controller: StatusController, owner_entity: Entity, effect_key: String) -> void:
	if refund_status_data == null or refund_stacks <= 0:
		return

	# 使用独立来源，避免返还的电力和原本被消耗的电力来源互相覆盖。
	status_controller.add_status(refund_status_data, owner_entity, "%s_refund" % effect_key, refund_stacks)


func _try_grant_random_stats(
	status_controller: StatusController,
	owner_entity: Entity,
	consumed_amount: int,
	effect_key: String
) -> void:
	if random_stat_chance <= 0.0 or random_stat_amount == 0.0 or random_primary_stats.is_empty():
		return

	var roll_count: int = consumed_amount if roll_per_consumed_stack else 1
	for roll_index in range(max(roll_count, 1)):
		if randf() > random_stat_chance:
			continue
		_grant_one_random_stat_status(status_controller, owner_entity, effect_key)


func _grant_one_random_stat_status(
	status_controller: StatusController,
	owner_entity: Entity,
	effect_key: String
) -> void:
	if not _active_records.has(effect_key):
		return

	var record: Dictionary = _active_records[effect_key] as Dictionary
	var trigger_count: int = int(record.get("trigger_count", 0)) + 1
	record["trigger_count"] = trigger_count
	_active_records[effect_key] = record

	var stat_name: StringName = StringName(random_primary_stats.pick_random())
	var status_data: StatusData = _build_random_stat_status(effect_key, trigger_count, stat_name)
	var source_key: String = "%s_random_stat_%s" % [effect_key, trigger_count]

	status_controller.add_status(status_data, owner_entity, source_key, 1)
	_record_stat_status_source(effect_key, status_data.id, source_key)


func _build_random_stat_status(effect_key: String, trigger_count: int, stat_name: StringName) -> StatusData:
	var stat_effect: StatusAddStatEffect = StatusAddStatEffect.new()
	stat_effect.stat_name = stat_name
	stat_effect.value_per_stack = random_stat_amount

	var status_data: StatusData = StatusData.new()
	status_data.id = StringName("%s_electromagnetic_%s_%s" % [effect_key, String(stat_name), trigger_count])
	status_data.status_name = "%s：%s" % [random_stat_status_name, _get_primary_stat_display_name(stat_name)]
	status_data.desc = "%s：%s +%s" % [random_stat_status_desc, _get_primary_stat_display_name(stat_name), str(random_stat_amount)]
	status_data.icon = random_stat_status_icon
	status_data.duration = -1.0
	status_data.max_stacks = 1
	status_data.stack_mode = StatusData.StackMode.REPLACE
	status_data.refresh_duration_on_reapply = false
	status_data.effects = [stat_effect]
	return status_data


func _record_stat_status_source(effect_key: String, status_id: StringName, source_key: String) -> void:
	if not _active_records.has(effect_key):
		return

	var record: Dictionary = _active_records[effect_key] as Dictionary
	var status_sources: Array = record.get("stat_status_sources", []) as Array
	status_sources.append({
		"status_id": status_id,
		"source_key": source_key,
	})
	record["stat_status_sources"] = status_sources
	_active_records[effect_key] = record


func _clear_refunded_status(status_controller: StatusController, effect_key: String) -> void:
	if refund_status_data == null:
		return
	if status_controller == null or not is_instance_valid(status_controller):
		return

	status_controller.remove_status_source(refund_status_data.id, "%s_refund" % effect_key)


func _clear_random_stat_statuses(status_controller: StatusController, record: Dictionary, effect_key: String) -> void:
	if status_controller == null or not is_instance_valid(status_controller):
		return

	var status_sources: Array = record.get("stat_status_sources", []) as Array
	for source_data in status_sources:
		if not (source_data is Dictionary):
			continue
		var status_source: Dictionary = source_data as Dictionary
		var status_id: StringName = StringName(str(status_source.get("status_id", &"")))
		var source_key: String = str(status_source.get("source_key", ""))
		if status_id == &"" or source_key.is_empty():
			continue
		status_controller.remove_status_source(status_id, source_key)


func _get_primary_stat_display_name(stat_name: StringName) -> String:
	match stat_name:
		&"strength":
			return "力量"
		&"dexterity":
			return "敏捷"
		&"intelligence":
			return "智力"
		&"constitution":
			return "体质"
		&"speed":
			return "速度"
		&"charm":
			return "魅力"
		&"luck":
			return "幸运"
		_:
			return String(stat_name)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity


func _should_ignore_for_levelup_relic(relic_context: RelicContext) -> bool:
	if not ignore_when_relic_levelup:
		return false
	if relic_context == null or relic_context.own_relic == null:
		return false
	return relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP
