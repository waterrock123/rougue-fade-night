class_name DamageScalingRule
extends Resource

enum FormulaMode {
	ADD_ALL_MATCHING,#应用所有伤害附加
	USE_HIGHEST_MATCHING,#饮用最高伤害附加
}

@export_group("配置")
@export var enabled: bool = true #是否应用
@export var formula_mode: FormulaMode = FormulaMode.ADD_ALL_MATCHING
@export var fallback_formula: String = ""

@export_group("伤害类型加成")
@export_multiline var physical_formula: String = "strength"
@export_multiline var ranged_formula: String = "floor(dexterity / 2.0)"
@export_multiline var fire_formula: String = ""
@export_multiline var ice_formula: String = ""
@export_multiline var lightning_formula: String = ""
@export_multiline var poison_formula: String = ""


# 按当前攻击者的属性和这次伤害的类型，计算额外附加到基础伤害上的加成值。
# 这个资源挂在具体的伤害来源上，用来让不同技能/投射物拥有不同的成长公式。
func get_bonus_damage(stats_controller: StatsController, damage_data: DamageData) -> float:
	if not enabled or stats_controller == null or damage_data == null:
		return 0.0

	var values := _build_formula_values(stats_controller, damage_data)
	var matched_results: Array[float] = []

	for damage_type in damage_data.damage_types:
		var formula := _get_formula_for_type(damage_type)
		if formula.is_empty():
			continue

		matched_results.append(_evaluate_formula(formula, values))

	if matched_results.is_empty():
		if fallback_formula.is_empty():
			return 0.0
		return max(_evaluate_formula(fallback_formula, values), 0.0)

	if formula_mode == FormulaMode.USE_HIGHEST_MATCHING:
		var max_bonus := 0.0
		for result in matched_results:
			max_bonus = max(max_bonus, result)
		return max_bonus

	var total_bonus := 0.0
	for result in matched_results:
		total_bonus += result
	return max(total_bonus, 0.0)


# 组装公式可用的变量表。
# 这里暴露的是“伤害公式上下文”，后面在编辑器里写公式时就能直接使用这些变量名。
func _build_formula_values(stats_controller: StatsController, damage_data: DamageData) -> Dictionary:
	return {
		"base_damage": damage_data.base_damage,
		"final_damage": damage_data.final_damage,
		"strength": stats_controller.get_stat("strength"),
		"dexterity": stats_controller.get_stat("dexterity"),
		"intelligence": stats_controller.get_stat("intelligence"),
		"constitution": stats_controller.get_stat("constitution"),
		"speed": stats_controller.get_stat("speed"),
		"charm": stats_controller.get_stat("charm"),
		"luck": stats_controller.get_stat("luck"),
		"crit_chance": stats_controller.get_stat("crit_chance"),
		"crit_damage": stats_controller.get_stat("crit_damage"),
	}


# 根据本次伤害携带的 damage_type，拿到对应的公式字符串。
func _get_formula_for_type(damage_type: int) -> String:
	match damage_type:
		DamageData.DamageType.PHYSICAL:
			return physical_formula
		DamageData.DamageType.RANGED:
			return ranged_formula
		DamageData.DamageType.FIRE:
			return fire_formula
		DamageData.DamageType.ICE:
			return ice_formula
		DamageData.DamageType.LIGHTNING:
			return lightning_formula
		DamageData.DamageType.POISON:
			return poison_formula
		_:
			return ""


# 解析并执行单条公式。
# 这里使用 Godot 的 Expression，可以在资源里直接写类似 strength * 1.5 的表达式。
func _evaluate_formula(formula: String, values: Dictionary) -> float:
	if formula.is_empty():
		return 0.0

	var expression := Expression.new()
	var input_names: PackedStringArray = []
	var input_values: Array = []

	for key in values.keys():
		input_names.append(String(key))
		input_values.append(values[key])

	var parse_error := expression.parse(formula, input_names)
	if parse_error != OK:
		push_warning("DamageScalingRule parse failed: %s" % formula)
		return 0.0

	var result = expression.execute(input_values, self, true)
	if expression.has_execute_failed():
		push_warning("DamageScalingRule execute failed: %s" % formula)
		return 0.0

	return max(float(result), 0.0)
