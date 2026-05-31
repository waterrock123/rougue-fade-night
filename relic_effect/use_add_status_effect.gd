## 消耗品使用时给拥有者添加状态的通用效果。
## 适合肾上腺素、临时护甲药剂、短时间增益/减益等“按下使用后获得一段状态”的装备。
class_name UseAddStatusEffect
extends RelicEffect


## 使用后要添加到拥有者身上的状态。
@export var status_data: StatusData
## 添加的层数。
@export var stacks: int = 1
## 状态持续时间覆盖。INF 表示使用 StatusData 资源里的默认 duration。
@export var duration_override: float = INF
## 勾选后，升级态遗物会跳过这条基础状态效果。
@export var ignore_when_relic_levelup: bool = false


func on_use(relic_context: RelicContext, effect_key) -> void:
	if relic_context == null or status_data == null:
		return
	if ignore_when_relic_levelup and relic_context.own_relic != null and relic_context.own_relic.leveltip == Relic.LevelTip.LEVELUP:
		return

	var status_controller := _get_status_controller(relic_context)
	if status_controller == null:
		return

	status_controller.add_status(status_data, relic_context.owner, effect_key, stacks, duration_override)


func _get_status_controller(relic_context: RelicContext) -> StatusController:
	if relic_context.owner == null:
		return null
	if relic_context.owner.has_method("get_status_controller"):
		return relic_context.owner.get_status_controller()
	return relic_context.owner.get_node_or_null("StatusController") as StatusController
