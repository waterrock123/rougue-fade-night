class_name ApplePickup
extends MapPickup

## 苹果拾取物：玩家碰到后恢复少量生命。
## 这是 MapPickup 的示例子类，后续金币、临时 buff、钥匙等拾取物都可以按这个模式扩展。

@export var heal_amount: float = 1.0
@export var show_heal_text: bool = true


func _apply_pickup(collector: Entity) -> void:
	if collector == null:
		return

	collector.apply_heal(heal_amount, show_heal_text)
