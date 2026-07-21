## 遗物效果：符合条件的伤害命中后，在目标位置追加一次范围伤害。
## 适合高爆子弹、溅射武器、命中后爆开的小范围法术等效果。
class_name OutgoingDamageSplashEffect
extends RelicEffect


@export var radius: float = 72.0
@export var damage_rate: float = 0.1
## 小于 0 时升级态仍使用 damage_rate；大于等于 0 时升级态使用该倍率。
@export var levelup_damage_rate: float = -1.0
@export var required_tags: Array[String] = []
@export var required_damage_types: Array[int] = []
@export var splash_damage_types: Array[int] = [DamageData.DamageType.FIRE]
@export var splash_tags: Array[String] = ["relic", "splash"]
@export var can_crit: bool = false
## 防止溅射伤害再次触发自己，造成递归爆炸。
@export var recursion_guard_tag: String = "splash_guard"

var active_connections: Dictionary = {}


func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null:
		return

	var key: String = str(effect_key)
	if active_connections.has(key):
		return

	var callback: Callable = Callable(self, "_on_damage_dealt").bind(relic_context, key)
	if not owner.damage_dealt.is_connected(callback):
		owner.damage_dealt.connect(callback)
		active_connections[key] = {
			"owner": owner,
			"callback": callback,
		}


func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	var key: String = str(effect_key)
	if not active_connections.has(key):
		return

	var entry: Dictionary = active_connections[key] as Dictionary
	var owner: Entity = entry.get("owner") as Entity
	var callback: Callable = entry.get("callback") as Callable
	if owner != null and is_instance_valid(owner) and owner.damage_dealt.is_connected(callback):
		owner.damage_dealt.disconnect(callback)

	active_connections.erase(key)


func _on_damage_dealt(damage_data: DamageData, relic_context: RelicContext, _effect_key: String) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null or owner.is_dead:
		return
	if damage_data == null or damage_data.target == null or not is_instance_valid(damage_data.target):
		return
	if damage_data.final_damage <= 0.0:
		return
	if damage_data.tags.has(recursion_guard_tag):
		return
	if not _damage_matches(damage_data):
		return

	var center: Vector2 = damage_data.target.global_position
	var splash_damage: float = max(damage_data.final_damage, 0.0) * _get_damage_rate(relic_context)
	if splash_damage <= 0.0:
		return

	for target: Entity in _collect_targets_in_radius(owner, center):
		var splash_data: DamageData = DamageData.create(
			splash_damage,
			splash_damage_types,
			_build_splash_tags(),
			owner,
			target,
			can_crit,
			null,
			damage_data.source_ability_id,
			damage_data.source_ability_slot_index
		)
		target.apply_damage(splash_data)


func _damage_matches(damage_data: DamageData) -> bool:
	for required_tag: String in required_tags:
		if not damage_data.tags.has(required_tag):
			return false

	for required_damage_type: int in required_damage_types:
		if not damage_data.damage_types.has(required_damage_type):
			return false

	return true


func _collect_targets_in_radius(owner: Entity, center: Vector2) -> Array[Entity]:
	var result: Array[Entity] = []
	var checked_ids: Dictionary = {}
	var groups: Array[StringName] = _get_opponent_groups(owner)
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return result

	for group_name: StringName in groups:
		for node: Node in tree.get_nodes_in_group(String(group_name)):
			var target: Entity = node as Entity
			if target == null or target == owner or target.is_dead:
				continue
			if checked_ids.has(target.get_instance_id()):
				continue
			checked_ids[target.get_instance_id()] = true
			if target.global_position.distance_to(center) <= radius:
				result.append(target)

	return result


func _get_opponent_groups(owner: Entity) -> Array[StringName]:
	if owner.is_player_side():
		return [&"enemy"]
	if owner.is_enemy_side():
		return [&"player", &"player_ally", &"summon_pet"]
	return [&"enemy"]


func _build_splash_tags() -> Array[String]:
	var result: Array[String] = splash_tags.duplicate()
	if not result.has(recursion_guard_tag):
		result.append(recursion_guard_tag)
	return result


func _get_damage_rate(relic_context: RelicContext) -> float:
	if relic_context != null and relic_context.own_relic != null:
		if relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP and levelup_damage_rate >= 0.0:
			return max(levelup_damage_rate, 0.0)
	return max(damage_rate, 0.0)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
