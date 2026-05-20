## 施法者前推组件。让施法者朝面向方向小幅位移，常用于近战挥击、突进起手的手感补偿。
class_name AbilityPushBack
extends AbilityComponent
#出于手感考虑改成往前进

#前推距离
@export var push_back_distance = 30
#前推持续时间
@export var duration =1.0
#频率，每攻击ferquenct次前推
@export var frequenct = 2
#清空间隔,超过这个时间将重置要触发前推攻击次数
@export var clear_tween = 1000
#反转方向
@export var revert = false
var push_back_counter = 0 
var last_activation_time = -1

func _activate(context: AbilityContext):
	
	
	if frequenct != -1 and Time.get_ticks_msec() - last_activation_time > 1000:
		push_back_counter = 0
	
	push_back_counter += 1
		
	if frequenct == -1 or  push_back_counter == frequenct:
		push_back_counter = 0
	
		var caster = context.caster
		var caster_pos = caster.position
		var mouse_pos = get_window().get_camera_2d().get_global_mouse_position()
		var push_dir
		if revert:
			push_dir = (mouse_pos - caster_pos).normalized()		
		else:
			push_dir = (caster_pos - mouse_pos).normalized()
		var target_pos = caster_pos + push_dir * push_back_distance
		
		var tween = create_tween()
		tween.tween_property(caster,"position",target_pos,duration)
		tween.set_ease(Tween.EASE_IN)
	last_activation_time = Time.get_ticks_msec()
	
