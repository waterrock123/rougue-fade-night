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
var has_movement_input: bool = false
var weapon_right:Vector2
var weapon_left:Vector2
var spawn_location:Vector2
var footstep_timer = 0.0
var character: Character
var character_visual_data: CharacterVisualData


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
	# Player 没有 Enemy 那样的移动锁计时循环，这里统一推进它，供持续施法、前摇等组件使用。
	movement_lock_timer = maxf(movement_lock_timer - delta, 0.0)
	if not can_act():
		is_moving = false
		clear_terrain_motion_velocity()
		footstep_effect.stop()
		footstep_timer = 0.0
		return
	_handle_ability_input()
	_handle_movement(delta)
	_handle_footstep_sound(delta)
	_handle_region_energy(delta)
	_handle_animation() 
	

func _handle_ability_input() -> void:
	# ability_1 永远对应技能槽 1，ability_2 对应技能槽 2，以此类推。
	# 一个 action 可以绑定多个按键，例如 ability_1 同时绑定鼠标左键和键盘 1。
	var action_number := 1
	while true:
		var action_name := StringName("ability_%s" % str(action_number))
		if not InputMap.has_action(action_name):
			break

		var ability_index := action_number - 1
		_handle_ability_action(action_name, ability_index)
		action_number += 1

func _handle_ability_action(action_name: StringName, ability_index: int) -> void:
	if Input.is_action_just_pressed(action_name):
		ability_controller.begin_ability_preview_by_idx(ability_index)
	# 第一个技能槽固定为基础攻击。按住时会持续尝试释放，实际频率仍由技能冷却控制。
	elif ability_index == 0 and Input.is_action_pressed(action_name):
		ability_controller.trigger_held_ability_by_idx(ability_index)
	if Input.is_action_just_released(action_name):
		ability_controller.release_ability_preview_by_idx(ability_index)


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
	
	
func bind_player_build(player_build: PlayerBuild, new_character: Character = null) -> void:
	if player_build == null:
		return

	if new_character != null:
		bind_character(new_character)

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


## 绑定当前角色，并把角色视觉资源应用到玩家的 AnimatedSprite2D。
## 属性、背包和技能仍由 PlayerBuild 管理，视觉只从 Character 读取。
func bind_character(new_character: Character) -> void:
	character = new_character
	character_visual_data = new_character.visual_data if new_character != null else null
	if character_visual_data == null or animated_sprite == null:
		return

	if character_visual_data.sprite_frames != null:
		animated_sprite.sprite_frames = character_visual_data.sprite_frames
	animated_sprite.scale = character_visual_data.visual_scale
	animated_sprite.position = character_visual_data.visual_offset
	animated_sprite.flip_h = character_visual_data.default_facing_left

	var default_animation: StringName = character_visual_data.default_animation
	if character_visual_data.has_animation(default_animation):
		animated_sprite.play(default_animation)
	elif character_visual_data.has_animation(&"idle"):
		animated_sprite.play(&"idle")
	

func _handle_abilities(ability:Ability):
	ability_controller.trigger_ability(ability)


func apply_runtime_stats(final_stats: Dictionary) -> void:
	if final_stats.has("move_speed"):
		speed = float(final_stats["move_speed"])
	EventBus.player_health_changed.emit(current_health, max_health)
	EventBus.player_energy_changed.emit(current_energy, max_energy)



func _handle_movement(delta: float):
	is_moving = false
	has_movement_input = false
	# 移动锁只禁止玩家自主输入；击退、冲刺等会走 move_direct_with_physics，不受这里影响。
	if is_movement_locked():
		clear_terrain_motion_velocity()
		footstep_effect.stop()
		return
	turning_cooldown = max(0,turning_cooldown - delta)
	var horizontal = Input.get_axis("leftmove","rightmove")
	var vertical = Input.get_axis("upmove","downmove")
	
	
	var movement = Vector2(horizontal,vertical)
	var n_movement=movement.normalized()
	has_movement_input = movement.length_squared() > 0.0001
	
	var actual_movement: Vector2 = move_with_physics(n_movement * speed * delta)
	
	if actual_movement.length() > 0:
		is_moving = true
		if has_movement_input:
			footstep_effect.play()
		else:
			footstep_effect.stop()
		if turning_cooldown == 0:
			if horizontal > 0:
				animated_sprite.flip_h = _get_flip_h_for_direction(false)
			elif horizontal < 0:
				animated_sprite.flip_h = _get_flip_h_for_direction(true)
	else:
		footstep_effect.stop()

func _handle_footstep_sound(delta: float):
	if is_moving and has_movement_input:
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


## 根据角色原图默认朝向，把“向左/向右”转换成 AnimatedSprite2D.flip_h。
func _get_flip_h_for_direction(moving_left: bool) -> bool:
	if character_visual_data == null:
		return moving_left
	return not character_visual_data.default_facing_left if moving_left else character_visual_data.default_facing_left

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
