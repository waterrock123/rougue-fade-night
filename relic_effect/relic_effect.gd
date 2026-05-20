## 遗物效果基类。
## 继承它来编写装备、消耗品、出售、获得等不同生命周期下触发的效果。
class_name RelicEffect
extends Resource


## 获得遗物时触发。
## 适合做一次性的注册、监听或初始化逻辑。
func on_gain(relic_context: RelicContext, effect_key) -> void:
	pass


## 遗物处于“已装备/已激活”状态时触发。
## 大多数常驻装备效果都应该在这里生效。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	pass


## 遗物失效或卸下时触发。
## 这里负责清理 on_activate 时创建的效果。
func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	pass


## 使用消耗品时触发。
## 只有 Relic.use_consumable() 会分发到这里，避免消耗品刚装备时就立刻生效。
func on_use(relic_context: RelicContext, effect_key) -> void:
	pass


## 遗物出售时触发。
## 适合做出售后返利、刷新商店、触发特殊事件等一次性逻辑。
func on_sold(relic_context: RelicContext, effect_key) -> void:
	pass
