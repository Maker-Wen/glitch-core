extends RefCounted
## PhysicsResolver push tests: empty cell slide, fall off, wall bump.

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_state() -> BattleState:
	var s := BattleState.new()
	return s

static func _add_unit(s: BattleState, faction: int, hp: int, pos: Vector2i) -> Unit:
	var def := TestUnitDefs.generic_warden({"max_hp": hp, "color": Color.WHITE}) if faction == UnitDef.Faction.WARDEN else TestUnitDefs.generic_enemy({"max_hp": hp, "color": Color.WHITE})
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	u.hp = hp
	s.units.append(u)
	return u

static func run(tr) -> void:
	_test_push_slide(tr)
	_test_push_off_board_fell(tr)
	_test_push_into_void_tile_fell(tr)
	_test_push_off_abyss_edge_marks_event(tr)
	_test_push_into_pillar_wall_bump(tr)
	_test_zero_force_just_damage(tr)

static func _test_push_slide(tr) -> void:
	var s := _make_state()
	var attacker := _add_unit(s, UnitDef.Faction.WARDEN, 2, Vector2i(2, 4))
	var target := _add_unit(s, UnitDef.Faction.ENEMY, 2, Vector2i(3, 4))
	var ev := PhysicsResolver.resolve_attack(s, attacker, target, Vector2i(1, 0), 1, 1)
	tr.assert_eq("target hp", target.hp, 1)
	tr.assert_eq("target alive", target.alive, true)
	tr.assert_eq("target moved east 1", target.position, Vector2i(4, 4))
	tr.assert_true("events not empty", ev.size() > 0)

static func _test_push_off_board_fell(tr) -> void:
	var s := _make_state()
	var attacker := _add_unit(s, UnitDef.Faction.WARDEN, 2, Vector2i(6, 4))
	var target := _add_unit(s, UnitDef.Faction.ENEMY, 2, Vector2i(7, 4))
	# Push east 1 -> off board -> fell
	PhysicsResolver.resolve_attack(s, attacker, target, Vector2i(1, 0), 1, 1)
	tr.assert_eq("target removed from board after fall", s.find_unit(target.id), null)

static func _test_push_into_void_tile_fell(tr) -> void:
	var s := _make_state()
	s.grid.set_tile(Vector2i(4, 4), Grid.TileType.VOID)
	var attacker := _add_unit(s, UnitDef.Faction.WARDEN, 2, Vector2i(2, 4))
	var target := _add_unit(s, UnitDef.Faction.ENEMY, 2, Vector2i(3, 4))
	var events := PhysicsResolver.resolve_attack(s, attacker, target, Vector2i(1, 0), 1, 1)
	tr.assert_eq("target removed after void fall", s.find_unit(target.id), null)
	var marked := false
	for e in events:
		if e.type == BattleEvent.Type.UNIT_FELL and bool(e.extra.get("void_tile", false)):
			marked = true
	tr.assert_true("void fall marks event", marked)

static func _test_push_off_abyss_edge_marks_event(tr) -> void:
	var s := _make_state()
	s.abyss_edges[Vector2i(7, 4)] = {Vector2i(1, 0): true}
	var attacker := _add_unit(s, UnitDef.Faction.WARDEN, 2, Vector2i(6, 4))
	var target := _add_unit(s, UnitDef.Faction.ENEMY, 2, Vector2i(7, 4))
	var events := PhysicsResolver.resolve_attack(s, attacker, target, Vector2i(1, 0), 1, 1)
	var marked := false
	for e in events:
		if e.type == BattleEvent.Type.UNIT_FELL and bool(e.extra.get("abyss_edge", false)):
			marked = true
	tr.assert_true("abyss edge fall marks event", marked)

static func _test_push_into_pillar_wall_bump(tr) -> void:
	var s := _make_state()
	s.grid.set_tile(Vector2i(4, 4), Grid.TileType.PILLAR)
	var attacker := _add_unit(s, UnitDef.Faction.WARDEN, 2, Vector2i(2, 4))
	var target := _add_unit(s, UnitDef.Faction.ENEMY, 3, Vector2i(3, 4))
	# Push east 1: target hits pillar at (4,4) -> 1 dmg from attack + 1 wall = 2 total
	PhysicsResolver.resolve_attack(s, attacker, target, Vector2i(1, 0), 1, 1)
	tr.assert_eq("target hp after wall bump", target.hp, 1)
	tr.assert_eq("target stays at (3,4)", target.position, Vector2i(3, 4))

static func _test_zero_force_just_damage(tr) -> void:
	var s := _make_state()
	var attacker := _add_unit(s, UnitDef.Faction.WARDEN, 2, Vector2i(2, 4))
	var target := _add_unit(s, UnitDef.Faction.ENEMY, 1, Vector2i(3, 4))
	PhysicsResolver.resolve_attack(s, attacker, target, Vector2i(1, 0), 0, 1)
	tr.assert_eq("zero-force kill removes target", s.find_unit(target.id), null)
