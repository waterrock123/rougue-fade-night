## 破韧后给持有者或被破韧目标施加状态的通用遗物效果。
## 同一个装备来源重复触发时会遵循 StatusData 的叠层规则，并刷新配置的持续时间。
class_name PoiseBreakApplyStatusEffect
extends PoiseBreakRelicEffect


enum Recipient {
	OWNER,
	BROKEN_ENEMY,
}

@export_group("状态")
@export var status_data: StatusData
@export var recipient: Recipient = Recipient.OWNER
@export var stacks: int = 1
## INF 表示使用状态资源的默认持续时间。
@export var duration_override: float = INF


## 找到接收者的 StatusController，并以装备效果键作为独立叠层来源。
func apply_poise_break_effect(
	owner: Entity,
	broken_enemy: Entity,
	_damage_data: DamageData,
	effect_key: String,
	_is_levelup: bool
) -> void:
	if status_data == null or stacks <= 0:
		return

	var status_target: Entity = owner if recipient == Recipient.OWNER else broken_enemy
	if status_target == null or not is_instance_valid(status_target):
		return

	var status_controller: StatusController = status_target.get_status_controller()
	if status_controller == null:
		return

	var source_key: String = "%s_poise_break_status" % effect_key
	status_controller.add_status(status_data, owner, source_key, stacks, duration_override)
