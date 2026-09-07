class_name TemporaryEnergyPickup
extends MapPickup

## 临时蓝星：拾取后恢复当前实体能量。
## Entity 目前没有统一 apply_energy，所以这里负责同步 StatsController 与玩家能量 UI。

@export var energy_amount: float = 5.0
@export var show_energy_text: bool = true
@export var energy_text_color: Color = Color(0.48, 0.78, 1.0, 1.0)


func _ready() -> void:
	if pickup_display_name.is_empty():
		pickup_display_name = "临时蓝星"
	super._ready()


func _apply_pickup(collector: Entity) -> void:
	if collector == null or collector.is_dead:
		return

	var max_energy_value: float = _get_max_energy(collector)
	if max_energy_value <= 0.0:
		show_collected_tip("没有可恢复的能量")
		return

	var previous_energy: float = collector.current_energy
	collector.current_energy = min(collector.current_energy + energy_amount, max_energy_value)
	var actual_energy: float = max(collector.current_energy - previous_energy, 0.0)

	_sync_energy_to_runtime(collector, max_energy_value)
	if show_energy_text and actual_energy > 0.0:
		_show_energy_popup(collector, actual_energy)

	if actual_energy > 0.0:
		show_collected_tip("恢复了 %s 点能量" % str(int(actual_energy)))
	else:
		show_collected_tip("能量已满")


func _get_max_energy(collector: Entity) -> float:
	if collector.stats_controller != null:
		return collector.stats_controller.get_stat(&"max_energy", collector.max_energy)
	return collector.max_energy


func _sync_energy_to_runtime(collector: Entity, max_energy_value: float) -> void:
	if collector.stats_controller != null:
		collector.stats_controller.current_energy = collector.current_energy
		collector.stats_controller.sync_runtime_resources()

	if collector.is_in_group("player"):
		EventBus.player_energy_changed.emit(collector.current_energy, max_energy_value)


func _show_energy_popup(collector: Entity, actual_energy: float) -> void:
	if FloatText == null or not FloatText.has_method("show_damage_text"):
		return

	var spawn_position: Vector2 = collector.global_position + Vector2(0.0, -collector.get_height() * 0.5)
	FloatText.show_damage_text("+%s" % str(int(actual_energy)), spawn_position, energy_text_color)
