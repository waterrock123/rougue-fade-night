## 遗物效果：当拥有者进入指定状态时触发奖励。
## 可复用给“睡眠时回血/加属性”“冻结时获得护甲”“中毒时获得攻击力”等条件型装备。
class_name StatusEnterRewardEffect
extends RelicEffect

const DEFAULT_RANDOM_PRIMARY_STATS: Array[StringName] = [
	&"strength",
	&"dexterity",
	&"intelligence",
	&"constitution",
	&"speed",
	&"charm",
	&"luck",
]

@export var watched_status_id: StringName = &"sleep"
@export var trigger_once_per_activate: bool = true
@export var ignore_when_relic_levelup: bool = false

@export_group("Heal")
@export_range(0.0, 1.0, 0.01) var heal_max_health_percent: float = 0.1

@export_group("Random Stat")
@export var random_primary_stats: Array[StringName] = DEFAULT_RANDOM_PRIMARY_STATS
@export var random_stat_amount: float = 1.0
@export var random_stat_status_name: String = "安眠帽祝福"
@export_multiline var random_stat_status_desc: String = "本场战斗中获得随机一级属性提升。"
@export var random_stat_status_icon: Texture2D

var records: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or relic_context.owner == null:
		return
	if ignore_when_relic_levelup and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return

	var status_controller := _get_status_controller(relic_context)
	if status_controller == null:
		return

	var key := str(effect_key)
	var callback := Callable(self, "_on_status_changed").bind(key)
	records[key] = {
		"context": relic_context,
		"controller": status_controller,
		"callback": callback,
		"had_status": status_controller.has_status(watched_status_id),
		"triggered": false,
		"trigger_count": 0,
	}

	if not status_controller.status_changed.is_connected(callback):
		status_controller.status_changed.connect(callback)


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	var record = records.get(key)
	if not (record is Dictionary):
		return

	var status_controller := record.get("controller") as StatusController
	var callback := record.get("callback") as Callable
	if status_controller != null and is_instance_valid(status_controller) and status_controller.status_changed.is_connected(callback):
		status_controller.status_changed.disconnect(callback)

	records.erase(key)


func _on_status_changed(record_key: String) -> void:
	var record = records.get(record_key)
	if not (record is Dictionary):
		return

	var status_controller := record.get("controller") as StatusController
	if status_controller == null or not is_instance_valid(status_controller):
		records.erase(record_key)
		return

	var has_status := status_controller.has_status(watched_status_id)
	var had_status := bool(record.get("had_status", false))
	record["had_status"] = has_status

	if not has_status or had_status:
		return
	if trigger_once_per_activate and bool(record.get("triggered", false)):
		return

	record["triggered"] = true
	record["trigger_count"] = int(record.get("trigger_count", 0)) + 1
	var relic_context := record.get("context") as RelicContext
	_apply_rewards(relic_context, record_key, int(record["trigger_count"]))


func _apply_rewards(relic_context: RelicContext, record_key: String, trigger_count: int) -> void:
	_heal_owner(relic_context)
	_apply_random_primary_stat_status(relic_context, record_key, trigger_count)


func _heal_owner(relic_context: RelicContext) -> void:
	if heal_max_health_percent <= 0.0 or relic_context == null or not (relic_context.owner is Entity):
		return

	var owner := relic_context.owner as Entity
	var heal_amount := owner.max_health * heal_max_health_percent
	owner.current_health = min(owner.current_health + heal_amount, owner.max_health)

	if owner.stats_controller != null:
		owner.stats_controller.current_health = owner.current_health
		owner.stats_controller.sync_runtime_resources()

	if owner.is_in_group("player"):
		EventBus.player_health_changed.emit(owner.current_health, owner.max_health)


func _apply_random_primary_stat_status(relic_context: RelicContext, record_key: String, trigger_count: int) -> void:
	if random_stat_amount == 0.0 or random_primary_stats.is_empty():
		return

	var status_controller := _get_status_controller(relic_context)
	if status_controller == null:
		return

	var stat_name = random_primary_stats.pick_random()
	var reward_status := _build_random_stat_status(record_key, trigger_count, stat_name)
	status_controller.add_status(reward_status, relic_context.owner, "%s_%s" % [record_key, trigger_count], 1)


func _build_random_stat_status(record_key: String, trigger_count: int, stat_name: StringName) -> StatusData:
	var stat_effect := StatusAddStatEffect.new()
	stat_effect.stat_name = stat_name
	stat_effect.value_per_stack = random_stat_amount

	var status_data := StatusData.new()
	status_data.id = StringName("%s_random_%s_%s" % [record_key, String(stat_name), trigger_count])
	status_data.status_name = random_stat_status_name
	status_data.desc = "%s：%s +%s" % [random_stat_status_desc, _get_primary_stat_display_name(stat_name), str(random_stat_amount)]
	status_data.icon = random_stat_status_icon
	status_data.duration = -1.0
	status_data.max_stacks = 1
	status_data.stack_mode = StatusData.StackMode.REPLACE
	status_data.refresh_duration_on_reapply = false
	status_data.effects = [stat_effect]
	return status_data


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


func _get_status_controller(relic_context: RelicContext) -> StatusController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_status_controller()
	if relic_context.owner != null and relic_context.owner.has_method("get_status_controller"):
		return relic_context.owner.get_status_controller()
	if relic_context.owner != null:
		return relic_context.owner.get_node_or_null("StatusController") as StatusController
	return null
