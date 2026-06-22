extends RefCounted
## Full-battle trace: simulates the production battle_scene setup and
## verifies the enemy that spawns from a rift DOES move on the round it
## spawned, not the round after.

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_carrion() -> UnitDef:
	return TestUnitDefs.carrion_spawn()

static func _make_bh() -> UnitDef:
	return TestUnitDefs.bountyhunter()

static func run(tr) -> void:
	_test_spawned_enemy_moves_in_same_round(tr)

static func _test_spawned_enemy_moves_in_same_round(tr) -> void:
	# Production-like config:
	#   Rift at (2, 1) predicts during round 2 -> spawns at start of round 3.
	#   Spawned enemy should MOVE during round 3 begin (visible to player).
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var rift := Vector2i(2, 1)
	var schedule: Array = [
		{"round": 2, "pos": rift, "def": _make_carrion()},
	]
	# Place a warden far enough that the spawned carrion has somewhere to walk.
	var dz: Array[Vector2i] = [Vector2i(2, 7)]
	engine.start_battle(grid, [_make_bh()], [], dz, [rift], schedule)
	engine.apply_action(BattleAction.deploy(Vector2i(2, 7)))
	engine.apply_action(BattleAction.confirm_deploy())
	# === Round 1 ===
	tr.assert_eq("starting round 1", engine.state.current_round, 1)
	tr.assert_eq("round 1: 0 enemies", engine.state.enemies().size(), 0)
	tr.assert_eq("round 1: 0 predictions (schedule starts at round 2)",
		engine.state.pending_rift_spawns.size(), 0)
	# End round 1.
	engine.apply_action(BattleAction.end_turn())
	# === Round 2 ===
	tr.assert_eq("now round 2", engine.state.current_round, 2)
	tr.assert_eq("round 2: still 0 enemies (predicted)", engine.state.enemies().size(), 0)
	tr.assert_eq("round 2: 1 prediction visible", engine.state.pending_rift_spawns.size(), 1)
	# End round 2.
	engine.apply_action(BattleAction.end_turn())
	# === Round 3: enemy SHOULD spawn AND move ===
	tr.assert_eq("now round 3", engine.state.current_round, 3)
	tr.assert_eq("round 3: enemy spawned", engine.state.enemies().size(), 1)
	var spawned: Unit = engine.state.enemies()[0]
	# Critical assertion: enemy is NOT still at the rift cell. It moved already.
	tr.assert_true("spawned enemy moved AWAY from rift (not waiting until next round)",
		spawned.position != rift)
	# It should be closer to the warden than the rift was.
	tr.assert_true("spawned enemy moved toward warden",
		Grid.manhattan(spawned.position, Vector2i(2, 7)) < Grid.manhattan(rift, Vector2i(2, 7)))
