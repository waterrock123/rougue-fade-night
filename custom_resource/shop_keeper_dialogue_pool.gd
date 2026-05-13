class_name ShopKeeperDialoguePool
extends Resource

@export var lines: Array[String] = []


# 从语料库中随机取一句话。对白不影响玩法随机，所以不接入 RunRng。
func get_random_line() -> String:
	var valid_lines: Array[String] = []
	for line in lines:
		if not line.strip_edges().is_empty():
			valid_lines.append(line)

	if valid_lines.is_empty():
		return ""

	return valid_lines.pick_random()
