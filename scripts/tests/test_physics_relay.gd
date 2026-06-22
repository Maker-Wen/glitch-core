extends RefCounted
## PhysicsResolver relay (chain bump) tests -- the core physics fun.

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _add(s: BattleState, faction: int, hp: int, pos: Vector2i) -> Unit:
	var def := TestUnitDefs.generic_warden({"max_hp": hp}) if faction == UnitDef.Faction.WARDEN else TestUnitDefs.generic_enemy({"max_hp": hp})
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	u.hp = hp
	s.units.append(u)
	return u

static func run(tr) -> void:
	_test_relay_push2_kills_second(tr)
	_test_relay_chain_three_in_line(tr)
	_test_relay_dead_unit_still_occupies(tr)

static func _test_relay_push2_kills_second(tr) -> void:
	# A at (2,4); B at (3,4) hp=1; C at (4,4) hp=1.
	# Push B east 2. B takes 1 dmg -> dies. Remaining push 1 transferred to C.
	# C takes 1 dmg -> dies. Both removed.
	var s := BattleState.new()
	var a := _add(s, UnitDef.Faction.WARDEN, 2, Vector2i(2, 4))
	var b := _add(s, UnitDef.Faction.ENEMY, 1, Vector2i(3, 4))
	var c := _add(s, UnitDef.Faction.ENEMY, 1, Vector2i(4, 4))
	PhysicsResolver.resolve_attack(s, a, b, Vector2i(1, 0), 2, 1)
	tr.assert_eq("B removed", s.find_unit(b.id), null)
	tr.assert_eq("C removed", s.find_unit(c.id), null)

static func _test_relay_chain_three_in_line(tr) -> void:
	# A pushes B east 1 (force=1). B takes 1 dmg from attack -> hp=1.
	# B slides east: cell (4,4)=C -> bump. C takes 1 dmg (bump always damages),
	# remaining force=0 transferred to C so C does NOT move. B stops short of (4,4).
	# Per truth_table §3.5: "U 受 1 伤" regardless of transferred force.
	var s := BattleState.new()
	var a := _add(s, UnitDef.Faction.WARDEN, 2, Vector2i(2, 4))
	var b := _add(s, UnitDef.Faction.ENEMY, 2, Vector2i(3, 4))
	var c := _add(s, UnitDef.Faction.ENEMY, 2, Vector2i(4, 4))
	PhysicsResolver.resolve_attack(s, a, b, Vector2i(1, 0), 1, 1)
	tr.assert_eq("B hp after relay-no-force", b.hp, 1)
	tr.assert_eq("B stays at (3,4)", b.position, Vector2i(3, 4))
	tr.assert_eq("C takes bump damage", c.hp, 1)
	tr.assert_eq("C does not move (transferred=0)", c.position, Vector2i(4, 4))

static func _test_relay_dead_unit_still_occupies(tr) -> void:
	# A pushes B (hp=1) east 2. B dies on impact, transferred=1 to C, C pushed
	# east 1 to empty cell. B then removed at Tend; cell (3,4) becomes empty.
	# A is not moved (it was the attacker, only B/C are pushed).
	# Net: B gone, C at (5,4), A still at (2,4).
	var s := BattleState.new()
	var a := _add(s, UnitDef.Faction.WARDEN, 2, Vector2i(2, 4))
	var b := _add(s, UnitDef.Faction.ENEMY, 1, Vector2i(3, 4))
	var c := _add(s, UnitDef.Faction.ENEMY, 2, Vector2i(4, 4))
	PhysicsResolver.resolve_attack(s, a, b, Vector2i(1, 0), 2, 1)
	tr.assert_eq("B removed", s.find_unit(b.id), null)
	tr.assert_eq("C pushed to (5,4)", c.position, Vector2i(5, 4))
	tr.assert_eq("C alive", c.alive, true)
	tr.assert_eq("A still at start", a.position, Vector2i(2, 4))
