class_name StatsController
extends Node

@export var base_stats: Stats   # 配置数据

var final_stats = {}            # 计算后的属性
var modifiers: Array = []       # 装备 / 遗物 / buff

var current_health: float
var current_energy: float


func _ready():
	# 防止 Resource 被共享（关键！）
	base_stats = base_stats.duplicate()

	compute_stats()

	current_health = final_stats.max_health
	current_energy = final_stats.max_energy


func add_modifier(mod):
	modifiers.append(mod)
	compute_stats()


#应用修饰器
func apply_modifier(final, mod):
	if not final.has(mod.stat):
		return

	if mod.type == "flat":
		final[mod.stat] += mod.value
	elif mod.type == "percent":
		final[mod.stat] *= (1 + mod.value)



#计算属性
func compute_stats():
	var s = base_stats
	var final = {}
	
	# 一级 → 基础
	final.max_health = 2 +s.constitution * 5
	final.max_energy = 5 + s.intelligence * 3

	final.move_speed = 100 + s.speed * 10
	
	final.crit_chance = s.critical_chance + s.luck * 0.002
	final.crit_damage = s.critical_rate
	
	final.dodge_rate = s.dodge_rate + s.speed * 0.001
	
	final.damage_reduction = s.damage_reduction_rate

	# 👉 modifiers（装备/遗物）
	if modifiers!= null:
		for mod in modifiers:
		
			apply_modifier(final, mod)

	final_stats = final
