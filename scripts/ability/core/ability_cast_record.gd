## 一次真实施法的共享记录：分裂弹、延迟伤害共用它，不持有场景节点。
## 以效果来源和目标编号去重，随最后一枚投射物销毁而回收，无需永久计数表。
class_name AbilityCastRecord
extends RefCounted

var is_basic_attack: bool = false
var damage_multiplier: float = 1.0
var claims: Dictionary = {}
## 只记录实际支付成功的材料，不把预检查或背包里“存在材料”当作已消耗。
var material_payments: Dictionary = {}
var projectile_options: Dictionary = {}
var projectile_count_bonus: int = 0


func claim_once(effect_key: String, target_id: int = 0) -> bool:
	var key: String = "%s:%d" % [effect_key, target_id]
	if claims.has(key):
		return false
	claims[key] = true
	return true
