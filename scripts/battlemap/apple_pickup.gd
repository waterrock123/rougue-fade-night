class_name ApplePickup
extends MapPickup

## 苹果拾取物：玩家碰到后恢复少量生命。
## 这是 MapPickup 的示例子类，后续金币、临时 buff、钥匙等拾取物都可以按这个模式扩展。

@export var heal_amount: float = 1.0
@export var show_heal_text: bool = true


func _ready() -> void:
	if pickup_display_name.is_empty():
		pickup_display_name = "苹果"
	super._ready()


func _apply_pickup(collector: Entity) -> void:
	if collector == null:
		return

	var actual_heal: float = collector.apply_heal(heal_amount, show_heal_text)
	if actual_heal > 0.0:
		show_collected_tip("恢复了 %s 点生命" % str(int(actual_heal)))
	else:
		show_collected_tip("生命已满")
