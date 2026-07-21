## 遗物效果：累计释放主动技能，达到次数后触发自伤与临时状态。
## 适合“每释放 N 次技能触发一次副作用/增益”的装备，例如激励项圈。
class_name AbilityCastCountSelfDamageStatusEffect
extends RelicEffect

const DEFAULT_PRIMARY_STATS: Array[StringName] = [
	&"strength",
	&"dexterity",
	&"intelligence",
	&"constitution",
	&"speed",
	&"charm",
	&"luck",
]

## 每释放多少次主动技能触发一次效果。
@export var casts_per_trigger: int = 4
## 触发时对自己造成的基础伤害。
@export var self_damage: float = 5.0
## 自伤的伤害类型。激励项圈默认是闪电伤害。
@export var damage_types: Array[int] = [DamageData.DamageType.LIGHTNING]
## 自伤标签，方便其他效果识别这次伤害的来源。
@export var damage_tags: Array[String] = ["relic", "self_damage", "inspiration_collar"]
## 是否允许这次自伤暴击。自伤通常不应暴击，所以默认关闭。
@export var self_damage_can_crit: bool = false

@export_group("Temporary Buff")
## 临时提升的一级属性列表。默认等于“全属性”。
@export var buff_primary_stats: Array[StringName] = DEFAULT_PRIMARY_STATS
## 每个属性提升多少。激励项圈默认全属性 +1。
@export var stat_bonus: float = 1.0
## 临时状态持续时间。
@export var buff_duration: float = 10.0
@export var buff_status_name: String = "激励"
@export_multiline var buff_status_desc: String = "在激励项圈的刺激下，全属性暂时提升。"
@export var buff_status_icon: Texture2D

var active_records: Dictionary = {}


## 装备生效时开始监听持有者的主动技能释放信号。
func on_activate(relic_context: RelicContext, effect_key) -> void:
	var owner: Entity = _get_owner_entity(relic_context)
	if owner == null:
		return
	if active_records.has(str(effect_key)):
		return

	var ability_controller: AbilityController = owner.get_node_or_null("AbilityController") as AbilityController
	if ability_controller == null:
		return

	var record_key: String = str(effect_key)
	var callback: Callable = Callable(self, "_on_ability_triggered").bind(owner, relic_context, record_key)
	if not ability_controller.ability_triggered.is_connected(callback):
		ability_controller.ability_triggered.connect(callback)

	active_records[record_key] = {
		"controller": ability_controller,
		"callback": callback,
		"owner": owner,
		"cast_count": 0,
		"buff_status_id": _build_buff_status_id(record_key),
	}


## 装备失效时断开监听，并清理这件装备提供的临时状态。
func on_deactivate(relic_context: RelicContext, effect_key) -> void:
	var record_key: String = str(effect_key)
	var record = active_records.get(record_key)
	if not (record is Dictionary):
		return

	var ability_controller: AbilityController = record.get("controller") as AbilityController
	var callback: Callable = record.get("callback")
	if ability_controller != null and is_instance_valid(ability_controller) and ability_controller.ability_triggered.is_connected(callback):
		ability_controller.ability_triggered.disconnect(callback)

	var owner: Entity = record.get("owner") as Entity
	if owner == null:
		owner = _get_owner_entity(relic_context)
	_remove_buff_from_owner(owner, record_key, record.get("buff_status_id", &""))
	active_records.erase(record_key)


func _on_ability_triggered(_ability: Ability, caster: Entity, owner: Entity, relic_context: RelicContext, record_key: String) -> void:
	if owner == null or not is_instance_valid(owner) or owner.is_dead:
		active_records.erase(record_key)
		return
	if caster != owner:
		return

	var record = active_records.get(record_key)
	if not (record is Dictionary):
		return

	var trigger_threshold: int = max(casts_per_trigger, 1)
	var cast_count: int = int(record.get("cast_count", 0)) + 1
	if cast_count < trigger_threshold:
		record["cast_count"] = cast_count
		active_records[record_key] = record
		return

	record["cast_count"] = 0
	active_records[record_key] = record
	_apply_self_damage(owner)
	if owner.is_dead:
		return
	_apply_temporary_buff(owner, relic_context, record_key)


func _apply_self_damage(owner: Entity) -> void:
	if owner == null or self_damage <= 0.0:
		return

	# 走统一伤害链路，让闪避、减伤、伤害数字以及其他“受到闪电伤害”联动都能自然生效。
	var damage_data: DamageData = DamageData.create(
		self_damage,
		damage_types,
		damage_tags,
		owner,
		owner,
		self_damage_can_crit
	)
	owner.apply_damage(damage_data)


func _apply_temporary_buff(owner: Entity, relic_context: RelicContext, record_key: String) -> void:
	var status_controller: StatusController = owner.get_status_controller()
	if status_controller == null:
		return

	var status_data: StatusData = _build_buff_status_data(relic_context, record_key)
	status_controller.add_status(status_data, owner, record_key, 1, buff_duration)


func _build_buff_status_data(relic_context: RelicContext, record_key: String) -> StatusData:
	var status_data: StatusData = StatusData.new()
	status_data.id = _build_buff_status_id(record_key)
	status_data.status_name = buff_status_name
	status_data.desc = buff_status_desc
	status_data.icon = _get_buff_icon(relic_context)
	status_data.duration = buff_duration
	status_data.max_stacks = 1
	status_data.stack_mode = StatusData.StackMode.REFRESH
	status_data.refresh_duration_on_reapply = true

	var stat_values: Dictionary = {}
	for stat_name in buff_primary_stats:
		stat_values[stat_name] = stat_bonus

	var stat_effect: StatusAddStatsEffect = StatusAddStatsEffect.new()
	stat_effect.stat_values = stat_values

	var effects: Array[StatusEffect] = []
	effects.append(stat_effect)
	status_data.effects = effects
	return status_data


func _remove_buff_from_owner(owner: Entity, record_key: String, status_id_value) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var status_controller: StatusController = owner.get_status_controller()
	if status_controller == null:
		return

	var status_id: StringName = StringName(str(status_id_value))
	if status_id == &"":
		status_id = _build_buff_status_id(record_key)
	status_controller.remove_status_source(status_id, record_key)


func _build_buff_status_id(record_key: String) -> StringName:
	return StringName("%s_inspiration" % record_key)


func _get_buff_icon(relic_context: RelicContext) -> Texture2D:
	if buff_status_icon != null:
		return buff_status_icon
	if relic_context != null and relic_context.own_relic != null:
		return relic_context.own_relic.icon as Texture2D
	return null


func _get_owner_entity(relic_context: RelicContext) -> Entity:
	if relic_context == null or not (relic_context.owner is Entity):
		return null
	return relic_context.owner as Entity
