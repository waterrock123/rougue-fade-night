## 配送交互点，只允许任务拥有者触碰；复用拾取物浮动和重叠检测。
class_name DeliveryMarker
extends MapPickup

var task: BattleDeliveryTask
var is_destination: bool = false
var cargo_icon: Texture2D


func _ready() -> void:
	super._ready()
	var sprite: Sprite2D = get_node_or_null("VisualRoot/Sprite2D") as Sprite2D
	if not is_destination and sprite != null and cargo_icon != null:
		sprite.texture = cargo_icon
	if not is_destination and is_instance_valid(task) and task.chosen != null:
		var effect_label: Label = get_node_or_null("EffectLabel") as Label
		if effect_label != null:
			effect_label.text = task.chosen.option_name
	queue_redraw()


func _draw() -> void:
	if not is_destination:
		return
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not (collision.shape is CircleShape2D):
		return
	# 范围直接读取真实触碰半径，避免美术圆圈与交互范围不一致。
	var radius: float = (collision.shape as CircleShape2D).radius
	draw_circle(collision.position, radius, Color(1.0, 0.85, 0.3, 0.16))
	draw_arc(collision.position, radius, 0.0, TAU, 48, Color(1.0, 0.92, 0.65, 0.9), 1.0, true)


func _can_collect(collector: Entity) -> bool:
	return is_instance_valid(task) and task.can_interact(collector)


func _apply_pickup(_collector: Entity) -> void:
	# 接触可能来自物理查询回调，任务生成和撤销统一推迟执行。
	if is_destination:
		task.deliver.call_deferred()
	else:
		task.collect_cargo.call_deferred()
