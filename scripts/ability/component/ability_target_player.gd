class_name AbilityTargetPlayer
extends AbilityComponent

#瞄准玩家组件  必中
func _activate(context: AbilityContext):
	var player = get_tree().get_first_node_in_group("player")
	context.targets = [player]
	
