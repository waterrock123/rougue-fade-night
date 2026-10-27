class_name BigDogRoom
extends EventRoom

const EVENT_BUTTON_GROUP := "big_dog_room_event_buttons"
const BIG_DOG_ENEMY_SCENE: PackedScene = preload("res://entity/enemy/big_dog.tscn")
const BIG_DOG_BRAND: Relic = preload("res://relics/special/203_大狗的烙印.tres")
const BACKGROUND_SILENT: Texture2D = preload("res://assets/ai art/事件背景/大狗/大狗不叫.png")
const BACKGROUND_SMILE: Texture2D = preload("res://assets/ai art/事件背景/大狗/大狗笑.png")
const BACKGROUND_BARK: Texture2D = preload("res://assets/ai art/事件背景/大狗/大狗叫.png")
const BACKGROUND_LOUD_BARK: Texture2D = preload("res://assets/ai art/事件背景/大狗/大狗大叫.png")
const SOUND_BIG_DOG_PATH := "res://assets/Sound/大狗叫自用音效 - 大狗.mp3"
const SOUND_BARK_PATH := "res://assets/Sound/大狗叫自用音效 - 叫.mp3"

@export var bounty_gold: int = 8
@export_range(0.1, 1.0, 0.05) var neutral_speed_multiplier: float = 0.45

@onready var background: TextureRect = $Background
@onready var desc_label: Label = $DescLabel
@onready var dog_button: EventRoomButton = $DogButton
@onready var double_dog_button: EventRoomButton = $DoubleDogButton
@onready var bark_button: EventRoomButton = $BarkButton

var challenge_choice_count: int = 0


func setup() -> void:
	background.texture = BACKGROUND_SILENT
	_setup_event_button(dog_button, _on_challenge_chosen.bind(dog_button))
	_setup_event_button(double_dog_button, _on_challenge_chosen.bind(double_dog_button))
	_setup_event_button(bark_button, _on_bark_reward_chosen)
	_refresh_reward_description()


func _setup_event_button(button: EventRoomButton, callback: Callable) -> void:
	if button == null:
		return
	button.add_to_group(EVENT_BUTTON_GROUP)
	button.setup_button(callback)


# 前两个选项可以分别选择一次；每选择一次，就为下一场战斗排入一只特殊悬赏大狗。
func _on_challenge_chosen(button: EventRoomButton) -> void:
	if button == null or not is_instance_valid(button) or button.disabled:
		return

	button.disabled = true
	if run_stats != null:
		run_stats.queue_bounty_enemy_for_next_battle(
			BIG_DOG_ENEMY_SCENE,
			1,
			bounty_gold,
			true,
			neutral_speed_multiplier
		)

	challenge_choice_count = min(challenge_choice_count + 1, 2)
	button.queue_free()

	if challenge_choice_count == 1:
		desc_label.text = "狗露出微笑，嘴巴微张。"
		background.texture = BACKGROUND_SMILE
		_play_event_sound(SOUND_BIG_DOG_PATH, 0.0, 1.0, 0.4)
	else:
		desc_label.text = "狗张大嘴巴，眼神变得凌厉。"
		background.texture = BACKGROUND_BARK

	_refresh_reward_description()


# “叫？”会结算烙印奖励；此前挑战大狗的次数越多，得到的烙印越强。
func _on_bark_reward_chosen() -> void:
	var reward := _build_brand_reward()
	if not _try_grant_reward(reward):
		desc_label.text = "大狗盯着塞满的背包，没有把烙印交给你。"
		return

	match challenge_choice_count:
		0:
			desc_label.text = "大狗轻轻地叫了一下，然后离开了。"
			background.texture = BACKGROUND_BARK
			_play_event_sound(SOUND_BARK_PATH, -8.0, 1.35)
		1:
			desc_label.text = "叫！"
			background.texture = BACKGROUND_BARK
			_play_event_sound(SOUND_BARK_PATH, 0.0, 1.0)
		_:
			desc_label.text = "叫——————！"
			background.texture = BACKGROUND_LOUD_BARK
			_play_event_sound(SOUND_BARK_PATH, 6.0, 0.75)

	_clear_event_buttons()
	_sync_run_after_choice()


func _build_brand_reward() -> Relic:
	var reward := BIG_DOG_BRAND.duplicate(true) as Relic
	if reward == null:
		return null

	match challenge_choice_count:
		0:
			reward.level = 2
			reward.leveltip = Relic.LevelTip.UNLEVELUP
		1:
			reward.level = 3
			reward.leveltip = Relic.LevelTip.UNLEVELUP
		_:
			reward.level = 5
			reward.leveltip = Relic.LevelTip.LEVELUP
	return reward


func _try_grant_reward(reward: Relic) -> bool:
	if reward == null or run_stats == null or run_stats.player_build == null:
		return false
	if not run_stats.player_build.can_accept_relic(reward):
		return false
	return run_stats.player_build.add_relic(reward)


func _refresh_reward_description() -> void:
	if bark_button == null or not is_instance_valid(bark_button):
		return

	match challenge_choice_count:
		0:
			bark_button.detail_text = "获得2阶特殊装备“大狗的烙印”：每场战斗召唤1只猎犬盟友"
		1:
			bark_button.detail_text = "获得3阶特殊装备“大狗的烙印”：每场战斗召唤2只猎犬盟友"
		_:
			bark_button.detail_text = "获得5阶升级态特殊装备“大狗的烙印”：每场战斗召唤4只更强大的猎犬盟友"
	bark_button.refresh_display()


func _play_event_sound(
	stream_path: String,
	volume_db: float,
	pitch_scale: float,
	max_play_duration: float = 0.0
) -> void:
	# 音频资源损坏时不能让整个事件脚本无法加载；替换为有效音频后会自动恢复播放。
	if stream_path.is_empty() or not ResourceLoader.exists(stream_path):
		return
	var stream := load(stream_path) as AudioStream
	if stream == null:
		return
	var config := AudiioConfig.new()
	config.audio_streams = [stream]
	config.volume_db = volume_db
	config.bus = &"sfx"
	var player: AudioStreamPlayer2D = AudioController.play(config) as AudioStreamPlayer2D
	if player != null:
		player.pitch_scale = pitch_scale
		if max_play_duration > 0.0:
			var stop_timer := get_tree().create_timer(max_play_duration)
			stop_timer.timeout.connect(
				_stop_audio_player_if_stream_matches.bind(player, stream),
				CONNECT_ONE_SHOT
			)


# AudioController 会复用播放器，因此延迟停止前必须确认播放器仍在播放同一个流。
func _stop_audio_player_if_stream_matches(player: AudioStreamPlayer2D, stream: AudioStream) -> void:
	if not is_instance_valid(player):
		return
	if player.stream == stream:
		player.stop()


func _clear_event_buttons() -> void:
	for node: Node in get_tree().get_nodes_in_group(EVENT_BUTTON_GROUP):
		if node is EventRoomButton and is_ancestor_of(node):
			node.queue_free()


func _sync_run_after_choice() -> void:
	var run := _get_run()
	if run == null:
		return
	if run.player_build_proxy != null and run_stats != null and run_stats.player_build != null:
		run.player_build_proxy.bind_player_build(run_stats.player_build)


func _get_run() -> Run:
	var node: Node = get_parent()
	while node != null:
		if node is Run:
			return node as Run
		node = node.get_parent()
	return null


func _on_leave_button_pressed() -> void:
	EventBus.event_room_exited.emit()
