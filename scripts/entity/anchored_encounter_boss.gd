## 驻扎型 Boss AI：不追击、不被击退；攻击完整结束后累计次数，达到上限才迁根。
## 攻击场景负责效果，AI 只负责节奏、二阶段、驻扎点与生命周期。
class_name AnchoredEncounterBoss
extends Enemy

signal encounter_phase_changed(phase: int)
@export var attacks_before_relocation: int = 3
@export var phase_two_health_ratio: float = 0.4
@export var opening_delay: float = 2.0
@export var interrupted_recovery: float = 1.0
@export var center_search_radius_cells: int = 24
## 仅控制伤害/治疗数字的显示高度，不改变身体碰撞、技能范围或安全落点尺寸。
@export var visual_popup_height: float = 96.0
## 地图可放置此组 Marker2D 覆盖默认迁根点；不放时使用 Boss 内的 RelocationPoints。
@export var anchor_marker_group: StringName = &"mushroom_boss_anchor"

var anchor_position: Vector2
var anchor_candidates: Array[Vector2] = []
var action_busy: bool = false
var completed_attacks: int = 0
var attack_cursor: int = 0
var rest_remaining: float = 0.0
var encounter_phase: int = 1
var anchored_ready: bool = false
@onready var relocation: Ability = $AbilityController/Relocation
@onready var placement: AbilityRelocateToAnchor = $AbilityController/Relocation/Sequence/Move


func _ready() -> void:
	# 后续填入共享动画资源时，仅修改本实例，死亡/施法不能循环占住动作。
	animated_sprite.sprite_frames = animated_sprite.sprite_frames.duplicate(true) as SpriteFrames
	for animation: StringName in [&"die", &"attack", &"cast", &"relocate"]:
		animated_sprite.sprite_frames.set_animation_loop(animation, false)
	animated_sprite.play(&"idle")
	super._ready()
	for ability: Ability in ability_controller.abilities:
		ability.id = StringName(ability.name)
		var sequence: AbilityTimedSequence = ability.get_node("Sequence") as AbilityTimedSequence
		sequence.sequence_finished.connect(_on_sequence_finished)
	rest_remaining = opening_delay
	_refresh_enemy_health_bar(true)
	# 生成器/地图先完成初始化，再寻找中心；不在物理回调里改碰撞状态。
	call_deferred("_initialize_anchors")


func _initialize_anchors() -> void:
	if is_dead:
		return
	var map: BattleMap = get_tree().get_first_node_in_group("battle_map") as BattleMap
	if map != null:
		var center: Variant = map.get_map_center_world()
		if center is Vector2:
			var point: Variant = _find_safe_center(map, center)
			if point is Vector2:
				global_position = point
	anchor_position = global_position
	anchor_candidates.append(anchor_position)
	for marker: Node in get_tree().get_nodes_in_group(anchor_marker_group):
		if marker is Marker2D:
			anchor_candidates.append(marker.global_position)
	if anchor_candidates.size() == 1:
		for marker: Node in $RelocationPoints.get_children():
			if marker is Marker2D:
				anchor_candidates.append(marker.global_position)
	anchored_ready = true


func _find_safe_center(map: BattleMap, center: Vector2) -> Variant:
	var reserved: Array[Vector2] = []
	for player: Node in get_tree().get_nodes_in_group("player"):
		if player is Node2D:
			reserved.append(player.global_position)
	# 排除玩家出生点以及压住实体圆形身体的动态障碍，不能只检查落点中心。
	for attempt: int in range(12):
		var point: Variant = map.get_nearest_playable_position(center, center_search_radius_cells, placement.clearance_cells, reserved, placement.minimum_player_distance)
		if not point is Vector2:
			break
		if placement.is_footprint_clear(self, point):
			return point
		reserved.append(point)
	push_warning("菌冠古树在地图中心附近未找到安全空地，请扩大 Boss 战场中央区域。")
	return null


func _process(delta: float) -> void:
	if is_dead or not anchored_ready:
		return
	global_position = anchor_position
	clear_terrain_motion_velocity()
	movement_lock_timer = maxf(movement_lock_timer - delta, 0.0)
	_update_phase()
	if not can_act():
		if action_busy:
			cancel_active_actions()
		return
	rest_remaining = maxf(rest_remaining - delta, 0.0)
	if action_busy or rest_remaining > 0.0:
		return
	current_target = _find_encounter_target()
	if not is_instance_valid(current_target):
		return
	var ability: Ability = relocation if completed_attacks >= attacks_before_relocation else _choose_attack()
	if ability == null:
		return
	_face_target(current_target.global_position - global_position)
	action_busy = true
	if not ability_controller.trigger_ability(ability):
		action_busy = false


func _find_encounter_target() -> Entity:
	# 主技能锁定玩家本人；地图动物/召唤物仍可以被范围攻击命中，但不牵走落点。
	var player: Entity = get_tree().get_first_node_in_group("player") as Entity
	if is_instance_valid(player) and player.can_be_targeted():
		return player
	return _find_nearest_player_side_target()


func _choose_attack() -> Ability:
	var distance: float = global_position.distance_to(current_target.global_position)
	var available: Array[Ability] = ability_controller.get_ai_castable_abilities(distance, stop_distance, current_target)
	var attacks: Array[Ability] = []
	for ability: Ability in ability_controller.abilities:
		if ability != relocation:
			attacks.append(ability)
	if attacks.is_empty():
		return null
	for offset: int in range(attacks.size()):
		var index: int = (attack_cursor + offset) % attacks.size()
		var ability: Ability = attacks[index]
		if available.has(ability):
			attack_cursor = (index + 1) % attacks.size()
			return ability
	return null


func _on_sequence_finished(context: AbilityContext, completed: bool) -> void:
	if is_dead or context.caster != self:
		return
	action_busy = false
	if not completed:
		rest_remaining = interrupted_recovery
		return
	if context.ability == relocation:
		completed_attacks = 0
	else:
		completed_attacks += 1
	current_anim = null
	play_animation(AnimationWrapper.new("idle"))


func _update_phase() -> void:
	if encounter_phase == 1 and current_health <= max_health * phase_two_health_ratio:
		encounter_phase = 2
		encounter_phase_changed.emit(encounter_phase)


func get_encounter_phase() -> int:
	return encounter_phase


func get_relocation_candidates() -> Array[Vector2]:
	return anchor_candidates.duplicate()


func set_anchor_position(point: Vector2) -> void:
	anchor_position = point
	global_position = point


func move_direct_with_physics(_motion: Vector2, _update_inertia: bool = false) -> Vector2:
	# 固定大型 Boss 不接受普通击退；迁根使用经过落点检查的专用组件。
	return Vector2.ZERO


func move_with_physics(_motion: Vector2) -> Vector2:
	return Vector2.ZERO


func get_height() -> float:
	return visual_popup_height


func get_current_texture() -> Texture2D:
	var frames: SpriteFrames = animated_sprite.sprite_frames
	var animation: StringName = animated_sprite.animation
	if not frames.has_animation(animation) or frames.get_frame_count(animation) == 0:
		return null
	return frames.get_frame_texture(animation, animated_sprite.frame)


func _die() -> void:
	super._die()
	if is_dead and not _has_death_art():
		queue_free()


func _has_death_art() -> bool:
	var frames: SpriteFrames = animated_sprite.sprite_frames
	return frames.has_animation(&"die") and frames.get_frame_count(&"die") > 0 and frames.get_frame_texture(&"die", 0) != null
