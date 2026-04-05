class_name  AbilityComponentGroup
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
		
	for sub_component in sub_components:
		sub_component.activate(context)
	
	
