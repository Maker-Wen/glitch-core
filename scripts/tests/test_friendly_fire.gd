extends RefCounted
## Verifies the slice's no-friendly-fire rule: same-faction collisions deal
## 0 bump damage. Relay physics still proceed.

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_bh() -> UnitDef:
	return TestUnitDefs.bountyhunter({"max_hp": 2})

static func _make_gr() -> UnitDef:
	return TestUnitDefs.graverobber({"max_hp": 2})

static func _make_carrion() -> UnitDef:
	return TestUnitDefs.carrion_spawn()

static func _add(s: BattleState, def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	s.units.append(u)
	return u

static func run(tr) -> void:
	_test_warden_chain_into_warden_no_damage(tr)
	_test_warden_chain_into_enemy_damages_enemy(tr)
	_test_enemy_chain_into_warden_damages_warden(tr)

static func _test_warden_chain_into_warden_no_damage(tr) -> void:
	# Warden A pulls an enemy through warden F. F takes 0 damage because the
	# original attacker (A) is the same faction as F. Enemy still gets pushed.
	var s := BattleState.new()
	s.grid = Grid.new()
	var a := _add(s, _make_gr(), Vector2i(0, 4))
	var f := _add(s, _make_bh(), Vector2i(3, 4))
	var t := _add(s, _make_carrion(), Vector2i(6, 4))
	# Pull T west by 3: T slides (6,4)→(5,4)→(4,4), then bumps F at (3,4).
	# attacker=GR(warden), F=warden -> 0 friendly damage. T stops at (4,4).
	PhysicsResolver.resolve_attack(s, a, t, Vector2i(-1, 0), 3, 1)
	tr.assert_eq("friendly warden takes 0 bump damage", f.hp, 2)
	tr.assert_eq("friendly warden stays put (transferred=0)", f.position, Vector2i(3, 4))
	tr.assert_eq("enemy stops at (4,4)", t.position, Vector2i(4, 4))

static func _test_warden_chain_into_enemy_damages_enemy(tr) -> void:
	# Warden pushes a carrion into another carrion. Attacker=warden, victim=
	# carrion -> DIFFERENT faction -> 1 damage (player intends to deal
	# collateral via chain).
	var s := BattleState.new()
	s.grid = Grid.new()
	var a := _add(s, _make_bh(), Vector2i(0, 4))
	var c1 := _add(s, _make_carrion(), Vector2i(3, 4))
	var c2 := _add(s, _make_carrion(), Vector2i(4, 4))
	PhysicsResolver.resolve_attack(s, a, c1, Vector2i(1, 0), 2, 1)
	tr.assert_eq("C1 took attack damage", c1.hp, 1)
	tr.assert_eq("C2 took 1 bump damage (attacker is enemy faction to C2)", c2.hp, 1)
	tr.assert_eq("C2 pushed east", c2.position, Vector2i(5, 4))
	tr.assert_eq("C1 took C2's old cell", c1.position, Vector2i(4, 4))

static func _test_enemy_chain_into_warden_damages_warden(tr) -> void:
	# Inverse: enemy initiates a push that bumps into a warden. Attacker=enemy,
	# victim=warden -> different faction -> 1 damage.
	# (Simulate this by using a Carrion as the "attacker" parameter -- though
	# Carrion's MELEE_BUMP normally has force=0, we manually force=2 for the test.)
	var s := BattleState.new()
	s.grid = Grid.new()
	var enemy_attacker := _add(s, _make_carrion(), Vector2i(0, 4))
	var pushed := _add(s, _make_bh(), Vector2i(3, 4))   # warden being shoved
	var f := _add(s, _make_bh(), Vector2i(4, 4))         # another warden in the way
	# Push pushed east by 2: chains into F. attacker=enemy, F=warden -> diff faction.
	PhysicsResolver.resolve_attack(s, enemy_attacker, pushed, Vector2i(1, 0), 2, 1)
	tr.assert_eq("primary warden took 1 attack damage", pushed.hp, 1)
	tr.assert_eq("second warden took 1 bump damage (enemy-initiated)", f.hp, 1)
