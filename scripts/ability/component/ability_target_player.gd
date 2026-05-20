## 玩家目标组件。把场景中第一个 player 组实体写入 AbilityContext.targets，适合敌人技能锁定玩家。
class_name AbilityTargetPlayer
extends AbilityComponent

#瞄准玩家组件  必中
func _activate(context: AbilityContext):
	var player = get_tree().get_first_node_in_group("player")
	context.targets = [player]
	
