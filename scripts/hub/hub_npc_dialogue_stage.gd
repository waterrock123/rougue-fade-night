class_name HubNpcDialogueStage
extends Resource

enum UpgradeRequirement {
	ANY,
	UNUPGRADED,
	UPGRADED,
}

## NPC 对话阶段：数组中排在前面的适用阶段优先，日常对白应放在最后。
@export var stage_id: StringName
@export var required_event_ids: Array[StringName] = []
@export var excluded_event_ids: Array[StringName] = []
## 非空时，只有大厅背包携带指定装备之一才会进入该对话阶段。
@export var required_carried_relic_ids: Array[String] = []
## 非空时，携带装备必须同时拥有这里填写的全部标签。
@export var required_carried_relic_tags: Array[RelicTag] = []
## -1 表示不限制；否则携带装备的等阶不得低于此值。
@export_range(-1, 100, 1) var minimum_carried_relic_level: int = -1
## 可限定携带装备必须为未升级态或升级态。
@export var carried_relic_upgrade_requirement: UpgradeRequirement = UpgradeRequirement.ANY
## 完成此阶段的事件后，是否从大厅背包消耗当前携带的装备。
@export var consume_carried_relic_on_completion: bool = false
## 非重复阶段在完成事件后自动退出；必须填写完成事件才能记录进度。
@export var repeatable: bool = false
@export var completion_event_id: StringName
@export_multiline var dialogue_lines: Array[String] = []
@export var random_line: bool = false
@export var actions: Array[HubNpcActionData] = []


func matches(completed_ids: Array[StringName], carried_relic: Relic = null, carried_relic_locked: bool = false) -> bool:
	for event_id: StringName in required_event_ids:
		if not completed_ids.has(event_id):
			return false
	for event_id: StringName in excluded_event_ids:
		if completed_ids.has(event_id):
			return false
	if _has_carried_relic_requirement() and carried_relic == null:
		return false
	if not required_carried_relic_ids.is_empty() and not required_carried_relic_ids.has(carried_relic.id):
		return false
	if carried_relic != null and carried_relic.level < minimum_carried_relic_level:
		return false
	if carried_relic != null and not _matches_required_tags(carried_relic):
		return false
	if carried_relic != null and not _matches_upgrade_requirement(carried_relic):
		return false
	# 会消耗装备的阶段不能选中已锁定装备，避免先完成事件再发现无法扣除。
	if consume_carried_relic_on_completion and carried_relic_locked:
		return false
	if not repeatable:
		return not completion_event_id.is_empty() and not completed_ids.has(completion_event_id)
	return true


func _has_carried_relic_requirement() -> bool:
	return (
		not required_carried_relic_ids.is_empty()
		or not required_carried_relic_tags.is_empty()
		or minimum_carried_relic_level >= 0
		or carried_relic_upgrade_requirement != UpgradeRequirement.ANY
	)


func _matches_required_tags(carried_relic: Relic) -> bool:
	for required_tag: RelicTag in required_carried_relic_tags:
		if required_tag == null:
			continue
		var found_tag: bool = false
		for relic_tag: RelicTag in carried_relic.tags:
			if relic_tag != null and relic_tag.tag_name == required_tag.tag_name:
				found_tag = true
				break
		if not found_tag:
			return false
	return true


func _matches_upgrade_requirement(carried_relic: Relic) -> bool:
	match carried_relic_upgrade_requirement:
		UpgradeRequirement.UNUPGRADED:
			return carried_relic.leveltip == Relic.LevelTip.UNLEVELUP
		UpgradeRequirement.UPGRADED:
			return carried_relic.leveltip == Relic.LevelTip.LEVELUP
		_:
			return true
