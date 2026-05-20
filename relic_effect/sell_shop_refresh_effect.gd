## 兑换券出售效果。
## 未升级时立即免费刷新当前商店；升级态时获得可储存的免费商店刷新次数。
class_name SellShopRefreshEffect
extends RelicEffect


## 升级态出售时获得的可储存免费刷新次数。
@export var refresh_count: int = 1


## 兑换券出售效果：
## 未升级时立即免费刷新当前商店；升级态时改为获得可储存的免费刷新次数。
func on_sold(relic_context: RelicContext, _effect_key) -> void:
	if relic_context == null or relic_context.own_relic == null:
		return

	var owner := relic_context.owner
	var run_stats := _resolve_run_stats(owner)
	if run_stats == null:
		return

	if relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		run_stats.add_shop_free_refresh_count(refresh_count)
		return

	var shop_controller := _resolve_shop_controller(owner)
	if shop_controller != null and shop_controller.has_method("refresh_for_free"):
		shop_controller.refresh_for_free()
	else:
		push_warning("SellShopRefreshEffect: 未找到当前商店，无法立即免费刷新。")


func _resolve_run_stats(owner: Node) -> RunStats:
	if owner == null:
		return null
	if "run_stats" in owner:
		return owner.run_stats

	var node := owner.get_parent()
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()
	return null


func _resolve_shop_controller(owner: Node) -> ShopController:
	if owner == null:
		return null

	if owner.has_method("get_sell_shop_controller"):
		return owner.get_sell_shop_controller()

	var node := owner
	while node != null:
		if node is ShopController:
			return node as ShopController
		node = node.get_parent()
	return null
