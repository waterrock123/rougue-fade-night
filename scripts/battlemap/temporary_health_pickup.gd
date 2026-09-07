class_name TemporaryHealthPickup
extends MapPickup

## 临时红心：拾取后恢复当前实体生命值。
## 数值做成 export，后续炼金台、事件或其他地图物件都可以复用这个拾取物。

@export var heal_amount: float = 5.0
@export var show_heal_text: bool = true


func _ready() -> void:
	if pickup_display_name.is_empty():
		pickup_display_name = "临时红心"
	super._ready()


func _apply_pickup(collector: Entity) -> void:
	if collector == null:
		return

	var actual_heal: float = collector.apply_heal(heal_amount, show_heal_text)
	if actual_heal > 0.0:
		show_collected_tip("恢复了 %s 点生命" % str(int(actual_heal)))
	else:
		show_collected_tip("生命已满")
