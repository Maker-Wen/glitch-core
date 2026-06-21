class_name BattleSfxPresenter extends RefCounted
## Lightweight procedural one-shot SFX for battle feedback.
## No external audio assets are required; each sound is a short generated WAV.

const SAMPLE_RATE := 22050
const DEFAULT_VOLUME_DB := -12.0

var _scene: Node = null
var _streams: Dictionary = {}

func bind(scene: Node) -> void:
	_scene = scene

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
	if _scene == null or _scene.get_tree() == null:
		return
	var stream: AudioStreamWAV = _streams.get(sound_id, null)
	if stream == null:
		stream = _build_stream(sound_id)
		_streams[sound_id] = stream
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = DEFAULT_VOLUME_DB
	_scene.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _build_stream(sound_id: StringName) -> AudioStreamWAV:
	match sound_id:
		&"ranged_push":
			return _make_tone(620.0, 980.0, 0.11, 0.26, 0.32)
		&"ranged_pull":
			return _make_tone(760.0, 330.0, 0.13, 0.22, 0.42)
		&"melee_push":
			return _make_noise(0.08, 0.32, 0.22, 0.48)
		&"melee_bump":
			return _make_noise(0.06, 0.22, 0.18, 0.34)
		&"impact_pull":
			return _make_tone(240.0, 180.0, 0.08, 0.30, 0.36)
		&"impact_magic":
			return _make_tone(900.0, 420.0, 0.09, 0.28, 0.38)
		_:
			return _make_noise(0.07, 0.30, 0.20, 0.42)

func _make_tone(start_hz: float, end_hz: float, duration: float, gain: float, grit: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(sample_count)
	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(maxi(1, sample_count - 1))
		var hz := lerpf(start_hz, end_hz, t)
		phase += TAU * hz / float(SAMPLE_RATE)
		var env := _pluck_envelope(t)
		var body := sin(phase)
		var edge := sin(phase * 2.01) * grit
		data[i] = _sample_to_u8((body + edge) * gain * env)
	return _wav_from_data(data)

func _make_noise(duration: float, gain: float, tone: float, punch: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(sample_count)
	var seed := 1397
	var filtered := 0.0
	for i in range(sample_count):
		var t := float(i) / float(maxi(1, sample_count - 1))
		seed = int((seed * 1103515245 + 12345) & 0x7fffffff)
		var noise := (float(seed % 65536) / 32768.0) - 1.0
		filtered = lerpf(filtered, noise, tone)
		var click := sin(TAU * (150.0 + 80.0 * punch) * t * duration) * 0.18
		data[i] = _sample_to_u8((filtered + click) * gain * _pluck_envelope(t))
	return _wav_from_data(data)

func _pluck_envelope(t: float) -> float:
	var attack := smoothstep(0.0, 0.06, t)
	var decay := pow(maxf(0.0, 1.0 - t), 2.2)
	return attack * decay

func _sample_to_u8(value: float) -> int:
	return clampi(int((clampf(value, -1.0, 1.0) * 0.5 + 0.5) * 255.0), 0, 255)

func _wav_from_data(data: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
