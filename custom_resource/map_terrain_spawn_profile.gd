class_name MapTerrainSpawnProfile
extends Resource

## 一张战斗地图使用的一组特殊地形随机生成规则。
## BattleMapTerrainRandomizer 会读取这里的规则，并把瓦片铺到 EffectLayer 上。

@export var enabled: bool = true
@export var rules: Array[MapTerrainSpawnRule] = []


func get_enabled_rules() -> Array[MapTerrainSpawnRule]:
	var result: Array[MapTerrainSpawnRule] = []
	if not enabled:
		return result

	for rule: MapTerrainSpawnRule in rules:
		if rule == null or not rule.is_valid_rule():
			continue
		result.append(rule)

	return result
