class_name StatusData
extends Resource

enum Polarity {
	NEUTRAL,
	POSITIVE,
	NEGATIVE,
}

enum StackMode {
	REFRESH,
	ADD_STACK,
	REPLACE,
}

@export var id: StringName
@export var status_name: String
@export_multiline var desc: String
@export var icon: Texture2D

@export_group("分类")
## 用于区分增益和负面状态，羊毛等效果会根据这个分类拦截负面状态。
@export var polarity: Polarity = Polarity.NEUTRAL

@export_group("持续与叠层")
# duration < 0 表示永久，duration > 0 表示限时状态。
@export var duration: float = -1.0
@export var max_stacks: int = 1
@export var stack_mode: StackMode = StackMode.REFRESH
@export var refresh_duration_on_reapply: bool = true
# 再次施加状态时，是否把本次持续时间追加到剩余时间上。
# 适合“流血”这类在已有状态上继续延长时间，但又不能超过上限的状态。
@export var add_duration_on_reapply: bool = false
# 追加持续时间后的最大持续时间；小于等于 0 时默认使用 duration 作为上限。
@export var max_duration: float = -1.0
# 开启后，一次施加多层状态会按层数追加持续时间。
@export var duration_add_scales_with_stacks: bool = true

@export_group("效果")
@export var effects: Array[StatusEffect] = []


func is_positive() -> bool:
	return polarity == Polarity.POSITIVE


func is_negative() -> bool:
	return polarity == Polarity.NEGATIVE
