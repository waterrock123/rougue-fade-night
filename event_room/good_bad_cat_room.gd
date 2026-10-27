class_name GoodBadCatRoom
extends RelicRewardEventRoom

const JOY_RELIC: Relic = preload("res://relics/special/207_自然的喜悦.tres")
const GLOOM_RELIC: Relic = preload("res://relics/special/208_不散的郁闷.tres")
const INSIGHT_TAG_NAME: String = "洞察"
const CHARM_REQUIREMENT: float = 10.0

@onready var pet_button: EventRoomButton = $PetButton
@onready var observe_button: EventRoomButton = $ObserveButton
@onready var charm_button: EventRoomButton = $CharmButton

var is_good_cat: bool = false
var observed: bool = false


func setup() -> void:
	is_good_cat = _make_room_rng(207).randf() < 0.5
	pet_button.setup_button(_pet_cat)
	observe_button.setup_button(_observe_cat)
	charm_button.setup_button(_charm_cat)
	observe_button.disabled = not _has_inventory_tag(INSIGHT_TAG_NAME)
	charm_button.disabled = _get_current_stat(&"charm") < CHARM_REQUIREMENT
	if observe_button.disabled:
		observe_button.detail_text = "需要背包中有带洞察标签的装备：判断猫咪的性格"
		observe_button.refresh_display()
	if charm_button.disabled:
		charm_button.detail_text = "需要魅力至少10点：使猫咪变为好猫并获得自然的喜悦"
		charm_button.refresh_display()


func _pet_cat() -> void:
	var reward: Relic = JOY_RELIC if is_good_cat else GLOOM_RELIC
	if not _grant_special_relic(reward):
		return
	_finish_choice(pet_button, 0 if is_good_cat else 1, [pet_button, observe_button, charm_button])


func _observe_cat() -> void:
	if observed or not _has_inventory_tag(INSIGHT_TAG_NAME):
		return
	observed = true
	desc_label.text = observe_button.get_pressed_desc(0 if is_good_cat else 1)
	observe_button.disabled = true
	pet_button.detail_text = "已确认是%s；抚摸后获得%s" % ["好猫" if is_good_cat else "坏猫", "自然的喜悦" if is_good_cat else "不散的郁闷"]
	pet_button.refresh_display()
	# 观察不会结束事件，玩家仍可决定是否抚摸，或直接离开。


func _charm_cat() -> void:
	if _get_current_stat(&"charm") < CHARM_REQUIREMENT:
		return
	if not _grant_special_relic(JOY_RELIC):
		return
	_finish_choice(charm_button, 0, [pet_button, observe_button, charm_button])


func _has_inventory_tag(tag_name: String) -> bool:
	if run_stats == null or run_stats.player_build == null or run_stats.player_build.player_inventory == null:
		return false
	for slot: Slot in run_stats.player_build.player_inventory.slots:
		if slot == null or slot.item == null:
			continue
		for tag: RelicTag in slot.item.tags:
			if tag != null and tag.tag_name == tag_name:
				return true
	return false
