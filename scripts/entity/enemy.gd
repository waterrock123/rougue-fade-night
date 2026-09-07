class_name Enemy
extends Entity

const DEFAULT_POISE_BREAK_SOUND = preload("res://resource/poise_break_sound.tres")


enum AbilitySelectMode {
	FIRST_READY,
	SEQUENCE_READY,
	RANDOM_READY,
}


#速度
@export var speed: float = 10.0
@export var sprite_faces_left_by_default: bool = false
#停下来攻击的距离
@export var stop_distance: float = 10.0
#攻击性
@export var aggresive = false
#记忆：追击玩家的秒数
@export var memory = 0.0
#警戒范围,进入此范围敌人开始追击
@export var chase_distance = 30.0
#被击中粒子特效
@export var hit_particles: CPUParticles2D 
@export var ability_select_mode: AbilitySelectMode = AbilitySelectMode.FIRST_READY

@export_group("受击硬直")
## 是否允许这类敌人在受到有效直接伤害后进入短硬直。
@export var hit_stun_enabled: bool = true
## 单次硬直持续时间。硬直期间不会重复刷新持续时间。
@export_range(0.0, 1.0, 0.01) var hit_stun_duration: float = 0.12
## 硬直结束后的短暂保护时间，用于缓解高攻速攻击造成的连续控制。
@export_range(0.0, 1.0, 0.01) var hit_stun_recovery_time: float = 0.08
## 如果 SpriteFrames 中存在该动画，受击时会优先播放；暂时没有可以保持默认值。
@export var hit_animation_name: StringName = &"hit"
## 没有受击动画时，是否在硬直期间暂停当前动画作为临时反馈。
@export var pause_animation_without_hit_animation: bool = true
## 这些伤害仍然正常扣血，但不会造成硬直。
@export var hit_stun_ignored_damage_tags: Array[String] = ["status", "terrain", "periodic", "retaliation", "reflect"]

@export_group("韧性")
## 达到指定硬直次数后，敌人在最后一次硬直结束时进入韧性状态。
@export var poise_enabled: bool = true
@export_range(1, 20, 1) var hit_stuns_required_for_poise: int = 3
## 敌人进入韧性状态后的韧性上限。默认 10，较旧版 100 下调十倍，让破韧循环更快进入反馈。
@export var max_poise: float = 10.0
## 未给 DamageData 单独配置削韧值时，每次直接攻击提供的固定削韧。
@export var base_poise_damage: float = 15.0
## 未单独配置削韧值时，最终伤害按该比例额外转化为削韧。
@export var damage_to_poise_ratio: float = 0.5
@export var poise_outline_color: Color = Color.WHITE
@export_range(0.5, 4.0, 0.1) var poise_outline_width: float = 1.0
## 韧性归零后的长硬直时间。普通怪可设置更长，Boss 可单独调短。
@export_range(0.0, 5.0, 0.05) var poise_break_stun_duration: float = 1.0
## 破韧时显示在敌人头顶的文字和颜色。
@export var poise_break_text: String = "破韧"
@export var poise_break_text_color: Color = Color(1.0, 0.82, 0.28, 1.0)
## 血条韧性外圈归零时的扩散闪白持续时间。
@export_range(0.0, 2.0, 0.05) var poise_break_ui_feedback_duration: float = 0.35

@export_group("韧性调试浮字")
## 默认关闭。常规战斗仅使用血条外沿的白色轮廓表示剩余韧性。
## 开启后，受到削韧时会在血条上方短暂显示本次削韧值。
@export var show_poise_damage_popup: bool = false
@export var poise_debug_damage_color: Color = Color(1.0, 0.78, 0.3, 1.0)

@export_group("韧性视觉反馈")
## 韧性状态下是否为敌人本体显示缓慢闪烁的发光轮廓。
@export var poise_body_glow_enabled: bool = true
@export var poise_body_glow_color: Color = Color(1.0, 0.95, 0.72, 1.0)
@export_range(0.0, 4.0, 0.1) var poise_body_glow_size: float = 1.0
@export_range(0.0, 1.0, 0.01) var poise_body_glow_alpha: float = 0.75
@export_range(0.0, 1.0, 0.01) var poise_body_glow_pulse_strength: float = 0.25
@export_range(0.0, 12.0, 0.1) var poise_body_glow_pulse_speed: float = 3.0
## 破韧时本体闪白的颜色与淡入淡出时间。
@export var poise_break_flash_color: Color = Color.WHITE
@export_range(0.0, 1.0, 0.01) var poise_break_flash_in_duration: float = 0.05
@export_range(0.0, 1.0, 0.01) var poise_break_flash_out_duration: float = 0.2
## 默认复用现有撞击音效，也可以为 Boss 单独替换。
@export var poise_break_sound: AudiioConfig = DEFAULT_POISE_BREAK_SOUND
@export_range(0.0, 10.0, 0.1) var poise_break_camera_shake_strength: float = 1.2
@export_range(0.0, 1.0, 0.01) var poise_break_camera_shake_duration: float = 0.16

@export_group("敌人血条")
## 默认寻找敌人根节点下名为 EnemyHealthBar 的 TextureProgressBar。
@export var health_bar_path: NodePath = NodePath("EnemyHealthBar")
## 敌人受伤后才显示血条，避免战场上常驻太多 UI。
@export var show_health_bar_after_damage: bool = true
## 血量回满时重新隐藏血条。
@export var hide_health_bar_when_full: bool = true

@export_group("悬赏精英怪")
## 是否作为悬赏精英怪。悬赏怪可以不参与战斗胜利判定，并在死亡时给玩家额外金币。
@export var is_bounty_elite: bool = false
@export var bounty_gold: int = 0
## 开场是否保持中立。中立时只会在出生点附近游荡，被玩家侧单位攻击后才会主动追击。
@export var bounty_starts_neutral: bool = false
@export var neutral_speed_multiplier: float = 0.45
@export var neutral_wander_radius: float = 120.0
@export var neutral_wander_repick_interval: float = 1.8
@export var neutral_wander_arrive_distance: float = 12.0


var current_target: Entity
var current_speed: float
var last_position
#是否处于追击状态
var chasing = false
#记忆计时器
var memory_timer = 0.0
var next_ability_index: int = 0
var bounty_activated: bool = false
var neutral_home_position: Vector2 = Vector2.ZERO
var neutral_wander_anchor: Vector2 = Vector2.ZERO
var neutral_wander_timer: float = 0.0
var last_damage_source: Entity
var enemy_health_bar: TextureProgressBar
var hit_reaction_controller: EnemyHitReactionController
var poise_controller: EnemyPoiseController
var poise_feedback_controller: EnemyPoiseFeedbackController

@onready var ability_controller: AbilityController = $AbilityController
@onready var collision_shape: CollisionShape2D =$Area2D/CollisionShape2D

@onready var pathfinding: Pathfinding = $Pathfinding


func _ready() -> void:
	super._ready()
	_setup_hit_reaction_controller()
	_setup_enemy_health_bar()
	_setup_poise_controller()
	_setup_poise_feedback_controller()
	add_to_group('enemy')
	if is_bounty_elite:
		add_to_group("bounty_elite")
	last_position = position
	neutral_home_position = global_position
	bounty_activated = not (is_bounty_elite and bounty_starts_neutral)
	if aggresive and bounty_activated:
		chasing = true
	_pick_neutral_wander_anchor()
	_connect_death_animation_finished()
	


func _process(delta: float) -> void:
	if is_dead: return
	movement_lock_timer = max(0.0, movement_lock_timer - delta)
	if not can_act():
		clear_terrain_motion_velocity()
		current_speed = 0.0
		last_position = position
		return

	if _is_waiting_neutral_bounty():
		_process_neutral_wander(delta)
		return

	current_target = _find_nearest_player_side_target()
	if current_target == null:
		if not aggresive:
			chasing = false
		_update_motion_cache(delta)
		_handle_animations()
		return

	var distance := global_position.distance_to(current_target.global_position)
	if !aggresive and distance <= chase_distance:
		chasing = true

	if is_movement_locked():
		clear_terrain_motion_velocity()
		_update_motion_cache(delta)
		_handle_animations()
		return
	
	
	if  chasing and current_target != null:
		# 先按技能自己的 AI 距离尝试施法；远程/突进技能不再被 stop_distance 卡住。
		if _try_cast_ability(distance):
			_face_target(current_target.global_position - global_position)
			_update_motion_cache(delta)
			_handle_animations()
			return

		# 移动方向：敌人现在会把玩家侧召唤物也当作追击目标。
		var movement_dir = Vector2.ZERO
		
		if pathfinding !=null:
			movement_dir = pathfinding.find_path(current_target.global_position).normalized()
		else:
			movement_dir = (current_target.global_position - global_position).normalized()
		
		var approach_stop_distance = _get_approach_stop_distance()
		if distance > approach_stop_distance:
			move_with_physics(movement_dir * delta * speed)
			
		_face_target(current_target.global_position - global_position)	
	_update_motion_cache(delta)
	
	_handle_animations()
	if not aggresive and chasing and distance >= chase_distance:
		memory_timer += delta
		
		if memory_timer >= memory:
			memory_timer = 0.0
			chasing = false


func configure_bounty_elite(
	new_bounty_gold: int,
	starts_neutral: bool = true,
	new_neutral_speed_multiplier: float = 0.45,
	new_neutral_wander_radius: float = 120.0,
	new_neutral_wander_repick_interval: float = 1.8
) -> void:
	is_bounty_elite = true
	bounty_gold = max(new_bounty_gold, 0)
	bounty_starts_neutral = starts_neutral
	neutral_speed_multiplier = max(new_neutral_speed_multiplier, 0.0)
	neutral_wander_radius = max(new_neutral_wander_radius, 0.0)
	neutral_wander_repick_interval = max(new_neutral_wander_repick_interval, 0.1)
	bounty_activated = not bounty_starts_neutral
	if is_inside_tree():
		add_to_group("bounty_elite")
		neutral_home_position = global_position
		_pick_neutral_wander_anchor()


func activate_bounty_elite() -> void:
	if not is_bounty_elite or bounty_activated:
		return

	bounty_activated = true
	chasing = true
	aggresive = true
	memory_timer = 0.0


func _is_waiting_neutral_bounty() -> bool:
	return is_bounty_elite and bounty_starts_neutral and not bounty_activated


func is_neutral_bounty_elite() -> bool:
	return _is_waiting_neutral_bounty()


func _process_neutral_wander(delta: float) -> void:
	neutral_wander_timer -= delta
	if neutral_wander_timer <= 0.0 or global_position.distance_to(neutral_wander_anchor) <= neutral_wander_arrive_distance:
		_pick_neutral_wander_anchor()

	var direction: Vector2 = Vector2.ZERO
	if pathfinding != null:
		direction = pathfinding.find_path(neutral_wander_anchor)
	if direction == Vector2.ZERO:
		direction = global_position.direction_to(neutral_wander_anchor)

	if direction != Vector2.ZERO:
		move_with_physics(direction.normalized() * speed * neutral_speed_multiplier * delta)
		_face_target(direction)

	_update_motion_cache(delta)
	_handle_animations()


func _pick_neutral_wander_anchor() -> void:
	neutral_wander_timer = neutral_wander_repick_interval
	var angle: float = randf() * TAU
	var distance: float = randf_range(0.0, max(neutral_wander_radius, 0.0))
	neutral_wander_anchor = neutral_home_position + Vector2.RIGHT.rotated(angle) * distance


func _update_motion_cache(delta: float) -> void:
	if delta <= 0.0:
		velocity = Vector2.ZERO
	else:
		velocity = (position - last_position) / delta
	current_speed = velocity.length()
	last_position = position


func _find_nearest_player_side_target() -> Entity:
	var nearest: Entity
	var nearest_distance := INF

	# 地图动物加入 map_object 组，并通过 is_player_side() 表示“敌人可以攻击它”。
	for group_name in [&"player", &"player_ally", &"summon_pet", &"map_object"]:
		for node in get_tree().get_nodes_in_group(String(group_name)):
			if not (node is Entity):
				continue

			var candidate := node as Entity
			if not candidate.is_player_side():
				continue
			if candidate.has_method("can_be_targeted") and not candidate.can_be_targeted():
				continue

			var distance := global_position.distance_to(candidate.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate

	return nearest


func apply_runtime_stats(final_stats: Dictionary) -> void:
	if final_stats.has("move_speed"):
		speed = float(final_stats["move_speed"])
	_refresh_enemy_health_bar(enemy_health_bar != null and enemy_health_bar.visible)


# 敌人 AI 的技能选择入口。
# 普通小怪可以保持 FIRST_READY；Boss 推荐使用 SEQUENCE_READY 或 RANDOM_READY。
func _try_cast_ability(target_distance: float) -> bool:
	if ability_controller == null:
		return false

	match ability_select_mode:
		AbilitySelectMode.SEQUENCE_READY:
			var next_index := ability_controller.trigger_next_available_ability_for_ai(next_ability_index, target_distance, stop_distance, current_target)
			if next_index >= 0:
				next_ability_index = next_index
				return true
			return false
		AbilitySelectMode.RANDOM_READY:
			return ability_controller.trigger_random_available_ability_for_ai(target_distance, stop_distance, current_target)
		_:
			return ability_controller.trigger_first_available_ability_for_ai(target_distance, stop_distance, current_target)
	

func _get_approach_stop_distance() -> float:
	if ability_controller == null:
		return stop_distance

	var closest_ready_cast_range = INF
	for ability in ability_controller.abilities:
		if ability == null:
			continue
		if not ability_controller.can_cast_ability(ability):
			continue

		var cast_range = ability.get_ai_max_cast_distance(stop_distance)
		if cast_range <= 0.0:
			continue

		closest_ready_cast_range = min(closest_ready_cast_range, cast_range)

	if closest_ready_cast_range == INF:
		return stop_distance

	# 如果技能真正的可释放距离比 stop_distance 更近，就继续靠近，避免敌人在攻击范围外发呆。
	return min(stop_distance, max(closest_ready_cast_range * 0.9, 0.0))
	
	
func _handle_animations():
	if current_speed <= 0:
		play_animation(AnimationWrapper.new("idle"))
	else:
		play_animation(AnimationWrapper.new("walk"))
		
		
func _face_target(dir: Vector2):
	if dir.x == 0:
		return

	var should_face_left := dir.x < 0
	animated_sprite.flip_h = should_face_left != sprite_faces_left_by_default
		
	
func get_height() ->float:
	if collision_shape!= null:
		var shape = collision_shape.shape
		if shape is CapsuleShape2D:
			return shape.height*self.scale.y
		elif  shape is RectangleShape2D:
			return shape.size.y * self.scale.y
		else:
			return super.get_height()
	else:
		return super.get_height()
	

func _show_damage_taken_effect():
	super._show_damage_taken_effect()
	if hit_particles != null:
		hit_particles.emitting = true


func _handle_damage_callback(damage_data: DamageData) -> void:
	if damage_data == null:
		return

	last_damage_source = damage_data.source
	if _is_waiting_neutral_bounty() and _is_player_side_source(damage_data.source):
		activate_bounty_elite()


func _die() -> void:
	var should_grant_bounty: bool = is_bounty_elite and bounty_gold > 0 and _is_player_side_source(last_damage_source)
	super._die()
	if should_grant_bounty:
		EventBus.bounty_enemy_killed.emit(self, last_damage_source, bounty_gold)


func _setup_enemy_health_bar() -> void:
	var bar_node: Node = get_node_or_null(health_bar_path)
	enemy_health_bar = bar_node as TextureProgressBar
	if enemy_health_bar == null:
		return

	# 敌人血条只显示百分比，所以统一把进度条范围标准化为 0-100。
	enemy_health_bar.min_value = 0.0
	enemy_health_bar.max_value = 100.0
	enemy_health_bar.value = 100.0
	enemy_health_bar.visible = false
	_refresh_enemy_health_bar(false)

	var damage_callback := Callable(self, "_on_enemy_damage_taken")
	if not damage_taken.is_connected(damage_callback):
		damage_taken.connect(damage_callback)

	var death_callback := Callable(self, "_on_enemy_died")
	if not died.is_connected(death_callback):
		died.connect(death_callback)


## 受击反应由独立控制器管理，Enemy 只负责提供每种怪物可调的参数。
func _setup_hit_reaction_controller() -> void:
	hit_reaction_controller = get_node_or_null("HitReactionController") as EnemyHitReactionController
	if hit_reaction_controller == null:
		hit_reaction_controller = EnemyHitReactionController.new()
		hit_reaction_controller.name = "HitReactionController"
		add_child(hit_reaction_controller)

	hit_reaction_controller.hit_stun_enabled = hit_stun_enabled
	hit_reaction_controller.hit_stun_duration = hit_stun_duration
	hit_reaction_controller.hit_stun_recovery_time = hit_stun_recovery_time
	hit_reaction_controller.hit_animation_name = hit_animation_name
	hit_reaction_controller.pause_animation_without_hit_animation = pause_animation_without_hit_animation
	hit_reaction_controller.ignored_damage_tags = hit_stun_ignored_damage_tags.duplicate()
	hit_reaction_controller.automatically_react_to_damage = false
	hit_reaction_controller.bind_target(self)


## 韧性控制器统一接管受伤事件，并决定本次攻击触发短硬直还是削减韧性。
func _setup_poise_controller() -> void:
	poise_controller = get_node_or_null("PoiseController") as EnemyPoiseController
	if poise_controller == null:
		poise_controller = EnemyPoiseController.new()
		poise_controller.name = "PoiseController"
		add_child(poise_controller)

	poise_controller.poise_enabled = poise_enabled
	poise_controller.hit_stuns_required = hit_stuns_required_for_poise
	poise_controller.max_poise = maxf(max_poise, 0.0)
	poise_controller.base_poise_damage = maxf(base_poise_damage, 0.0)
	poise_controller.damage_to_poise_ratio = maxf(damage_to_poise_ratio, 0.0)
	poise_controller.outline_color = poise_outline_color
	poise_controller.outline_width = poise_outline_width
	poise_controller.break_stun_duration = maxf(poise_break_stun_duration, 0.0)
	poise_controller.break_text = poise_break_text
	poise_controller.break_text_color = poise_break_text_color
	poise_controller.break_ui_feedback_duration = maxf(poise_break_ui_feedback_duration, 0.0)
	poise_controller.show_debug_damage_popup = show_poise_damage_popup
	poise_controller.debug_damage_color = poise_debug_damage_color
	poise_controller.bind_target(self, hit_reaction_controller, enemy_health_bar)


## 韧性反馈单独监听状态机信号，负责 Shader、音效与相机，不参与战斗数值计算。
func _setup_poise_feedback_controller() -> void:
	poise_feedback_controller = get_node_or_null("PoiseFeedbackController") as EnemyPoiseFeedbackController
	if poise_feedback_controller == null:
		poise_feedback_controller = EnemyPoiseFeedbackController.new()
		poise_feedback_controller.name = "PoiseFeedbackController"
		add_child(poise_feedback_controller)

	poise_feedback_controller.body_glow_enabled = poise_body_glow_enabled
	poise_feedback_controller.body_glow_color = poise_body_glow_color
	poise_feedback_controller.body_glow_size = poise_body_glow_size
	poise_feedback_controller.body_glow_alpha = poise_body_glow_alpha
	poise_feedback_controller.body_glow_pulse_strength = poise_body_glow_pulse_strength
	poise_feedback_controller.body_glow_pulse_speed = poise_body_glow_pulse_speed
	poise_feedback_controller.break_flash_color = poise_break_flash_color
	poise_feedback_controller.break_flash_in_duration = poise_break_flash_in_duration
	poise_feedback_controller.break_flash_out_duration = poise_break_flash_out_duration
	poise_feedback_controller.break_sound = poise_break_sound
	poise_feedback_controller.camera_shake_strength = poise_break_camera_shake_strength
	poise_feedback_controller.camera_shake_duration = poise_break_camera_shake_duration
	poise_feedback_controller.bind_target(self, poise_controller)


func _on_enemy_damage_taken(_damage_data: DamageData) -> void:
	_refresh_enemy_health_bar(show_health_bar_after_damage)


func _on_enemy_died(_entity: Entity) -> void:
	if enemy_health_bar != null:
		enemy_health_bar.visible = false


func _refresh_enemy_health_bar(allow_show: bool) -> void:
	if enemy_health_bar == null:
		return

	var max_health_value: float = max_health
	if stats_controller != null:
		max_health_value = stats_controller.get_stat(&"max_health", max_health)

	if max_health_value <= 0.0:
		enemy_health_bar.value = 0.0
		enemy_health_bar.visible = false
		return

	var health_percent: float = clamp(current_health / max_health_value, 0.0, 1.0) * 100.0
	enemy_health_bar.value = health_percent

	if not allow_show:
		enemy_health_bar.visible = false
		return

	if hide_health_bar_when_full and health_percent >= 99.9:
		enemy_health_bar.visible = false
		return

	enemy_health_bar.visible = true


func _is_player_side_source(source: Entity) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	return source.is_player_side()
	


func _on_animated_sprite_2d_animation_finished() -> void:
	# current_anim 会被 Entity.on_animation_finished 清空，所以这里直接读取当前精灵动画名。
	# 这样不依赖信号连接顺序，死亡动画结束后一定能释放敌人节点。
	if animated_sprite != null and animated_sprite.animation == &"die":
		queue_free()


func _connect_death_animation_finished() -> void:
	if animated_sprite == null:
		return

	var callback := Callable(self, "_on_animated_sprite_2d_animation_finished")
	if not animated_sprite.animation_finished.is_connected(callback):
		animated_sprite.animation_finished.connect(callback)
