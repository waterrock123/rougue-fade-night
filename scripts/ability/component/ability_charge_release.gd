## 可由被动启用的按住蓄力、松开释放组件。只记录本次释放比例并修正弹体基础伤害。
## 不在预览时扣法力或进入冷却，也不锁定人物移动。
class_name AbilityChargeRelease
extends AbilityComponent

@export var charge_seconds: float = 1.5
@export var max_damage_multiplier: float = 2.0
## 按所属技能的最终冷却/基础冷却比例缩短蓄力时间；每次开始蓄力时锁定本次时长。
@export var scale_charge_with_cooldown: bool = false
## 关闭后该技能始终允许蓄力；开启时由控制器的charge_enabled修正决定。
@export var requires_tuning: bool = true

@export_group("Charge Indicator")
## 圆环相对于角色根节点的位置；只改变预览UI，不改变施法方向和伤害。
@export var indicator_offset: Vector2 = Vector2(0, -12)
@export var indicator_radius: float = 20.0
@export var indicator_line_width: float = 2.0

var active_context: AbilityContext
var indicator: AbilityChargeIndicator
var elapsed: float = 0.0
var active_charge_seconds: float = 0.0


func is_preview_enabled() -> bool:
	if not requires_tuning:
		return true
	var ability: Ability = get_parent() as Ability
	if ability == null:
		return false
	var controller: AbilityController = ability.get_parent() as AbilityController
	return controller != null and bool(controller.get_cast_tuning(ability)["charge_enabled"])


func begin_preview(context: AbilityContext) -> void:
	end_preview()
	active_context = context
	elapsed = 0.0
	active_charge_seconds = get_charge_duration()
	indicator = AbilityChargeIndicator.new()
	indicator.position = indicator_offset
	indicator.radius = indicator_radius
	indicator.line_width = indicator_line_width
	indicator.z_index = 50
	context.caster.add_child(indicator)


func _process(delta: float) -> void:
	if active_context == null:
		return
	if not active_context.is_caster_action_valid() or not active_context.caster.can_act():
		var controller: AbilityController = get_parent().get_parent() as AbilityController
		if is_instance_valid(controller):
			controller.cancel_ability_preview()
		end_preview()
		return
	elapsed += delta
	active_context.charge_ratio = get_charge_ratio(elapsed)
	if is_instance_valid(indicator):
		indicator.ratio = active_context.charge_ratio
		indicator.queue_redraw()


func get_charge_ratio(seconds: float) -> float:
	var duration: float = active_charge_seconds if active_charge_seconds > 0.0 else charge_seconds
	return clampf(seconds / maxf(duration, 0.01), 0.0, 1.0)


## 复用实际冷却规则，包含属性、技能专属修正和冷却下限；增冷却不会反向延长蓄力。
func get_charge_duration() -> float:
	var duration: float = maxf(charge_seconds, 0.01)
	if not scale_charge_with_cooldown:
		return duration
	var ability: Ability = get_parent() as Ability
	if not is_instance_valid(ability) or ability.cooldown <= 0.0:
		return duration
	var controller: AbilityController = ability.get_parent() as AbilityController
	if not is_instance_valid(controller):
		return duration
	var ratio: float = clampf(controller.get_effective_cooldown(ability) / ability.cooldown, 0.0, 1.0)
	return maxf(duration * ratio, 0.01)


func _activate(context: AbilityContext) -> void:
	if is_preview_enabled():
		context.projectile_damage_multiplier *= lerpf(1.0, max_damage_multiplier, context.charge_ratio)


func end_preview() -> void:
	if is_instance_valid(indicator):
		indicator.queue_free()
	indicator = null
	active_context = null
	elapsed = 0.0
	active_charge_seconds = 0.0


func _exit_tree() -> void:
	end_preview()
