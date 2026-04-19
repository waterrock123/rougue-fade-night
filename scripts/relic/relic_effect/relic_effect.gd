class_name RelicEffect
extends Resource


# 获得遗物时触发。
# 适合做一次性的注册、监听或初始化逻辑。
func on_gain(_owner, _relic_controller: RelicController = null, _effect_key: String = "") -> void:
	pass


# 遗物处于“已装备/已激活”状态时触发。
# 大多数常驻装备效果都会在这里生效。
func on_activate(_owner, _relic_controller: RelicController = null, _effect_key: String = "") -> void:
	pass


# 遗物失效或卸下时触发。
# 这里负责清理 on_activate 时创建的效果。
func on_deactivate(_owner, _relic_controller: RelicController = null, _effect_key: String = "") -> void:
	pass
