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
func use_consumable(owner, relic_controller: RelicController = null, relic_key: String = "") -> void:
	if not is_consumable:
		return

	_apply_effect_list(owner, relic_controller, relic_key, effects, "base", "use")

	if leveltip == LevelTip.LEVELUP:
		_apply_effect_list(owner, relic_controller, relic_key, great_effects, "great", "use")


# 对一组效果做统一分发，避免基础效果和强化效果写两份几乎一样的逻辑。
func _apply_effect_list(
	owner,
	relic_controller: RelicController,
	relic_key: String,
	effect_list: Array[RelicEffect],
	effect_group: String,
	action: String
) -> void:
	for effect_index in range(effect_list.size()):
		var effect := effect_list[effect_index]
		if effect == null:
			continue

		var effect_key := _build_effect_key(relic_key, effect_group, effect_index)
		var relic_context = RelicContext.new(self,owner,relic_controller,relic_key,effect_list,effect_group,action)
		match action:
			"gain":
				effect.on_gain(relic_context, effect_key)
			"activate":
				effect.on_activate(relic_context, effect_key)
			"deactivate":
				effect.on_deactivate(relic_context, effect_key)
			"use":
				effect.on_use(relic_context, effect_key)


# effect_key 里加入组别，避免 base[0] 和 great[0] 互相覆盖。
func _build_effect_key(relic_key: String, effect_group: String, effect_index: int) -> String:
	return "%s_%s_effect_%s" % [relic_key, effect_group, effect_index]
