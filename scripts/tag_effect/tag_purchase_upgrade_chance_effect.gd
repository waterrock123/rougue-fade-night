## 套装效果：购买遗物时有小概率直接把本次购买的遗物变为升级态。
class_name TagPurchaseUpgradeChanceEffect
extends TagEffect

@export_range(0.0, 1.0, 0.001) var upgrade_chance: float = 0.02

var active_contexts: Dictionary = {}


func on_activate(context: TagEffectContext) -> void:
	var key := TagEffectRuntimeHelper.get_context_key(context)
	if key.is_empty():
		return

	active_contexts[key] = context
	if not EventBus.relic_purchase_preprocess.is_connected(_on_relic_purchase_preprocess):
		EventBus.relic_purchase_preprocess.connect(_on_relic_purchase_preprocess)


func on_deactivate(context: TagEffectContext) -> void:
	active_contexts.erase(TagEffectRuntimeHelper.get_context_key(context))
	if active_contexts.is_empty() and EventBus.relic_purchase_preprocess.is_connected(_on_relic_purchase_preprocess):
		EventBus.relic_purchase_preprocess.disconnect(_on_relic_purchase_preprocess)


func _on_relic_purchase_preprocess(relic: Relic) -> void:
	if active_contexts.is_empty() or relic == null:
		return
	if relic.leveltip != Relic.LevelTip.UNLEVELUP:
		return
	if RunRng.randf() > upgrade_chance:
		return

	relic.leveltip = Relic.LevelTip.LEVELUP
	AudioController.play_ui_sound(&"level_up_item")
