class_name EnemyHitReactionController
extends Node

signal hit_stun_started(duration: float)
signal hit_stun_ended

const ACTION_LOCK_KEY: StringName = &"enemy_hit_stun"

var hit_stun_enabled: bool = true
var hit_stun_duration: float = 0.12
var hit_stun_recovery_time: float = 0.08
var hit_animation_name: StringName = &"hit"
var pause_animation_without_hit_animation: bool = true
var ignored_damage_tags: Array[String] = []
var automatically_react_to_damage: bool = true

var target: Entity
var hit_stun_active: bool = false
var hit_stun_remaining: float = 0.0
var next_allowed_hit_stun_msec: int = 0
var paused_fallback_animation: bool = false


func _exit_tree() -> void:
	_unbind_target()


func _process(delta: float) -> void:
	if not hit_stun_active:
		return
	if target == null or not is_instance_valid(target) or target.is_dead:
		_cancel_hit_stun(false)
		return

	hit_stun_remaining = maxf(hit_stun_remaining - delta, 0.0)
	if hit_stun_remaining <= 0.0:
		_end_hit_stun()


## 绑定受击实体，并监听统一伤害与死亡信号。
func bind_target(new_target: Entity) -> void:
	if target == new_target:
		return

	_unbind_target()
	target = new_target
	if target == null:
		return

	if not target.damage_taken.is_connected(_on_target_damage_taken):
		target.damage_taken.connect(_on_target_damage_taken)
	if not target.died.is_connected(_on_target_died):
		target.died.connect(_on_target_died)


## 尝试触发一次短硬直；未来的韧性系统可以直接调用这个入口。
func try_apply_hit_stun(damage_data: DamageData) -> bool:
	if not _can_apply_hit_stun(damage_data):
		return false
	return _start_hit_stun(hit_stun_duration)


## 强制施加一次指定时长的硬直，供破韧等明确控制效果使用。
## 该入口不受普通短硬直冷却与 can_act 限制，但仍会拒绝死亡或无效目标。
func apply_forced_hit_stun(duration: float) -> bool:
	if duration <= 0.0:
		return false
	if target == null or not is_instance_valid(target) or target.is_dead:
		return false

	if hit_stun_active:
		_cancel_hit_stun(false)
	next_allowed_hit_stun_msec = 0
	return _start_hit_stun(duration)


func _start_hit_stun(duration: float) -> bool:
	hit_stun_active = true
	hit_stun_remaining = maxf(duration, 0.0)
	var has_hit_animation: bool = _has_hit_animation()
	paused_fallback_animation = pause_animation_without_hit_animation and not has_hit_animation

	target.add_action_lock(ACTION_LOCK_KEY, paused_fallback_animation)
	if has_hit_animation:
		target.play_animation(AnimationWrapper.new(String(hit_animation_name), true))

	hit_stun_started.emit(hit_stun_remaining)
	return true


## 只判断伤害本身是否属于可触发受击反应的直接伤害，不检查当前硬直冷却。
func is_damage_eligible_for_hit_reaction(damage_data: DamageData) -> bool:
	if not hit_stun_enabled:
		return false
	if target == null or not is_instance_valid(target) or target.is_dead or target.current_health <= 0.0:
		return false
	if damage_data == null or damage_data.final_damage <= 0.0:
		return false

	for ignored_tag: String in ignored_damage_tags:
		if damage_data.tags.has(ignored_tag):
			return false
	return true


func _can_apply_hit_stun(damage_data: DamageData) -> bool:
	if hit_stun_duration <= 0.0:
		return false
	if not is_damage_eligible_for_hit_reaction(damage_data):
		return false
	if hit_stun_active or Time.get_ticks_msec() < next_allowed_hit_stun_msec:
		return false
	return target.can_act()


func _end_hit_stun() -> void:
	if not hit_stun_active:
		return

	hit_stun_active = false
	hit_stun_remaining = 0.0
	if target != null and is_instance_valid(target):
		target.remove_action_lock(ACTION_LOCK_KEY)
		_reset_fallback_animation()

	next_allowed_hit_stun_msec = Time.get_ticks_msec() + int(maxf(hit_stun_recovery_time, 0.0) * 1000.0)
	paused_fallback_animation = false
	hit_stun_ended.emit()


func _cancel_hit_stun(restore_animation: bool) -> void:
	if target != null and is_instance_valid(target):
		target.remove_action_lock(ACTION_LOCK_KEY)
		if restore_animation:
			_reset_fallback_animation()

	hit_stun_active = false
	hit_stun_remaining = 0.0
	paused_fallback_animation = false


func _reset_fallback_animation() -> void:
	if not paused_fallback_animation or target == null or target.is_dead:
		return

	# 未配置受击动画时，硬直结束后不要继续播放已经被取消的旧攻击动画。
	target.current_anim = null
	target.play_animation(AnimationWrapper.new("idle"))


func _has_hit_animation() -> bool:
	if hit_animation_name == &"" or target == null or target.animated_sprite == null:
		return false
	if target.animated_sprite.sprite_frames == null:
		return false
	return target.animated_sprite.sprite_frames.has_animation(hit_animation_name)


func _on_target_damage_taken(damage_data: DamageData) -> void:
	if automatically_react_to_damage:
		try_apply_hit_stun(damage_data)


func _on_target_died(_entity: Entity) -> void:
	_cancel_hit_stun(false)


func _unbind_target() -> void:
	if target == null or not is_instance_valid(target):
		target = null
		return

	_cancel_hit_stun(false)
	if target.damage_taken.is_connected(_on_target_damage_taken):
		target.damage_taken.disconnect(_on_target_damage_taken)
	if target.died.is_connected(_on_target_died):
		target.died.disconnect(_on_target_died)
	target = null
