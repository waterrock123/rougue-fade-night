class_name Stats
extends Resource

@export_group("简介")
@export var entity_name:String


@export_group("基础属性")
#最大生命值
var max_health 
#最大能量
var max_energy 
#能量恢复量
var energy_regen_tick_value
#减伤率 
var damage_reduction_rate :float
#强韧，固定伤害减免
var static_damage_reduction:int 
#闪避率
var dodge_rate: float
#暴击率
var critical_chance :float
#暴击伤害
var critical_rate :float
#冷却缩减
var cooldown_reduction 
#移动速度
var move_speed 

@export_group("一级属性")
#力量：影响近战基础攻击与近战技能的效果
@export var strength = 5
#敏捷：影响远程基础攻击与远程技能的效果
@export var dexterity = 5
#智力：影响最大法力值与法力值恢复
@export var intelligence = 5
#体质：影响最大生命值与战后生命恢复
@export var constitution = 5
#速度：影响玩家的冷却缩减以及闪避率
@export var speed = 5
#魅力：影响经验值获得，且达到30后商店所有商品降价1元
@export var charm = 5
#幸运：影响各种概率事件，商店刷新物品的稀有度出率
@export var luck = 5
