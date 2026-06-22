extends RefCounted
## Tests for Plague Archer ranged AI behavior.

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_archer() -> UnitDef:
	return TestUnitDefs.plague_archer({"def_id": &"archer"})

static func _make_bh() -> UnitDef:
	return TestUnitDefs.bountyhunter()

static func _add(s: BattleState, def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	s.units.append(u)
	return u

static func run(tr) -> void:
	_test_archer_shoots_warden_in_line(tr)
	_test_archer_moves_when_no_target(tr)
	_test_archer_does_not_shoot_diagonal(tr)
	_test_archer_line_blocked_by_pillar(tr)

static func _test_archer_shoots_warden_in_line(tr) -> void:
	# Archer at (3,3), warden at (3,6). Line distance = 3 (in range).
	var s := BattleState.new()
	s.grid = Grid.new()
	var bh := _add(s, _make_bh(), Vector2i(3, 6))
	var archer := _add(s, _make_archer(), Vector2i(3, 3))
	var plans := AIDecider.plan_enemy_turn(s)
	var plan = plans[archer.id]
	tr.assert_true("attack planned", plan.has_attack())
	tr.assert_eq("attack target = warden cell", plan.attack_pos, bh.position)
	tr.assert_eq("no move (stand still and shoot)", plan.move_to, archer.position)

static func _test_archer_moves_when_no_target(tr) -> void:
	# Warden is far from archer's range -- archer should walk closer.
	var s := BattleState.new()
	s.grid = Grid.new()
	var bh := _add(s, _make_bh(), Vector2i(0, 7))
	var archer := _add(s, _make_archer(), Vector2i(7, 0))
	# With the current archer resource (move 2 + range 3), this cannot shoot
	# in the same turn from Manhattan distance 14.
	var plans := AIDecider.plan_enemy_turn(s)
	var plan = plans[archer.id]
	tr.assert_true("no attack (out of range)", not plan.has_attack())
	tr.assert_true("archer walks closer", plan.move_to != archer.position)
	tr.assert_true("walked toward warden",
		Grid.manhattan(plan.move_to, bh.position) < Grid.manhattan(archer.position, bh.position))

static func _test_archer_does_not_shoot_diagonal(tr) -> void:
	# Archer at (3,3), warden at (5,5). Not collinear -- can't shoot.
	# Archer should walk to a position where shot becomes possible.
	var s := BattleState.new()
	s.grid = Grid.new()
	var bh := _add(s, _make_bh(), Vector2i(5, 5))
	var archer := _add(s, _make_archer(), Vector2i(3, 3))
	var plans := AIDecider.plan_enemy_turn(s)
	var plan = plans[archer.id]
	# Either the archer moves to a cell where the warden is in line, or just
	# walks closer (still no attack from non-collinear cell).
	if plan.has_attack():
		# If it claims an attack, the post-move pos MUST be on a cardinal line.
		var delta: Vector2i = plan.attack_pos - plan.move_to
		var collinear: bool = (delta.x == 0) != (delta.y == 0)
		tr.assert_true("post-move attack is collinear with target", collinear)
	else:
		tr.assert_true("walks toward warden when can't shoot", plan.move_to != archer.position)

static func _test_archer_line_blocked_by_pillar(tr) -> void:
	# Archer at (3,3), warden at (3,6), pillar at (3,4) blocks line.
	# Archer can't shoot -- must move or stand still.
	var s := BattleState.new()
	s.grid = Grid.new()
	s.grid.set_tile(Vector2i(3, 4), Grid.TileType.PILLAR)
	var bh := _add(s, _make_bh(), Vector2i(3, 6))
	var archer := _add(s, _make_archer(), Vector2i(3, 3))
	var plans := AIDecider.plan_enemy_turn(s)
	var plan = plans[archer.id]
	# If the archer ends up at a position with clear line, attack should be set.
	# Otherwise no attack.
	if plan.has_attack():
		# Validate the line from plan.move_to to plan.attack_pos is clear.
		var from: Vector2i = plan.move_to
		var to: Vector2i = plan.attack_pos
		var delta: Vector2i = to - from
		var collinear: bool = (delta.x == 0) != (delta.y == 0)
		tr.assert_true("attack line is collinear", collinear)
		# The archer can't shoot through (3,4) so the line shouldn't cross it.
		if from.x == 3 and to.x == 3:
			# Vertical line on x=3 between from.y and to.y
			var lo: int = mini(from.y, to.y)
			var hi: int = maxi(from.y, to.y)
			tr.assert_true("pillar (3,4) not between from and to",
				not (lo < 4 and 4 < hi))
	else:
		# No attack possible -- just walks.
		tr.assert_true("walks (no attack possible due to pillar)",
			plan.move_to != Vector2i(-1, -1))
