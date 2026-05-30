class_name Relic
extends Resource

# 显示当前遗物的升级状态。
enum LevelTip {
	UNLEVELUP,
	LEVELUP,
}

# 遗物类型。
enum RelicType {
	COMMON,
	UNIQUE,
}

enum CharacterType {
	ALL,
	WARRIOR,
	SCOUNTS,
}

const LEVEL_TIP_COLORS := {
	Relic.LevelTip.UNLEVELUP: Color.GRAY,
	Relic.LevelTip.LEVELUP: Color.GOLD,
}



@export_group("Description")
@export var relic_name: String
@export var icon: Texture
@export_multiline var tooltip: String
@export_multiline var desc: String

@export_group("Gameplay")
@export var price: int
@export var sell_price: int = 2
@export var level: int
@export var leveltip: LevelTip
# 几件同 id、未升级的遗物会自动合成为一件升级态遗物。
@export var upgrade_merge_count: int = 3
@export var relic_type: RelicType
@export var tags: Array[RelicTag]
@export var id: String
@export var is_consumable: bool = false
@export var effects: Array[RelicEffect]
@export var great_effects: Array[RelicEffect]


# 返回当前遗物真正用于 UI 预览和出售结算的售价。
# 某些效果并不直接修改 sell_price，而是通过效果资源提供额外售价加成。
func get_effective_sell_price() -> int:
	var result := sell_price
	result += _get_sell_bonus_from_effects(effects)
	if leveltip == LevelTip.LEVELUP:
		result += _get_sell_bonus_from_effects(great_effects)
	return max(result, 0)


# 获得遗物时执行基础效果；如果是升级态，再额外执行强化效果。
func gain_relic(owner, relic_controller: RelicController = null, relic_key: String = "") -> void:
	_apply_effect_list(owner, relic_controller, relic_key, effects, "base", "gain")

	if leveltip == LevelTip.LEVELUP:
		_apply_effect_list(owner, relic_controller, relic_key, great_effects, "great", "gain")


# 装备遗物时执行基础效果；如果是升级态，再追加执行强化效果。
func activate_relic(owner, relic_controller: RelicController = null, relic_key: String = "") -> void:
	_apply_effect_list(owner, relic_controller, relic_key, effects, "base", "activate")

	if leveltip == LevelTip.LEVELUP:
		_apply_effect_list(owner, relic_controller, relic_key, great_effects, "great", "activate")


# 卸下遗物时，按和激活时一致的键把效果完整清掉。
func deactivate_relic(owner, relic_controller: RelicController = null, relic_key: String = "") -> void:
	_apply_effect_list(owner, relic_controller, relic_key, effects, "base", "deactivate")

	if leveltip == LevelTip.LEVELUP:
		_apply_effect_list(owner, relic_controller, relic_key, great_effects, "great", "deactivate")


# 使用消耗品时执行基础效果；如果是升级态，再额外执行强化效果。
func use_consumable(
	owner,
	relic_controller: RelicController = null,
	relic_key: String = "",
	use_target_position: Variant = null
) -> void:
	if not is_consumable:
		return

	_apply_effect_list(owner, relic_controller, relic_key, effects, "base", "use", use_target_position)

	if leveltip == LevelTip.LEVELUP:
		_apply_effect_list(owner, relic_controller, relic_key, great_effects, "great", "use", use_target_position)


# 出售遗物时执行售卖效果。某些遗物会在卖出后触发刷新、返利等一次性效果。
func sell_relic(owner, relic_controller: RelicController = null, relic_key: String = "") -> void:
	_apply_effect_list(owner, relic_controller, relic_key, effects, "base", "sold")

	if leveltip == LevelTip.LEVELUP:
		_apply_effect_list(owner, relic_controller, relic_key, great_effects, "great", "sold")


# 遗物被用具、技能或被动“消耗”时执行。
# 注意：这里不负责从背包/装备栏移除自身，移除动作由 RelicConsumption 统一处理。
func consume_relic(owner, relic_controller: RelicController = null, relic_key: String = "") -> void:
	_apply_effect_list(owner, relic_controller, relic_key, effects, "base", "consumed")

	if leveltip == LevelTip.LEVELUP:
		_apply_effect_list(owner, relic_controller, relic_key, great_effects, "great", "consumed")


# 对一组效果做统一分发，避免基础效果和强化效果写两份几乎一样的逻辑。
func _apply_effect_list(
	owner,
	relic_controller: RelicController,
	relic_key: String,
	effect_list: Array[RelicEffect],
	effect_group: String,
	action: String,
	use_target_position: Variant = null
) -> void:
	for effect_index in range(effect_list.size()):
		var effect := effect_list[effect_index]
		if effect == null:
			continue

		var effect_key := _build_effect_key(relic_key, effect_group, effect_index)
		var relic_context = RelicContext.new(
			self,
			owner,
			relic_controller,
			relic_key,
			effect_list,
			effect_group,
			action,
			use_target_position
		)
		match action:
			"gain":
				effect.on_gain(relic_context, effect_key)
			"activate":
				effect.on_activate(relic_context, effect_key)
			"deactivate":
				effect.on_deactivate(relic_context, effect_key)
			"use":
				effect.on_use(relic_context, effect_key)
			"sold":
				effect.on_sold(relic_context, effect_key)
			"consumed":
				effect.on_consumed(relic_context, effect_key)


# effect_key 里加入组别，避免 base[0] 和 great[0] 互相覆盖。
func _build_effect_key(relic_key: String, effect_group: String, effect_index: int) -> String:
	return "%s_%s_effect_%s" % [relic_key, effect_group, effect_index]


func _get_sell_bonus_from_effects(effect_list: Array[RelicEffect]) -> int:
	var result := 0
	for effect in effect_list:
		if effect != null and effect.has_method("get_sell_gold_bonus"):
			result += int(effect.get_sell_gold_bonus())
	return result
