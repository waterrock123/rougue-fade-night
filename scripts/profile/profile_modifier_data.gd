class_name ProfileModifierData
extends Resource

## 局外修正器既可作为自动生效的永久奖励，也可作为出发前选择携带的 NPC 信物。
enum ModifierType {
	PRIMARY_STAT,
	STARTING_GOLD,
}

enum ActivationMode {
	## 解锁后每一局自动生效，不占用信物栏。
	PERMANENT,
	## 解锁后需要在出发面板主动携带，占用一个信物栏位。
	EQUIPPABLE_TOKEN,
}

@export var modifier_id: StringName
@export var display_name: String = "未命名局外加成"
@export_multiline var description: String
@export var activation_mode: ActivationMode = ActivationMode.PERMANENT
@export var modifier_type: ModifierType = ModifierType.PRIMARY_STAT
@export var stat_name: StringName
@export var amount: float = 0.0
