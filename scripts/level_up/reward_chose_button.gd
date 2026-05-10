class_name RewardChoseButton
extends Button

signal reward_chosen(reward: LevelUpReward)
signal reward_focused(reward: LevelUpReward)

@export var keyword_database: KeywordDatabase = preload("res://custom_resource/default_keyword_database.tres")

var reward: LevelUpReward

@onready var name_label: Label = %NameLabel
@onready var icon_texture: TextureRect = %Texture
@onready var desc_label: RichTextLabel = %DescLabel


# 绑定一个升级奖励，并刷新按钮上的名称、图标和描述。
func setup(new_reward: LevelUpReward) -> void:
	reward = new_reward
	disabled = reward == null
	visible = reward != null

	if reward == null:
		return

	name_label.text = reward.get_display_title()
	_set_rich_desc(reward.get_display_desc())
	icon_texture.texture = reward.get_display_icon()


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	_set_child_mouse_filter_ignore(self)


# 点击按钮时，不直接处理奖励逻辑，而是把选择结果交给 LevelUPController。
func _on_pressed() -> void:
	if reward == null:
		return

	reward_chosen.emit(reward)


# 悬停按钮时，通知控制器刷新说明文字。
func _on_mouse_entered() -> void:
	if reward == null:
		return

	reward_focused.emit(reward)


# 子控件只负责显示内容，不抢按钮根节点的点击和悬停事件。
func _set_child_mouse_filter_ignore(root: Node) -> void:
	for child in root.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_child_mouse_filter_ignore(child)


func _set_rich_desc(raw_desc: String) -> void:
	if desc_label == null:
		return

	var result := KeywordTextFormatter.format_text(raw_desc, keyword_database)
	desc_label.clear()
	desc_label.append_text(result.bbcode_text)
