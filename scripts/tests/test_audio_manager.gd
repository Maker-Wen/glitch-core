extends RefCounted
## Regression coverage for the shared resource-backed audio manager.

const AudioManagerScript := preload("res://scripts/core/audio_manager.gd")

static func run(tr) -> void:
	_test_audio_manager_resolves_existing_resources(tr)
	_test_audio_manager_missing_resources_are_silent(tr)
	_test_audio_manager_reuses_current_bgm_request(tr)
	_test_audio_manager_creates_one_shot_sfx_player(tr)

static func _test_audio_manager_resolves_existing_resources(tr) -> void:
	var audio = AudioManagerScript.new()
	tr.assert_true("menu bgm resource resolves", audio.has_bgm(AudioManagerScript.BGM_MENU))
	tr.assert_true("battle bgm resource resolves", audio.has_bgm(AudioManagerScript.BGM_BATTLE))
	tr.assert_true("ranged push sfx resource resolves", audio.has_sfx(AudioManagerScript.SFX_RANGED_PUSH))
	tr.assert_true("impact hit sfx resource resolves", audio.has_sfx(AudioManagerScript.SFX_IMPACT_HIT))
	for sound_id in _expected_new_sfx_ids():
		tr.assert_true("%s sfx resource resolves" % String(sound_id), audio.has_sfx(sound_id))
	audio.queue_free()

static func _test_audio_manager_missing_resources_are_silent(tr) -> void:
	var audio = AudioManagerScript.new()
	tr.assert_true("missing bgm does not resolve", not audio.has_bgm(&"missing_bgm"))
	tr.assert_true("missing sfx does not resolve", not audio.has_sfx(&"missing_sfx"))
	tr.assert_eq("missing sfx returns no player", audio.play_sfx(&"missing_sfx"), null)
	audio.play_bgm(&"missing_bgm")
	tr.assert_eq("missing bgm does not become current", audio.current_bgm_id(), &"")
	audio.queue_free()

static func _test_audio_manager_reuses_current_bgm_request(tr) -> void:
	var audio = AudioManagerScript.new()
	audio.play_bgm(AudioManagerScript.BGM_MENU, 0.0)
	var player: AudioStreamPlayer = audio._music_player
	var first_stream := player.stream
	audio.play_bgm(AudioManagerScript.BGM_MENU, 0.0)
	tr.assert_eq("duplicate bgm request keeps current id", audio.current_bgm_id(), AudioManagerScript.BGM_MENU)
	tr.assert_true("duplicate bgm request keeps same stream", player.stream == first_stream)
	audio.queue_free()

static func _test_audio_manager_creates_one_shot_sfx_player(tr) -> void:
	var audio = AudioManagerScript.new()
	var player := audio.play_sfx(AudioManagerScript.SFX_MELEE_BUMP)
	tr.assert_true("existing sfx creates player", player != null)
	tr.assert_true("sfx player is parented under audio manager", player.get_parent() == audio)
	tr.assert_true("sfx player uses configured stream", player.stream != null)
	audio.queue_free()

static func _expected_new_sfx_ids() -> Array[StringName]:
	return [
		AudioManagerScript.SFX_UI_CONFIRM,
		AudioManagerScript.SFX_UI_CANCEL,
		AudioManagerScript.SFX_UI_DISABLED,
		AudioManagerScript.SFX_UNIT_SELECT,
		AudioManagerScript.SFX_TILE_SELECT,
		AudioManagerScript.SFX_DEPLOY_CONFIRM,
		AudioManagerScript.SFX_END_TURN,
		AudioManagerScript.SFX_ABILITY_ARM,
		AudioManagerScript.SFX_ABILITY_UNAVAILABLE,
		AudioManagerScript.SFX_UNIT_DEATH,
		AudioManagerScript.SFX_VICTORY_STINGER,
		AudioManagerScript.SFX_DEFEAT_STINGER,
	]
