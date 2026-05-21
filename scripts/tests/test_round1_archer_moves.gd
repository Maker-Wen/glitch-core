extends RefCounted
## Verify: when battle starts with the production setup (archer at (3,0),
## carrions adjacent), the archer DOES move south in round 1.

static func _make_archer() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"archer"
	d.faction = UnitDef.Faction.ENEMY
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.RANGED_PUSH
	d.attack_range = 3
	d.attack_damage = 1
	d.attack_force = 0
	return d

static func _make_carrion() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"carrion"
	d.faction = UnitDef.Faction.ENEMY
	d.max_hp = 2
	d.move = 3
	d.attack_kind = UnitDef.AttackKind.MELEE_BUMP
	d.attack_damage = 1
	d.attack_range = 1
	return d

static func _make_bh() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"bh"
	d.faction = UnitDef.Faction.WARDEN
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.MELEE_PUSH
	d.attack_range = 1
	d.attack_damage = 1
	d.attack_force = 1
	return d

static func run(tr) -> void:
	_test_archer_moves_in_round_1(tr)
	_test_unit_moved_event_emitted_for_archer(tr)

static func _test_archer_moves_in_round_1(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	grid.set_tile(Vector2i(3, 3), Grid.TileType.PILLAR)
	grid.set_tile(Vector2i(4, 4), Grid.TileType.PILLAR)
	var archer_pos := Vector2i(3, 0)
	var enemies: Array = [
		{"def": _make_carrion(), "pos": Vector2i(1, 0)},
		{"def": _make_archer(),  "pos": archer_pos},
		{"def": _make_carrion(), "pos": Vector2i(6, 0)},
	]
	var dz: Array[Vector2i] = []
	for y in [6, 7]:
		for x in range(Grid.SIZE):
			dz.append(Vector2i(x, y))
	engine.start_battle(grid, [_make_bh(), _make_bh(), _make_bh()], enemies, dz, [], [])
	engine.apply_action(BattleAction.deploy(Vector2i(1, 6)))
	engine.apply_action(BattleAction.deploy(Vector2i(3, 7)))
	engine.apply_action(BattleAction.deploy(Vector2i(5, 6)))
	engine.apply_action(BattleAction.confirm_deploy())
	# Round 1 player turn now. The archer should have MOVED south by now.
	var archer: Unit = null
	for u in engine.state.enemies():
		if u.def.def_id == &"archer":
			archer = u
			break
	tr.assert_true("archer exists", archer != null)
	if archer != null:
		tr.assert_true("archer moved south in round 1", archer.position != archer_pos)
		tr.assert_true("archer moved toward south edge", archer.position.y > archer_pos.y)

static func _test_unit_moved_event_emitted_for_archer(tr) -> void:
	# Capture events fired during round 1 begin and verify a UNIT_MOVED
	# event was emitted for the archer.
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var archer_pos := Vector2i(3, 0)
	var enemies: Array = [
		{"def": _make_archer(),  "pos": archer_pos},
	]
	var dz: Array[Vector2i] = [Vector2i(3, 7)]
	var all_events: Array = []
	engine.events_produced.connect(func(events: Array): all_events.append_array(events))
	engine.start_battle(grid, [_make_bh()], enemies, dz, [], [])
	engine.apply_action(BattleAction.deploy(Vector2i(3, 7)))
	all_events.clear()
	engine.apply_action(BattleAction.confirm_deploy())
	# Look for UNIT_MOVED for the archer.
	var archer: Unit = engine.state.enemies()[0]
	var moved: bool = false
	for e in all_events:
		if e.type == BattleEvent.Type.UNIT_MOVED and e.unit_id == archer.id:
			moved = true
			break
	tr.assert_true("UNIT_MOVED event was emitted for archer in round 1", moved)
