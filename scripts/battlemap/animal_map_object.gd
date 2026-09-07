class_name AnimalMapObject
extends MapObject

signal animal_reward_granted(animal: AnimalMapObject, relic: Relic, count: int)

enum WanderMode {
	DISABLED,
	LEFT_RIGHT,
	RANDOM_WANDER,
}

## 动物的唯一地图物体 ID，同时也是变体池和装备效果匹配的 ID。
@export var animal_id: StringName = &"animal"

@export_group("动物徘徊")
## 动物是否移动，以及采用哪一种简单的移动方式。可以在具体动物场景中关闭。
@export_enum("关闭", "左右移动", "随机徘徊") var wander_mode: int = WanderMode.RANDOM_WANDER
## 徘徊中心点以动物生成位置为准，动物不会主动离开这个半径。
@export_range(0.0, 128.0, 1.0) var wander_radius: float = 28.0
## 动物徘徊时的基础移动速度。
@export_range(0.0, 128.0, 1.0) var wander_speed: float = 16.0
## 到达目标点后停留多久，再前往下一个目标点。
@export_range(0.0, 5.0, 0.05) var wander_pause_duration: float = 0.6
## 随机徘徊时单个目标最长追踪时间，卡在障碍物上会重新选点。
@export_range(0.1, 10.0, 0.1) var wander_repick_interval: float = 1.5
## 动物没有移动时是否暂停行走逐帧动画。
@export var animate_only_when_moving: bool = true
## 行走动画名称。你的四个动物目前都使用 default。
@export var wander_animation: StringName = &"default"
## 精灵默认朝左时打开；默认朝右则保持关闭。
@export var sprite_faces_left_by_default: bool = false

@export_group("动物奖励")
## 战斗结束时动物仍存活，就按这个资源发放奖励。
@export var reward_relic: Relic
@export var reward_count: int = 1
@export var show_reward_tip: bool = true

var reward_granted: bool = false
var wander_origin: Vector2 = Vector2.ZERO
var wander_target: Vector2 = Vector2.ZERO
var wander_direction: Vector2 = Vector2.RIGHT
var wander_pause_timer: float = 0.0
var wander_repick_timer: float = 0.0
var wander_is_moving: bool = false


func _ready() -> void:
	# 动物属于玩家可保护的一方，因此敌人可以将它视为目标，玩家却不能把它当作敌人攻击。
	targetable_by_player_side = false
	targetable_by_enemy_side = true
	add_to_group("animal")
	super._ready()
	_initialize_wander()

	if EventBus != null and not EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.connect(_on_battle_rewards_resolving)


func _exit_tree() -> void:
	if EventBus != null and EventBus.battle_rewards_resolving.is_connected(_on_battle_rewards_resolving):
		EventBus.battle_rewards_resolving.disconnect(_on_battle_rewards_resolving)
	super._exit_tree()


func _process(delta: float) -> void:
	# 动物死亡后仍可能需要播放死亡动画，因此这里只停移动，不暂停死亡动画。
	if is_dead:
		clear_terrain_motion_velocity()
		return

	if wander_mode == WanderMode.DISABLED or not can_act() or is_movement_locked():
		_stop_wandering()
		return

	var actual_movement: Vector2 = _process_wander(delta)
	var is_moving: bool = actual_movement.length_squared() > 0.0001
	_update_wander_animation(is_moving)


## 初始化徘徊中心和第一个目标点。中心点固定在动物初次生成的位置，避免长期移动后漂移。
func _initialize_wander() -> void:
	wander_origin = global_position
	wander_target = global_position
	wander_direction = Vector2.LEFT if randf() < 0.5 else Vector2.RIGHT
	wander_pause_timer = 0.0
	wander_repick_timer = 0.0
	wander_is_moving = false


## 根据当前模式推进动物移动，并返回这一帧实际移动的位移。
func _process_wander(delta: float) -> Vector2:
	if delta <= 0.0 or wander_radius <= 0.0 or wander_speed <= 0.0:
		_stop_wandering()
		return Vector2.ZERO

	if wander_pause_timer > 0.0:
		wander_pause_timer = maxf(wander_pause_timer - delta, 0.0)
		_stop_wandering()
		return Vector2.ZERO

	var distance_to_target: float = global_position.distance_to(wander_target)
	if distance_to_target <= 2.0 or wander_repick_timer <= 0.0:
		_pick_next_wander_target()
		_stop_wandering()
		return Vector2.ZERO

	wander_repick_timer = maxf(wander_repick_timer - delta, 0.0)
	var move_direction: Vector2 = global_position.direction_to(wander_target)
	var move_distance: float = minf(wander_speed * delta, distance_to_target)
	var actual_movement: Vector2 = move_with_physics(move_direction * move_distance)
	if actual_movement.length_squared() <= 0.0001:
		# 被墙或其他障碍物卡住时，不原地持续撞击，下一帧重新规划目标。
		wander_repick_timer = 0.0

	_face_wander_direction(move_direction)
	wander_is_moving = actual_movement.length_squared() > 0.0001
	return actual_movement


## 选择下一个目标点。左右模式只改变 X，随机模式在小圆形范围内选点。
func _pick_next_wander_target() -> void:
	if wander_mode == WanderMode.LEFT_RIGHT:
		wander_direction.x = -wander_direction.x
		wander_direction.y = 0.0
		wander_target = wander_origin + Vector2(wander_direction.x * wander_radius, 0.0)
	else:
		var angle: float = randf() * TAU
		var distance: float = sqrt(randf()) * wander_radius
		wander_target = wander_origin + Vector2.RIGHT.rotated(angle) * distance

	wander_repick_timer = maxf(wander_repick_interval, 0.1)
	wander_pause_timer = maxf(wander_pause_duration, 0.0)


## 让动物的行走精灵朝向实际移动方向。默认假设精灵原图朝右，可在检查器中切换。
func _face_wander_direction(move_direction: Vector2) -> void:
	if animated_sprite == null or absf(move_direction.x) <= 0.05:
		return

	animated_sprite.flip_h = move_direction.x > 0.0 if sprite_faces_left_by_default else move_direction.x < 0.0


## 行走动画只在真正移动时播放，暂停时保留当前帧，恢复移动后继续播放。
func _update_wander_animation(is_moving: bool) -> void:
	if animated_sprite == null or not animate_only_when_moving:
		return

	if is_moving:
		if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(wander_animation):
			animated_sprite.play(wander_animation)
		return

	if animated_sprite.is_playing():
		animated_sprite.pause()


## 停止徘徊时清空 CharacterBody2D 的速度，避免地形惯性让动物继续滑动。
func _stop_wandering() -> void:
	wander_is_moving = false
	clear_terrain_motion_velocity()


func get_map_object_id() -> StringName:
	return animal_id


func _on_battle_rewards_resolving() -> void:
	if reward_granted or is_dead or reward_relic == null:
		return

	var stats: RunStats = _get_run_stats()
	if stats == null or stats.player_build == null:
		return

	var safe_count: int = max(reward_count, 0)
	var gained_count: int = 0
	var reward_owner: Node = get_tree().get_first_node_in_group("player") as Node
	if reward_owner == null:
		reward_owner = self
	for reward_index: int in range(safe_count):
		var relic: Relic = reward_relic.duplicate(true) as Relic
		if relic == null or not stats.player_build.add_relic(relic):
			continue

		gained_count += 1
		var relic_key: String = "animal_reward_%s_%s_%s" % [animal_id, get_instance_id(), reward_index]
		# 奖励属于玩家构筑，未来若奖励带有 on_gain 效果，也应由玩家作为效果拥有者。
		relic.gain_relic(reward_owner, null, relic_key)

	reward_granted = gained_count > 0
	if gained_count > 0:
		animal_reward_granted.emit(self, reward_relic, gained_count)
		if show_reward_tip and FloatText != null and FloatText.has_method("show_screen_tip"):
			FloatText.show_screen_tip("保护了%s，获得%s × %s" % [animal_id, reward_relic.relic_name, gained_count])


func _get_run_stats() -> RunStats:
	var current_node: Node = self
	while current_node != null:
		for property_info: Dictionary in current_node.get_property_list():
			if String(property_info.get("name", "")) != "run_stats":
				continue

			var value: Variant = current_node.get("run_stats")
			if value is RunStats:
				return value as RunStats
		current_node = current_node.get_parent()

	return null
