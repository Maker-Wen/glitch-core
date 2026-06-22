extends RefCounted
## End-to-end tests for warden attack actions through BattleEngine.
## Verifies that knockback/pull effects actually fire in the action pipeline.

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_state_with(engine: BattleEngine, grid: Grid, units: Array) -> void:
	engine.state = BattleState.new()
	engine.state.grid = grid
	for entry in units:
		var u := Unit.new(engine.state.allocate_unit_id(), entry["def"], entry["pos"])
		engine.state.units.append(u)
		# If pre-set hp, override (otherwise uses max_hp from def)
		if entry.has("hp"):
			u.hp = entry["hp"]
	engine.state.phase = BattleState.Phase.PLAYER_ACTION

static func _make_carrion_def() -> UnitDef:
	return TestUnitDefs.carrion_spawn()

static func _make_bh_def() -> UnitDef:
	return TestUnitDefs.bountyhunter()

static func _make_gr_def() -> UnitDef:
	return TestUnitDefs.graverobber()

static func _make_mage_def() -> UnitDef:
	return TestUnitDefs.mage()

static func run(tr) -> void:
	_test_bountyhunter_pushes_target(tr)
	_test_bountyhunter_push_off_board(tr)
	_test_graverobber_pulls_target(tr)
	_test_mage_pushes_at_range(tr)
	_test_mage_pushes_beyond_three_cells(tr)

static func _test_bountyhunter_pushes_target(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var bh := _make_bh_def()
	var carrion := _make_carrion_def()
	# BH at (3,5); Carrion (HP=2) at (3,4) -- one cell north.
	# Use a second decoy warden so the player turn doesn't auto-advance
	# (which would trigger round-end attacks + round-start moves).
	_make_state_with(engine, grid, [
		{"def": bh, "pos": Vector2i(3, 5)},
		{"def": bh, "pos": Vector2i(0, 0)},  # decoy
		{"def": carrion, "pos": Vector2i(3, 4)},
	])
	var bh_unit: Unit = engine.state.units[0]
	var carrion_unit: Unit = engine.state.units[2]
	var events := engine.apply_action(BattleAction.attack(bh_unit.id, Vector2i(3, 4)))
	tr.assert_eq("carrion damaged (hp 2 -> 1)", carrion_unit.hp, 1)
	tr.assert_eq("carrion pushed north to (3,3)", carrion_unit.position, Vector2i(3, 3))
	tr.assert_eq("carrion alive", carrion_unit.alive, true)
	tr.assert_eq("bh stays still at (3,5)", bh_unit.position, Vector2i(3, 5))
	var pushed_count := 0
	for e in events:
		if e.type == BattleEvent.Type.UNIT_PUSHED:
			pushed_count += 1
	tr.assert_true("at least one UNIT_PUSHED event fired", pushed_count >= 1)

static func _test_bountyhunter_push_off_board(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var bh := _make_bh_def()
	var carrion := _make_carrion_def()
	# Carrion sits on the top row; pushing it north sends it off the board.
	_make_state_with(engine, grid, [
		{"def": bh, "pos": Vector2i(3, 1)},
		{"def": carrion, "pos": Vector2i(3, 0)},
	])
	var bh_unit: Unit = engine.state.units[0]
	var carrion_unit: Unit = engine.state.units[1]
	var events := engine.apply_action(BattleAction.attack(bh_unit.id, Vector2i(3, 0)))
	tr.assert_eq("carrion removed after fall", engine.state.find_unit(carrion_unit.id), null)
	var fell_count := 0
	for e in events:
		if e.type == BattleEvent.Type.UNIT_FELL:
			fell_count += 1
	tr.assert_true("UNIT_FELL event emitted", fell_count >= 1)

static func _test_graverobber_pulls_target(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var gr := _make_gr_def()
	var carrion := _make_carrion_def()
	var bh := _make_bh_def()
	# GR at (3,5); Carrion (HP=2) at (3,2) -- 3 cells north. Pull 1 -> (3,3).
	# Decoy BH prevents turn auto-advance.
	_make_state_with(engine, grid, [
		{"def": gr, "pos": Vector2i(3, 5)},
		{"def": bh, "pos": Vector2i(0, 0)},  # decoy
		{"def": carrion, "pos": Vector2i(3, 2)},
	])
	var gr_unit: Unit = engine.state.units[0]
	var carrion_unit: Unit = engine.state.units[2]
	engine.apply_action(BattleAction.attack(gr_unit.id, Vector2i(3, 2)))
	tr.assert_eq("carrion pulled south by 1 to (3,3)", carrion_unit.position, Vector2i(3, 3))
	tr.assert_eq("carrion damaged", carrion_unit.hp, 1)

static func _test_mage_pushes_at_range(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var mage := _make_mage_def()
	var carrion := _make_carrion_def()
	var bh := _make_bh_def()
	# Mage at (3,5); Carrion at (3,3) -- 2 cells north. Push 1 -> Carrion goes to (3,2).
	_make_state_with(engine, grid, [
		{"def": mage, "pos": Vector2i(3, 5)},
		{"def": bh, "pos": Vector2i(0, 0)},  # decoy
		{"def": carrion, "pos": Vector2i(3, 3)},
	])
	var mage_unit: Unit = engine.state.units[0]
	var carrion_unit: Unit = engine.state.units[2]
	engine.apply_action(BattleAction.attack(mage_unit.id, Vector2i(3, 3)))
	tr.assert_eq("carrion pushed north 1 to (3,2)", carrion_unit.position, Vector2i(3, 2))
	tr.assert_eq("carrion damaged", carrion_unit.hp, 1)

static func _test_mage_pushes_beyond_three_cells(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var mage := _make_mage_def()
	var carrion := _make_carrion_def()
	var bh := _make_bh_def()
	# Mage attack aliases to Repulsion Bolt, which ignores distance on clear lines.
	_make_state_with(engine, grid, [
		{"def": mage, "pos": Vector2i(3, 7)},
		{"def": bh, "pos": Vector2i(0, 0)},  # decoy
		{"def": carrion, "pos": Vector2i(3, 2)},
	])
	var mage_unit: Unit = engine.state.units[0]
	var carrion_unit: Unit = engine.state.units[2]
	engine.apply_action(BattleAction.attack(mage_unit.id, Vector2i(3, 2)))
	tr.assert_eq("distant carrion pushed north 1 to (3,1)", carrion_unit.position, Vector2i(3, 1))
	tr.assert_eq("distant carrion damaged", carrion_unit.hp, 1)
