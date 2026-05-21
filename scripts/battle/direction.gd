class_name Direction extends RefCounted
## Helpers for converting between cell deltas and 4-direction unit vectors.
## All grid logic is 4-directional (N/E/S/W); no diagonals.

## Returns the unit vector representing the cardinal direction from `from` to
## `to`. Returns Vector2i.ZERO if they are equal or not collinear (i.e. on a
## diagonal). Callers can use the zero result as a "not a valid line" sentinel.
static func from_cells(from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return Vector2i.ZERO
	var delta := to - from
	if delta.x != 0 and delta.y != 0:
		return Vector2i.ZERO  # diagonal -- not a cardinal direction
	if delta.x != 0:
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))

## True iff `from` and `to` are on the same cardinal line within `max_range`
## cells, and the path between (exclusive of `to`) is clear of pillars,
## buildings, out-of-bounds, and OTHER units. Used to validate ranged attacks
## are still firing-legal after a player turn.
##
## `state` provides terrain + unit occupancy.
## `from`, `to`: cells.
## `max_range`: maximum collinear distance allowed.
static func has_clear_line(state: BattleState, from: Vector2i, to: Vector2i, max_range: int) -> bool:
	var dir: Vector2i = from_cells(from, to)
	if dir == Vector2i.ZERO:
		return false
	var steps: int = absi(to.x - from.x) + absi(to.y - from.y)
	if steps > max_range:
		return false
	# Walk cells strictly between `from` and `to` -- any blocker breaks line.
	for k in range(1, steps):
		var p: Vector2i = from + dir * k
		if not state.grid.in_bounds(p):
			return false
		if state.grid.blocks_movement(p):
			return false
		if state.get_alive_unit_at(p) != null:
			return false
	return true
