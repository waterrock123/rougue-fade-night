class_name SpellBar
extends PanelContainer



var spell_buttons: Array[SpellButton] = []

@export var button_container: Node


func _enter_tree() -> void:
	spell_buttons.clear()
	for spell_button in button_container.get_children():
		if spell_button is SpellButton:
			spell_buttons.push_back(spell_button)
	_refresh_key_labels()
	if not InputSettingsManager.bindings_changed.is_connected(_on_bindings_changed):
		InputSettingsManager.bindings_changed.connect(_on_bindings_changed)


func _exit_tree() -> void:
	if InputSettingsManager.bindings_changed.is_connected(_on_bindings_changed):
		InputSettingsManager.bindings_changed.disconnect(_on_bindings_changed)


func _on_bindings_changed(_action: StringName) -> void:
	_refresh_key_labels()


## 与教学、设置界面共用实际InputMap键名，两个备选绑定并列显示。
func _refresh_key_labels() -> void:
	for index: int in range(spell_buttons.size()):
		var action: StringName = StringName("ability_%d" % (index + 1))
		spell_buttons[index].binded_key = InputBindingDisplay.action_text(action)


func register_ability(ability:Ability,idx: int):
	if idx >=0 and idx < spell_buttons.size():
		var spell_button = spell_buttons[idx]
		spell_button.set_ability(ability)


func refresh_from_controller(ability_controller: AbilityController):
	if ability_controller == null:
		return

	for idx in range(spell_buttons.size()):
		var ability := ability_controller.abilities[idx] if idx < ability_controller.abilities.size() else null
		spell_buttons[idx].set_ability(ability)
