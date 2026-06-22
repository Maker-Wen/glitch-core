class_name AttackFxPresenter extends RefCounted
## Owns transient attack action + impact FX. It does not mutate battle state.

const MUZZLE_DURATION := 0.12
const PROJECTILE_DURATION := 0.36
const MELEE_ACTION_DURATION := 0.32
const TETHER_ACTION_DURATION := 0.40
const IMPACT_DURATION := 0.30
const ACTION_DURATION := PROJECTILE_DURATION

const BattleSfxPresenterScript := preload("res://scripts/view/battle_sfx_presenter.gd")

var _scene: Node = null
var _board: DiamondBoardView = null
var _sfx = null

func bind(scene: Node, board: DiamondBoardView, audio = null) -> void:
	_scene = scene
	_board = board
	if _sfx == null:
		_sfx = BattleSfxPresenterScript.new()
	if audio != null:
		_sfx.bind_audio(audio)
	else:
		_sfx.bind(scene)

func play_attack(request: Dictionary) -> void:
	if _board == null:
		return
	var from_cell: Vector2i = request.get("from_cell", DiamondBoardView.INVALID_CELL)
	var to_cell: Vector2i = request.get("to_cell", DiamondBoardView.INVALID_CELL)
	if from_cell == DiamondBoardView.INVALID_CELL or to_cell == DiamondBoardView.INVALID_CELL:
		await _wait(0.06)
		return
	_board.set_attack_fx_suppresses_intents(true)
	await _play_action(request)
	await _play_impact(request)
	_finish_attack()

func clear() -> void:
	_finish_attack()

func _finish_attack() -> void:
	if _board != null:
		_board.clear_attack_fx_layers()
		_board.set_attack_fx_suppresses_intents(false)

func _play_action(request: Dictionary) -> void:
	if _sfx != null:
		_sfx.play_attack_action(int(request.get("attack_kind", UnitDef.AttackKind.MELEE_BUMP)))
	var duration := _action_duration(request)
	if _scene == null or _scene.get_tree() == null:
		_board.set_attack_fx_layers(_action_layers(request, 1.0))
		return
	var tween := _scene.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(progress: float) -> void:
			_board.set_attack_fx_layers(_action_layers(request, progress)),
		0.0,
		1.0,
		duration
	)
	await tween.finished

func _play_impact(request: Dictionary) -> void:
	if _sfx != null:
		_sfx.play_impact(int(request.get("attack_kind", UnitDef.AttackKind.MELEE_BUMP)))
	if _scene == null or _scene.get_tree() == null:
		_board.set_attack_fx_layers(_impact_layers(request, 1.0))
		return
	var tween := _scene.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(progress: float) -> void:
			_board.set_attack_fx_layers(_impact_layers(request, progress)),
		0.0,
		1.0,
		IMPACT_DURATION
	)
	await tween.finished

func _action_duration(request: Dictionary) -> float:
	match int(request.get("attack_kind", UnitDef.AttackKind.MELEE_BUMP)):
		UnitDef.AttackKind.RANGED_PUSH:
			return PROJECTILE_DURATION
		UnitDef.AttackKind.RANGED_PULL:
			return TETHER_ACTION_DURATION
		_:
			return MELEE_ACTION_DURATION

func _action_layers(request: Dictionary, progress: float) -> Array:
	var p := clampf(progress, 0.0, 1.0)
	var layers: Array = []
	if p < 0.32:
		layers.append(_phase_layer(request, "muzzle", clampf(p / 0.32, 0.0, 1.0)))
	match int(request.get("attack_kind", UnitDef.AttackKind.MELEE_BUMP)):
		UnitDef.AttackKind.RANGED_PUSH:
			if p >= 0.10:
				layers.append(_phase_layer(request, "projectile", clampf((p - 0.10) / 0.90, 0.0, 1.0)))
		UnitDef.AttackKind.RANGED_PULL:
			if p >= 0.08:
				layers.append(_phase_layer(request, "tether", clampf((p - 0.08) / 0.92, 0.0, 1.0)))
		UnitDef.AttackKind.MELEE_PUSH:
			if p >= 0.06:
				layers.append(_phase_layer(request, "slash", clampf((p - 0.06) / 0.94, 0.0, 1.0)))
		_:
			if p >= 0.08:
				layers.append(_phase_layer(request, "strike", clampf((p - 0.08) / 0.92, 0.0, 1.0)))
	return layers

func _impact_layers(request: Dictionary, progress: float) -> Array:
	var p := clampf(progress, 0.0, 1.0)
	var layers: Array = []
	if p >= 0.34:
		layers.append(_phase_layer(request, "dust", clampf((p - 0.34) / 0.66, 0.0, 1.0)))
	layers.append(_phase_layer(request, "impact", p))
	return layers

func _phase_layer(request: Dictionary, phase: String, progress: float) -> Dictionary:
	var layer := request.duplicate(true)
	layer["phase"] = phase
	layer["progress"] = clampf(progress, 0.0, 1.0)
	return layer

func _wait(duration: float) -> void:
	if duration <= 0.0 or _scene == null or _scene.get_tree() == null:
		return
	await _scene.get_tree().create_timer(duration).timeout
