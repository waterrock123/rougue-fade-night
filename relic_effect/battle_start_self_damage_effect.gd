## 遗物效果：进入战斗时对拥有者造成一次伤害。
## 适合“粗糙匕首”“开局献祭”等进场带代价的装备效果。
class_name BattleStartSelfDamageEffect
extends RelicEffect

## 进入战斗时流失的基础生命值。
@export var damage: float = 1.0
## 是否允许这次自伤被护甲/减伤率减免。粗糙匕首默认是“流失生命”，因此默认不走减伤。
@export var ignore_damage_reduction: bool = true
## 伤害类型，用于飘字颜色和后续条件判断。
@export var damage_types: Array[int] = [DamageData.DamageType.PHYSICAL]
## 伤害标签，方便后续被动或状态判断“这是进场自伤”。
@export var tags: Array[String] = ["relic", "battle_start", "self_damage"]
## 勾选后，升级态遗物会跳过这条基础进场自伤。
## 适合“升级后自伤数值变低”的装备：基础效果跳过，great_effects 再提供新的自伤数值。
@export var ignore_when_relic_levelup: bool = false


func on_activate(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return
	if ignore_when_relic_levelup and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return
	if damage <= 0.0:
		return

	var callback := Callable(self, "_on_battle_started").bind(relic_context, str(effect_key))
	if not EventBus.battle_started.is_connected(callback):
		# 只监听一次，避免旧战斗或场景残留重复扣血。
		EventBus.battle_started.connect(callback, CONNECT_ONE_SHOT)


func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var callback := Callable(self, "_on_battle_started").bind(relic_context, str(effect_key))
	if EventBus.battle_started.is_connected(callback):
		EventBus.battle_started.disconnect(callback)


func _on_battle_started(relic_context: RelicContext, _effect_key: String) -> void:
	if relic_context == null or not (relic_context.owner is Entity):
		return

	var owner := relic_context.owner as Entity
	if not is_instance_valid(owner) or owner.is_dead:
		return

	if ignore_damage_reduction:
		_apply_direct_health_loss(owner)
	else:
		_apply_normal_self_damage(owner)


func _apply_normal_self_damage(owner: Entity) -> void:
	var damage_data := DamageData.create(
		damage,
		damage_types,
		tags,
		null,
		owner,
		false
	)
	owner.apply_damage(damage_data)


func _apply_direct_health_loss(owner: Entity) -> void:
	var damage_data := DamageData.create(
		damage,
		damage_types,
		tags,
		null,
		owner,
		false
	)
	damage_data.final_damage = max(damage, 0.0)

	owner.current_health = max(owner.current_health - damage_data.final_damage, 0.0)
	if owner.stats_controller != null:
		owner.stats_controller.current_health = owner.current_health
		owner.stats_controller.sync_runtime_resources()

	if damage_data.final_damage > 0.0:
		owner._show_damage_taken_effect()
		owner.show_damage_popup(damage_data)
		owner.damage_taken.emit(damage_data)
		owner._handle_damage_callback(damage_data)

	if owner.current_health <= 0.0:
		owner.call_deferred("_die")
