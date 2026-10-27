## 出售时获得指定装备。复用指定装备的加载和 PlayerBuild 查找逻辑。
## 目标可填资源路径以避免互相引用形成循环；获得本装备时不会触发。
class_name SoldSpecificRelicEffect
extends GainSpecificRelicEffect


func on_gain(_context: RelicContext, _effect_key) -> void:
	pass


func on_sold(context: RelicContext, effect_key) -> void:
	super.on_gain(context, effect_key)
