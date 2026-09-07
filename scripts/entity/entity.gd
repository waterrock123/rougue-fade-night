class_name Entity
extends CharacterBody2D

signal died(entity: Entity)
signal damage_taken(damage_data: DamageData)
signal damage_dealt(damage_data: DamageData)
## 成功闪避一次伤害时发出，供遗物和状态监听“闪避后”类效果。
signal damage_evaded(damage_data: DamageData)

@export var max_health: float = 50.0
@export var max_energy: float = 50.0
@export var damage_text_color: Color = Color.WHITE
@export var crit_damage_text_color: Color = Color(1.0, 0.85, 0.2, 1.0)
@export var miss_damage_text_color: Color = Color(0.65, 0.85, 1.0, 1.0)
@export var heal_text_color: Color = Color(0.55, 1.0, 0.62, 1.0)

@export var energy_region_freq = 0.5
@export var energy_region_tick_value = 3
@export_group("物理移动")
## 普通移动撞到墙体后是否沿碰撞面滑动，能减少角色卡在墙角的生硬感。
@export var slide_on_collision: bool = true
## 一次移动最多尝试几次滑动。数值太高会增加物理查询，通常 1-2 次足够。
@export_range(0, 4, 1) var max_collision_slide_count: int = 1
@export_group("地形移动")
## 开启后，实体会读取 BattleMap 脚下瓦片的 move_cost，并按 1 / move_cost 修正移动距离。
@export var affected_by_terrain_move_cost: bool = true
## 地形带来的最低移动倍率，避免泥地/沼泽把实体减速到完全走不动。
@export var min_terrain_move_multiplier: float = 0.25
## 地形带来的最高移动倍率，允许道路等低 move_cost 地形小幅加速，但避免数值失控。
@export var max_terrain_move_multiplier: float = 2.0
## 开启后，实体会读取 BattleMap 脚下瓦片的 terrain_motion / acceleration_multiplier / friction_multiplier。
@export var affected_by_terrain_motion: bool = true
## 普通地面的加速响应。数值越高，按下方向键后越快达到目标速度。
@export var terrain_acceleration_rate: float = 18.0
## 普通地面的刹车响应。冰面会用 friction_multiplier 把这个值压低，从而产生滑行。
@export var terrain_friction_rate: float = 20.0
## 很慢的实体也需要一个最低参考速度，否则低 speed 下惯性会几乎看不出来。
@export var terrain_min_speed_reference: float = 24.0
@export_group("绘制排序")
## 开启后把实体根节点放回普通世界排序层，让 PlayScene/BattleMap 的 y-sort 决定前后遮挡。
@export var enable_depth_sorting: bool = true
@export var depth_sort_z_index: int = 0

var current_anim: AnimationWrapper
var current_health: float
var current_energy: float
var is_dead: bool = false
var turning_cooldown = 0.0
var movement_lock_timer = 0.0
var energy_timer = 0.0
var invulnerable_until_msec: int = 0
var action_version: int = 0
var action_tweens: Array[Tween] = []
var action_lock_sources: Dictionary = {}
var animation_pause_sources: Dictionary = {}
var animation_speed_before_pause: float = 1.0
var terrain_battle_map_cache: BattleMap
var terrain_motion_velocity: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var stats_controller: StatsController = get_node_or_null("StatsController") as StatsController
@onready var status_controller: StatusController = get_node_or_null("StatusController") as StatusController


func _ready() -> void:
	_configure_depth_sorting()
	if stats_controller != null:
		current_health = stats_controller.current_health
		current_energy = stats_controller.current_energy
	else:
		current_health = max_health
		current_energy = max_energy

	if animated_sprite != null:
		if animated_sprite.material != null:
			animated_sprite.material = animated_sprite.material.duplicate()
		if not animated_sprite.animation_finished.is_connected(on_animation_finished):
			animated_sprite.animation_finished.connect(on_animation_finished)


## 角色、敌人、召唤物和地图物件都继承 Entity，因此这里统一修正根节点 z_index。
## 这样它们不会因为某个场景里手动写了很高的 z_index 而永远压在山丘/树木前面。
func _configure_depth_sorting() -> void:
	if not enable_depth_sorting:
		return

	z_index = depth_sort_z_index
	z_as_relative = true


func _exit_tree() -> void:
	if animated_sprite != null and animated_sprite.animation_finished.is_connected(on_animation_finished):
		animated_sprite.animation_finished.disconnect(on_animation_finished)


func apply_damage(damage_event):
	if is_dead:
		return null

	var damage_data := _normalize_damage_event(damage_event)
	if damage_data == null:
		return null

	damage_data.target = self

	if is_invulnerable():
		damage_data.final_damage = 0.0
		return damage_data

	if stats_controller != null and stats_controller.should_dodge_damage(damage_data):
		damage_data.final_damage = 0.0
		damage_data.is_miss = true
		show_damage_popup(damage_data)
		damage_evaded.emit(damage_data)
		_handle_damage_callback(damage_data)
		return damage_data

	if damage_data.source != null and damage_data.source.stats_controller != null:
		damage_data = damage_data.source.stats_controller.process_outgoing_damage(damage_data)

	if stats_controller != null:
		damage_data = stats_controller.process_incoming_damage(damage_data)

	var final_damage :float = max(damage_data.final_damage, 0.0)
	current_health -= final_damage
	current_health = max(0, current_health)

	if stats_controller != null:
		stats_controller.current_health = current_health
		stats_controller.sync_runtime_resources()

	if final_damage > 0.0:
		_show_damage_taken_effect()
		show_damage_popup(damage_data)
		damage_taken.emit(damage_data)
		if damage_data.source != null and is_instance_valid(damage_data.source):
			damage_data.source.damage_dealt.emit(damage_data)

	_handle_damage_callback(damage_data)
	if current_health == 0:
		if is_in_group("enemy"):
			EventBus.enemy_killed.emit(self, damage_data.source)
		_die()

	return damage_data


func spend_energy(energy: float):
	pass


func apply_heal(heal_amount: float, show_float_text: bool = true, text_color: Color = Color.TRANSPARENT) -> float:
	if is_dead or heal_amount <= 0.0:
		return 0.0

	var max_health_value: float = get_runtime_max_health()
	if max_health_value <= 0.0:
		return 0.0

	var previous_health: float = current_health
	current_health = min(current_health + heal_amount, max_health_value)
	var actual_heal: float = max(current_health - previous_health, 0.0)
	if actual_heal <= 0.0:
		return 0.0

	if stats_controller != null:
		stats_controller.current_health = current_health
		stats_controller.sync_runtime_resources()

	if is_in_group("player"):
		EventBus.player_health_changed.emit(current_health, max_health_value)

	if show_float_text:
		var final_text_color := heal_text_color if text_color == Color.TRANSPARENT else text_color
		show_heal_popup(actual_heal, final_text_color)

	return actual_heal


func apply_runtime_stats(_final_stats: Dictionary) -> void:
	pass


func get_status_controller() -> StatusController:
	return status_controller


func get_runtime_max_health() -> float:
	if stats_controller != null:
		return stats_controller.get_stat(&"max_health", max_health)
	return max_health


## 统一的物理移动入口。
## 调用者传入“这一帧想移动多少”，这里会结合 move_cost 与地形运动参数算出真正位移。
func move_with_physics(delta_position: Vector2) -> Vector2:
	var delta: float = max(get_process_delta_time(), 0.0001)
	var adjusted_delta_position: Vector2 = _resolve_terrain_adjusted_delta(delta_position, delta)
	return _move_with_collision_delta(adjusted_delta_position, affected_by_terrain_motion)


## 给冲刺、击退、技能前摇位移使用：只走 CharacterBody2D 碰撞，不叠加脚下地形惯性。
## 这样技能位移不会因为冰面加速过慢，也不会像直接改 position 一样把实体塞进障碍物。
func move_direct_with_physics(delta_position: Vector2, update_terrain_inertia: bool = false) -> Vector2:
	return _move_with_collision_delta(delta_position, update_terrain_inertia)


func _move_with_collision_delta(delta_position: Vector2, update_terrain_inertia: bool) -> Vector2:
	var delta: float = max(get_process_delta_time(), 0.0001)
	if delta_position.length_squared() <= 0.000001:
		velocity = Vector2.ZERO
		return Vector2.ZERO

	var original_position: Vector2 = global_position
	var remaining_motion: Vector2 = delta_position
	var slide_count: int = 0

	while remaining_motion.length_squared() > 0.000001:
		var collision: KinematicCollision2D = move_and_collide(remaining_motion)
		if collision == null:
			break
		if not slide_on_collision or slide_count >= max_collision_slide_count:
			break

		remaining_motion = collision.get_remainder().slide(collision.get_normal())
		slide_count += 1

	var actual_movement: Vector2 = global_position - original_position
	velocity = actual_movement / delta
	if update_terrain_inertia:
		terrain_motion_velocity = velocity
	return actual_movement


# 兼容旧调用：移动阻挡现在由 CharacterBody2D + TileSet/StaticBody2D 物理碰撞处理。
func move_with_battle_map(delta_position: Vector2) -> Vector2:
	return move_with_physics(delta_position)


## 返回当前脚下地形给实体移动带来的倍率。move_cost=2 表示 0.5 倍速，move_cost=0.5 表示 2 倍速。
func get_terrain_move_multiplier() -> float:
	if not affected_by_terrain_move_cost:
		return 1.0
	if not is_inside_tree():
		return 1.0

	var battle_map: BattleMap = _get_terrain_battle_map()
	if battle_map == null:
		return 1.0

	var move_cost: float = battle_map.get_move_cost(global_position, 1.0)
	if move_cost <= 0.0:
		return 1.0

	return clamp(1.0 / move_cost, min_terrain_move_multiplier, max_terrain_move_multiplier)


## 立即清空地形惯性速度。冻结、强制位移或特殊技能如果需要完全停住实体，可以调用它。
func clear_terrain_motion_velocity() -> void:
	terrain_motion_velocity = Vector2.ZERO
	velocity = Vector2.ZERO


func _resolve_terrain_adjusted_delta(delta_position: Vector2, delta: float) -> Vector2:
	var desired_velocity: Vector2 = Vector2.ZERO
	if delta > 0.0:
		desired_velocity = delta_position / delta

	desired_velocity *= get_terrain_move_multiplier()
	if not affected_by_terrain_motion:
		return desired_velocity * delta

	terrain_motion_velocity = _update_terrain_motion_velocity(desired_velocity, delta)
	return terrain_motion_velocity * delta


func _update_terrain_motion_velocity(desired_velocity: Vector2, delta: float) -> Vector2:
	var profile: Dictionary = get_terrain_motion_profile()
	var acceleration_multiplier: float = float(profile.get("acceleration_multiplier", 1.0))
	var friction_multiplier: float = float(profile.get("friction_multiplier", 1.0))
	var turn_control_multiplier: float = float(profile.get("turn_control_multiplier", 1.0))
	var speed_reference: float = max(max(desired_velocity.length(), terrain_motion_velocity.length()), max(terrain_min_speed_reference, 1.0))

	if desired_velocity.length_squared() <= 0.000001:
		var friction_delta: float = speed_reference * max(terrain_friction_rate, 0.0) * friction_multiplier * delta
		return terrain_motion_velocity.move_toward(Vector2.ZERO, friction_delta)

	var target_velocity: Vector2 = _apply_terrain_turn_control(desired_velocity, turn_control_multiplier)
	var acceleration_delta: float = speed_reference * max(terrain_acceleration_rate, 0.0) * acceleration_multiplier * delta
	return terrain_motion_velocity.move_toward(target_velocity, acceleration_delta)


func _apply_terrain_turn_control(desired_velocity: Vector2, turn_control_multiplier: float) -> Vector2:
	if terrain_motion_velocity.length_squared() <= 0.000001:
		return desired_velocity
	if desired_velocity.length_squared() <= 0.000001:
		return desired_velocity

	var safe_turn_control: float = clamp(turn_control_multiplier, 0.0, 1.0)
	if safe_turn_control >= 0.999:
		return desired_velocity

	var current_angle: float = terrain_motion_velocity.angle()
	var desired_angle: float = desired_velocity.angle()
	var limited_angle: float = lerp_angle(current_angle, desired_angle, safe_turn_control)
	return Vector2.RIGHT.rotated(limited_angle) * desired_velocity.length()


func get_terrain_motion_profile() -> Dictionary:
	if not affected_by_terrain_motion:
		return {
			"motion_id": &"normal",
			"acceleration_multiplier": 1.0,
			"friction_multiplier": 1.0,
			"turn_control_multiplier": 1.0,
		}
	if not is_inside_tree():
		return {
			"motion_id": &"normal",
			"acceleration_multiplier": 1.0,
			"friction_multiplier": 1.0,
			"turn_control_multiplier": 1.0,
		}

	var battle_map: BattleMap = _get_terrain_battle_map()
	if battle_map == null:
		return {
			"motion_id": &"normal",
			"acceleration_multiplier": 1.0,
			"friction_multiplier": 1.0,
			"turn_control_multiplier": 1.0,
		}

	return battle_map.get_terrain_motion_profile(global_position)


func _get_terrain_battle_map() -> BattleMap:
	if terrain_battle_map_cache != null and is_instance_valid(terrain_battle_map_cache):
		return terrain_battle_map_cache

	terrain_battle_map_cache = get_tree().get_first_node_in_group("battle_map") as BattleMap
	return terrain_battle_map_cache


func lock_movement(duration: float) -> void:
	movement_lock_timer = max(movement_lock_timer, duration)


func is_movement_locked() -> bool:
	return movement_lock_timer > 0.0


func grant_invulnerability(duration: float) -> void:
	if duration <= 0.0:
		return

	var end_time := Time.get_ticks_msec() + int(duration * 1000.0)
	invulnerable_until_msec = max(invulnerable_until_msec, end_time)


func is_invulnerable() -> bool:
	return Time.get_ticks_msec() < invulnerable_until_msec


func can_be_targeted() -> bool:
	return not is_dead and not is_invulnerable()


## 阵营判断：玩家本体、玩家友军和召唤物都属于玩家侧。
## 不直接把召唤物加入 player 组，是为了避免触发只该属于玩家本体的 UI/存档/死亡逻辑。
func is_player_side() -> bool:
	return is_in_group("player") or is_in_group("player_ally") or is_in_group("summon_pet")


## 阵营判断：目前敌人侧主要由 enemy 组表示，后续如果有敌方召唤物也可以在这里扩展。
func is_enemy_side() -> bool:
	return is_in_group("enemy")


## 统一判断一个实体是否匹配目标组。
## 当旧技能写 target_group = "player" 时，现在会命中整个玩家侧，包括召唤物。
func matches_target_group(group_name: StringName) -> bool:
	if group_name == &"":
		return true
	if group_name == &"player":
		return is_player_side()
	if group_name == &"enemy":
		return is_enemy_side()
	return is_in_group(String(group_name))


func can_act() -> bool:
	return not is_dead and action_lock_sources.is_empty()


func add_action_lock(source_key: Variant, pause_animation: bool = false) -> void:
	var key := str(source_key)
	action_lock_sources[key] = true
	cancel_active_actions()
	if pause_animation:
		_pause_animation_from_source(key)


func remove_action_lock(source_key: Variant) -> void:
	var key := str(source_key)
	action_lock_sources.erase(key)
	_resume_animation_from_source(key)


func get_action_version() -> int:
	return action_version


func register_action_tween(tween: Tween) -> void:
	if tween == null:
		return
	action_tweens.append(tween)


func cancel_active_actions() -> void:
	action_version += 1
	movement_lock_timer = 0.0
	clear_terrain_motion_velocity()

	for tween in action_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	action_tweens.clear()


func _pause_animation_from_source(source_key: String) -> void:
	animation_pause_sources[source_key] = true
	if animated_sprite == null:
		return
	if animation_pause_sources.size() == 1:
		animation_speed_before_pause = animated_sprite.speed_scale
		animated_sprite.speed_scale = 0.0


func _resume_animation_from_source(source_key: String) -> void:
	animation_pause_sources.erase(source_key)
	if animated_sprite == null:
		return
	if animation_pause_sources.is_empty():
		animated_sprite.speed_scale = animation_speed_before_pause


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	cancel_active_actions()
	play_animation(AnimationWrapper.new("die", true))
	died.emit(self)


func play_animation(anim: AnimationWrapper):
	if animated_sprite == null or anim == null:
		return
	if animated_sprite.animation == anim.name:
		return

	if current_anim != null and current_anim.is_high_priority and not anim.is_high_priority:
		return

	current_anim = anim
	if animated_sprite.sprite_frames == null or not animated_sprite.sprite_frames.has_animation(anim.name):
		return
	animated_sprite.play(anim.name)


func turn_to_position(pos: Vector2):
	if animated_sprite == null:
		return
	if position.x > pos.x and not animated_sprite.flip_h:
		animated_sprite.flip_h = true
	elif position.x < pos.x and animated_sprite.flip_h:
		animated_sprite.flip_h = false


func get_facing_direction() -> Vector2:
	if animated_sprite == null:
		return Vector2.RIGHT
	if animated_sprite.flip_h:
		return Vector2.LEFT
	return Vector2.RIGHT


func on_animation_finished():
	current_anim = null


func get_height() -> float:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return 32.0 * absf(scale.y)

	var anim: StringName = animated_sprite.animation
	if not animated_sprite.sprite_frames.has_animation(anim):
		return 32.0 * absf(scale.y)

	var frame_texture: Texture2D = animated_sprite.sprite_frames.get_frame_texture(anim, 0)
	if frame_texture == null:
		return 32.0 * absf(scale.y)

	return frame_texture.get_height() * absf(scale.y)


func get_current_texture() -> Texture2D:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return null
	if not animated_sprite.sprite_frames.has_animation(animated_sprite.animation):
		return null
	return animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)


func show_damage_popup(damage_data: DamageData):
	var height = get_height()
	var spawn_position = Vector2(position.x, position.y - (height * 0.5))
	if damage_data != null and damage_data.is_miss:
		FloatText.show_damage_text("miss", spawn_position, miss_damage_text_color)
		return

	var text_color := damage_text_color
	if damage_data != null:
		text_color = damage_data.get_damage_type_color(damage_text_color)
		if damage_data.is_crit:
			text_color = crit_damage_text_color

	FloatText.show_damage_text(str(int(damage_data.get_display_damage())), spawn_position, text_color)


func show_heal_popup(heal_amount: float, text_color: Color = Color.TRANSPARENT) -> void:
	if heal_amount <= 0.0:
		return

	var height = get_height()
	var spawn_position = Vector2(position.x, position.y - (height * 0.5))
	var final_text_color := heal_text_color if text_color == Color.TRANSPARENT else text_color
	FloatText.show_damage_text("+%s" % int(heal_amount), spawn_position, final_text_color)


func _handle_damage_callback(_damage_data: DamageData):
	pass


func _show_damage_taken_effect():
	if animated_sprite != null and animated_sprite.material != null:
		for _i in 2:
			animated_sprite.material.set_shader_parameter("is_hurt", true)
			await get_tree().create_timer(0.05).timeout
			animated_sprite.material.set_shader_parameter("is_hurt", false)
			await get_tree().create_timer(0.05).timeout


func _normalize_damage_event(damage_event) -> DamageData:
	if damage_event is DamageData:
		var damage_data := damage_event as DamageData
		if damage_data.final_damage <= 0.0:
			damage_data.final_damage = damage_data.base_damage
		return damage_data

	if damage_event is float or damage_event is int:
		return DamageData.create(float(damage_event))

	return null
