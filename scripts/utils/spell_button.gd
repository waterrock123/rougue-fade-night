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
		print("Binding: " + key)
		binded_key = key
		shortcut = Shortcut.new()
		var input_key = InputEventKey.new()
		input_key.keycode = key.unicode_at(0)
		print("Binding uni:" + str(input_key.keycode))
		shortcut.events = [input_key]
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
	icon.texture = ability.icon_texture
	progress_bar.max_value = ability.cooldown
	


func _ready() -> void:
	pass

func _on_pressed() -> void:
	
	if ability == null: return
	if _disabled :
		_shake()
		return
	_disabled = true
	EventBus.play_cast_ability.emit(ability)
	
	
	
	
	
	
	
