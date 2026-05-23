## 添加状态的遗物效果。
## 装备生效时给拥有者添加 StatusData，卸下时移除这件装备来源提供的状态层数。
class_name AddStatusEffect
extends RelicEffect


## 要添加到拥有者身上的状态资源。
@export var status_data: StatusData
## 添加的层数。同 id 状态可以通过不同来源叠层。
@export var stacks: int = 1
## 本次施加状态的持续时间覆盖。INF 表示使用 StatusData 资源里的默认 duration。
@export var duration_override: float = INF


## 装备遗物时给拥有者添加状态，effect_key 会作为“这件装备”的来源标识。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	var status_controller := _get_status_controller(relic_context)
	if status_controller == null:
		return

	status_controller.add_status(status_data, relic_context.owner, effect_key, stacks, duration_override)


## 卸下遗物时只移除当前装备来源的状态层数，不影响其他同 id 状态来源。
func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var status_controller := _get_status_controller(relic_context)
	if status_controller == null or status_data == null:
		return

	status_controller.remove_status_source(status_data.id, effect_key)


func _get_status_controller(relic_context: RelicContext) -> StatusController:
	if relic_context == null or relic_context.owner == null:
		return null

	if relic_context.owner.has_method("get_status_controller"):
		return relic_context.owner.get_status_controller()

	return relic_context.owner.get_node_or_null("StatusController") as StatusController
