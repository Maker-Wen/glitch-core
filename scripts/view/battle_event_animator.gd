class_name BattleEventAnimator extends RefCounted
## View-layer router for sequential BattleEvent playback.
## BattleState is already resolved when events arrive; this class only owns
## transient presentation such as temporary DiamondBoardView draw positions.

const MOVE_DURATION := 0.30
const PUSH_DURATION := 0.24
const FALL_DURATION := 0.28

var _scene: BattleScene = null
var _board: DiamondBoardView = null
var _unit_snapshots: Dictionary = {}

func bind(scene: BattleScene, board: DiamondBoardView) -> void:
	_scene = scene
	_board = board

func set_unit_snapshots(unit_snapshots: Dictionary) -> void:
	_unit_snapshots = unit_snapshots.duplicate(true)

func play_events(events: Array) -> void:
	_prime_displacement_visual_positions(events)
	var player_attack_fx_played := false
	for raw in events:
		var event: BattleEvent = raw
		if not player_attack_fx_played and _scene._event_starts_player_attack_fx(event):
			await _scene._play_pending_player_attack_fx(event)
			player_attack_fx_played = true
		match event.type:
			BattleEvent.Type.UNIT_SPAWNED:
				await _scene._anim_unit_spawned(event)
			BattleEvent.Type.UNIT_MOVED:
				_hide_enemy_intents_during_displacement(event)
				await _play_unit_moved(event)
			BattleEvent.Type.UNIT_PUSHED:
				_hide_enemy_intents_during_displacement(event)
				await _play_unit_pushed(event)
			BattleEvent.Type.UNIT_DAMAGED:
				await _scene._anim_unit_damaged(event)
			BattleEvent.Type.UNIT_DIED:
				await _scene._anim_unit_died(event)
			BattleEvent.Type.UNIT_FELL:
				_hide_enemy_intents_during_displacement(event)
				await _play_unit_fell(event)
			BattleEvent.Type.UNIT_REMOVED:
				_scene._anim_unit_removed(event)
			BattleEvent.Type.TILE_DAMAGED, BattleEvent.Type.TILE_REPAIRED, BattleEvent.Type.TILE_SHIELDED, BattleEvent.Type.TILE_DESTROYED:
				_scene._anim_tile_changed(event)
				_scene._update_boss_event_feedback(event)
			BattleEvent.Type.BUMP_WALL, BattleEvent.Type.BUMP_UNIT:
				await _scene._anim_bump(event)
			BattleEvent.Type.ENEMY_ATTACK_STARTED:
				_scene._set_executing_enemy(event.unit_id)
				await _scene._play_enemy_attack_fx(event)
			BattleEvent.Type.ENEMY_ATTACK_MISSED:
				await _scene._anim_enemy_attack_missed(event)
			BattleEvent.Type.ROUND_STARTED:
				_hide_enemy_intents_for_round_start()
			BattleEvent.Type.PHASE_CHANGED:
				_scene._update_boss_event_feedback(event)
			_:
				pass
	_clear_all_visual_positions()

func _play_unit_moved(event: BattleEvent) -> void:
	await _animate_unit_position(event, MOVE_DURATION)

func _play_unit_pushed(event: BattleEvent) -> void:
	await _animate_unit_position(event, PUSH_DURATION)

func _play_unit_fell(event: BattleEvent) -> void:
	await _animate_unit_position(event, FALL_DURATION)
	await _scene._anim_unit_died(event)

func _prime_displacement_visual_positions(events: Array) -> void:
	if _board == null:
		return
	var first_from_by_unit: Dictionary = {}
	for raw in events:
		var event: BattleEvent = raw
		if not _is_displacement_event(event):
			continue
		if first_from_by_unit.has(event.unit_id):
			continue
		first_from_by_unit[event.unit_id] = event.from_pos
	for unit_id in first_from_by_unit.keys():
		var visual_unit: Unit = _unit_snapshots.get(unit_id, null)
		if visual_unit == null and _scene != null and _scene.engine != null and _scene.engine.state != null:
			visual_unit = _scene.engine.state.find_unit(unit_id)
		_board.set_unit_visual_position(unit_id, _board.cell_to_pixel(first_from_by_unit[unit_id]), visual_unit)

func _animate_unit_position(event: BattleEvent, duration: float) -> void:
	if _board == null:
		_scene._refresh_diamond_board()
		return
	var from_pixel := _board.cell_to_pixel(event.from_pos)
	var to_pixel := _board.cell_to_pixel(event.to_pos)
	var visual_unit: Unit = _unit_snapshots.get(event.unit_id, null)
	if visual_unit == null and _scene != null and _scene.engine != null and _scene.engine.state != null:
		visual_unit = _scene.engine.state.find_unit(event.unit_id)
	_board.set_unit_visual_position(event.unit_id, from_pixel, visual_unit)
	if duration <= 0.0 or _scene == null or _scene.get_tree() == null:
		_board.set_unit_visual_position(event.unit_id, to_pixel)
		_board.clear_unit_visual_position(event.unit_id)
		return
	var tween := _scene.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		func(pos: Vector2) -> void:
			_board.set_unit_visual_position(event.unit_id, pos),
		from_pixel,
		to_pixel,
		duration
	)
	await tween.finished
	_board.clear_unit_visual_position(event.unit_id)

func _is_displacement_event(event: BattleEvent) -> bool:
	return event.type == BattleEvent.Type.UNIT_MOVED \
		or event.type == BattleEvent.Type.UNIT_PUSHED \
		or event.type == BattleEvent.Type.UNIT_FELL

func _hide_enemy_intents_during_displacement(event: BattleEvent) -> void:
	if _scene == null:
		return
	if _scene._suppress_enemy_intents_until_events_done and _scene._event_unit_is_enemy(event):
		_scene._set_diamond_board_enemy_intents([])
		_scene.hud.set_enemy_action_stack([])
		_scene._set_focused_enemy(-1)

func _hide_enemy_intents_for_round_start() -> void:
	if _scene == null or not _scene._suppress_enemy_intents_until_events_done:
		return
	_scene._set_diamond_board_enemy_intents([])
	_scene.hud.set_enemy_action_stack([])
	_scene._set_focused_enemy(-1)

func _clear_all_visual_positions() -> void:
	if _board != null:
		_board.clear_unit_visual_positions()
