class_name AmmoBox
extends MapObject

@export_group("弹药补给")
## 弹药箱可代替背包弹药装备支付的最大次数。
@export var max_charges: int = 5
## 角色必须在这个范围内，弹药箱才会为技能支付弹药成本。
@export var supply_radius: float = 96.0
## 次数耗尽后进入冷却，冷却结束恢复到满次数。
@export var cooldown_duration: float = 8.0
## 这个弹药箱能代替的标签。默认用于“弹药”标签。
@export var supported_tag_name: StringName = &"弹药"

@export_group("UI")
@export var charge_label_path: NodePath = NodePath("AmmoBoxUI/ChargeLabel")
@export var cooldown_bar_path: NodePath = NodePath("AmmoBoxUI/CooldownBar")
@export var cooldown_label_path: NodePath = NodePath("AmmoBoxUI/CooldownLabel")

var current_charges: int = 0
var cooldown_remaining: float = 0.0

@onready var charge_label: Label = get_node_or_null(charge_label_path) as Label
@onready var cooldown_bar: ProgressBar = get_node_or_null(cooldown_bar_path) as ProgressBar
@onready var cooldown_label: Label = get_node_or_null(cooldown_label_path) as Label


func _ready() -> void:
	super._ready()
	add_to_group("ammo_box")
	current_charges = max(max_charges, 0)
	_refresh_ui()


func _process(delta: float) -> void:
	if cooldown_remaining <= 0.0:
		return

	cooldown_remaining = max(cooldown_remaining - delta, 0.0)
	if cooldown_remaining <= 0.0:
		_finish_cooldown()
	else:
		_refresh_ui()


## 技能组件会先调用这里检查弹药箱是否能替代背包弹药消耗。
func can_supply_ammo(caster: Entity, required_tag: RelicTag, required_tag_name: StringName) -> bool:
	if is_dead:
		return false
	if cooldown_remaining > 0.0:
		return false
	if current_charges <= 0:
		return false
	if not _matches_required_tag(required_tag, required_tag_name):
		return false
	if not _is_caster_in_supply_range(caster):
		return false

	return true


## 真正扣除一次弹药箱次数。次数归零时立刻进入冷却。
func consume_ammo(caster: Entity, required_tag: RelicTag, required_tag_name: StringName) -> bool:
	if not can_supply_ammo(caster, required_tag, required_tag_name):
		return false

	current_charges = max(current_charges - 1, 0)
	if current_charges <= 0:
		_begin_cooldown()
	else:
		_refresh_ui()

	return true


func _begin_cooldown() -> void:
	cooldown_remaining = max(cooldown_duration, 0.0)
	if cooldown_remaining <= 0.0:
		_finish_cooldown()
		return

	_refresh_ui()


func _finish_cooldown() -> void:
	cooldown_remaining = 0.0
	current_charges = max(max_charges, 0)
	_refresh_ui()


func _matches_required_tag(required_tag: RelicTag, required_tag_name: StringName) -> bool:
	if required_tag != null:
		if StringName(required_tag.tag_name) == supported_tag_name:
			return true

	if required_tag_name != &"":
		return required_tag_name == supported_tag_name

	return false


func _is_caster_in_supply_range(caster: Entity) -> bool:
	if caster == null or not is_instance_valid(caster):
		return false

	return global_position.distance_to(caster.global_position) <= max(supply_radius, 0.0)


func _refresh_ui() -> void:
	if charge_label != null:
		charge_label.text = "%s/%s" % [str(current_charges), str(max(max_charges, 0))]

	var is_cooling_down: bool = cooldown_remaining > 0.0
	if cooldown_bar != null:
		cooldown_bar.visible = is_cooling_down
		cooldown_bar.max_value = max(cooldown_duration, 0.01)
		cooldown_bar.value = cooldown_duration - cooldown_remaining

	if cooldown_label != null:
		cooldown_label.visible = is_cooling_down
		cooldown_label.text = "冷却中。。"
