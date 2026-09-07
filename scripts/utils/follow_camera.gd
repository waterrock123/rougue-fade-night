extends Camera2D

@export var follow_target: Node2D
@export_group("屏幕震动")
## 震动采样频率。数值越高，震动越急促。
@export_range(1.0, 60.0, 1.0) var shake_frequency: float = 30.0

var base_offset: Vector2 = Vector2.ZERO
var shake_strength: float = 0.0
var shake_duration: float = 0.0
var shake_remaining: float = 0.0
var shake_phase: float = 0.0


func _ready() -> void:
	base_offset = offset

func _process(delta: float) -> void:
	if follow_target != null and is_instance_valid(follow_target):
		position = follow_target.position
	_update_shake(delta)


## 战斗反馈统一调用此入口；连续请求会保留更强的强度和更长的剩余时间。
func request_shake(strength: float, duration: float) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	shake_strength = maxf(shake_strength, strength)
	shake_duration = maxf(shake_duration, duration)
	shake_remaining = maxf(shake_remaining, duration)


func _update_shake(delta: float) -> void:
	if shake_remaining <= 0.0:
		offset = base_offset
		shake_strength = 0.0
		shake_duration = 0.0
		return

	shake_remaining = maxf(shake_remaining - delta, 0.0)
	shake_phase += delta * shake_frequency
	var fade: float = shake_remaining / maxf(shake_duration, 0.001)
	var direction := Vector2(
		sin(shake_phase * 2.17),
		cos(shake_phase * 1.73)
	).normalized()
	offset = base_offset + direction * shake_strength * fade
