## 使用消耗品时直接流失生命，不参与闪避、护甲与减伤判定，也不伪造造成伤害事件。
## 这是生命代价而非攻击；仍同步构筑、生命条并走统一死亡/复活入口。
class_name UseHealthLossEffect
extends RelicEffect

@export var health_loss: float = 5.0


func on_use(context: RelicContext, _effect_key) -> void:
	if context == null or not is_instance_valid(context.owner) or not (context.owner is Entity):
		return
	var entity: Entity = context.owner as Entity
	if entity.is_dead:
		return
	entity.current_health = maxf(entity.current_health - maxf(health_loss, 0.0), 0.0)
	if entity.stats_controller != null:
		entity.stats_controller.current_health = entity.current_health
		entity.stats_controller.sync_runtime_resources()
	entity._handle_damage_callback(null)
	if entity.current_health <= 0.0:
		entity._die()
