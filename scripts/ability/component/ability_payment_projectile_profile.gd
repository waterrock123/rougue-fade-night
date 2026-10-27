## 按真实材料支付结果选择本次投射物参数；只修改施法快照，不污染共享资源。
class_name AbilityPaymentProjectileProfile
extends AbilityComponent

@export var payment_tag: StringName = &"弹药"
@export var unpaid_damage_multiplier: float = 0.5
@export var paid_hit_limit: int = 5
@export var unpaid_hit_limit: int = 1


func _activate(context: AbilityContext) -> void:
	var paid: bool = int(context.cast_record.material_payments.get(payment_tag, 0)) > 0
	if not paid:
		context.cast_record.damage_multiplier *= maxf(unpaid_damage_multiplier, 0.0)
	context.cast_record.projectile_options["max_hits"] = paid_hit_limit if paid else unpaid_hit_limit
	context.cast_record.projectile_options["penetrate"] = paid
