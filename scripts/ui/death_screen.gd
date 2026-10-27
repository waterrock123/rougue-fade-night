class_name DeathScreen
extends Control

const CHARACTER_SELECTOR_SCENE := preload("res://scenes/character_selector.tscn")
const HOME_SCENE := preload("res://scenes/home_scene.tscn")

@onready var restart_button: Button = %RestartButton
@onready var home_button: Button = %HomeButton
@onready var salvage_label: Label = %SalvageLabel


func _ready() -> void:
	get_tree().paused = false
	if restart_button != null and not restart_button.pressed.is_connected(_on_restart_button_pressed):
		restart_button.pressed.connect(_on_restart_button_pressed)
	if home_button != null and not home_button.pressed.is_connected(_on_home_button_pressed):
		home_button.pressed.connect(_on_home_button_pressed)


func show_recovered_relic(relic: Relic, warehouse_unlocked: bool, warehouse_full: bool = false) -> void:
	var relics: Array[Relic] = []
	if relic != null:
		relics.append(relic)
	show_recovered_relics(relics, warehouse_unlocked, warehouse_full)


## 支持普通单件回收与避难所批量回收，结果只展示、不再次写入仓库。
func show_recovered_relics(relics: Array[Relic], warehouse_unlocked: bool, warehouse_full: bool = false) -> void:
	if salvage_label == null:
		return
	if not warehouse_unlocked:
		salvage_label.text = "迷途中的装备无人收回。"
	elif warehouse_full and relics.is_empty():
		salvage_label.text = "拾荒仓库已满，没有空间保存这次带回的装备。"
	elif relics.is_empty():
		salvage_label.text = "拾荒者没有从这次旅途中找到可回收的装备。"
	elif relics.size() == 1:
		salvage_label.text = "拾荒者带回了：%s\n装备已存入局外仓库。" % relics[0].relic_name
	else:
		# 不罗列整背包名称，避免大批量回收时撑开死亡界面。
		salvage_label.text = "拾荒者带回了 %d 件装备。\n装备已存入局外仓库，可在大厅查看。" % relics.size()


# 重新开始一局时回到角色选择界面，让玩家重新选择角色。
func _on_restart_button_pressed() -> void:
	Run.pending_startup = null
	get_tree().change_scene_to_packed(CHARACTER_SELECTOR_SCENE)


# 本局已结束，返回大厅时只保留角色选择，不重新保存死亡后的构筑。
func _on_home_button_pressed() -> void:
	Run.pending_startup = null
	ResourceLocator.go_to_hub_scene(false)
