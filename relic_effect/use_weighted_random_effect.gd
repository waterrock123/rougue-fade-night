## 消耗品使用时按权重随机触发一个结果。
## 适合神秘药剂、随机料理、混沌卷轴等“多个结果里抽一个”的装备效果。
class_name UseWeightedRandomEffect
extends RelicEffect

@export var options: Array[WeightedRelicEffectOption] = []


func on_use(relic_context: RelicContext, effect_key) -> void:
	var available_options := _get_available_options(relic_context)
	if available_options.is_empty():
		return

	var chosen_option := _pick_weighted_option(available_options)
	if chosen_option == null:
		return

	var option_key := "%s_%s" % [str(effect_key), chosen_option.option_name]
	chosen_option.apply_on_use(relic_context, option_key)


func _get_available_options(relic_context: RelicContext) -> Array[WeightedRelicEffectOption]:
	var result: Array[WeightedRelicEffectOption] = []
	for option in options:
		if option != null and option.is_available(relic_context):
			result.append(option)
	return result


func _pick_weighted_option(available_options: Array[WeightedRelicEffectOption]) -> WeightedRelicEffectOption:
	var total_weight := 0.0
	for option in available_options:
		total_weight += max(option.weight, 0.0)

	if total_weight <= 0.0:
		return null

	# 消耗品是在战斗中使用的随机效果，不接入 RunRng，避免影响商店/地图种子流。
	var roll := randf_range(0.0, total_weight)
	var accumulated := 0.0
	for option in available_options:
		accumulated += max(option.weight, 0.0)
		if roll <= accumulated:
			return option

	return available_options.back()
