class_name HubCharacterNpc
extends Node2D

## 角色驻点只负责外观和距离判定，对话及角色切换由大厅管理。
@export var character: Character
@export var interaction_radius: float = 32.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt: Label = $CanvasLayer/Label


func _ready() -> void:
	if character == null:
		return
	var visual: CharacterVisualData = character.visual_data
	if visual == null or visual.sprite_frames == null:
		push_warning("大厅角色缺少动画：%s" % character.character_name)
		return
	sprite.sprite_frames = visual.sprite_frames
	sprite.position = visual.visual_offset
	sprite.scale = visual.visual_scale
	sprite.flip_h = visual.default_facing_left
	if visual.has_animation(&"idle"):
		sprite.play(&"idle")
	elif visual.has_animation(visual.default_animation):
		sprite.play(visual.default_animation)


## CanvasLayer 不继承世界节点显隐，所以同步隐藏提示。
func set_selected_character(selected: Character) -> void:
	visible = character != null and character != selected
	if character != null and selected != null and not character.resource_path.is_empty():
		visible = character.resource_path != selected.resource_path
	prompt.visible = false


func update_prompt(focused: bool) -> void:
	prompt.visible = visible and focused
	if not prompt.visible:
		return
	prompt.text = "%s · 交谈" % character.character_name
	var screen_position: Vector2 = get_global_transform_with_canvas().origin
	prompt.position = (screen_position + Vector2(-120, -65)).round()
