## 装备后临时解锁背包锁格的通用遗物效果。
## 适合“背包”“储物袋”这类增加可用储备空间的装备；卸下后会恢复为锁格。
class_name AddInventorySlotsEffect
extends RelicEffect


## 本效果提供的额外可用背包格数量。
@export var slot_count: int = 1


## 装备生效时，向 Inventory 注册一份临时解锁来源。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	var inventory := _get_inventory(relic_context)
	if inventory == null or slot_count <= 0:
		return

	inventory.unlock_locked_slots(effect_key, slot_count)


## 卸下或刷新装备效果时，移除这份临时解锁来源。
func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var inventory := _get_inventory(relic_context)
	if inventory == null:
		return

	inventory.clear_unlocked_slots(effect_key)


func _get_inventory(relic_context: RelicContext) -> Inventory:
	if relic_context == null:
		return null

	if relic_context.relic_controller != null and relic_context.relic_controller.player_build != null:
		return relic_context.relic_controller.player_build.player_inventory

	var owner := relic_context.owner
	if owner == null:
		return null

	if owner is PlayerBuildProxy and (owner as PlayerBuildProxy).player_build != null:
		return (owner as PlayerBuildProxy).player_build.player_inventory

	if owner is Player:
		return (owner as Player).player_inventory

	if "player_inventory" in owner:
		return owner.player_inventory

	return null
