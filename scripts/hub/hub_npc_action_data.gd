class_name HubNpcActionData
extends Resource

## 单个 NPC 服务按钮的数据。新增服务类型时由大厅统一调度，不把业务写进 NPC 节点。
enum ActionType {
	NONE,
	OPEN_PICTORIAL_BOOK,
	OPEN_RELIC_WAREHOUSE,
	OPEN_ANTIQUE_TRADE,
	DELIVER_ZHANG_SAN_SUPPLY,
	HARVEST_ZHANG_SAN_MOOD,
}

@export_group("功能信息")
@export var action_id: StringName
@export var display_name: String = "未命名功能"
@export_multiline var description: String
@export var action_type: ActionType = ActionType.NONE
