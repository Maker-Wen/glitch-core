extends RefCounted
## Verifies rift schedule. Per design §3.4:
##   - Predictions for round N+1 are visible during round N's player turn.
##   - Actual spawning happens at the start of round N+1's warning phase.
##   - Round 1 has no spawns (no predictions made before battle starts).

static func _make_carrion_def() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"carrion"
	d.display_name = "腐食兽"
	d.faction = UnitDef.Faction.ENEMY
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.MELEE_BUMP
	d.attack_damage = 1
	d.attack_range = 1
	return d

static func _make_bh_def() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"bh"
	d.display_name = "赏金猎人"
	d.faction = UnitDef.Faction.WARDEN
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.MELEE_PUSH
	d.attack_damage = 1
	d.attack_force = 1
	d.attack_range = 1
	return d

static func run(tr) -> void:
	_test_predicted_then_spawn(tr)
	_test_no_spawn_on_round_1(tr)
	_test_no_predictions_when_schedule_starts_at_round_2(tr)
	_test_spawn_then_immediate_move(tr)
	_test_scripted_spawn_then_immediate_move(tr)
	_test_scripted_spawn_defers_when_occupied(tr)
	_test_scripted_spawn_takes_priority_over_rift_same_cell(tr)

static func _test_predicted_then_spawn(tr) -> void:
	# Schedule entry with round=1 means: predicted during round 1, spawns
	# at start of round 2.
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var carrion := _make_carrion_def()
	var bh := _make_bh_def()
	var rift := Vector2i(3, 2)
	var schedule: Array = [{"round": 1, "pos": rift, "def": carrion}]
	var dz: Array[Vector2i] = [Vector2i(3, 7)]
	engine.start_battle(grid, [bh], [], dz, [rift], schedule)
	engine.apply_action(BattleAction.deploy(Vector2i(3, 7)))
	engine.apply_action(BattleAction.confirm_deploy())
	# Round 1 player turn: no enemies on board yet, BUT prediction is visible.
	tr.assert_eq("round 1 active", engine.state.current_round, 1)
	tr.assert_eq("no enemies spawned yet", engine.state.enemies().size(), 0)
	tr.assert_eq("1 prediction visible for round 2", engine.state.pending_rift_spawns.size(), 1)
	# End turn -> round 2 begins -> spawn pending + approach.
	engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("now round 2", engine.state.current_round, 2)
	tr.assert_eq("1 enemy spawned from rift", engine.state.enemies().size(), 1)
	var spawned := engine.state.enemies()[0]
	# Newly-spawned enemies perform an immediate approach move toward the
	# nearest warden. With move=2 and warden at (3,7), spawn at (3,2) moves 2
	# cells south. Then the spawned enemy stops (still not adjacent to warden).
	tr.assert_eq("spawned + approached to (3, 4)", spawned.position, Vector2i(3, 4))
	tr.assert_true("spawned south of rift", spawned.position.y > rift.y)
	tr.assert_eq("pending cleared after spawn", engine.state.pending_rift_spawns.size(), 0)

static func _test_no_spawn_on_round_1(tr) -> void:
	# Round 1 must have no rift spawn since predictions are only made during
	# round N for round N+1, not before battle starts.
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var carrion := _make_carrion_def()
	var bh := _make_bh_def()
	var rift := Vector2i(3, 2)
	var schedule: Array = [
		{"round": 1, "pos": rift, "def": carrion},
	]
	var dz: Array[Vector2i] = [Vector2i(3, 7)]
	engine.start_battle(grid, [bh], [], dz, [rift], schedule)
	engine.apply_action(BattleAction.deploy(Vector2i(3, 7)))
	engine.apply_action(BattleAction.confirm_deploy())
	tr.assert_eq("round 1 active", engine.state.current_round, 1)
	tr.assert_eq("zero enemies at round 1 start", engine.state.enemies().size(), 0)

static func _test_no_predictions_when_schedule_starts_at_round_2(tr) -> void:
	# If the schedule has no entries for round 1, the player gets a clean
	# round 1 -- no predictions, no UI clutter. Matches the production
	# battle_scene config: rift_schedule starts at round 2.
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var carrion := _make_carrion_def()
	var bh := _make_bh_def()
	var rift := Vector2i(3, 2)
	var schedule: Array = [
		{"round": 2, "pos": rift, "def": carrion},  # predicts during round 2
	]
	var dz: Array[Vector2i] = [Vector2i(3, 7)]
	engine.start_battle(grid, [bh], [], dz, [rift], schedule)
	engine.apply_action(BattleAction.deploy(Vector2i(3, 7)))
	engine.apply_action(BattleAction.confirm_deploy())
	tr.assert_eq("round 1 clean: 0 predictions", engine.state.pending_rift_spawns.size(), 0)

static func _test_spawn_then_immediate_move(tr) -> void:
	# At round start (after spawn), the new enemy's move executes immediately
	# as part of the round's enemy-move phase. By the time the player has
	# control, the spawned enemy should be at its planned post-move cell.
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var carrion := _make_carrion_def()
	var bh := _make_bh_def()
	var rift := Vector2i(3, 2)
	var schedule: Array = [{"round": 1, "pos": rift, "def": carrion}]
	var dz: Array[Vector2i] = [Vector2i(3, 7)]
	engine.start_battle(grid, [bh], [], dz, [rift], schedule)
	engine.apply_action(BattleAction.deploy(Vector2i(3, 7)))
	engine.apply_action(BattleAction.confirm_deploy())
	engine.apply_action(BattleAction.end_turn())  # round 1 ends -> round 2 begins
	var spawned: Unit = engine.state.enemies()[0]
	var plan = engine.state.enemy_warnings.get(spawned.id, null)
	tr.assert_true("spawned enemy has plan", plan != null)
	# After round start moves, the enemy is at plan.move_to.
	tr.assert_eq("enemy at planned post-move cell", spawned.position, plan.move_to)

static func _test_scripted_spawn_then_immediate_move(tr) -> void:
	# Scripted spawns are direct round-start spawns: no rift preview, and the
	# spawned enemy participates in the same round's move planning.
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var carrion := _make_carrion_def()
	var bh := _make_bh_def()
	var spawn_pos := Vector2i(3, 2)
	var scripted_schedule: Array = [{"round": 1, "pos": spawn_pos, "def": carrion}]
	var dz: Array[Vector2i] = [Vector2i(3, 7)]
	var all_events: Array = []
	engine.events_produced.connect(func(events: Array): all_events.append_array(events))
	engine.start_battle(grid, [bh], [], dz, [], [], 5, [], [], [], {}, scripted_schedule)
	engine.apply_action(BattleAction.deploy(Vector2i(3, 7)))
	all_events.clear()
	engine.apply_action(BattleAction.confirm_deploy())
	tr.assert_eq("scripted round 1 active", engine.state.current_round, 1)
	tr.assert_eq("scripted enemy spawned", engine.state.enemies().size(), 1)
	tr.assert_eq("scripted spawns do not create rift previews", engine.state.pending_rift_spawns.size(), 0)
	var spawned: Unit = engine.state.enemies()[0]
	tr.assert_eq("scripted spawned + approached to (3, 4)", spawned.position, Vector2i(3, 4))
	var plan = engine.state.enemy_warnings.get(spawned.id, null)
	tr.assert_true("scripted spawned enemy has plan", plan != null)
	if plan != null:
		tr.assert_eq("scripted enemy at planned post-move cell", spawned.position, plan.move_to)
	var spawn_idx := -1
	var move_idx := -1
	for i in range(all_events.size()):
		var e: BattleEvent = all_events[i]
		if e.type == BattleEvent.Type.UNIT_SPAWNED and bool(e.extra.get("scripted_spawn", false)):
			spawn_idx = i
			tr.assert_eq("scripted spawn event to_pos", e.to_pos, spawn_pos)
		elif e.type == BattleEvent.Type.UNIT_MOVED and spawn_idx >= 0 and e.unit_id == spawned.id:
			move_idx = i
			break
	tr.assert_true("scripted UNIT_SPAWNED event exists", spawn_idx >= 0)
	tr.assert_true("scripted UNIT_MOVED event exists", move_idx >= 0)
	tr.assert_true("scripted spawn before move", spawn_idx >= 0 and spawn_idx < move_idx)

static func _test_scripted_spawn_defers_when_occupied(tr) -> void:
	# If the configured spawn cell is occupied at round start, the entry shifts
	# forward one round instead of replacing or overlapping the occupant.
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var carrion := _make_carrion_def()
	var bh := _make_bh_def()
	var occupied := Vector2i(3, 7)
	var scripted_schedule: Array = [{"round": 1, "pos": occupied, "def": carrion}]
	var dz: Array[Vector2i] = [occupied]
	engine.start_battle(grid, [bh], [], dz, [], [], 5, [], [], [], {}, scripted_schedule)
	engine.apply_action(BattleAction.deploy(occupied))
	engine.apply_action(BattleAction.confirm_deploy())
	tr.assert_eq("occupied scripted spawn deferred enemy count", engine.state.enemies().size(), 0)
	tr.assert_eq("occupied scripted spawn shifted to next round", int(engine.state.scripted_spawn_schedule[0].get("round", 0)), 2)

static func _test_scripted_spawn_takes_priority_over_rift_same_cell(tr) -> void:
	# Round-start order is scripted first, then pending rifts. If both want the
	# same cell, the scripted spawn occupies it and the rift stays pending.
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var carrion := _make_carrion_def()
	var bh := _make_bh_def()
	var spawn_pos := Vector2i(3, 2)
	var rift_schedule: Array = [{"round": 1, "pos": spawn_pos, "def": carrion}]
	var scripted_schedule: Array = [{"round": 2, "pos": spawn_pos, "def": carrion}]
	var dz: Array[Vector2i] = [Vector2i(3, 7)]
	engine.start_battle(grid, [bh], [], dz, [spawn_pos], rift_schedule, 5, [], [], [], {}, scripted_schedule)
	engine.apply_action(BattleAction.deploy(Vector2i(3, 7)))
	engine.apply_action(BattleAction.confirm_deploy())
	tr.assert_eq("same-cell round 1 prediction visible", engine.state.pending_rift_spawns.size(), 1)
	engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("same-cell now round 2", engine.state.current_round, 2)
	tr.assert_eq("same-cell only scripted enemy spawned", engine.state.enemies().size(), 1)
	tr.assert_eq("same-cell rift stayed pending", engine.state.pending_rift_spawns.size(), 1)
