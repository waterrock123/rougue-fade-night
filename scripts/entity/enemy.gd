class_name Enemy
extends Entity


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
var velocity: Vector2
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

@onready var ability_controller: AbilityController = $AbilityController
@onready var collision_shape: CollisionShape2D =$Area2D/CollisionShape2D

@onready var pathfinding: Pathfinding = $Pathfinding


func _ready() -> void:
	super._ready()
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
		velocity = Vector2.ZERO
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
			global_position += movement_dir * delta * speed
			
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
		global_position += direction.normalized() * speed * neutral_speed_multiplier * delta
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

	for group_name in [&"player", &"player_ally", &"summon_pet"]:
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


# 敌人 AI 的技能选择入口。
# 普通小怪可以保持 FIRST_READY；Boss 推荐使用 SEQUENCE_READY 或 RANDOM_READY。
func _try_cast_ability(target_distance: float) -> bool:
	if ability_controller == null:
		return false

	match ability_select_mode:
		AbilitySelectMode.SEQUENCE_READY:
			var next_index := ability_controller.trigger_next_available_ability_for_ai(next_ability_index, target_distance, stop_distance)
			if next_index >= 0:
				next_ability_index = next_index
				return true
			return false
		AbilitySelectMode.RANDOM_READY:
			return ability_controller.trigger_random_available_ability_for_ai(target_distance, stop_distance)
		_:
			return ability_controller.trigger_first_available_ability_for_ai(target_distance, stop_distance)
	

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
