extends RefCounted
## Repro test for "archer's plan falls flat on round 1" bug.
## Mirrors the production battle_scene initial setup.

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_archer() -> UnitDef:
	return TestUnitDefs.plague_archer({"def_id": &"archer"})

static func _make_carrion() -> UnitDef:
	return TestUnitDefs.carrion_spawn()

static func _make_bh() -> UnitDef:
	return TestUnitDefs.bountyhunter()

static func run(tr) -> void:
	_test_archer_plan_is_actionable_in_production_setup(tr)

static func _test_archer_plan_is_actionable_in_production_setup(tr) -> void:
	# Reproduce production battle_scene setup.
	var engine := BattleEngine.new()
	var grid := Grid.new()
	grid.set_tile(Vector2i(3, 3), Grid.TileType.PILLAR)
	grid.set_tile(Vector2i(4, 4), Grid.TileType.PILLAR)
	var enemies: Array = [
		{"def": _make_carrion(), "pos": Vector2i(1, 0)},
		{"def": _make_archer(),  "pos": Vector2i(3, 0)},
		{"def": _make_carrion(), "pos": Vector2i(6, 0)},
	]
	# Deploy zone south.
	var dz: Array[Vector2i] = []
	for y in [6, 7]:
		for x in range(Grid.SIZE):
			dz.append(Vector2i(x, y))
	engine.start_battle(grid, [_make_bh(), _make_bh(), _make_bh()], enemies, dz, [], [])
	# Deploy three wardens at (1,6) (3,7) (5,6) -- production warden positions.
	engine.apply_action(BattleAction.deploy(Vector2i(1, 6)))
	engine.apply_action(BattleAction.deploy(Vector2i(3, 7)))
	engine.apply_action(BattleAction.deploy(Vector2i(5, 6)))
	engine.apply_action(BattleAction.confirm_deploy())
	# Round 1 player turn now. Find the archer.
	var archer: Unit = null
	for u in engine.state.enemies():
		if u.def.def_id == &"archer":
			archer = u
			break
	tr.assert_true("archer exists", archer != null)
	if archer == null:
		return
	var plan = engine.state.enemy_warnings.get(archer.id, null)
	tr.assert_true("archer has plan", plan != null)
	# Diagnostic prints (will only show on assertion failure)
	if plan != null:
		print("  Archer at: ", archer.position)
		print("  Plan move_to: ", plan.move_to)
		print("  Plan attack_pos: ", plan.attack_pos)
		print("  Plan origin_pos: ", plan.origin_pos)
		print("  Plan has_attack: ", plan.has_attack())
		print("  Actionable: ", engine.is_plan_actionable(archer.id))
	# The archer should be doing SOMETHING (either moving or attacking, but
	# definitely not "displaced" since no one has touched it yet).
	tr.assert_true("archer plan should be actionable (just spawned, nothing moved it)",
		engine.is_plan_actionable(archer.id) or not plan.has_attack())
