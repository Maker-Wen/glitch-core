extends RefCounted
## Verifies Carrion attack adjacency: Carrion can attack a warden only when
## (after its planned move) it ends up at manhattan distance 1 from the warden.
## In particular: a non-collinear enemy that cannot reach adjacency in one
## move must NOT receive an attack plan.

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_bh() -> UnitDef:
	return TestUnitDefs.bountyhunter()

static func _make_carrion(move: int = -1) -> UnitDef:
	if move < 0:
		return TestUnitDefs.carrion_spawn()
	return TestUnitDefs.carrion_spawn({"move": move})

static func _add(s: BattleState, def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	s.units.append(u)
	return u

static func run(tr) -> void:
	## ITB-style rule: enemy moves AT ROUND START (visible), then attacks at
	## ROUND END. An enemy that can reach adjacency via its planned move WILL
	## attack from the post-move position later that round. An enemy too far
	## to reach adjacency this turn only moves (no attack target set).
	_test_adjacent_attacks_no_move(tr)
	_test_close_enemy_moves_then_attacks(tr)
	_test_far_enemy_only_moves(tr)
	_test_attacks_imply_adjacent_post_move(tr)

static func _test_adjacent_attacks_no_move(tr) -> void:
	# Carrion already adjacent -> attack from current position, no move.
	var s := BattleState.new()
	s.grid = Grid.new()
	var bh := _add(s, _make_bh(), Vector2i(3, 3))
	var carrion := _add(s, _make_carrion(3), Vector2i(3, 4))
	var plans := AIDecider.plan_enemy_turn(s)
	var plan = plans[carrion.id]
	tr.assert_true("attack planned (adjacent)", plan.has_attack())
	tr.assert_eq("attack target = warden cell", plan.attack_pos, bh.position)
	tr.assert_eq("no move (move_to = current)", plan.move_to, carrion.position)

static func _test_close_enemy_moves_then_attacks(tr) -> void:
	# Carrion 3 cells away, move=3, can reach adjacency via path.
	# Plan should include BOTH a move AND an attack (executed in sequence:
	# move at round start, attack at round end).
	var s := BattleState.new()
	s.grid = Grid.new()
	var bh := _add(s, _make_bh(), Vector2i(3, 3))
	var carrion := _add(s, _make_carrion(3), Vector2i(5, 4))
	var plans := AIDecider.plan_enemy_turn(s)
	var plan = plans[carrion.id]
	tr.assert_true("move planned", plan.move_to != carrion.position)
	tr.assert_true("attack planned (will be adjacent post-move)", plan.has_attack())
	tr.assert_eq("attack target = warden cell", plan.attack_pos, bh.position)
	tr.assert_eq("move ends adjacent to warden", Grid.manhattan(plan.move_to, bh.position), 1)

static func _test_far_enemy_only_moves(tr) -> void:
	# Carrion too far -- can move but won't reach adjacency this turn.
	# Should have a move plan but NO attack plan.
	var s := BattleState.new()
	s.grid = Grid.new()
	var bh := _add(s, _make_bh(), Vector2i(0, 3))
	var carrion := _add(s, _make_carrion(3), Vector2i(7, 3))
	# Manhattan 7, move=3, can't bridge in one turn.
	var plans := AIDecider.plan_enemy_turn(s)
	var plan = plans[carrion.id]
	tr.assert_true("move planned", plan.move_to != carrion.position)
	tr.assert_true("no attack (too far to reach adjacency)", not plan.has_attack())
	tr.assert_true("moved closer", Grid.manhattan(plan.move_to, bh.position) < Grid.manhattan(carrion.position, bh.position))

static func _test_attacks_imply_adjacent_post_move(tr) -> void:
	# Sweep board: whenever an attack is planned, the post-move cell MUST be
	# adjacent to the warden. (Validates we never plan an attack from a cell
	# that can't actually reach the target.)
	var failures: int = 0
	for cx in range(8):
		for cy in range(8):
			if cx == 3 and cy == 3:
				continue
			var s := BattleState.new()
			s.grid = Grid.new()
			var bh := _add(s, _make_bh(), Vector2i(3, 3))
			var carrion := _add(s, _make_carrion(3), Vector2i(cx, cy))
			var plans := AIDecider.plan_enemy_turn(s)
			var plan = plans[carrion.id]
			if plan.has_attack():
				if Grid.manhattan(plan.move_to, bh.position) != 1:
					failures += 1
	tr.assert_eq("all attacks have adjacent post-move", failures, 0)
