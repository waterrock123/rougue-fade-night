@tool
class_name BasicTutorialProgress
extends RefCounted

## 纯教学状态机，不读取输入、不访问存档；只接受真实移动、预览、施法与命中的结果。
signal stage_changed(stage: int)
signal completed()

enum Stage { MOVE, BASIC_ATTACK, AIM_HOLD, AIM_RELEASE, COMPLETE }
var stage: Stage = Stage.MOVE
var minimum_movement: float = 40.0
var required_basic_hits: int = 3
var required_hold_seconds: float = 0.35
var movement: float = 0.0
var basic_hits: int = 0
var hold_seconds: float = 0.0
var holding: bool = false
var release_armed: bool = false
var authorized_casts: Dictionary = {}


func record_movement(actual_distance: float, at_goal: bool) -> void:
	if stage != Stage.MOVE:
		return
	movement += clampf(actual_distance, 0.0, 32.0)
	if at_goal and movement >= minimum_movement:
		_advance(Stage.BASIC_ATTACK)


func record_basic_hit() -> void:
	if stage != Stage.BASIC_ATTACK:
		return
	basic_hits += 1
	if basic_hits >= required_basic_hits:
		_advance(Stage.AIM_HOLD)


func begin_preview() -> void:
	if stage != Stage.AIM_HOLD and stage != Stage.AIM_RELEASE:
		return
	holding = true
	hold_seconds = 0.0
	release_armed = false
	authorized_casts.clear()
	_advance(Stage.AIM_HOLD)


func tick_preview(delta: float) -> void:
	if not holding or stage != Stage.AIM_HOLD:
		return
	hold_seconds += maxf(delta, 0.0)
	if hold_seconds >= required_hold_seconds:
		_advance(Stage.AIM_RELEASE)


func release_preview() -> void:
	release_armed = holding and stage == Stage.AIM_RELEASE and hold_seconds >= required_hold_seconds
	holding = false
	if not release_armed and stage == Stage.AIM_RELEASE:
		_advance(Stage.AIM_HOLD)


func cancel_preview() -> void:
	holding = false
	hold_seconds = 0.0
	release_armed = false
	authorized_casts.clear()
	if stage == Stage.AIM_RELEASE:
		_advance(Stage.AIM_HOLD)


func authorize_cast(cast_id: int) -> void:
	if release_armed and cast_id != 0 and stage == Stage.AIM_RELEASE:
		authorized_casts[cast_id] = true
		release_armed = false


func record_aim_hit(cast_id: int) -> void:
	if stage == Stage.AIM_RELEASE and authorized_casts.has(cast_id):
		authorized_casts.clear()
		_advance(Stage.COMPLETE)
		completed.emit()


func _advance(next: Stage) -> void:
	stage = next
	stage_changed.emit(stage)
