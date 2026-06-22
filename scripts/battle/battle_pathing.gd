class_name BattlePathing extends RefCounted
## Shared battle pathing helpers.
##
## Path blockers and final-claim rules are intentionally separate:
## same-faction units may be crossed, but already occupied / claimed cells are
## not valid destinations.

const NO_CELL := Vector2i(-1, -1)

static func opponent_blockers_for_enemies(state: BattleState) -> Dictionary:
	var blocked: Dictionary = {}
	for u in state.wardens():
		blocked[u.position] = true
	return blocked

static func best_step_toward(
	state: BattleState,
	unit: Unit,
	goal: Vector2i,
	blocked: Dictionary,
	claimed: Dictionary,
	move_override: int = -1
) -> Vector2i:
	## Walk up to `unit.def.move` cells, choosing the reachable unclaimed cell
	## that most reduces the remaining path length to `goal`.
	var move_steps := unit.def.move if move_override < 0 else move_override
	var reachable := state.grid.reachable_cells(unit.position, move_steps, blocked)
	if reachable.is_empty():
		return unit.position
	var origin_remaining := path_length_from_cell(state, unit.position, goal, blocked)
	var best := unit.position
	var best_remaining := origin_remaining
	for candidate in reachable:
		if claimed.has(candidate):
			continue
		var remaining := path_length_from_cell(state, candidate, goal, blocked)
		if remaining == -1:
			continue
		if best_remaining == -1 or remaining < best_remaining:
			best_remaining = remaining
			best = candidate
	return best

static func shortest_adjacent_cell_to_pos(
	state: BattleState,
	unit: Unit,
	target_pos: Vector2i,
	blocked: Dictionary,
	claimed: Dictionary
) -> Vector2i:
	return shortest_neighbor_at_step(state, unit, target_pos, 1, blocked, claimed)

static func shortest_line_of_sight_cell_to_pos(
	state: BattleState,
	unit: Unit,
	target_pos: Vector2i,
	blocked: Dictionary,
	claimed: Dictionary,
	shadow: Dictionary
) -> Vector2i:
	var best := NO_CELL
	var best_len: int = 1 << 30
	for d in Grid.DIRS:
		for step in range(1, unit.def.attack_range + 1):
			var cand: Vector2i = target_pos + d * step
			if not state.grid.in_bounds(cand) or state.grid.blocks_movement(cand):
				break
			if cand != unit.position and claimed.has(cand):
				continue
			if not line_terrain_clear(state, target_pos, d, step):
				continue
			if not line_units_clear(target_pos, d, step, unit.id, shadow):
				continue
			var path_len := path_length(state, unit, cand, blocked)
			if path_len == -1:
				continue
			if path_len < best_len:
				best_len = path_len
				best = cand
	return best

static func shortest_neighbor_at_step(
	state: BattleState,
	unit: Unit,
	target_pos: Vector2i,
	step: int,
	blocked: Dictionary,
	claimed: Dictionary
) -> Vector2i:
	var best := NO_CELL
	var best_len: int = 1 << 30
	for d in Grid.DIRS:
		var cand: Vector2i = target_pos + d * step
		if not state.grid.in_bounds(cand) or state.grid.blocks_movement(cand):
			continue
		if cand != unit.position and claimed.has(cand):
			continue
		var path_len := path_length(state, unit, cand, blocked)
		if path_len == -1:
			continue
		if path_len < best_len:
			best_len = path_len
			best = cand
	return best

static func path_length(state: BattleState, unit: Unit, cand: Vector2i, blocked: Dictionary) -> int:
	if cand == unit.position:
		return 0
	return path_length_from_cell(state, unit.position, cand, blocked)

static func path_length_from_cell(state: BattleState, from: Vector2i, to: Vector2i, blocked: Dictionary) -> int:
	if from == to:
		return 0
	var p := state.grid.find_path(from, to, blocked)
	return -1 if p.is_empty() else p.size()

static func line_terrain_clear(state: BattleState, from: Vector2i, dir: Vector2i, steps: int) -> bool:
	for k in range(1, steps):
		var p: Vector2i = from + dir * k
		if state.grid.blocks_movement(p):
			return false
	return true

static func line_units_clear(from: Vector2i, dir: Vector2i, steps: int, self_id: int, shadow: Dictionary) -> bool:
	for k in range(1, steps):
		var p: Vector2i = from + dir * k
		for uid in shadow.keys():
			if int(uid) == self_id:
				continue
			if shadow[uid] == p:
				return false
	return true
