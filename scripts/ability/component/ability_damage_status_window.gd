## 指定技能在短命中窗口内造成有效伤害后施加状态；不参与伤害计算。
## 闪避、零伤害不触发，每个目标在窗口内最多一次，适合冲刺命中减速。
class_name AbilityDamageStatusWindow
extends AbilityComponent

@export var status_data: StatusData
@export var duration: float = 0.35
@export var status_duration: float = 1.5
@export var required_tag: String = "charge"

var active_context: AbilityContext
var hit_ids: Dictionary = {}
var remaining: float = 0.0


func _activate(context: AbilityContext) -> void:
	_clear_listener()
	active_context = context
	remaining = duration
	hit_ids.clear()
	context.caster.damage_dealt.connect(_on_damage)


func _process(delta: float) -> void:
	if active_context == null:
		return
	remaining -= delta
	if remaining <= 0.0 or not active_context.is_caster_action_valid():
		_clear_listener()


func _on_damage(data: DamageData) -> void:
	if active_context == null or not active_context.is_caster_action_valid() or status_data == null:
		return
	if data.final_damage <= 0.0 or data.is_miss or not is_instance_valid(data.target):
		return
	if data.source_ability_id != active_context.ability.id or not data.tags.has(required_tag):
		return
	var id: int = data.target.get_instance_id()
	if hit_ids.has(id) or not is_instance_valid(data.target.status_controller):
		return
	hit_ids[id] = true
	data.target.status_controller.add_status(status_data, active_context.caster, active_context.ability.id, 1, status_duration)


func _clear_listener() -> void:
	if active_context != null and is_instance_valid(active_context.caster):
		if active_context.caster.damage_dealt.is_connected(_on_damage):
			active_context.caster.damage_dealt.disconnect(_on_damage)
	active_context = null


func _exit_tree() -> void:
	_clear_listener()
