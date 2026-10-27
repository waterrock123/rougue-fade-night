class_name MergeTutorialConfig
extends Resource

## 固定教学候选，正式商店的随机池不变。奖励等阶须匹配合成时商店等级+1。
@export var shop_level: int = 1
@export var ordinary_extras: Array[Relic] = []
@export var reward_relics: Array[Relic] = []


func is_valid_for_lesson() -> bool:
	if shop_level < 1 or ordinary_extras.size() != 2 or reward_relics.size() != 3:
		return false
	for relic: Relic in ordinary_extras:
		if relic == null:
			return false
	var ids: Array[String] = []
	for relic: Relic in reward_relics:
		if relic == null or relic.level != shop_level + 1 or ids.has(relic.id):
			return false
		ids.append(relic.id)
	return true
