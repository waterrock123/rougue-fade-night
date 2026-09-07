class_name BattleEndPoint
extends MapObject

## 玩家触碰后提前结束本场战斗的地图物体。
## 它只发出“请求”，实际结算仍由 PlayScene 统一处理，避免跳过回血、结算效果和转场。

@export_group("结束点设置")
## true 时触碰后直接进入修整期；false 时走普通的升级奖励流程。
@export var skip_level_up: bool = false
## 触碰后是否关闭检测。通常保持开启，避免同一帧重复发出结束请求。
@export var consume_on_trigger: bool = true
## 触碰范围使用的物理层掩码。默认同时检测玩家根节点和玩家 Area2D。
@export_flags_2d_physics var trigger_collision_mask: int = 3
@export var trigger_area_path: NodePath = NodePath("TriggerArea")

@export_group("提示")
@export var show_screen_tip: bool = true
@export var screen_tip: String = "已抵达结束点，战斗即将结束。"

@onready var trigger_area: Area2D = get_node_or_null(trigger_area_path) as Area2D

var triggered: bool = false


func _ready() -> void:
	# 结束点不是可攻击目标，也不应阻挡角色移动，只负责提供触碰区域。
	targetable_by_player_side = false
	targetable_by_enemy_side = false
	blocks_navigation = false
	add_to_group("battle_end_point")
	super._ready()

	if trigger_area == null:
		push_warning("BattleEndPoint 缺少触碰区域：%s" % get_path())
		return

	trigger_area.collision_mask = trigger_collision_mask
	if not trigger_area.body_entered.is_connected(_on_trigger_body_entered):
		trigger_area.body_entered.connect(_on_trigger_body_entered)
	if not trigger_area.area_entered.is_connected(_on_trigger_area_entered):
		trigger_area.area_entered.connect(_on_trigger_area_entered)


func _exit_tree() -> void:
	if trigger_area != null:
		if trigger_area.body_entered.is_connected(_on_trigger_body_entered):
			trigger_area.body_entered.disconnect(_on_trigger_body_entered)
		if trigger_area.area_entered.is_connected(_on_trigger_area_entered):
			trigger_area.area_entered.disconnect(_on_trigger_area_entered)
	super._exit_tree()


func _on_trigger_body_entered(body: Node2D) -> void:
	_try_trigger_from_node(body)


func _on_trigger_area_entered(area: Area2D) -> void:
	_try_trigger_from_node(area)


## Area2D 和 CharacterBody2D 都可能代表玩家，因此统一向父节点查找 Player。
func _try_trigger_from_node(source_node: Node) -> void:
	if triggered:
		return

	var player_entity: Entity = _find_player_entity(source_node)
	if player_entity == null or player_entity.is_dead:
		return

	triggered = true
	_request_battle_end.call_deferred(player_entity)


func _request_battle_end(player_entity: Entity) -> void:
	if player_entity == null or not is_instance_valid(player_entity) or player_entity.is_dead:
		triggered = false
		return
	if EventBus == null or not EventBus.is_battle_active:
		triggered = false
		return

	if consume_on_trigger and trigger_area != null:
		trigger_area.set_deferred("monitoring", false)

	if show_screen_tip and not screen_tip.is_empty() and FloatText != null:
		FloatText.show_screen_tip(screen_tip)

	# 由 PlayScene 监听并执行完整的战斗结束流程。
	EventBus.battle_end_requested.emit(self, skip_level_up)


func _find_player_entity(source_node: Node) -> Entity:
	var current_node: Node = source_node
	while current_node != null:
		if current_node is Entity and current_node.is_in_group("player"):
			return current_node as Entity
		current_node = current_node.get_parent()

	return null
