class_name ShopKeeper
extends Resource

@export var name: String
@export var relics: Array[Relic]
@export var texture: Texture2D
@export var havetag:Array[RelicTag]
@export_multiline() var shop_desc:String

@export_group("Dialogue")
@export var enter_rest_period_dialogues: ShopKeeperDialoguePool
@export var exit_rest_period_dialogues: ShopKeeperDialoguePool
@export var buy_relic_dialogues: ShopKeeperDialoguePool
@export var sell_relic_dialogues: ShopKeeperDialoguePool


func get_dialogue(pool: ShopKeeperDialoguePool) -> String:
	if pool == null:
		return ""
	return pool.get_random_line()

#

#商人名称
#商人货物
#商人立绘
