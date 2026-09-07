class_name EnemyPoiseController
extends Node

signal poise_state_changed(is_active: bool)
signal poise_changed(current_poise: float, max_poise: float)
signal poise_damaged(amount: float, current_poise: float, max_poise: float, damage_data: DamageData)
signal poise_broken(duration: float)
signal poise_break_ended

var poise_enabled: bool = true
var hit_stuns_required: int = 3
# 控制器兜底值需与 Enemy 默认值一致，覆盖未来手动创建控制器的情况。
var max_poise: float = 10.0
var base_poise_damage: float = 15.0
var damage_to_poise_ratio: float = 0.5
var outline_color: Color = Color.WHITE
var outline_width: float = 1.0
var break_stun_duration: float = 1.0
var break_text: String = "破韧"
var break_text_color: Color = Color(1.0, 0.82, 0.28, 1.0)
var break_ui_feedback_duration: float = 0.35
var show_debug_damage_popup: bool = false
var debug_damage_color: Color = Color(1.0, 0.78, 0.3, 1.0)

var target: Entity
var hit_reaction_controller: EnemyHitReactionController
var health_bar: TextureProgressBar
var poise_outline: EnemyPoiseOutline
var poise_debug_display: EnemyPoiseDebugDisplay
var current_poise: float = 0.0
var completed_hit_stuns: int = 0
var poise_active: bool = false
var poise_break_active: bool = false
var enter_poise_after_hit_stun: bool = false


func _exit_tree() -> void:
	_unbind_target()


## 将韧性系统绑定到敌人与受击控制器，并把轮廓 UI 套在敌人血条上。
func bind_target(
	new_target: Entity,
	new_hit_reaction_controller: EnemyHitReactionController,
	new_health_bar: TextureProgressBar
) -> void:
	_unbind_target()
	target = new_target
	hit_reaction_controller = new_hit_reaction_controller
	health_bar = new_health_bar
	current_poise = maxf(max_poise, 0.0)
	completed_hit_stuns = 0
	poise_active = false
	poise_break_active = false
	enter_poise_after_hit_stun = false

	if target != null:
		if not target.damage_taken.is_connected(_on_target_damage_taken):
			target.damage_taken.connect(_on_target_damage_taken)
		if not target.died.is_connected(_on_target_died):
			target.died.connect(_on_target_died)

	if hit_reaction_controller != null and not hit_reaction_controller.hit_stun_ended.is_connected(_on_hit_stun_ended):
		hit_reaction_controller.hit_stun_ended.connect(_on_hit_stun_ended)

	_setup_poise_outline()
	_setup_poise_debug_display()
	_refresh_poise_ui()


func is_poise_active() -> bool:
	return poise_active


func get_current_poise() -> float:
	return current_poise


func _on_target_damage_taken(damage_data: DamageData) -> void:
	if target == null or target.is_dead or target.current_health <= 0.0:
		return
	if hit_reaction_controller == null:
		return
	if poise_break_active:
		return

	if not poise_enabled:
		hit_reaction_controller.try_apply_hit_stun(damage_data)
		return
	if not hit_reaction_controller.is_damage_eligible_for_hit_reaction(damage_data):
		return

	if poise_active:
		_apply_poise_damage(damage_data)
		return

	if hit_reaction_controller.try_apply_hit_stun(damage_data):
		completed_hit_stuns += 1
		if completed_hit_stuns >= maxi(hit_stuns_required, 1):
			enter_poise_after_hit_stun = true


## 最后一次短硬直结束后再进入韧性，避免把这一帧硬直直接截断。
func _on_hit_stun_ended() -> void:
	if poise_break_active:
		_finish_poise_break()
		return
	if not enter_poise_after_hit_stun or target == null or target.is_dead:
		return
	_enter_poise_state()


func _enter_poise_state() -> void:
	if poise_active or not poise_enabled:
		return
	if max_poise <= 0.0:
		completed_hit_stuns = 0
		enter_poise_after_hit_stun = false
		return
	poise_active = true
	enter_poise_after_hit_stun = false
	current_poise = maxf(max_poise, 0.0)
	if health_bar != null:
		health_bar.visible = true
	poise_state_changed.emit(true)
	poise_changed.emit(current_poise, max_poise)
	_refresh_poise_ui()


func _apply_poise_damage(damage_data: DamageData) -> void:
	var poise_damage: float = damage_data.poise_damage
	if poise_damage < 0.0:
		poise_damage = base_poise_damage + damage_data.final_damage * damage_to_poise_ratio
	# 固定削韧和目标默认削韧公式都统一受到攻击方削韧倍率影响。
	poise_damage *= maxf(damage_data.poise_damage_multiplier, 0.0)
	poise_damage = maxf(poise_damage, 0.0)
	if poise_damage <= 0.0:
		return

	var applied_poise_damage: float = minf(poise_damage, current_poise)
	current_poise = maxf(current_poise - applied_poise_damage, 0.0)
	poise_damaged.emit(applied_poise_damage, current_poise, max_poise, damage_data)
	if poise_debug_display != null:
		poise_debug_display.play_damage_popup(applied_poise_damage)
	poise_changed.emit(current_poise, max_poise)
	_refresh_poise_ui()
	if current_poise <= 0.0:
		_begin_poise_break(damage_data)


## 韧性归零后立即打断当前动作，并进入一次不受普通硬直冷却影响的长硬直。
func _begin_poise_break(damage_data: DamageData) -> void:
	if poise_break_active or target == null or target.is_dead:
		return

	poise_active = false
	poise_break_active = true
	completed_hit_stuns = 0
	enter_poise_after_hit_stun = false
	current_poise = 0.0
	poise_state_changed.emit(false)
	poise_broken.emit(maxf(break_stun_duration, 0.0))
	_show_break_feedback()

	var forced_stun_started := (
		hit_reaction_controller != null
		and hit_reaction_controller.apply_forced_hit_stun(break_stun_duration)
	)

	# 状态和视觉反馈先建立，再通知被动、遗物等外部系统处理“破韧时”效果。
	var breaker: Entity = null
	if damage_data != null and damage_data.source != null and is_instance_valid(damage_data.source):
		breaker = damage_data.source
	EventBus.enemy_poise_broken.emit(target, breaker, damage_data)

	if not forced_stun_started:
		_finish_poise_break()


## 破韧硬直结束后恢复完整韧性，并重新开始累计普通短硬直次数。
func _finish_poise_break() -> void:
	if not poise_break_active:
		return
	poise_break_active = false
	current_poise = maxf(max_poise, 0.0)
	completed_hit_stuns = 0
	enter_poise_after_hit_stun = false
	poise_break_ended.emit()
	_refresh_poise_ui()


func _show_break_feedback() -> void:
	if poise_outline != null:
		poise_outline.play_break_feedback(break_ui_feedback_duration)
	if break_text.is_empty() or FloatText == null or not FloatText.has_method("show_damage_text"):
		return

	var height: float = target.get_height() if target.has_method("get_height") else 32.0
	var spawn_position: Vector2 = target.global_position + Vector2(0.0, -height * 0.65)
	FloatText.show_damage_text(break_text, spawn_position, break_text_color)


func _setup_poise_outline() -> void:
	if health_bar == null:
		return

	poise_outline = health_bar.get_node_or_null("PoiseOutline") as EnemyPoiseOutline
	if poise_outline == null:
		poise_outline = EnemyPoiseOutline.new()
		poise_outline.name = "PoiseOutline"
		health_bar.add_child(poise_outline)
	poise_outline.outline_color = outline_color
	poise_outline.outline_width = maxf(outline_width, 0.5)


func _setup_poise_debug_display() -> void:
	if health_bar == null:
		return

	poise_debug_display = health_bar.get_node_or_null("PoiseDebugDisplay") as EnemyPoiseDebugDisplay
	if poise_debug_display == null:
		poise_debug_display = EnemyPoiseDebugDisplay.new()
		poise_debug_display.name = "PoiseDebugDisplay"
		health_bar.add_child(poise_debug_display)
	poise_debug_display.configure(
		show_debug_damage_popup,
		debug_damage_color
	)


func _refresh_poise_ui() -> void:
	if poise_outline != null:
		poise_outline.set_poise(current_poise, max_poise, poise_active)


func _on_target_died(_entity: Entity) -> void:
	poise_active = false
	poise_break_active = false
	enter_poise_after_hit_stun = false
	_refresh_poise_ui()


func _unbind_target() -> void:
	if target != null and is_instance_valid(target):
		if target.damage_taken.is_connected(_on_target_damage_taken):
			target.damage_taken.disconnect(_on_target_damage_taken)
		if target.died.is_connected(_on_target_died):
			target.died.disconnect(_on_target_died)
	if hit_reaction_controller != null and is_instance_valid(hit_reaction_controller):
		if hit_reaction_controller.hit_stun_ended.is_connected(_on_hit_stun_ended):
			hit_reaction_controller.hit_stun_ended.disconnect(_on_hit_stun_ended)

	target = null
	hit_reaction_controller = null
	health_bar = null
	poise_break_active = false
