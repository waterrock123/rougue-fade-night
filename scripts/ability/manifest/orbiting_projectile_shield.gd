## 独立环绕盾：只反弹敌方真实投射物，不拦截近战、抛射物和地面领域。
## 碰撞回调配合飞行线段检测，高速子弹也不会轻易穿过盾面。
class_name OrbitingProjectileShield
extends Node2D

@export var orbit_radius: float = 36.0
@export var orbit_speed: float = 1.8
@export var intercept_radius: float = 10.0
var angle: float = 0.0
var actor: Entity
var battle: PlayScene


func _ready() -> void:
	actor = get_parent() as Entity
	var ancestor: Node = get_parent()
	while ancestor != null and not ancestor is PlayScene:
		ancestor = ancestor.get_parent()
	battle = ancestor as PlayScene
	add_to_group("projectile_reflectors")
	var area: Area2D = get_node("Area2D") as Area2D
	area.area_entered.connect(_on_area_entered)
	position = Vector2.RIGHT * orbit_radius
	visible = false


func _physics_process(delta: float) -> void:
	visible = _is_active()
	if not visible:
		return
	angle = fmod(angle + orbit_speed * delta, TAU)
	position = Vector2.RIGHT.rotated(angle) * orbit_radius
	rotation = angle


func _is_active() -> bool:
	return EventBus.is_battle_active and bool(get_meta(&"relic_attached_enabled", true)) \
		and is_instance_valid(actor) and not actor.is_dead and not actor.is_queued_for_deletion() \
		and is_instance_valid(battle) and not battle.battle_completion_started


func try_intercept(projectile: AbilityManifest, start: Vector2, end: Vector2) -> bool:
	if not _is_active() or not ProjectileReflection.can_reflect(projectile, actor):
		return false
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(global_position, start, end)
	if closest.distance_squared_to(global_position) > intercept_radius * intercept_radius:
		return false
	if not ProjectileReflection.reflect(projectile, actor):
		return false
	projectile.global_position = closest
	return true


func _on_area_entered(area: Area2D) -> void:
	var projectile: AbilityManifest = area.get_parent() as AbilityManifest
	# 物理重叠包含炮弹自身的尺寸；不再用炮弹中心的距离把边缘接触排除。
	if projectile != null and _is_active():
		ProjectileReflection.reflect(projectile, actor)
