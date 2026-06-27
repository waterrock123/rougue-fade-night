class_name Ability
extends Node

# 技能身份与展示信息由 ActiveSkillData 注入，避免 Ability 场景和 SkillData 重复维护同一份文本。
var id:StringName
var ability_name:String
var icon_texture: Texture2D
@export var cooldown: float =2.0
@export var energy_cost:float = 10.0
@export_group("AI 释放距离")
## AI 释放这个技能的最小距离。0 表示没有最近距离限制。
@export var ai_min_cast_distance: float = 0.0
## AI 释放这个技能的最大距离。0 表示自动尝试从组件推断；推断不到时使用敌人/召唤物自己的 stop_distance 兼容旧逻辑。
@export var ai_max_cast_distance: float = 0.0
## 未手动填写最大释放距离时，是否从 AbilityGetTarget、AbilityChargeToTarget、ProjectileManifest 等组件里推断。
@export var ai_infer_cast_range_from_components: bool = true
var desc:String
var skill_data: ActiveSkillData
var skill_entry: SkillEntry
var runtime_slot_index: int = -1


var current_cooldown: float
var can_be_casted = false
var preview_context: AbilityContext
var cached_ai_component_cast_range: float = -1.0


# 主动技能运行时注册后调用，把资源里的数据同步到 Ability 实例。
func apply_skill_data(new_skill_data: ActiveSkillData, new_skill_entry: SkillEntry = null) -> void:
	skill_data = new_skill_data
	skill_entry = new_skill_entry
	if skill_data == null:
		return

	id = skill_data.id
	ability_name = skill_data.skill_name
	icon_texture = skill_data.icon
	desc = skill_data.desc
	if skill_data.base_cooldown > 0.0:
		cooldown = skill_data.base_cooldown
	if skill_data.base_energy_cost > 0.0:
		energy_cost = skill_data.base_energy_cost


func  activate(entity: Entity):
	var context=AbilityContext.new(entity,self)
	
	_activate_components(context)


# 释放前校验：给“需要弹药/材料/特殊资源”的技能组件预留扩展点。
func can_pay_activation_costs(entity: Entity) -> bool:
	var context := AbilityContext.new(entity, self)
	for component in _get_activation_cost_components():
		if component.has_method("can_pay_ability_cost") and not component.can_pay_ability_cost(context):
			return false
	return true


# 返回阻止释放的提示文本；没有特殊提示时返回空字符串。
func get_activation_block_reason(entity: Entity) -> String:
	var context := AbilityContext.new(entity, self)
	for component in _get_activation_cost_components():
		if not component.has_method("can_pay_ability_cost"):
			continue
		if component.can_pay_ability_cost(context):
			continue
		if component.has_method("get_ability_cost_block_reason"):
			return String(component.get_ability_cost_block_reason(context))
	return ""


# 真正支付额外释放成本；只有 AbilityController 已确认能量/冷却通过后才会调用。
func pay_activation_costs(entity: Entity) -> bool:
	var context := AbilityContext.new(entity, self)
	for component in _get_activation_cost_components():
		if component.has_method("pay_ability_cost") and not component.pay_ability_cost(context):
			return false
	return true


func _get_activation_cost_components() -> Array[Node]:
	var result: Array[Node] = []
	_collect_activation_cost_components(self, result)
	return result


func _collect_activation_cost_components(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if child.has_method("can_pay_ability_cost") or child.has_method("pay_ability_cost"):
			result.append(child)
		_collect_activation_cost_components(child, result)


## 给敌人/召唤物 AI 使用：判断当前目标距离是否适合释放这个技能。
## fallback_max_distance 是旧的 stop_distance，用来兼容还没单独配置 AI 距离的老技能。
func can_ai_cast_at_distance(target_distance: float, fallback_max_distance: float) -> bool:
	if target_distance < max(ai_min_cast_distance, 0.0):
		return false

	var max_distance := get_ai_max_cast_distance(fallback_max_distance)
	if max_distance <= 0.0:
		return true

	return target_distance <= max_distance


## 返回 AI 释放最大距离。优先读手动配置，其次尝试从组件推断，最后回落到旧 stop_distance。
func get_ai_max_cast_distance(fallback_max_distance: float) -> float:
	if ai_max_cast_distance > 0.0:
		return ai_max_cast_distance

	if ai_infer_cast_range_from_components:
		var inferred_range := _get_inferred_ai_component_cast_range()
		if inferred_range > 0.0:
			return inferred_range

	return fallback_max_distance


func has_cast_preview() -> bool:
	for child in get_children():
		if child is AbilityComponent and child.has_method("begin_preview"):
			return true
	return false


# 按住技能键时调用，只启动“显示范围”等预览组件，不触发真正的技能效果。
func begin_cast_preview(entity: Entity) -> void:
	if not has_cast_preview():
		return

	preview_context = AbilityContext.new(entity, self)
	for child in get_children():
		if child is AbilityComponent and child.has_method("begin_preview"):
			child.begin_preview(preview_context)


# 松开技能键或取消施法时调用，让所有预览组件收尾隐藏。
func end_cast_preview() -> void:
	for child in get_children():
		if child is AbilityComponent and child.has_method("end_preview"):
			child.end_preview()
	preview_context = null

func _activate_components(context: AbilityContext):
	for child in get_children():
		if child is AbilityComponent and child.auto_activate:	
			child.activate(context)


# 供动画关键帧或其他控制组件按名字手动触发指定技能组件。
func trigger_component_by_name(component_name: String, context: AbilityContext) -> void:
	var component := get_node_or_null(component_name)
	if component is AbilityComponent:
		(component as AbilityComponent).activate(context)


func _get_inferred_ai_component_cast_range() -> float:
	if cached_ai_component_cast_range >= 0.0:
		return cached_ai_component_cast_range

	cached_ai_component_cast_range = _scan_ai_cast_range_from_node(self)
	return cached_ai_component_cast_range


func _scan_ai_cast_range_from_node(node: Node) -> float:
	var best_range := 0.0
	for child in node.get_children():
		best_range = max(best_range, _read_ai_cast_range_from_component(child))
		best_range = max(best_range, _scan_ai_cast_range_from_node(child))

	return best_range


func _read_ai_cast_range_from_component(component: Node) -> float:
	if component is AbilityChargeToTarget:
		var charge_component := component as AbilityChargeToTarget
		return max(charge_component.charge_distance + charge_component.hit_width, 0.0)

	if component is AbilityGetTarget:
		return max((component as AbilityGetTarget).radius, 0.0)

	if component is AbilitySpawnManifest:
		return _read_ai_cast_range_from_manifest_scene((component as AbilitySpawnManifest).manifest_scene)

	return 0.0


func _read_ai_cast_range_from_manifest_scene(manifest_scene: PackedScene) -> float:
	if manifest_scene == null:
		return 0.0

	var manifest := manifest_scene.instantiate()
	var result := 0.0
	if manifest is ProjectileManifest:
		result = max((manifest as ProjectileManifest).max_distance, 0.0)
	elif manifest is AnimatedProjectileManifest:
		result = max((manifest as AnimatedProjectileManifest).max_distance, 0.0)
	elif manifest is ThrownArcImpactManifest:
		result = max((manifest as ThrownArcImpactManifest).max_range, 0.0)

	manifest.free()
	return result
