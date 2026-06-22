extends RefCounted
## Trace event ordering when a rift spawns + immediately moves.
## Verifies the events that the view layer receives.

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_carrion() -> UnitDef:
	return TestUnitDefs.carrion_spawn()

static func _make_bh() -> UnitDef:
	return TestUnitDefs.bountyhunter()

static func run(tr) -> void:
	_test_spawn_then_move_events_in_one_batch(tr)

static func _test_spawn_then_move_events_in_one_batch(tr) -> void:
	# Set up: 1 BH at (3,7), 1 rift at (3,2), schedule to spawn at round 2.
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var rift := Vector2i(3, 2)
	var schedule: Array = [{"round": 1, "pos": rift, "def": _make_carrion()}]
	var dz: Array[Vector2i] = [Vector2i(3, 7)]
	# Capture all events from start_battle + deploy + confirm + end_turn.
	var all_events: Array = []
	engine.events_produced.connect(func(events: Array): all_events.append_array(events))
	engine.start_battle(grid, [_make_bh()], [], dz, [rift], schedule)
	engine.apply_action(BattleAction.deploy(Vector2i(3, 7)))
	engine.apply_action(BattleAction.confirm_deploy())
	# End round 1 turn -> round 2 begins -> spawn + move should happen.
	all_events.clear()
	engine.apply_action(BattleAction.end_turn())
	# In the events list, after ROUND_STARTED for round 2, we expect:
	#   UNIT_SPAWNED at (3,2)
	#   UNIT_MOVED from (3,2) to somewhere closer to (3,7)
	var spawn_idx: int = -1
	var move_idx: int = -1
	var spawned_id: int = -1
	for i in range(all_events.size()):
		var e: BattleEvent = all_events[i]
		if e.type == BattleEvent.Type.UNIT_SPAWNED and spawn_idx == -1:
			spawn_idx = i
			spawned_id = e.unit_id
			tr.assert_eq("spawn event to_pos = rift", e.to_pos, rift)
		elif e.type == BattleEvent.Type.UNIT_MOVED and e.unit_id == spawned_id:
			move_idx = i
			break
	tr.assert_true("UNIT_SPAWNED event exists", spawn_idx >= 0)
	tr.assert_true("UNIT_MOVED event exists for spawned enemy", move_idx >= 0)
	tr.assert_true("spawn before move", spawn_idx < move_idx)
	# Also check that the move was non-trivial (didn't stay put).
	if move_idx >= 0:
		var mv: BattleEvent = all_events[move_idx]
		tr.assert_eq("move from_pos = rift", mv.from_pos, rift)
		tr.assert_true("move to_pos != rift (actually moved)", mv.to_pos != rift)
