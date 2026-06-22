class_name GameAudioManager extends Node
## Shared resource-backed audio playback for BGM and one-shot SFX.

const BGM_MENU := &"menu"
const BGM_BATTLE := &"battle"

const SFX_RANGED_PUSH := &"battle.ranged_push"
const SFX_RANGED_PULL := &"battle.ranged_pull"
const SFX_MELEE_PUSH := &"battle.melee_push"
const SFX_MELEE_BUMP := &"battle.melee_bump"
const SFX_IMPACT_PULL := &"battle.impact_pull"
const SFX_IMPACT_MAGIC := &"battle.impact_magic"
const SFX_IMPACT_HIT := &"battle.impact_hit"
const SFX_UI_CONFIRM := &"ui.confirm"
const SFX_UI_CANCEL := &"ui.cancel"
const SFX_UI_DISABLED := &"ui.disabled"
const SFX_UNIT_SELECT := &"battle.unit_select"
const SFX_TILE_SELECT := &"battle.tile_select"
const SFX_DEPLOY_CONFIRM := &"battle.deploy_confirm"
const SFX_END_TURN := &"battle.end_turn"
const SFX_ABILITY_ARM := &"battle.ability_arm"
const SFX_ABILITY_UNAVAILABLE := &"battle.ability_unavailable"
const SFX_UNIT_DEATH := &"battle.unit_death"
const SFX_VICTORY_STINGER := &"battle.victory_stinger"
const SFX_DEFEAT_STINGER := &"battle.defeat_stinger"

const BGM_VOLUME_DB := -14.0
const SFX_VOLUME_DB := -12.0
const SILENT_VOLUME_DB := -60.0
const BGM_FADE_SECONDS := 0.45
const SFX_PITCH_VARIATION := 0.035

const BGM_PATHS := {
	BGM_MENU: "res://audio/bgm/menu_loop_dark_ambient_01.ogg",
	BGM_BATTLE: "res://audio/bgm/battle_loop_dark_tactics_01.ogg",
}

const SFX_PATHS := {
	SFX_RANGED_PUSH: "res://audio/sfx/battle/attack_ranged_push_01.ogg",
	SFX_RANGED_PULL: "res://audio/sfx/battle/attack_ranged_pull_01.ogg",
	SFX_MELEE_PUSH: "res://audio/sfx/battle/attack_melee_push_01.ogg",
	SFX_MELEE_BUMP: "res://audio/sfx/battle/attack_melee_bump_01.ogg",
	SFX_IMPACT_PULL: "res://audio/sfx/battle/impact_pull_01.ogg",
	SFX_IMPACT_MAGIC: "res://audio/sfx/battle/impact_magic_01.ogg",
	SFX_IMPACT_HIT: "res://audio/sfx/battle/impact_hit_01.ogg",
	SFX_UI_CONFIRM: "res://audio/sfx/ui/ui_confirm_01.ogg",
	SFX_UI_CANCEL: "res://audio/sfx/ui/ui_cancel_01.ogg",
	SFX_UI_DISABLED: "res://audio/sfx/ui/ui_disabled_01.ogg",
	SFX_UNIT_SELECT: "res://audio/sfx/battle/command/unit_select_01.ogg",
	SFX_TILE_SELECT: "res://audio/sfx/battle/command/tile_select_01.ogg",
	SFX_DEPLOY_CONFIRM: "res://audio/sfx/battle/command/deploy_confirm_01.ogg",
	SFX_END_TURN: "res://audio/sfx/battle/command/end_turn_01.ogg",
	SFX_ABILITY_ARM: "res://audio/sfx/battle/command/ability_arm_01.ogg",
	SFX_ABILITY_UNAVAILABLE: "res://audio/sfx/battle/command/ability_unavailable_01.ogg",
	SFX_UNIT_DEATH: "res://audio/sfx/battle/command/unit_death_01.ogg",
	SFX_VICTORY_STINGER: "res://audio/sfx/battle/command/victory_stinger_01.ogg",
	SFX_DEFEAT_STINGER: "res://audio/sfx/battle/command/defeat_stinger_01.ogg",
}

var _music_player: AudioStreamPlayer = null
var _fade_player: AudioStreamPlayer = null
var _stream_cache: Dictionary = {}
var _current_bgm_id: StringName = &""
var _bgm_tween: Tween = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_ensure_music_players()

func play_menu_bgm() -> void:
	play_bgm(BGM_MENU)

func play_battle_bgm() -> void:
	play_bgm(BGM_BATTLE)

func play_bgm(bgm_id: StringName, fade_seconds: float = BGM_FADE_SECONDS) -> void:
	var stream := _bgm_stream(bgm_id)
	if stream == null:
		return
	_ensure_music_players()
	if _current_bgm_id == bgm_id and _music_player.playing:
		return
	_current_bgm_id = bgm_id
	_enable_loop(stream)
	if _music_player.playing and fade_seconds > 0.0 and is_inside_tree():
		_crossfade_to(stream, fade_seconds)
	else:
		_stop_fade_player()
		_music_player.stream = stream
		_music_player.volume_db = BGM_VOLUME_DB
		if is_inside_tree():
			_music_player.play()

func stop_bgm(fade_seconds: float = BGM_FADE_SECONDS) -> void:
	_ensure_music_players()
	_current_bgm_id = &""
	if not _music_player.playing:
		return
	if fade_seconds > 0.0 and is_inside_tree():
		_kill_bgm_tween()
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_music_player, "volume_db", SILENT_VOLUME_DB, fade_seconds)
		_bgm_tween.tween_callback(_music_player.stop)
	else:
		_music_player.stop()

func play_sfx(sound_id: StringName, volume_db: float = SFX_VOLUME_DB) -> AudioStreamPlayer:
	var stream := _sfx_stream(sound_id)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.name = "Sfx_%s" % String(sound_id).replace(".", "_")
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-SFX_PITCH_VARIATION, SFX_PITCH_VARIATION)
	add_child(player)
	player.finished.connect(player.queue_free)
	if is_inside_tree():
		player.play()
	return player

func play_ui_confirm() -> AudioStreamPlayer:
	return play_sfx(SFX_UI_CONFIRM)

func play_ui_cancel() -> AudioStreamPlayer:
	return play_sfx(SFX_UI_CANCEL)

func play_ui_disabled() -> AudioStreamPlayer:
	return play_sfx(SFX_UI_DISABLED)

func has_bgm(bgm_id: StringName) -> bool:
	return _bgm_stream(bgm_id) != null

func has_sfx(sound_id: StringName) -> bool:
	return _sfx_stream(sound_id) != null

func bgm_path(bgm_id: StringName) -> String:
	return String(BGM_PATHS.get(bgm_id, ""))

func sfx_path(sound_id: StringName) -> String:
	return String(SFX_PATHS.get(sound_id, ""))

func current_bgm_id() -> StringName:
	return _current_bgm_id

func _crossfade_to(stream: AudioStream, fade_seconds: float) -> void:
	_kill_bgm_tween()
	_fade_player.stop()
	_fade_player.stream = _music_player.stream
	_fade_player.volume_db = _music_player.volume_db
	if _fade_player.stream != null:
		_fade_player.play(_music_player.get_playback_position())
	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = SILENT_VOLUME_DB
	_music_player.play()
	_bgm_tween = create_tween()
	_bgm_tween.set_parallel(true)
	_bgm_tween.tween_property(_music_player, "volume_db", BGM_VOLUME_DB, fade_seconds)
	_bgm_tween.tween_property(_fade_player, "volume_db", SILENT_VOLUME_DB, fade_seconds)
	_bgm_tween.set_parallel(false)
	_bgm_tween.tween_callback(_stop_fade_player)

func _ensure_music_players() -> void:
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "Bgm"
		_music_player.volume_db = BGM_VOLUME_DB
		add_child(_music_player)
	if _fade_player == null:
		_fade_player = AudioStreamPlayer.new()
		_fade_player.name = "BgmFade"
		_fade_player.volume_db = SILENT_VOLUME_DB
		add_child(_fade_player)

func _bgm_stream(bgm_id: StringName) -> AudioStream:
	return _stream_for_path(bgm_path(bgm_id))

func _sfx_stream(sound_id: StringName) -> AudioStream:
	return _stream_for_path(sfx_path(sound_id))

func _stream_for_path(path: String) -> AudioStream:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if _stream_cache.has(path):
		return _stream_cache[path]
	var stream := ResourceLoader.load(path) as AudioStream
	if stream != null:
		_stream_cache[path] = stream
	return stream

func _enable_loop(stream: AudioStream) -> void:
	if _has_property(stream, &"loop"):
		stream.set("loop", true)

func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == String(property_name):
			return true
	return false

func _kill_bgm_tween() -> void:
	if _bgm_tween != null:
		_bgm_tween.kill()
		_bgm_tween = null

func _stop_fade_player() -> void:
	if _fade_player != null:
		_fade_player.stop()
		_fade_player.stream = null
		_fade_player.volume_db = SILENT_VOLUME_DB
