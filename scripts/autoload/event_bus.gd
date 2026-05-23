
extends Node

#施法信号
signal play_cast_ability(ability: Ability)
#玩家生命值变化信号
signal player_health_changed(current_health: float,max_health:float)
#玩家能量变化信号
signal player_energy_changed(current_energy: float,max_energy:float)
#游戏暂停信号
signal game_paused(paused: bool)
#场景变更信号
signal  scene_changed(scene: String)
#战斗胜利信号
signal battle_win()
# 战斗正式开始信号。PlayScene 初始化完玩家、装备和 UI 后发出，供“进场触发”的遗物/被动使用。
signal battle_started()
# 敌人死亡归属信号。用于击杀奖励类效果，不让具体遗物去扫描敌人节点。
signal enemy_killed(enemy: Entity, killer: Entity)
# 战斗胜利结算信号。会在切换升级/修整场景前触发，供被动技能处理吞噬装备、升级装备等局内结算。
signal battle_rewards_resolving()
#战斗失败信号
signal battle_lost()
#打开背包信号 
signal change_bag()
#背包库存更新信号，背包库存数据发生变化时，发送这个信号，通知UI同步更新
signal inventory_update()
#装备更新信号，当装备栏数据发生变化时，发送这个信号，通知UI同步更新
signal equipment_update()
#商店库存更新信号，商店库存数据发生变化时，发送这个信号，通知UI同步更新
signal shop_inventory_update()
#玩家属性发生变更信号，发送这个信号，通知属性面板UI同步更新
signal attribute_update() 
#金币变化信号，发送这个信号通知UI同步更新
signal gold_changed()
#装备购买信号,传递这个装备
signal buy_equipment(equipment:Relic)
# 商店真正把遗物放进背包前发出，允许套装效果先修改本次购买的遗物。
signal relic_purchase_preprocess(relic: Relic)
# 商店购买完成后发出，适合返利、老板对话、购买计数这类“已成交”效果。
signal relic_purchased(relic: Relic)
# 玩家出售遗物后通知 UI/商店老板播放对应反馈。
signal relic_sold(relic: Relic)
# 遗物被使用、售卖或销毁时发出，reason 用于区分 "used" / "sold" / "destroyed"。
# 注意："used" 表示触发了使用行为，不一定代表物品已经被移除。
signal relic_removed(relic: Relic, reason: String)
# 战斗中使用消耗品后发出，给消耗品套装、被动技能等做触发点。
signal consumable_used(relic: Relic, user: Entity)
# 遗物合成升级信号。只在“多件未升级同 id 遗物合成”时发出，用来发放免费三选一机会。
signal relic_merged_to_levelup(upgraded_relic: Relic)
# 免费遗物三选一机会变化信号，商店 UI 用它切入/继续奖励选择。
signal free_relic_choice_changed()
# 升级奖励刷新次数变化信号，升级奖励界面用它刷新按钮状态。
signal level_up_reward_refresh_changed()
# 商店免费刷新次数变化信号，商店 UI 用它刷新价格与次数显示。
signal shop_free_refresh_changed()
# 进入修整期并初始化商店 UI 后发出，供“本次修整期开始”类套装效果重置计数或改造商店。
signal rest_period_started()


#退出地图信号，进入传入的房间的场景
signal map_exited(room: Room)
#离开事件房间信号，进入战斗
signal event_room_exited()
