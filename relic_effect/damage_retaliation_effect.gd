## 受到伤害时对伤害来源造成反击伤害的通用遗物效果。
## 适合打火机、荆棘甲、火焰护盾等“被打就反伤”的装备或状态复用。
class_name DamageRetaliationEffect
extends RelicEffect


## 反击造成的基础伤害。
@export var damage: float = 20.0
## 升级态额外增加的反击伤害。例如普通 20、升级 30，则填 10。
@export var levelup_bonus_damage: float = 0.0
## 反击伤害类型，打火机一般使用 FIRE。
@export var damage_types: Array[int] = [DamageData.DamageType.FIRE]
## 反击伤害标签。默认带 retaliation，防止反伤再次触发反伤形成循环。
@export var tags: Array[String] = ["retaliation"]
## 反击伤害是否可以暴击。
@export var can_crit: bool = false
## 是否只在实际受到大于 0 的伤害后反击。
@export var require_positive_damage: bool = true
## 忽略这些标签的入站伤害，避免反伤、持续伤害等特殊伤害再次触发反伤。
@export var ignored_incoming_tags: Array[String] = ["retaliation"]

var _active_connections: Dictionary = {}


## 装备生效时监听拥有者的受伤信号。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner := _get_owner_entity(relic_context)
	if owner == null:
		return
	if _active_connections.has(effect_key):
		return

	var callable := Callable(self, "_on_owner_damage_taken").bind(relic_context, effect_key)
	owner.damage_taken.connect(callable)
	_active_connections[effect_key] = {
		"owner": owner,
		"callable": callable,
	}


## 卸下装备时断开受伤监听，避免效果残留。
func on_deactivate(_relic_context: RelicContext, effect_key) -> void:
	if not _active_connections.has(effect_key):
		return

	var entry := _active_connections[effect_key] as Dictionary
	var owner := entry.get("owner") as Entity
	var callable := entry.get("callable") as Callable
	if owner != null and owner.damage_taken.is_connected(callable):
		owner.damage_taken.disconnect(callable)

	_active_connections.erase(effect_key)


func _on_owner_damage_taken(damage_data: DamageData, relic_context: RelicContext, _effect_key) -> void:
	if not _can_retaliate(damage_data, relic_context):
		return

	var owner := relic_context.owner as Entity
	var attacker := damage_data.source
	var retaliation_damage := _get_retaliation_damage(relic_context)
	var retaliation_data := DamageData.create(
		retaliation_damage,
		damage_types,
		tags,
		owner,
		attacker,
		can_crit
	)
	attacker.apply_damage(retaliation_data)


func _can_retaliate(damage_data: DamageData, relic_context: RelicContext) -> bool:
	if damage_data == null or relic_context == null:
		return false
	if require_positive_damage and damage_data.final_damage <= 0.0:
		return false
	for tag in ignored_incoming_tags:
		if damage_data.tags.has(tag):
			return false
	if not (relic_context.owner is Entity):
		return false
	if damage_data.source == null or not is_instance_valid(damage_data.source):
		return false
	if damage_data.source == relic_context.owner:
		return false
	if damage_data.source.is_dead:
		return false
	return true


func _get_retaliation_damage(relic_context: RelicContext) -> float:
	var result := damage
	if relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		result += levelup_bonus_damage
	return max(result, 0.0)


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
