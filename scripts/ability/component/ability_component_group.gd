## 技能组件组。用于把多个子组件作为一组延迟或顺序触发，适合把复杂技能拆成阶段。
class_name AbilityComponentGroup
extends AbilityComponent

#延迟，负责控制子节点共同触发延迟
@export var delay: float =0.0

var sub_components: Array[AbilityComponent] = []

func _ready():
	for child in get_children():
		if child is AbilityComponent:
			sub_components.push_back(child)



func _activate(context: AbilityContext):
	if delay>0:
		await  get_tree().create_timer(delay).timeout
	if context == null or not context.is_caster_action_valid():
		return
		
	for sub_component in sub_components:
		if not context.is_caster_action_valid():
			return
		sub_component.activate(context)
	
	
