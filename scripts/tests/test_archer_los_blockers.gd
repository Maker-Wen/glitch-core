extends RefCounted

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_warden() -> UnitDef:
	return TestUnitDefs.generic_warden({"max_hp": 3, "move": 2})

static func _enemy(def_id: StringName, move: int, attack_kind: int, attack_range: int = 1) -> UnitDef:
	return TestUnitDefs.generic_enemy({
		"def_id": def_id,
		"max_hp": 2,
		"move": move,
		"attack_kind": attack_kind,
		"attack_range": attack_range,
		"attack_damage": 1,
		"attack_force": 0,
	})

static func _add(s: BattleState, def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	s.units.append(u)
	return u

static func run(tr) -> void:
	_test_archer_avoids_friend_blocked_los_cell(tr)

static func _test_archer_avoids_friend_blocked_los_cell(tr) -> void:
	var s := BattleState.new()
	var building := Vector2i(3, 4)
	s.grid.set_tile(building, Grid.TileType.BUILDING, 2)
	s.protected_targets = [building]
	s.capture_protected_initial_hp()
	_add(s, _make_warden(), Vector2i(7, 7))
	var blocker := _add(s, _enemy(&"blocker", 0, UnitDef.AttackKind.MELEE_BUMP), Vector2i(3, 3))
	var archer := _add(s, _enemy(&"archer", 2, UnitDef.AttackKind.RANGED_PUSH, 3), Vector2i(1, 2))
	var plan = AIDecider.plan_enemy_turn(s)[archer.id]
	tr.assert_true("archer does not pick LOS cell behind blocker", plan.move_to != Vector2i(3, 2))
	tr.assert_true("blocker remains between target and rejected cell", blocker.position == Vector2i(3, 3))
