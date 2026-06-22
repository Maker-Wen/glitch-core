extends RefCounted
## Grid pathfinding + tie-break tests.

static func run(tr) -> void:
	_test_bounds(tr)
	_test_reachable_no_blockers(tr)
	_test_reachable_blocked(tr)
	_test_void_blocks_movement_and_path_target(tr)
	_test_path_tie_break_NESW(tr)

static func _test_bounds(tr) -> void:
	var g := Grid.new()
	tr.assert_true("in_bounds (0,0)", g.in_bounds(Vector2i(0, 0)))
	tr.assert_true("in_bounds (7,7)", g.in_bounds(Vector2i(7, 7)))
	tr.assert_true("out of bounds (-1,0)", not g.in_bounds(Vector2i(-1, 0)))
	tr.assert_true("out of bounds (8,0)", not g.in_bounds(Vector2i(8, 0)))

static func _test_reachable_no_blockers(tr) -> void:
	var g := Grid.new()
	var cells := g.reachable_cells(Vector2i(3, 3), 2, {})
	# Manhattan distance <= 2 from (3,3), excluding (3,3) itself = 12 cells
	tr.assert_eq("reachable cells count (range=2)", cells.size(), 12)

static func _test_reachable_blocked(tr) -> void:
	var g := Grid.new()
	g.set_tile(Vector2i(3, 4), Grid.TileType.PILLAR)
	var cells := g.reachable_cells(Vector2i(3, 3), 1, {})
	# From (3,3) range 1 should reach (2,3) (3,2) (4,3) but NOT (3,4)
	tr.assert_eq("reachable with pillar block", cells.size(), 3)
	tr.assert_true("pillar cell not reachable", not (Vector2i(3, 4) in cells))

static func _test_void_blocks_movement_and_path_target(tr) -> void:
	var g := Grid.new()
	g.set_tile(Vector2i(4, 3), Grid.TileType.VOID)
	var cells := g.reachable_cells(Vector2i(3, 3), 1, {})
	tr.assert_true("void blocks movement", g.blocks_movement(Vector2i(4, 3)))
	tr.assert_true("void cell not reachable", not (Vector2i(4, 3) in cells))
	tr.assert_true("void cannot be path target", g.find_path(Vector2i(3, 3), Vector2i(4, 3), {}).is_empty())

static func _test_path_tie_break_NESW(tr) -> void:
	# Path from (3,3) to (4,2) -- N or E both 1-step. N=(3,2) wins, then E=(4,2).
	var g := Grid.new()
	var path := g.find_path(Vector2i(3, 3), Vector2i(4, 2), {})
	tr.assert_eq("path length", path.size(), 2)
	tr.assert_eq("first step is north", path[0], Vector2i(3, 2))
	tr.assert_eq("final cell", path[1], Vector2i(4, 2))
