class_name RelicContext
extends RefCounted

var own_relic:Relic
# 遗物效果的拥有者可能是战斗中的 Player，也可能是修整期里的 PlayerBuildProxy。
var owner:Node
var relic_controller: RelicController
var relic_key: String
var effect_list: Array[RelicEffect]
var effect_group: String
var action: String

func _init(_own_relic:Relic,
	_owner:Node,
	_relic_controller: RelicController,
	_relic_key: String,
	_effect_list: Array[RelicEffect],
	_effect_group: String,
	_action: String):
	self.own_relic = _own_relic
	self.owner = _owner
	self.relic_controller = _relic_controller
	self.relic_key = _relic_key
	self.effect_list = _effect_list
	self.effect_group = _effect_group
	self.action = _action
		
	
	
