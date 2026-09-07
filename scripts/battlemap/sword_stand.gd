## 剑座：玩家触碰后，临时获得环绕飞剑护体。
## 该物体本身只负责地图交互，真正的飞剑运动/伤害由 OrbitingSwordManifest 处理。
class_name SwordStand
extends MapObject

@export_group("剑座奖励")
@export var sword_manifest_scene: PackedScene = preload("res://scenes/ability/manifest/orbiting_sword_manifest.tscn")
@export var sword_count: int = 1
@export var sword_damage: float = 12.0
## 小于等于 0 表示持续到本场战斗结束。
@export var sword_lifetime: float = 0.0
@export var orbit_radius: float = 54.0
@export var orbit_speed: float = 2.1
@export var radius_wave_amplitude: float = 7.0
@export var slot_radius_variation: float = 4.0
@export var screen_tip: String = "触发了剑座，召唤了环绕飞剑。"

@onready var trigger_area: Area2D = get_node_or_null("TriggerArea") as Area2D

var triggered: bool = false


func _ready() -> void:
	super._ready()
	if trigger_area != null and not trigger_area.area_entered.is_connected(_on_trigger_area_entered):
		trigger_area.area_entered.connect(_on_trigger_area_entered)


func _exit_tree() -> void:
	if trigger_area != null and trigger_area.area_entered.is_connected(_on_trigger_area_entered):
		trigger_area.area_entered.disconnect(_on_trigger_area_entered)
	super._exit_tree()


func _on_trigger_area_entered(area: Area2D) -> void:
	if triggered:
		return

	var entity: Entity = _get_player_entity_from_area(area)
	if entity == null:
		return

	triggered = true
	# area_entered 正处于物理查询刷新中，延迟生成带 Area2D 的飞剑可以避免 flushing queries 报错。
	_grant_swords_and_consume.call_deferred(entity)


func _grant_swords_and_consume(player_entity: Entity) -> void:
	if player_entity == null or not is_instance_valid(player_entity):
		return

	var source_key: StringName = StringName("sword_stand_%s" % str(get_instance_id()))
	OrbitingSwordHelper.spawn_swords(
		player_entity,
		max(sword_count, 0),
		source_key,
		sword_manifest_scene,
		sword_damage,
		sword_lifetime,
		orbit_radius,
		orbit_speed,
		radius_wave_amplitude,
		slot_radius_variation
	)

	if not screen_tip.is_empty():
		FloatText.show_screen_tip(screen_tip)

	_unregister_navigation_blocker()
	_disable_collision_for_destroy()
	queue_free()


func _get_player_entity_from_area(area: Area2D) -> Entity:
	if area == null:
		return null

	var parent_node: Node = area.get_parent()
	if not (parent_node is Entity):
		return null

	var entity: Entity = parent_node as Entity
	if entity.is_dead:
		return null
	if not entity.is_player_side():
		return null

	return entity
