class_name Player
extends Entity


@export var speed: float = 20
@export var weapon: Node2D
@export var footstep_clip: AudiioConfig
@export var footstep_interval = 0.3
@export var spell_bar: SpellBar

@export var stats_data: StatsData

#库存变量
@export var player_inventory:Inventory
@export var player_equipment:Equipment

var is_bag_open:bool = false
var is_moving:bool = false
var weapon_right:Vector2
var weapon_left:Vector2
var spawn_location:Vector2
var footstep_timer = 0.0


@onready var bag_ui: PackageUI = get_node_or_null("CanvasLayer/PackageUI") as PackageUI
@onready var ability_controller: AbilityController = $AbilityController
@onready var footstep_effect: FootstepEffect = $FootstepEffect
@onready var package_ui: PackageUI = get_node_or_null("CanvasLayer/PackageUI") as PackageUI
@onready var attributes_panel: AttributesPanel = get_node_or_null("CanvasLayer/AttributesPanel") as AttributesPanel
@onready var relic_controller: RelicController = $RelicController
@onready var skill_controller: SkillController = get_node_or_null("SkillController") as SkillController

signal player_died(player:Player)

func _ready() -> void:
	super._ready()
	add_to_group("player")
	EventBus.change_bag.connect(toggle_bag)
	weapon_right=weapon.position
	weapon_left=self.position +(self.position -weapon.position)
	spawn_location = position
	
	
	var abilities = ability_controller.abilities
	
	for ability_idx in range(abilities.size()):
		var ability = abilities[ability_idx]
		spell_bar.register_ability(ability,ability_idx)
	
	
	EventBus.play_cast_ability.connect(_handle_abilities)
	EventBus.player_health_changed.emit(current_health,max_health)
	EventBus.player_energy_changed.emit(current_energy,max_energy)
	_handle_ui(player_inventory,player_equipment)
	_refresh_spell_bar()
	#health_bar.set_health(current_health ,max_health)
	
	
	
	



func _process(delta: float) -> void:
	if is_dead: return
	if  Input.is_action_just_pressed("ability_1"):
		ability_controller.trigger_ability_by_idx(0)
	if  Input.is_action_just_pressed("ability_2"):
		ability_controller.trigger_ability_by_idx(1)
	_handle_movement(delta)
	_handle_footstep_sound(delta)
	_handle_region_energy(delta)
	_handle_animation() 
	


func _handle_ui(player_inventory:Inventory,player_equipment:Equipment):
	stats_controller.stats_data = stats_data
	if package_ui != null:
		package_ui.bag_inventory = player_inventory
		package_ui.equipment_inventory = player_equipment
	relic_controller.player = self
	relic_controller.equipment_inventory = player_equipment
	relic_controller.refresh_all()
	if skill_controller != null:
		skill_controller.run_stats = _resolve_run_stats()
	if attributes_panel != null:
		attributes_panel.stats_controller = stats_controller
		attributes_panel.setup()
	
	
func bind_player_build(player_build: PlayerBuild) -> void:
	if player_build == null:
		return

	stats_data = player_build.player_stats
	player_inventory = player_build.player_inventory
	player_equipment = player_build.player_equipment

	if stats_controller != null:
		stats_controller.bind_player_build(player_build)
		current_health = stats_controller.current_health
		current_energy = stats_controller.current_energy
		max_health = stats_controller.get_stat("max_health")
		max_energy = stats_controller.get_stat("max_energy")

	_handle_ui(player_inventory, player_equipment)
	if skill_controller != null:
		skill_controller.bind_player_build(player_build)
	_refresh_spell_bar()
	EventBus.player_health_changed.emit(current_health, max_health)
	EventBus.player_energy_changed.emit(current_energy, max_energy)
	

func _handle_abilities(ability:Ability):
	ability_controller.trigger_ability(ability)


func apply_runtime_stats(final_stats: Dictionary) -> void:
	if final_stats.has("move_speed"):
		speed = float(final_stats["move_speed"])
	EventBus.player_health_changed.emit(current_health, max_health)
	EventBus.player_energy_changed.emit(current_energy, max_energy)



func _handle_movement(delta: float):
	is_moving = false
	turning_cooldown = max(0,turning_cooldown - delta)
	var horizontal = Input.get_axis("leftmove","rightmove")
	var vertical = Input.get_axis("upmove","downmove")
	
	
	var movement = Vector2(horizontal,vertical)
	var n_movement=movement.normalized()
	
	self.position += n_movement * speed * delta
	
	if n_movement.length() > 0:
		is_moving = true
		footstep_effect.play()
		if turning_cooldown == 0:
			if horizontal >0:
				animated_sprite.flip_h = false
			elif horizontal<0:
				animated_sprite.flip_h = true

func _handle_footstep_sound(delta: float):
	if is_moving:
		footstep_timer += delta
		if footstep_timer >= footstep_interval:
			AudioController.play(footstep_clip,global_position)
			footstep_timer = 0.0
	else:
		footstep_timer = 0.0


func  _handle_animation():
	if  is_moving:
		play_animation(AnimationWrapper.new("run"))
	else:
		play_animation(AnimationWrapper.new("idle"))

func _handle_damage_callback(_damage_data: DamageData):
	EventBus.player_health_changed.emit(current_health,max_health)
	


func _on_animated_sprite_2d_animation_finished() -> void:
	if current_anim.name == "die":
		player_died.emit(self)


func spend_energy(energy:float):
	current_energy -= energy
	current_energy = clamp(current_energy,0,max_energy)
	if stats_controller != null:
		stats_controller.current_energy = current_energy
		stats_controller.sync_runtime_resources()
	EventBus.player_energy_changed.emit(current_energy,max_energy)

func _handle_region_energy(delta: float):
	if current_energy >= max_energy:
		current_energy = max_energy
		return
	energy_timer +=delta
		
	if energy_timer >= energy_region_freq:
		energy_timer = 0
		current_energy += energy_region_tick_value
		current_energy = min(current_energy,max_energy)
		if stats_controller != null:
			stats_controller.current_energy = current_energy
			stats_controller.sync_runtime_resources()
		EventBus.player_energy_changed.emit(current_energy,max_energy)
	
#切换背包函数
func toggle_bag():
	if bag_ui == null or attributes_panel == null:
		return

	if is_bag_open == true:
		bag_ui.close_bag()
		attributes_panel.close_panel()
		is_bag_open = false	
	elif is_bag_open == false:
		bag_ui.open_bag(player_inventory,player_equipment)
		attributes_panel.open_panel()
		is_bag_open = true


func _resolve_run_stats() -> RunStats:
	var node := get_parent()
	while node != null:
		if "run_stats" in node:
			return node.run_stats
		node = node.get_parent()

	return null


func _refresh_spell_bar() -> void:
	if spell_bar == null or ability_controller == null:
		return

	spell_bar.refresh_from_controller(ability_controller)
