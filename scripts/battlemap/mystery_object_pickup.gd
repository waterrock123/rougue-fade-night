class_name MysteryObjectPickup
extends MapPickup

## 谜之物体：拾取后随机改变一项一级属性，持续到本场战斗结束。
## 这里用动态 StatusData 承载临时属性变化，离开战斗场景后状态自然消失，不会污染 PlayerBuild 永久属性。

const DEFAULT_PRIMARY_STATS: Array[StringName] = [
	&"strength",
	&"dexterity",
	&"intelligence",
	&"constitution",
	&"speed",
	&"charm",
	&"luck",
]

@export var stat_change_min: int = -4
@export var stat_change_max: int = 2
@export var candidate_stats: Array[StringName] = DEFAULT_PRIMARY_STATS
@export var status_duration: float = -1.0


func _ready() -> void:
	if pickup_display_name.is_empty():
		pickup_display_name = "谜之物体"
	super._ready()


func _apply_pickup(collector: Entity) -> void:
	if collector == null or collector.is_dead:
		return

	var status_controller: StatusController = collector.get_status_controller()
	if status_controller == null:
		show_collected_tip("没有发生变化")
		return

	var stat_name: StringName = _pick_stat()
	if stat_name == &"":
		show_collected_tip("没有发生变化")
		return

	var amount: int = _roll_stat_amount()
	if amount == 0:
		show_collected_tip("%s 没有发生变化" % _get_stat_display_name(stat_name))
		return

	var status_data: StatusData = _build_temporary_stat_status(stat_name, amount)
	status_controller.add_status(status_data, self, status_data.id, 1, status_duration)
	show_collected_tip("%s %s，持续到本场战斗结束" % [_get_stat_display_name(stat_name), _format_signed_amount(amount)])


func _pick_stat() -> StringName:
	var valid_stats: Array[StringName] = []
	for stat_name: StringName in candidate_stats:
		if stat_name != &"":
			valid_stats.append(stat_name)

	if valid_stats.is_empty():
		return &""

	var index: int = randi_range(0, valid_stats.size() - 1)
	return valid_stats[index]


func _roll_stat_amount() -> int:
	var safe_min: int = min(stat_change_min, stat_change_max)
	var safe_max: int = max(stat_change_min, stat_change_max)
	return randi_range(safe_min, safe_max)


func _build_temporary_stat_status(stat_name: StringName, amount: int) -> StatusData:
	var stat_effect: StatusAddStatEffect = StatusAddStatEffect.new()
	stat_effect.stat_name = stat_name
	stat_effect.value_per_stack = float(amount)
	stat_effect.modifier_type = Modifier.ModifierType.FLAT

	var effects: Array[StatusEffect] = []
	effects.append(stat_effect)

	var status_data: StatusData = StatusData.new()
	status_data.id = StringName("mystery_object_%s_%s_%s" % [String(stat_name), str(get_instance_id()), str(Time.get_ticks_msec())])
	status_data.status_name = "谜之物体：%s %s" % [_get_stat_display_name(stat_name), _format_signed_amount(amount)]
	status_data.desc = "谜之物体造成的临时属性变化，持续到本场战斗结束。"
	status_data.duration = status_duration
	status_data.max_stacks = 1
	status_data.stack_mode = StatusData.StackMode.REPLACE
	status_data.effects = effects
	return status_data


func _format_signed_amount(amount: int) -> String:
	if amount > 0:
		return "+%s" % str(amount)
	return str(amount)


func _get_stat_display_name(stat_name: StringName) -> String:
	match stat_name:
		&"strength":
			return "力量"
		&"dexterity":
			return "敏捷"
		&"intelligence":
			return "智力"
		&"constitution":
			return "体质"
		&"speed":
			return "速度"
		&"charm":
			return "魅力"
		&"luck":
			return "幸运"
		_:
			return String(stat_name)
