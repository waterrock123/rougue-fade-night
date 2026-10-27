class_name MapTagRuntimeModifier
extends Resource

## 地图标签的运行时规则；与生成概率分开配置，避免地图生成器承担战斗逻辑。
@export_enum("heart_heal_bonus", "extra_bounty_chance", "bounty_gold_bonus", "destroy_armor_chance", "road_speed_bonus", "cargo_extra_chance", "star_max_energy") var effect_id: String = "heart_heal_bonus"
@export var amount: float = 1.0
## 关闭后同类标签只生效一次，例如历战的额外赏金。
@export var stackable: bool = true
## {value} / {percent} 会替换为最终数值，其他 {关键词} 留给关键词格式器处理。
@export_multiline var summary: String = ""


func get_summary(total_amount: float = INF) -> String:
	var value: float = amount if is_inf(total_amount) else total_amount
	return summary.replace("{value}", _format_number(value)).replace("{percent}", _format_number(value * 100.0) + "%")


func _format_number(value: float) -> String:
	return str(int(roundf(value))) if is_equal_approx(value, roundf(value)) else String.num(value, 2)
