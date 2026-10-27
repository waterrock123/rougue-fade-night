class_name ProfileEventData
extends Resource

## 局外事件定义：前置、一次性规则与解锁奖励都由资源描述。
@export_group("基础信息")
@export var event_id: StringName
@export var display_name: String = "未命名事件"
@export_multiline var description: String
@export var repeatable: bool = false
## 过程标记可以参与剧情条件，但不作为独立事件显示在图鉴中。
@export var show_in_codex: bool = true

@export_group("触发条件")
@export var required_completed_event_ids: Array[StringName] = []

@export_group("完成奖励")
@export var unlock_content_ids: Array[StringName] = []
@export var unlock_modifier_ids: Array[StringName] = []
## 完成事件后直接放入拾荒仓库的随机装备奖励；0 表示没有此类奖励。
@export_range(0, 20, 1) var warehouse_relic_reward_count: int = 0
@export_range(0, 10, 1) var warehouse_relic_reward_level: int = 0
