## 获得或升级时重新分配当前本局基础一级属性总点数。保持总和，不修改装备/被动/狼奶修饰账本。
## 只修改本局StatsData副本，不改角色模板和开局快照；支持七项中的自定义子集。
class_name GainRedistributePrimaryStatsEffect
extends RelicEffect

@export var stat_names: Array[StringName] = [
	&"strength", &"dexterity", &"intelligence", &"constitution", &"speed", &"charm", &"luck",
]
@export var once_key: StringName = &"redistribute_primary_stats"


func on_gain(context: RelicContext, _effect_key: Variant) -> void:
	_apply_once(context)


func on_added(context: RelicContext, _effect_key: Variant) -> void:
	_apply_once(context)


func on_upgrade(context: RelicContext, _effect_key: Variant) -> void:
	_apply_once(context)


func _apply_once(context: RelicContext) -> void:
	var run: Run = RelicGainRuntimeHelper.get_run(context)
	if run == null or run.run_stats == null or run.run_stats.player_build == null:
		return
	var data: StatsData = run.run_stats.player_build.player_stats
	var names: Array[StringName] = []
	for stat: StringName in stat_names:
		if StatsController.PRIMARY_STATS.has(stat) and not names.has(stat):
			names.append(stat)
	if data == null or names.size() < 2 or not RelicGainRuntimeHelper.claim_once(context, once_key):
		return
	redistribute(data, names)
	RelicGainRuntimeHelper.refresh_attributes.call_deferred(context)


## 随机切分总点数，复杂度只与属性种类有关，不逐点循环，避免大数值调试时卡顿。
static func redistribute(data: StatsData, names: Array[StringName]) -> void:
	var total: int = 0
	for stat: StringName in names:
		total += int(data.get(stat))
	var points: int = absi(total)
	var cuts: Array[int] = [0, points]
	for _index: int in range(names.size() - 1):
		cuts.append(RunRng.randi_range(0, points))
	cuts.sort()
	var shuffled_names: Array[StringName] = names.duplicate()
	RunRng.shuffle_array(shuffled_names)
	for index: int in range(shuffled_names.size()):
		data.set(shuffled_names[index], (cuts[index + 1] - cuts[index]) * (-1 if total < 0 else 1))
