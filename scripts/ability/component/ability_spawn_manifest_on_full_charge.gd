## 只在成功释放且达到满蓄力时生成额外实体，取消或法力不足不会触发。
class_name AbilitySpawnManifestOnFullCharge
extends AbilitySpawnManifest


func _activate(context: AbilityContext) -> void:
	if context != null and context.charge_ratio >= 1.0:
		super._activate(context)
