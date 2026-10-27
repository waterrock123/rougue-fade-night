## 技能释放时临时修改施法者某个 CanvasItem 子节点的可见性，并在指定时间后恢复。
## 默认用于隐藏 Player/Weapon，也可以复用于护盾、光环、挂载武器等视觉节点。
class_name AbilityTemporaryNodeVisibility
extends AbilityComponent

@export_group("目标")
## 相对于施法者根节点的路径。
@export var target_path: NodePath = NodePath("Weapon")
## 技能生效期间目标节点是否可见。关闭即可实现“施法时隐藏武器”。
@export var visible_during_ability: bool = false

@export_group("恢复")
## 经过这段时间后恢复节点释放技能前的可见状态。
@export_range(0.0, 10.0, 0.01) var restore_delay: float = 0.3


func _activate(context: AbilityContext) -> void:
	if context == null or context.caster == null or not is_instance_valid(context.caster):
		return

	var target: CanvasItem = context.caster.get_node_or_null(target_path) as CanvasItem
	if target == null:
		return

	var previous_visibility: bool = target.visible
	target.visible = visible_during_ability
	if restore_delay <= 0.0:
		target.visible = previous_visibility
		return

	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(restore_delay, false).timeout
	if is_instance_valid(target):
		target.visible = previous_visibility
