extends RefCounted
## Pull = push in the opposite direction (toward the attacker).

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _add(s: BattleState, faction: int, hp: int, pos: Vector2i) -> Unit:
	var def := TestUnitDefs.generic_warden({"max_hp": hp}) if faction == UnitDef.Faction.WARDEN else TestUnitDefs.generic_enemy({"max_hp": hp})
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	u.hp = hp
	s.units.append(u)
	return u

static func run(tr) -> void:
	_test_pull_toward_attacker(tr)
	_test_pull_blocked_by_friendly(tr)

static func _test_pull_toward_attacker(tr) -> void:
	# Attacker at (2,4); target at (5,4). Pull 1: target moves west to (4,4).
	var s := BattleState.new()
	var a := _add(s, UnitDef.Faction.WARDEN, 2, Vector2i(2, 4))
	var t := _add(s, UnitDef.Faction.ENEMY, 2, Vector2i(5, 4))
	# Direction from target toward attacker = west (-1, 0)
	PhysicsResolver.resolve_attack(s, a, t, Vector2i(-1, 0), 1, 1)
	tr.assert_eq("pulled west by 1", t.position, Vector2i(4, 4))
	tr.assert_eq("target hp", t.hp, 1)

static func _test_pull_blocked_by_friendly(tr) -> void:
	# Pull T west by 3 (force=3). Setup: A at (0,4), F at (3,4), T at (6,4).
	# Step 1: T slides from (6,4) west to (5,4); remaining=2.
	# Step 2: T slides from (5,4) west to (4,4); remaining=1.
	# Step 3: cell (3,4) has F -> bump. attacker=warden, F=warden -> friendly-
	# fire rule kicks in: F takes 0 damage (but transferred force still 0).
	# F stays put, T stops at (4,4).
	var s := BattleState.new()
	var a := _add(s, UnitDef.Faction.WARDEN, 2, Vector2i(0, 4))
	var f := _add(s, UnitDef.Faction.WARDEN, 2, Vector2i(3, 4))
	var t := _add(s, UnitDef.Faction.ENEMY, 3, Vector2i(6, 4))
	PhysicsResolver.resolve_attack(s, a, t, Vector2i(-1, 0), 3, 1)
	tr.assert_eq("F NOT damaged (friendly-fire disabled)", f.hp, 2)
	tr.assert_eq("F stays put (transferred=0)", f.position, Vector2i(3, 4))
	tr.assert_eq("T stops at (4,4)", t.position, Vector2i(4, 4))
