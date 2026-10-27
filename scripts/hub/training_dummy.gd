extends Enemy

## 假人保留敌人的受击与韧性组件，但不索敌、不移动、不施法。
func _process(delta: float) -> void:
	movement_lock_timer = maxf(0.0, movement_lock_timer - delta)
	velocity = Vector2.ZERO


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	cancel_active_actions()
	died.emit(self)
	queue_free()
