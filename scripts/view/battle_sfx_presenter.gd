class_name BattleSfxPresenter extends RefCounted
## Maps battle attack semantics to shared resource-backed SFX playback.
## Missing audio assets are intentionally silent; no procedural fallback is used.

const AudioManagerScript := preload("res://scripts/core/audio_manager.gd")

const SOUND_IDS := {
	&"ranged_push": AudioManagerScript.SFX_RANGED_PUSH,
	&"ranged_pull": AudioManagerScript.SFX_RANGED_PULL,
	&"melee_push": AudioManagerScript.SFX_MELEE_PUSH,
	&"melee_bump": AudioManagerScript.SFX_MELEE_BUMP,
	&"impact_pull": AudioManagerScript.SFX_IMPACT_PULL,
	&"impact_magic": AudioManagerScript.SFX_IMPACT_MAGIC,
	&"impact_hit": AudioManagerScript.SFX_IMPACT_HIT,
}

var _audio = null

func bind(_scene: Node) -> void:
	_audio = _default_audio_manager(_scene)

func bind_audio(audio) -> void:
	_audio = audio

func play_attack_action(attack_kind: int) -> void:
	match attack_kind:
		UnitDef.AttackKind.RANGED_PUSH:
			_play(&"ranged_push")
		UnitDef.AttackKind.RANGED_PULL:
			_play(&"ranged_pull")
		UnitDef.AttackKind.MELEE_PUSH:
			_play(&"melee_push")
		_:
			_play(&"melee_bump")

func play_impact(attack_kind: int) -> void:
	match attack_kind:
		UnitDef.AttackKind.RANGED_PULL:
			_play(&"impact_pull")
		UnitDef.AttackKind.RANGED_PUSH:
			_play(&"impact_magic")
		_:
			_play(&"impact_hit")

func _play(sound_id: StringName) -> void:
	var manager = _audio if _audio != null else _default_audio_manager()
	if manager == null or not manager.has_method(&"play_sfx"):
		return
	var global_sound_id := _audio_sound_id(sound_id)
	if global_sound_id == &"":
		return
	manager.play_sfx(global_sound_id)

func _audio_sound_id(sound_id: StringName) -> StringName:
	return SOUND_IDS.get(sound_id, &"")

func _default_audio_manager(scene: Node = null):
	var tree := scene.get_tree() if scene != null else null
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null("AudioManager")
	return null
