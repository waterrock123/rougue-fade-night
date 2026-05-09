class_name StatusData
extends Resource

enum StackMode {
	REFRESH,
	ADD_STACK,
	REPLACE,
}

@export var id: StringName
@export var status_name: String
@export_multiline var desc: String
@export var icon: Texture2D

@export_group("持续与叠层")
# duration < 0 表示永久，duration > 0 表示限时状态。
@export var duration: float = -1.0
@export var max_stacks: int = 1
@export var stack_mode: StackMode = StackMode.REFRESH
@export var refresh_duration_on_reapply: bool = true

@export_group("效果")
@export var effects: Array[StatusEffect] = []
