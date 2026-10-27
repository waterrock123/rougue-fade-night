class_name LakeSwordRoom
extends RelicRewardEventRoom

const SWORD_RELIC: Relic = preload("res://relics/special/205_命定之剑.tres")
const DISAPPOINTMENT_RELIC: Relic = preload("res://relics/special/204_略微的失望.tres")
const HAMMER_RELIC: Relic = preload("res://relics/special/206_命定的石锤？.tres")
const PULL_SUCCESS_CHANCE: float = 0.35
const LUCK_PER_BONUS_DIE: int = 3
const STRENGTH_REQUIREMENT: float = 20.0

@onready var pull_button: EventRoomButton = $PullButton
@onready var platform_button: EventRoomButton = $PlatformButton


func setup() -> void:
	pull_button.setup_button(_try_pull_sword)
	platform_button.setup_button(_take_platform)
	platform_button.disabled = _get_current_stat(&"strength") < STRENGTH_REQUIREMENT
	if platform_button.disabled:
		platform_button.detail_text = "需要力量至少20点：获得命定的石锤？"
		platform_button.refresh_display()


func _try_pull_sword() -> void:
	# 幸运每3点多判定一次，只要其中一次成功，就采用拔剑成功的结果。
	var rng: RandomNumberGenerator = _make_room_rng(205)
	var bonus_dice: int = maxi(int(floor(_get_current_stat(&"luck") / float(LUCK_PER_BONUS_DIE))), 0)
	var success: bool = false
	for roll_index: int in range(1 + bonus_dice):
		if rng.randf() < PULL_SUCCESS_CHANCE:
			success = true
			break
	var reward: Relic = SWORD_RELIC if success else DISAPPOINTMENT_RELIC
	if not _grant_special_relic(reward):
		return
	_finish_choice(pull_button, 0 if success else 1, [pull_button, platform_button])


func _take_platform() -> void:
	if _get_current_stat(&"strength") < STRENGTH_REQUIREMENT:
		return
	if not _grant_special_relic(HAMMER_RELIC):
		return
	_finish_choice(platform_button, 0, [pull_button, platform_button])
