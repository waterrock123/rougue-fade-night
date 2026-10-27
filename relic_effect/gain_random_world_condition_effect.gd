## 获得时按权重触发一项非默认天气/环境；覆盖同类状态并沿用其持续房间配置。
## 不改动另一类状态，一次性记录随单件遗物存档，重穿和续档不会重复抽取。
class_name GainRandomWorldConditionEffect
extends RelicEffect

@export var include_weather: bool = true
@export var include_environment: bool = true
@export var once_key: StringName = &"gain_random_world_condition"


func on_gain(context: RelicContext, _effect_key: Variant) -> void:
	_apply_once(context)


func on_added(context: RelicContext, _effect_key: Variant) -> void:
	_apply_once(context)


func _apply_once(context: RelicContext) -> void:
	var run: Run = RelicGainRuntimeHelper.get_run(context)
	if run == null or not is_instance_valid(run.world_condition_controller):
		return
	if not RelicGainRuntimeHelper.claim_once(context, once_key):
		return
	var selected: WorldConditionData = run.world_condition_controller.trigger_random_condition(include_weather, include_environment)
	if selected == null:
		context.own_relic.effect_counters.erase(str(once_key))
		return
	if run.current_view.get_child_count() > 0:
		var battle: PlayScene = run.current_view.get_child(0) as PlayScene
		if battle != null:
			run.world_condition_controller.apply_to_battle(battle)
	run.save_current_run.call_deferred()
