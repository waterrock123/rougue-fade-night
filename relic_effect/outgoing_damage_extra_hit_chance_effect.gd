## 遗物效果：符合条件的伤害命中后，有概率追加一次固定基础伤害。
## 适合“瞄准镜”“连击弹药”等额外打击类效果。
class_name OutgoingDamageExtraHitChanceEffect
extends RelicEffect

@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 0.25
@export var required_tags: Array[String] = []
@export var required_damage_types: Array[int] = []
@export var extra_damage: float = 5.0
@export var extra_damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
@export var extra_tags: Array[String] = ["relic", "extra_hit"]
@export var can_crit: bool = false
@export var recursion_guard_tag: String = "extra_hit_guard"
@export var ignore_when_relic_levelup: bool = false

var active_connections: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if ignore_when_relic_levelup and relic_context != null and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return

	var owner := _get_owner_entity(relic_context)
	if owner == null:
		return

	var key := str(effect_key)
	if active_connections.has(key):
		return

	var callback := Callable(self, "_on_damage_dealt").bind(owner, key)
	owner.damage_dealt.connect(callback)
	active_connections[key] = {
		"owner": owner,
		"callback": callback,
	}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key := str(effect_key)
	if not active_connections.has(key):
		return

	var entry := active_connections[key] as Dictionary
	var owner := entry.get("owner") as Entity
	var callback := entry.get("callback") as Callable
	if owner != null and is_instance_valid(owner) and owner.damage_dealt.is_connected(callback):
		owner.damage_dealt.disconnect(callback)

	active_connections.erase(key)


func _on_damage_dealt(damage_data: DamageData, owner: Entity, _effect_key: String) -> void:
	if owner == null or not is_instance_valid(owner) or owner.is_dead:
		return
	if damage_data == null or damage_data.target == null or not is_instance_valid(damage_data.target):
		return
	if damage_data.tags.has(recursion_guard_tag):
		return
	if not _damage_matches(damage_data):
		return
	if randf() > trigger_chance:
		return

	var tags := extra_tags.duplicate()
	if not tags.has(recursion_guard_tag):
		tags.append(recursion_guard_tag)

	var extra_data := DamageData.create(
		extra_damage,
		extra_damage_types,
		tags,
		owner,
		damage_data.target,
		can_crit
	)
	damage_data.target.apply_damage(extra_data)


func _damage_matches(damage_data: DamageData) -> bool:
	for tag in required_tags:
		if not damage_data.tags.has(tag):
			return false

	for damage_type in required_damage_types:
		if not damage_data.damage_types.has(damage_type):
			return false

	return true


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
