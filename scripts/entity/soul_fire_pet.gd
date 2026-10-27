## 魂火仅负责漂浮、出现和死亡消散；追敌沿用 SummonPet，伤害由技能组件负责。
class_name SoulFirePet
extends SummonPet

@export var float_amplitude: float = 2.0
@export var float_speed: float = 2.5
var phase: float = 0.0
var visual_origin: Vector2
var fading: bool = false


func _ready() -> void:
	super._ready()
	phase = randf() * TAU
	visual_origin = animated_sprite.position
	animated_sprite.modulate.a = 0.0
	create_tween().tween_property(animated_sprite, "modulate:a", 1.0, 0.3)
	var pulse: Ability = get_node_or_null("AbilityController/SoulFirePulse") as Ability
	if pulse != null:
		pulse.id = &"soul_fire_pulse"


func _process(delta: float) -> void:
	super._process(delta)
	if is_dead or animated_sprite == null:
		return
	phase += delta * float_speed
	animated_sprite.position = visual_origin + Vector2(0.0, sin(phase) * float_amplitude)


func _die() -> void:
	super._die()
	if not is_dead or fading:
		return
	fading = true
	for shape: Node in find_children("*", "CollisionShape2D", true, false):
		shape.set_deferred("disabled", true)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(animated_sprite, "modulate:a", 0.0, 0.4)
	tween.tween_property(animated_sprite, "scale", Vector2(0.35, 0.35), 0.4)
	tween.chain().tween_callback(queue_free)
