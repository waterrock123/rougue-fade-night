class_name SpellButton
extends TextureButton

var ability: Ability = null

@export var icon: TextureRect
@export var progress_bar: TextureProgressBar
@export var cooldown_label: Label 
@export var keybind_label: Label 

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
	disabled = ability.current_cooldown > 0
	progress_bar.value = ability.current_cooldown
	cooldown_label.text = "%3.1f" %(ability.current_cooldown)

func set_ability(ability: Ability):
	
	self.ability = ability
	icon.texture = ability.icon_texture
	progress_bar.max_value = ability.cooldown
	


func _ready() -> void:
	pass

func _on_pressed() -> void:
	
	if ability == null: return
	if disabled: return
	EventBus.play_cast_ability.emit(ability)
	
	
	
	
	
	
	
