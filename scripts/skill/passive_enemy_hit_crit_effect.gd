class_name PassiveEnemyHitCritEffect
extends PassiveSkillEffect

## 对同一个敌人累计造成指定次数伤害后，获得战斗内暴击率提升。
## 每个敌人单独计数，触发后保留余数，因此可以连续触发多次。
@export var hits_required: int = 5
## 每次达成命中次数后叠加的可视状态；该状态负责真正提供暴击率。
@export var crit_status: StatusData

var active_contexts: Dictionary = {}
var damage_callbacks: Dictionary = {}
var hit_counts: Dictionary = {}


func apply(context: SkillContext) -> void:
	if context == null or context.caster == null:
		return
	if not context.caster.is_in_group("player"):
		return

	var context_key: String = _get_context_key(context)
	active_contexts[context_key] = context
	hit_counts[context_key] = {}

	var callback: Callable = Callable(self, "_on_damage_dealt").bind(context_key)
	damage_callbacks[context_key] = callback
	if not context.caster.damage_dealt.is_connected(callback):
		context.caster.damage_dealt.connect(callback)


func remove(context: SkillContext) -> void:
	if context == null:
		return

	var context_key: String = _get_context_key(context)
	var callback: Callable = damage_callbacks.get(context_key, Callable())
	if callback.is_valid() and is_instance_valid(context.caster):
		if context.caster.damage_dealt.is_connected(callback):
			context.caster.damage_dealt.disconnect(callback)

	if is_instance_valid(context.status_controller) and crit_status != null:
		context.status_controller.remove_status_source(crit_status.id, context.effect_key)
	damage_callbacks.erase(context_key)
	active_contexts.erase(context_key)
	hit_counts.erase(context_key)
	# 兼容旧版本曾直接注册到 StatsController 的隐藏修饰。
	if context.stats_controller != null:
		context.stats_controller.clear_effect_modifiers(context.effect_key)


func _on_damage_dealt(damage_data: DamageData, context_key: String) -> void:
	if damage_data == null or damage_data.final_damage <= 0.0:
		return
	if not active_contexts.has(context_key):
		return

	var target: Entity = damage_data.target
	if target == null or not is_instance_valid(target) or not target.is_in_group("enemy"):
		return

	var target_key: int = target.get_instance_id()
	var context_hit_counts: Dictionary = hit_counts.get(context_key, {}) as Dictionary
	var hit_count: int = int(context_hit_counts.get(target_key, 0)) + 1
	var required_hits: int = max(hits_required, 1)
	var trigger_count: int = hit_count / required_hits
	context_hit_counts[target_key] = hit_count % required_hits
	hit_counts[context_key] = context_hit_counts

	if trigger_count <= 0:
		return
	var context: SkillContext = active_contexts.get(context_key) as SkillContext
	if context == null or not is_instance_valid(context.status_controller) or crit_status == null:
		return

	# 一次伤害可能跨过多次阈值，直接按触发次数追加对应层数。
	context.status_controller.add_status(
		crit_status,
		context.caster,
		context.effect_key,
		trigger_count
	)


func _get_context_key(context: SkillContext) -> String:
	var controller_id: int = 0
	if context.skill_controller != null:
		controller_id = context.skill_controller.get_instance_id()
	return "%s:%s" % [str(controller_id), str(context.effect_key)]
