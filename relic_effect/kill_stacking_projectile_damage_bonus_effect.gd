## 每次由拥有者击杀敌人后，持续叠加飞行投射物伤害的通用遗物效果。
## 伤害加成只注册给 projectile 标签，抛射物和近战特效不会被误加成。
class_name KillStackingProjectileDamageBonusEffect
extends RelicEffect

@export_range(0.0, 10.0, 0.0001) var initial_bonus_percent: float = 0.02
@export_range(0.0, 10.0, 0.0001) var bonus_percent_per_kill: float = 0.02
@export_range(0.0, 20.0, 0.0001) var max_bonus_percent: float = 1.0
## 升级态遗物跳过这条基础效果，改由强化版本提供更高上限。
@export var ignore_when_owner_levelup: bool = false

var active_contexts: Dictionary = {}
var current_bonus_by_context: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null:
		return
	if ignore_when_owner_levelup and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return

	var context_id: String = _get_context_id(owner, effect_key)
	active_contexts[context_id] = {
		"relic_context": relic_context,
		"effect_key": effect_key,
	}
	current_bonus_by_context[context_id] = min(max(initial_bonus_percent, 0.0), max_bonus_percent)
	_refresh_bonus(relic_context, effect_key, context_id)
	if not EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.connect(_on_enemy_killed)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null:
		return

	var context_id: String = _get_context_id(owner, effect_key)
	var stats_controller: StatsController = _get_stats_controller(relic_context)
	if stats_controller != null:
		stats_controller.clear_outgoing_damage_bonus_modifier(effect_key)
	active_contexts.erase(context_id)
	current_bonus_by_context.erase(context_id)
	if active_contexts.is_empty() and EventBus.enemy_killed.is_connected(_on_enemy_killed):
		EventBus.enemy_killed.disconnect(_on_enemy_killed)


func _on_enemy_killed(_enemy: Entity, killer: Entity) -> void:
	if killer == null or not is_instance_valid(killer):
		return

	for context_id_variant in active_contexts.keys().duplicate():
		var context_id: String = str(context_id_variant)
		var record: Dictionary = active_contexts.get(context_id, {}) as Dictionary
		var relic_context: RelicContext = record.get("relic_context") as RelicContext
		var effect_key = record.get("effect_key")
		var owner: Entity = _get_owner_entity(relic_context)
		if owner == null or owner != killer:
			continue

		var old_bonus: float = float(current_bonus_by_context.get(context_id, 0.0))
		var new_bonus: float = min(old_bonus + max(bonus_percent_per_kill, 0.0), max_bonus_percent)
		current_bonus_by_context[context_id] = new_bonus
		_refresh_bonus(relic_context, effect_key, context_id)


func _refresh_bonus(relic_context: RelicContext, effect_key, context_id: String) -> void:
	var stats_controller: StatsController = _get_stats_controller(relic_context)
	if stats_controller == null:
		return
	var bonus_percent: float = float(current_bonus_by_context.get(context_id, 0.0))
	stats_controller.set_outgoing_damage_bonus_modifier(effect_key, {
		"required_tags": ["projectile"],
		"percent_bonus": bonus_percent,
	})


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity


func _get_stats_controller(relic_context: RelicContext) -> StatsController:
	if relic_context == null:
		return null
	if relic_context.relic_controller != null:
		return relic_context.relic_controller.get_stats_controller()
	return (relic_context.owner as Entity).stats_controller if relic_context.owner is Entity else null


func _get_context_id(owner: Entity, effect_key) -> String:
	return "%s_%s" % [str(owner.get_instance_id()), str(effect_key)]
