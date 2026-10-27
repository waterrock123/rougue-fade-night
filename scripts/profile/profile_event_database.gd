class_name ProfileEventDatabase
extends Resource

## 集中登记所有局外事件，避免 NPC 与剧情脚本各自维护事件表。
@export var events: Array[ProfileEventData] = []


func find_event(event_id: StringName) -> ProfileEventData:
	for event_data: ProfileEventData in events:
		if event_data != null and event_data.event_id == event_id:
			return event_data
	return null


## 向 UI 提供稳定的事件顺序，外部不直接遍历跨脚本的强类型资源数组。
func get_event_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for event_data: ProfileEventData in events:
		if event_data != null and not event_data.event_id.is_empty():
			result.append(event_data.event_id)
	return result
