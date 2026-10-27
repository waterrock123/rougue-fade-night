## 临时属性增益的转换策略：仅记录开启之后的正向增量，不把状态刷新或装备重算当作新奖励。
## 转换出的增量独立保存，原状态到期/移除不会撤销它；负值和常驻装备属性不进入转换入口。
class_name TemporaryStatGainPolicy
extends RefCounted

enum Mode { NORMAL, BATTLE, PERMANENT }

var policy_sources: Dictionary = {}
var records: Dictionary = {}
var battle_bonuses: Dictionary = {}


func set_policy(source_key: String, mode: Mode) -> void:
	policy_sources[source_key] = mode


func clear_policy(source_key: String) -> void:
	policy_sources.erase(source_key)


func get_mode() -> Mode:
	var result: int = Mode.NORMAL
	for mode: int in policy_sources.values():
		result = maxi(result, mode)
	return result as Mode


## eligible_ratio用于同id状态混合来源：装备提供的层数仍按原规则存在，只有战斗获得的层数能转换。
func transform(ledger_key: String, incoming: Array[Modifier], eligible_ratio: float, build: PlayerBuild) -> Array[Modifier]:
	var record: Dictionary = records.get(ledger_key, {"previous": {}, "converted": {}})
	var adjusted: Array[Modifier] = _subtract_reset_offsets(incoming, record.get("reset_offsets", {}))
	record["raw_totals"] = _signed_totals(incoming)
	var totals: Dictionary = _positive_totals(adjusted, clampf(eligible_ratio, 0.0, 1.0))
	var previous: Dictionary = record["previous"]
	var converted: Dictionary = record["converted"]
	var mode: Mode = get_mode()
	for key: String in totals:
		var total: float = float(totals[key])
		var delta: float = maxf(total - float(previous.get(key, 0.0)), 0.0)
		var active_converted: float = minf(float(converted.get(key, 0.0)), total)
		if mode != Mode.NORMAL and delta > 0.0 and (mode != Mode.PERMANENT or build != null):
			var destination: Dictionary = build.permanent_stat_bonuses if mode == Mode.PERMANENT else battle_bonuses
			destination[key] = float(destination.get(key, 0.0)) + delta
			active_converted += delta
		converted[key] = active_converted
	for key: String in converted.keys():
		if not totals.has(key):
			converted[key] = 0.0
	record["previous"] = totals
	records[ledger_key] = record
	return _subtract_converted(adjusted, converted)


func release_source(ledger_key: String) -> void:
	records.erase(ledger_key)


## 累积型效果自行保存了历史总量；重置后扣除旧基线，只允许后续新增的部分重新生效。
func reset_source(ledger_key: String) -> void:
	if not records.has(ledger_key):
		return
	var record: Dictionary = records[ledger_key]
	record["reset_offsets"] = record.get("raw_totals", {}).duplicate()
	record["previous"] = {}
	record["converted"] = {}


## 重置已转换的战斗增量，但保留当前来源基线，避免原有增益刷新后被再次“获得”。
func reset_battle_gains() -> void:
	battle_bonuses.clear()
	for record: Dictionary in records.values():
		record["converted"] = {}


static func build_modifiers(bonuses: Dictionary, source_key: String) -> Array[Modifier]:
	var result: Array[Modifier] = []
	for key: String in bonuses:
		var parts: PackedStringArray = key.split("|")
		if parts.size() != 2 or not parts[1].is_valid_int():
			continue
		var type_id: int = int(parts[1])
		var amount: float = float(bonuses[key])
		if type_id < 0 or type_id > Modifier.ModifierType.PERCENT or not is_finite(amount):
			continue
		result.append(Modifier.new(StringName(parts[0]), type_id as Modifier.ModifierType, amount, source_key))
	return result


func _positive_totals(incoming: Array[Modifier], ratio: float) -> Dictionary:
	var result: Dictionary = {}
	for modifier: Modifier in incoming:
		if modifier == null or modifier.value <= 0.0 or not is_finite(modifier.value):
			continue
		var key: String = _modifier_key(modifier)
		result[key] = float(result.get(key, 0.0)) + modifier.value * ratio
	return result


func _subtract_converted(incoming: Array[Modifier], converted: Dictionary) -> Array[Modifier]:
	var result: Array[Modifier] = []
	var remaining: Dictionary = converted.duplicate()
	for modifier: Modifier in incoming:
		if modifier == null:
			continue
		var key: String = _modifier_key(modifier)
		var subtraction: float = minf(maxf(modifier.value, 0.0), float(remaining.get(key, 0.0)))
		remaining[key] = maxf(float(remaining.get(key, 0.0)) - subtraction, 0.0)
		result.append(Modifier.new(modifier.stat, modifier.modifier_type, modifier.value - subtraction, modifier.source, modifier.duration))
	return result


func _modifier_key(modifier: Modifier) -> String:
	return "%s|%d" % [modifier.stat, modifier.modifier_type]


func _signed_totals(incoming: Array[Modifier]) -> Dictionary:
	var totals: Dictionary = {}
	for modifier: Modifier in incoming:
		if modifier == null or not is_finite(modifier.value):
			continue
		var key: String = "%s|%s" % [_modifier_key(modifier), "positive" if modifier.value >= 0.0 else "negative"]
		totals[key] = float(totals.get(key, 0.0)) + absf(modifier.value)
	return totals


func _subtract_reset_offsets(incoming: Array[Modifier], offsets: Dictionary) -> Array[Modifier]:
	var result: Array[Modifier] = []
	var remaining: Dictionary = offsets.duplicate()
	for modifier: Modifier in incoming:
		if modifier == null:
			continue
		var key: String = "%s|%s" % [_modifier_key(modifier), "positive" if modifier.value >= 0.0 else "negative"]
		var amount: float = minf(absf(modifier.value), float(remaining.get(key, 0.0)))
		remaining[key] = maxf(float(remaining.get(key, 0.0)) - amount, 0.0)
		var value: float = modifier.value - signf(modifier.value) * amount
		result.append(Modifier.new(modifier.stat, modifier.modifier_type, value, modifier.source, modifier.duration))
	return result
