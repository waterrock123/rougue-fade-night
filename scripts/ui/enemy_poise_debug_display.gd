## 敌人血条上的削韧调试浮字。
## 常规战斗只通过血条外沿的白色轮廓表现韧性，必要时才开启该浮字辅助调试。
class_name EnemyPoiseDebugDisplay
extends Control


var show_damage_popup: bool = false
var damage_color: Color = Color(1.0, 0.78, 0.3, 1.0)

var damage_label: Label
var damage_tween: Tween
var damage_start_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 12
	_ensure_labels()


## 应用 Enemy 提供的开关和颜色，不让调试 UI 反向依赖 Enemy 脚本。
func configure(
	new_show_damage_popup: bool,
	new_damage_color: Color
) -> void:
	show_damage_popup = new_show_damage_popup
	damage_color = new_damage_color
	_ensure_labels()
	_apply_colors()


## 在血条上方短暂显示本次真正扣除的韧性值。
func play_damage_popup(amount: float) -> void:
	if not show_damage_popup or amount <= 0.0:
		return
	_ensure_labels()
	if damage_label == null:
		return

	if damage_tween != null and damage_tween.is_valid():
		damage_tween.kill()

	damage_label.text = "-%d 韧" % roundi(amount)
	damage_label.visible = true
	damage_label.modulate = Color.WHITE
	damage_label.position = damage_start_position

	damage_tween = create_tween().set_parallel(true)
	damage_tween.tween_property(damage_label, "position", damage_start_position + Vector2(0.0, -8.0), 0.45)
	damage_tween.tween_property(damage_label, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.35).set_delay(0.15)
	damage_tween.finished.connect(_finish_damage_popup)


func _ensure_labels() -> void:
	if damage_label == null:
		damage_label = Label.new()
		damage_label.name = "PoiseDamageLabel"
		damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		damage_label.anchor_left = 0.5
		damage_label.anchor_right = 0.5
		damage_label.offset_left = -30.0
		damage_label.offset_top = -15.0
		damage_label.offset_right = 30.0
		damage_label.offset_bottom = -3.0
		damage_label.add_theme_font_size_override("font_size", 8)
		damage_label.add_theme_constant_override("outline_size", 2)
		damage_label.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.09, 0.95))
		damage_label.visible = false
		add_child(damage_label)
		damage_start_position = damage_label.position

	_apply_colors()


func _apply_colors() -> void:
	if damage_label != null:
		damage_label.add_theme_color_override("font_color", damage_color)


func _finish_damage_popup() -> void:
	if damage_label != null:
		damage_label.visible = false
		damage_label.modulate = Color.WHITE
		damage_label.position = damage_start_position
	damage_tween = null


func _exit_tree() -> void:
	if damage_tween != null and damage_tween.is_valid():
		damage_tween.kill()
	damage_tween = null
