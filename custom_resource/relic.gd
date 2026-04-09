class_name Relic
extends Resource

enum CharacterType {ALL,WARRIOR,SCOUNTS}
#售卖的价格
@export var price: int
@export var relic_name: String
#装备的阶数
@export var level: int
@export var tags: Array[String]
@export var id: String
#角色类型：只有此种角色的商店才会出现这种遗物
@export var character_type: CharacterType
#是否是主动消耗品
@export var is_consumable: bool = false
@export var icon: Texture
@export_multiline var tooltip: String

#遗物初始化，暂定用来连接遗物的各种效果和信号总线的信号
func init_relic(_owner:RelicUI) -> void:
	pass

#获得时触发效果
func gain_relic(_owner: RelicUI) -> void:
	pass

#激发时触发效果：满足一定条件下就就可以激活这个效果，最简单的条件应该是直接装备此遗物/如果是这个遗物是主动消耗品话主动消耗就可以激活这个函数
func activate_relic(_owner: RelicUI) -> void:
	pass

#解除遗物的效果，一般情况下是卸下装备时激发，移除装备的效果或者是连接函数
func deactivate_relic(_owner: RelicUI) -> void:
	pass


func get_tooltip() -> String:
	return tooltip
