class_name SummonPet
extends Entity

enum AbilitySelectMode {
	FIRST_READY,
	SEQUENCE_READY,
	RANDOM_READY,
}

enum AiRole {
	ATTACKER,
	SUPPORT,
}

@export_group("基础移动")
## 生成时播放的动画。放映机召唤出的影子会先播 appear，再进入正常 AI。
@export var spawn_animation: StringName = &"appear"
## 生成动画播放期间是否暂停 AI 与移动。
@export var pause_ai_during_spawn_animation: bool = true
## 召唤物移动速度，会被 StatsController 的 move_speed 覆盖。
@export var speed: float = 80.0
## 精灵图默认是否朝左。不同素材朝向不一致时，用这个修正翻转逻辑。
@export var sprite_faces_left_by_default: bool = false
## 朝向切换的水平占比阈值。目标几乎在正上/正下方时不转身，避免左右疯狂抖动。
@export_range(0.0, 1.0, 0.01) var face_horizontal_threshold: float = 0.25
## 每次真正翻转后的短暂冷却，防止寻路或碰撞带来的微小方向变化连续翻面。
@export var face_change_cooldown: float = 0.12
## 距离目标多近时停止移动并尝试攻击。
@export var stop_distance: float = 42.0

@export_group("召唤者")
## 召唤者路径。一般由召唤技能运行时调用 set_summoner() 设置；编辑器里也可以临时指定。
@export var summoner_path: NodePath
## 没有显式召唤者时，是否自动把场景里的 player 当作召唤者。
@export var auto_bind_player_as_summoner: bool = true
## 与召唤者保持的最小徘徊距离，避免召唤物紧贴玩家。
@export var follow_min_distance: float = 56.0
## 与召唤者保持的最大徘徊距离，超过后会向徘徊点移动。
@export var follow_max_distance: float = 120.0
## 召唤物离召唤者超过这个距离时，会放弃当前攻击目标并先回到召唤者附近。
@export var return_to_summoner_distance: float = 260.0
## 徘徊目标点多久重新随机一次。
@export var wander_repick_interval: float = 1.6
## 到达徘徊点多少距离内就认为已经到位。
@export var wander_arrive_distance: float = 14.0

@export_group("索敌")
## 召唤物会搜索这个 group 里的目标。玩家召唤物通常搜索 enemy。
@export var target_group: String = "enemy"
## 搜索附近敌人的范围。
@export var chase_distance: float = 240.0
## 追击目标时，目标离召唤者太远则不追，避免召唤物把玩家甩在身后。
@export var max_target_distance_from_summoner: float = 360.0
## 多久刷新一次当前目标，避免每帧全图扫描。
@export var target_refresh_interval: float = 0.25

@export_group("战斗")
## 召唤物的技能选择方式，和 Enemy 的可选项保持一致。
@export var ability_select_mode: AbilitySelectMode = AbilitySelectMode.FIRST_READY
## 召唤物的 AI 职责。攻击型会索敌追击；辅助型不追敌，只围绕召唤者并尝试释放增益技能。
@export var ai_role: AiRole = AiRole.ATTACKER
## 被击中粒子特效。
@export var hit_particles: CPUParticles2D

var summoner: Entity
var target: Entity
var current_speed: float = 0.0
var last_position: Vector2 = Vector2.ZERO
var next_ability_index: int = 0
var target_refresh_timer: float = 0.0
var wander_timer: float = 0.0
var wander_anchor: Vector2 = Vector2.ZERO
var is_playing_spawn_animation: bool = false
var spawn_animation_token: int = 0
var face_change_timer: float = 0.0

@onready var ability_controller: AbilityController = get_node_or_null("AbilityController") as AbilityController
@onready var collision_shape: CollisionShape2D = get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
@onready var pathfinding: Pathfinding = get_node_or_null("Pathfinding") as Pathfinding


func _ready() -> void:
	super._ready()
	add_to_group("summon_pet")
	add_to_group("player_ally")
	if hit_particles == null:
		hit_particles = get_node_or_null("HitParticles") as CPUParticles2D
	_resolve_initial_summoner()
	last_position = global_position
	_pick_new_wander_anchor()
	_connect_death_animation_finished()


func _process(delta: float) -> void:
	if is_dead:
		return

	movement_lock_timer = max(0.0, movement_lock_timer - delta)
	face_change_timer = max(0.0, face_change_timer - delta)
	if is_playing_spawn_animation and pause_ai_during_spawn_animation:
		_stop_moving()
		return
	if not can_act():
		_stop_moving()
		return

	if not _has_valid_summoner():
		_resolve_initial_summoner()

	if ai_role == AiRole.SUPPORT:
		target = null
	else:
		_update_target(delta)

	var move_direction := _decide_move_direction()
	_apply_movement(move_direction, delta)
	_update_motion_cache(delta)
	_handle_animations()


## 由召唤技能/遗物在实例化后调用，建立召唤物和召唤者的关系。
func set_summoner(new_summoner: Entity) -> void:
	summoner = new_summoner
	_pick_new_wander_anchor()


## 提供给召唤物派生效果查询召唤者，例如“召唤物命中后给主人回血/加状态”。
func get_summoner() -> Entity:
	if _has_valid_summoner():
		return summoner
	return null


## 播放召唤物出生动画。因为部分素材的 appear 是循环动画，所以这里按动画总时长计时，而不是依赖 animation_finished。
func play_spawn_animation(animation_name: StringName = spawn_animation) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	spawn_animation_token += 1
	var current_token := spawn_animation_token
	is_playing_spawn_animation = true
	current_anim = AnimationWrapper.new(String(animation_name), true)
	animated_sprite.play(animation_name)

	var duration := _get_animation_duration(animation_name)
	if duration <= 0.0:
		_finish_spawn_animation(current_token)
		return

	await get_tree().create_timer(duration, false).timeout
	_finish_spawn_animation(current_token)


func apply_runtime_stats(final_stats: Dictionary) -> void:
	if final_stats.has("move_speed"):
		speed = float(final_stats["move_speed"])


func get_height() -> float:
	if collision_shape != null:
		var shape := collision_shape.shape
		if shape is CapsuleShape2D:
			return (shape as CapsuleShape2D).height * scale.y
		if shape is RectangleShape2D:
			return (shape as RectangleShape2D).size.y * scale.y

	return super.get_height()


func _handle_damage_callback(_damage_data: DamageData) -> void:
	# 这里暂时只保留扩展点：后续召唤物受伤给主人触发效果时可以从这里接。
	pass


func _show_damage_taken_effect() -> void:
	super._show_damage_taken_effect()
	if hit_particles != null:
		hit_particles.emitting = true


func _resolve_initial_summoner() -> void:
	if summoner_path != NodePath():
		var node := get_node_or_null(summoner_path)
		if node is Entity:
			set_summoner(node as Entity)
			return

	if auto_bind_player_as_summoner:
		var player := get_tree().get_first_node_in_group("player")
		if player is Entity:
			set_summoner(player as Entity)


func _has_valid_summoner() -> bool:
	return summoner != null and is_instance_valid(summoner) and not summoner.is_dead


func _update_target(delta: float) -> void:
	if _must_return_to_summoner():
		target = null
		return

	target_refresh_timer -= delta
	if target_refresh_timer > 0.0 and _is_valid_target(target):
		return

	target_refresh_timer = target_refresh_interval
	target = _find_nearest_target()


func _decide_move_direction() -> Vector2:
	if ai_role == AiRole.SUPPORT:
		return _decide_support_move_direction()

	if _must_return_to_summoner():
		return _get_direction_to_wander_anchor(true)

	if _is_valid_target(target):
		var to_target := target.global_position - global_position
		var target_distance := to_target.length()
		_face_target(to_target)

		# 先按技能自己的 AI 距离尝试施法；突进/远程召唤物不再必须贴到 stop_distance。
		if _try_cast_ability(target_distance):
			return Vector2.ZERO

		if target_distance > stop_distance:
			return _get_path_direction(target.global_position)

		return Vector2.ZERO

	return _get_direction_to_wander_anchor(false)


func _decide_support_move_direction() -> Vector2:
	if _must_return_to_summoner():
		return _get_direction_to_wander_anchor(true)

	var support_distance := 0.0
	if _has_valid_summoner():
		support_distance = global_position.distance_to(summoner.global_position)

	# 辅助型召唤物不主动追敌；它把“离召唤者多远”当作 AI 施法距离，用于治疗圈、加速圈等增益技能。
	_try_cast_ability(support_distance)
	return _get_direction_to_wander_anchor(false)


func _apply_movement(direction: Vector2, delta: float) -> void:
	if is_movement_locked():
		return
	if direction == Vector2.ZERO:
		return

	move_with_physics(direction.normalized() * speed * delta)
	_face_target(direction)


func _update_motion_cache(delta: float) -> void:
	if delta <= 0.0:
		velocity = Vector2.ZERO
	else:
		velocity = (global_position - last_position) / delta

	current_speed = velocity.length()
	last_position = global_position


func _stop_moving() -> void:
	velocity = Vector2.ZERO
	current_speed = 0.0
	last_position = global_position


func _must_return_to_summoner() -> bool:
	if not _has_valid_summoner():
		return false
	return global_position.distance_to(summoner.global_position) > return_to_summoner_distance


func _get_direction_to_wander_anchor(force_repick_if_far: bool) -> Vector2:
	if not _has_valid_summoner():
		return Vector2.ZERO

	wander_timer -= get_process_delta_time()
	var distance_to_anchor := global_position.distance_to(wander_anchor)
	var distance_to_summoner := global_position.distance_to(summoner.global_position)

	if force_repick_if_far or wander_timer <= 0.0 or distance_to_anchor <= wander_arrive_distance:
		_pick_new_wander_anchor()

	if distance_to_summoner < follow_min_distance:
		var away := summoner.global_position.direction_to(global_position)
		return away if away != Vector2.ZERO else Vector2.RIGHT

	if distance_to_summoner > follow_max_distance or distance_to_anchor > wander_arrive_distance:
		return _get_path_direction(wander_anchor)

	return Vector2.ZERO


func _pick_new_wander_anchor() -> void:
	wander_timer = wander_repick_interval
	if not _has_valid_summoner():
		wander_anchor = global_position
		return

	var min_distance = min(follow_min_distance, follow_max_distance)
	var max_distance = max(follow_min_distance, follow_max_distance)
	var angle := randf() * TAU
	var distance := randf_range(min_distance, max_distance)
	wander_anchor = summoner.global_position + Vector2.RIGHT.rotated(angle) * distance


func _find_nearest_target() -> Entity:
	var nearest: Entity
	var nearest_distance := INF

	for node in get_tree().get_nodes_in_group(target_group):
		if not (node is Entity):
			continue

		var candidate := node as Entity
		if not _is_valid_target(candidate):
			continue

		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate

	return nearest


func _is_valid_target(candidate: Entity) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if candidate == self or candidate.is_dead:
		return false
	if candidate.has_method("is_neutral_bounty_elite") and candidate.is_neutral_bounty_elite():
		return false
	if candidate.has_method("can_be_targeted") and not candidate.can_be_targeted():
		return false
	if global_position.distance_to(candidate.global_position) > chase_distance:
		return false
	if _has_valid_summoner() and max_target_distance_from_summoner > 0.0:
		if summoner.global_position.distance_to(candidate.global_position) > max_target_distance_from_summoner:
			return false
	return true


func _get_path_direction(target_position: Vector2) -> Vector2:
	if pathfinding != null:
		var path_direction: Vector2 = pathfinding.find_path(target_position)
		if path_direction != Vector2.ZERO:
			return path_direction.normalized()

	return global_position.direction_to(target_position)


func _try_cast_ability(target_distance: float) -> bool:
	if ability_controller == null:
		return false

	match ability_select_mode:
		AbilitySelectMode.SEQUENCE_READY:
			var next_index := ability_controller.trigger_next_available_ability_for_ai(next_ability_index, target_distance, stop_distance, target)
			if next_index >= 0:
				next_ability_index = next_index
				return true
			return false
		AbilitySelectMode.RANDOM_READY:
			return ability_controller.trigger_random_available_ability_for_ai(target_distance, stop_distance, target)
		_:
			return ability_controller.trigger_first_available_ability_for_ai(target_distance, stop_distance, target)


func _handle_animations() -> void:
	if is_playing_spawn_animation:
		return
	if current_speed <= 0.0:
		play_animation(AnimationWrapper.new("idle"))
	else:
		play_animation(AnimationWrapper.new("walk"))


func _face_target(direction: Vector2) -> void:
	if animated_sprite == null or direction.length_squared() <= 0.0001:
		return

	var horizontal_ratio = absf(direction.x) / max(direction.length(), 0.001)
	if horizontal_ratio < face_horizontal_threshold:
		return

	var should_face_left := direction.x < 0.0
	var next_flip_h := should_face_left != sprite_faces_left_by_default
	if animated_sprite.flip_h == next_flip_h:
		return
	if face_change_timer > 0.0:
		return

	animated_sprite.flip_h = next_flip_h
	face_change_timer = face_change_cooldown


func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite != null and animated_sprite.animation == &"die":
		queue_free()


func _connect_death_animation_finished() -> void:
	if animated_sprite == null:
		return

	var callback := Callable(self, "_on_animated_sprite_2d_animation_finished")
	if not animated_sprite.animation_finished.is_connected(callback):
		animated_sprite.animation_finished.connect(callback)


func _finish_spawn_animation(token: int) -> void:
	if token != spawn_animation_token:
		return
	if is_dead:
		return

	is_playing_spawn_animation = false
	current_anim = null
	play_animation(AnimationWrapper.new("idle"))


func _get_animation_duration(animation_name: StringName) -> float:
	var frames := animated_sprite.sprite_frames
	if frames == null or not frames.has_animation(animation_name):
		return 0.0

	var animation_speed := frames.get_animation_speed(animation_name)
	if animation_speed <= 0.0:
		return 0.0

	var total_frame_duration := 0.0
	for frame_index in range(frames.get_frame_count(animation_name)):
		total_frame_duration += frames.get_frame_duration(animation_name, frame_index)

	var playback_speed = max(animated_sprite.speed_scale, 0.01)
	return total_frame_duration / animation_speed / playback_speed
