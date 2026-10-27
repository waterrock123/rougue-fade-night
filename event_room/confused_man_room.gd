## 迷茫之人：奖励和招募互斥，追问后才显示邀请选项。
extends RelicRewardEventRoom

const RELIC_POOL: RelicPool = preload("res://relic_pools/all_relic_pool.tres")

@onready var skill_button: EventRoomButton = $SkillButton
@onready var relic_button: EventRoomButton = $RelicButton
@onready var ask_button: EventRoomButton = $AskButton
@onready var invite_button: EventRoomButton = $InviteButton
var skill_candidates: Array[ActiveSkillData] = []
var relic_candidates: Array[Relic] = []
var choice_resolved: bool = false


func setup() -> void:
	skill_button.setup_button(_choose_skill)
	relic_button.setup_button(_choose_relic)
	ask_button.setup_button(_ask_about_power)
	invite_button.setup_button(_invite)
	invite_button.hide()
	_collect_skills("res://activate_skill")
	for relic: Relic in RELIC_POOL.get_relics_up_to_level(6):
		if relic.level >= 3:
			relic_candidates.append(relic)
	skill_button.disabled = skill_candidates.is_empty()
	relic_button.disabled = relic_candidates.is_empty()


## 沿用角色归属、技能分支和持有上限，不抽到基础攻击或已有技能。
func _collect_skills(folder: String) -> void:
	for file: String in DirAccess.get_files_at(folder):
		if not file.ends_with(".tres"):
			continue
		var skill: ActiveSkillData = load(folder.path_join(file)) as ActiveSkillData
		if skill == null or skill.is_basic_attack or skill.is_upgrade_skill or skill.ability_scene == null:
			continue
		var build: PlayerBuild = run_stats.player_build
		if skill.is_available_for_character(run_stats.picked_character) and build.can_add_active_skill(skill) and build.find_active_skill_entry(skill.id) == null:
			skill_candidates.append(skill)
	for directory: String in DirAccess.get_directories_at(folder):
		_collect_skills(folder.path_join(directory))


func _choose_skill() -> void:
	if choice_resolved or skill_candidates.is_empty():
		return
	var rng: RandomNumberGenerator = _make_room_rng(301)
	var skill: ActiveSkillData = skill_candidates[rng.randi_range(0, skill_candidates.size() - 1)]
	if run_stats.player_build.grant_active_skill(skill) == null:
		return
	EventBus.skill_loadout_changed.emit()
	_resolve(skill_button)
	desc_label.text += "\n获得技能：%s。" % skill.skill_name


func _choose_relic() -> void:
	if choice_resolved or relic_candidates.is_empty():
		return
	var rng: RandomNumberGenerator = _make_room_rng(302)
	var relic: Relic = relic_candidates[rng.randi_range(0, relic_candidates.size() - 1)]
	if _grant_special_relic(relic):
		_resolve(relic_button)
		desc_label.text += "\n获得装备：%s。" % relic.relic_name


func _ask_about_power() -> void:
	if choice_resolved:
		return
	desc_label.text = ask_button.get_pressed_desc(0)
	skill_button.hide()
	relic_button.hide()
	ask_button.hide()
	invite_button.show()
	invite_button.disabled = ProfileManager.has_completed_event(&"invited_zhang_san")
	if invite_button.disabled:
		desc_label.text += "\n张三已经加入你的家园。"


func _invite() -> void:
	if not choice_resolved and ProfileManager.try_complete_event(&"invited_zhang_san"):
		_resolve(invite_button)


func _resolve(button: EventRoomButton) -> void:
	choice_resolved = true
	_finish_choice(button, 0, [skill_button, relic_button, ask_button, invite_button])
