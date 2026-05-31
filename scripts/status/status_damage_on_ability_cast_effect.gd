## 状态效果：目标释放技能时受到固定伤害。
## 用于“麻痹”：处于麻痹的目标每次释放技能都会受到闪电伤害。
class_name StatusDamageOnAbilityCastEffect
extends StatusEffect

@export var damage: float = 30.0
@export var damage_types: Array[int] = [DamageData.DamageType.LIGHTNING]
@export var tags: Array[String] = ["status", "paralysis", "lightning"]
@export var can_crit: bool = false

var active_connections: Dictionary = {}


func on_apply(instance: StatusInstance) -> void:
	var target := _get_target_entity(instance)
	if target == null:
		return

	var ability_controller := target.get_node_or_null("AbilityController") as AbilityController
	if ability_controller == null:
		return

	var key := _get_effect_key(instance)
	if active_connections.has(key):
		return

	var callback := Callable(self, "_on_target_ability_triggered").bind(instance, key)
	ability_controller.ability_triggered.connect(callback)
	active_connections[key] = {
		"controller": ability_controller,
		"callback": callback,
	}


func on_remove(instance: StatusInstance) -> void:
	var key := _get_effect_key(instance)
	if not active_connections.has(key):
		return

	var entry := active_connections[key] as Dictionary
	var controller := entry.get("controller") as AbilityController
	var callback := entry.get("callback") as Callable
	if controller != null and is_instance_valid(controller) and controller.ability_triggered.is_connected(callback):
		controller.ability_triggered.disconnect(callback)

	active_connections.erase(key)


func _on_target_ability_triggered(_ability: Ability, caster: Entity, instance: StatusInstance, _key: String) -> void:
	if instance == null or caster == null or not is_instance_valid(caster) or caster.is_dead:
		return

	var source_entity := instance.source as Entity
	if source_entity != null and not is_instance_valid(source_entity):
		source_entity = null

	var damage_data := DamageData.create(
		damage,
		damage_types,
		tags,
		source_entity,
		caster,
		can_crit
	)
	caster.apply_damage(damage_data)


func _get_target_entity(instance: StatusInstance) -> Entity:
	if instance == null or not (instance.target is Entity):
		return null
	return instance.target as Entity


func _get_effect_key(instance: StatusInstance) -> String:
	return "%s_ability_cast_damage" % instance.get_effect_key()
