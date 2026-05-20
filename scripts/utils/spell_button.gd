class_name SpellButton
extends TextureButton

var ability: Ability = null

@export var icon: TextureRect
@export var progress_bar: TextureProgressBar
@export var cooldown_label: Label 
@export var keybind_label: Label 

var is_shaking = false
#自定义的禁用属性
var _disabled = false

var binded_key: String = "":
	set(key):
		
		binded_key = key
		# 技能输入由 Player 统一读取 InputMap。
		# 这里不再设置 Button.shortcut，避免键盘触发按钮 pressed 后绕过技能预览流程。
		shortcut = null
		cooldown_label.text = ""
		keybind_label.text = key


func _process(delta: float) -> void:
	if ability == null: return
	cooldown_label.visible = ability.current_cooldown > 0
	
	_disabled = !ability.can_be_casted
	progress_bar.value = ability.current_cooldown
	if _disabled:
	
		cooldown_label.text = "%3.1f" %(ability.current_cooldown)
		icon.modulate.a = 0.5
	else:
		icon.modulate.a = 1.0

func _shake():
	if is_shaking: return
	
	is_shaking = true
	
	var shake_times = 6
	var shake_amount = 3
	var original_pos = position
	var tween = create_tween()
	
	for i in range(shake_times):
		var offset = shake_amount if i % 2 == 0 else -shake_amount
		tween.tween_property(self,"position:x",original_pos.x + offset,0.05)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_property(self,"position:x",original_pos.x,0.05)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.play()
	await  tween.finished
	is_shaking = false
	
	
	
	


func set_ability(ability: Ability):
	self.ability = ability
	if ability == null:
		icon.texture = null
		tooltip_text = ""
		progress_bar.max_value = 0.0
		cooldown_label.text = ""
		cooldown_label.visible = false
		return

	icon.texture = ability.icon_texture
	progress_bar.max_value = ability.cooldown
	tooltip_text = " " if ability.skill_entry != null else ""
	


func _ready() -> void:
	# 子节点只负责显示，不抢按钮自身的点击和 tooltip 事件。
	_set_child_mouse_filter_ignore(self)


func _make_custom_tooltip(_for_text: String) -> Object:
	if ability == null or ability.skill_entry == null:
		return null

	var tooltip := FloatText.SKILL_TOOL_TIP_PANEL.instantiate() as SkillToolTipPanel
	tooltip.set_skill(ability.skill_entry)
	return tooltip

func _on_pressed() -> void:
	
	if ability == null: return
	if _disabled :
		_shake()
		return
	_disabled = true
	EventBus.play_cast_ability.emit(ability)
	
	
	
	
	
	

func _set_child_mouse_filter_ignore(root: Node) -> void:
	for child in root.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_child_mouse_filter_ignore(child)
	
