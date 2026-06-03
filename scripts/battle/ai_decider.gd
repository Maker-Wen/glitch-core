class_name AIDecider extends RefCounted
## Enemy AI planning. Strictly deterministic; same state in -> same plan out.
##
## Behavior by attack_kind:
##   MELEE_BUMP / MELEE_PUSH:
##     - If protected targets exist, walk toward the nearest protected building.
##     - Otherwise, walk toward nearest warden; if landing adjacent, queue attack.
##   RANGED_PUSH / RANGED_PULL:
##     - Cardinal-line scan within attack_range.
##     - Protected building / warden in line -> stand still + attack along that direction.
##     - Otherwise -> walk to a cell with LOS to the target (or fall back to adjacency).
##
## See docs/game_design.md §4.5, docs/design/round_flow_and_intent.md, and
## docs/design/ui_decision_rules.md §1 for the AI tie-break rules.

class EnemyPlan extends RefCounted:
	## Position when the plan was made. Used by the engine to detect "the
	## player displaced this enemy" so it can collapse the locked attack.
	var origin_pos: Vector2i = Vector2i(-1, -1)
	var move_to: Vector2i = Vector2i(-1, -1)
	var attack_pos: Vector2i = Vector2i(-1, -1)  ## (-1,-1) means "no attack this turn"

	func has_attack() -> bool:
		return attack_pos != Vector2i(-1, -1)


# ---------- public API ----------

## Returns {unit_id: EnemyPlan}. Two-phase so ranged enemies see where melee
## enemies will be after they move (avoids "shoot at unit that's about to walk
## off the line" bugs).
static func plan_enemy_turn(state: BattleState) -> Dictionary:
	var plans: Dictionary = {}
	var melee: Array[Unit] = []
	var ranged: Array[Unit] = []
	for u in state.enemies():
		if u.def == null:
			continue
		if _is_ranged(u.def):
			ranged.append(u)
		else:
			melee.append(u)
	melee.sort_custom(func(a, b): return a.id < b.id)
	ranged.sort_custom(func(a, b): return a.id < b.id)

	# Phase 1: melee. Update `claimed` as each plan resolves so two enemies
	# don't claim the same destination.
	var claimed := state.occupied_cells()
	for enemy in melee:
		var plan := _plan_melee(state, enemy, claimed)
		plans[enemy.id] = plan
		_update_claimed(claimed, enemy, plan)

	# Phase 2: ranged. Use shadow positions reflecting where melee enemies
	# will be after their moves resolve.
	var shadow := _build_shadow_positions(state, plans)
	for enemy in ranged:
		var plan := _plan_ranged(state, enemy, claimed, shadow)
		plans[enemy.id] = plan
		_update_claimed(claimed, enemy, plan)
	return plans

## Recomputes only the attack portion of a plan based on the current state.
## Used by BattleEngine after enemies have actually moved at round start --
## the move portion is locked, but the attack target may need updating.
static func replan_attack_only(state: BattleState, enemy: Unit, plan: EnemyPlan) -> void:
	# The move part is done; the enemy is at its new position. Lock in the
	# new origin/move_to to the current cell so displacement checks compare
	# against where the enemy actually stands.
	plan.origin_pos = enemy.position
	plan.move_to = enemy.position
	if _is_ranged(enemy.def):
		plan.attack_pos = scan_line_for_attack_target(state, enemy.position, enemy.def.attack_range, enemy.id)
	else:
		plan.attack_pos = _find_adjacent_attack_target_cell(state, enemy.position)


## 4-direction line scan for the first WARDEN in cardinal range of `from`.
## Returns the warden's cell, or (-1,-1) if no target. Non-warden units
## block the line (treated as walls); pillars / out-of-bounds also block.
##
## Direction tie-break: N -> E -> S -> W.
##
## Design note: enemies never target other enemies (slice simplification).
static func scan_line_for_warden(state: BattleState, from: Vector2i, range_steps: int, self_id: int) -> Vector2i:
	for d in Grid.DIRS:
		for step in range(1, range_steps + 1):
			var p: Vector2i = from + d * step
			if not state.grid.in_bounds(p) or state.grid.blocks_movement(p):
				break
			var u := state.get_alive_unit_at(p)
			if u == null or u.id == self_id:
				continue
			if u.is_warden():
				return p
			break  # non-warden blocks the line
	return Vector2i(-1, -1)

static func scan_line_for_attack_target(state: BattleState, from: Vector2i, range_steps: int, self_id: int) -> Vector2i:
	for d in Grid.DIRS:
		for step in range(1, range_steps + 1):
			var p: Vector2i = from + d * step
			if not state.grid.in_bounds(p) or state.grid.blocks_movement(p):
				if state.grid.in_bounds(p) \
					and state.grid.get_tile(p) == Grid.TileType.BUILDING \
					and state.is_protected_target(p):
					return p
				break
			var u := state.get_alive_unit_at(p)
			if u == null or u.id == self_id:
				continue
			if u.is_warden():
				return p
			break  # non-warden blocks the line
	return Vector2i(-1, -1)


# ---------- melee planner ----------

static func _plan_melee(state: BattleState, enemy: Unit, claimed: Dictionary) -> EnemyPlan:
	var plan := _new_plan(enemy)
	var target_pos := _find_nearest_attack_target_pos(state, enemy)
	if target_pos == Vector2i(-1, -1):
		return plan
	if Grid.manhattan(enemy.position, target_pos) == 1:
		plan.attack_pos = target_pos
		return plan
	# Move toward the cell adjacent to the target.
	var goal := _shortest_adjacent_cell_to_pos(state, enemy, target_pos, _blocked_minus_self(claimed, enemy))
	if goal == Vector2i(-1, -1):
		return plan
	plan.move_to = _walk_toward(state, enemy, goal, _blocked_minus_self(claimed, enemy))
	if Grid.manhattan(plan.move_to, target_pos) == 1:
		plan.attack_pos = target_pos
	return plan


# ---------- ranged planner ----------

static func _plan_ranged(state: BattleState, enemy: Unit, claimed: Dictionary, shadow: Dictionary) -> EnemyPlan:
	var plan := _new_plan(enemy)
	# Try to shoot from the current position first, using post-melee-move shadow.
	plan.attack_pos = _scan_with_shadow(state, enemy.position, enemy.def.attack_range, enemy.id, shadow)
	if plan.has_attack():
		return plan
	# No target -> walk toward a protected target / warden, prefer cells with line-of-sight.
	var target_pos := _find_nearest_attack_target_pos(state, enemy)
	if target_pos == Vector2i(-1, -1):
		return plan
	var blocked := _blocked_minus_self(claimed, enemy)
	var goal := _shortest_line_of_sight_cell_to_pos(state, enemy, target_pos, blocked)
	if goal == Vector2i(-1, -1):
		goal = _shortest_adjacent_cell_to_pos(state, enemy, target_pos, blocked)
	if goal == Vector2i(-1, -1):
		return plan
	plan.move_to = _walk_toward(state, enemy, goal, blocked)
	# Re-check after the projected move.
	if plan.move_to != Vector2i(-1, -1):
		plan.attack_pos = _scan_with_shadow(state, plan.move_to, enemy.def.attack_range, enemy.id, shadow)
	return plan

## Shadow-aware scan: uses `shadow_positions[unit_id] = expected_cell` for
## locating units instead of `state.get_alive_unit_at`. This lets ranged
## enemies see where melee enemies WILL be after the move phase.
static func _scan_with_shadow(state: BattleState, from: Vector2i, range_steps: int, self_id: int, shadow: Dictionary) -> Vector2i:
	# Build position -> unit_id lookup from the shadow.
	var pos_to_id: Dictionary = {}
	for uid in shadow.keys():
		if uid == self_id:
			continue
		pos_to_id[shadow[uid]] = uid
	for d in Grid.DIRS:
		for step in range(1, range_steps + 1):
			var p: Vector2i = from + d * step
			if not state.grid.in_bounds(p) or state.grid.blocks_movement(p):
				if state.grid.in_bounds(p) \
					and state.grid.get_tile(p) == Grid.TileType.BUILDING \
					and state.is_protected_target(p):
					return p
				break
			if not pos_to_id.has(p):
				continue
			var blocker_id: int = pos_to_id[p]
			var blocker := state.find_unit(blocker_id)
			if blocker != null and blocker.is_warden():
				return p
			break  # non-warden blocks
	return Vector2i(-1, -1)


# ---------- pathfinding helpers ----------

static func _walk_toward(state: BattleState, enemy: Unit, goal: Vector2i, blocked: Dictionary) -> Vector2i:
	## Walk up to `enemy.def.move` cells along the shortest path toward `goal`.
	## Returns the final cell (may equal enemy.position if no path).
	var path := state.grid.find_path(enemy.position, goal, blocked)
	if path.is_empty():
		return enemy.position
	var steps := mini(enemy.def.move, path.size())
	return path[steps - 1]

static func _shortest_adjacent_cell_to_pos(state: BattleState, enemy: Unit, target_pos: Vector2i, blocked: Dictionary) -> Vector2i:
	## Pick the cell adjacent to `target_pos` with the shortest path from enemy.
	## N->E->S->W tie-break (Grid.DIRS order).
	return _shortest_neighbor_at_step(state, enemy, target_pos, 1, blocked)

static func _shortest_line_of_sight_cell_to_pos(state: BattleState, enemy: Unit, target_pos: Vector2i, blocked: Dictionary) -> Vector2i:
	## Pick the cell where enemy can shoot target along a cardinal line.
	## Searches up to enemy.def.attack_range cells away from target.
	## N->E->S->W tie-break for direction; nearest distance for step.
	var best := Vector2i(-1, -1)
	var best_len: int = 1 << 30
	for d in Grid.DIRS:
		for step in range(1, enemy.def.attack_range + 1):
			var cand: Vector2i = target_pos + d * step
			if not state.grid.in_bounds(cand) or state.grid.blocks_movement(cand):
				break
			if cand != enemy.position and blocked.has(cand):
				continue
			# Line from cand back to target must be clear of pillars.
			if not _line_terrain_clear(state, target_pos, d, step):
				continue
			var path_len := _path_length(state, enemy, cand, blocked)
			if path_len == -1:
				continue
			if path_len < best_len:
				best_len = path_len
				best = cand
	return best

static func _shortest_neighbor_at_step(state: BattleState, enemy: Unit, target_pos: Vector2i, step: int, blocked: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_len: int = 1 << 30
	for d in Grid.DIRS:
		var cand: Vector2i = target_pos + d * step
		if not state.grid.in_bounds(cand) or state.grid.blocks_movement(cand):
			continue
		if cand != enemy.position and blocked.has(cand):
			continue
		var path_len := _path_length(state, enemy, cand, blocked)
		if path_len == -1:
			continue
		if path_len < best_len:
			best_len = path_len
			best = cand
	return best

static func _path_length(state: BattleState, enemy: Unit, cand: Vector2i, blocked: Dictionary) -> int:
	if cand == enemy.position:
		return 0
	var p := state.grid.find_path(enemy.position, cand, blocked)
	return -1 if p.is_empty() else p.size()

static func _line_terrain_clear(state: BattleState, from: Vector2i, dir: Vector2i, steps: int) -> bool:
	for k in range(1, steps):
		var p: Vector2i = from + dir * k
		if state.grid.blocks_movement(p):
			return false
	return true


# ---------- shared helpers ----------

static func _find_nearest_warden(state: BattleState, enemy: Unit) -> Unit:
	var wardens := state.wardens()
	if wardens.is_empty():
		return null
	var best: Unit = null
	var best_dist: int = 1 << 30
	for w in wardens:
		var d := Grid.manhattan(enemy.position, w.position)
		if d < best_dist or (d == best_dist and best != null and w.id < best.id):
			best = w
			best_dist = d
	return best

static func _find_nearest_attack_target_pos(state: BattleState, enemy: Unit) -> Vector2i:
	var buildings := state.alive_protected_targets()
	if not buildings.is_empty():
		var best := Vector2i(-1, -1)
		var best_dist: int = 1 << 30
		var best_hp: int = 1 << 30
		for p in buildings:
			var d := Grid.manhattan(enemy.position, p)
			var hp: int = state.grid.tile_hp.get(p, Grid.DEFAULT_BUILDING_HP)
			if d < best_dist \
				or (d == best_dist and hp < best_hp) \
				or (d == best_dist and hp == best_hp and _cell_id(p) < _cell_id(best)):
				best = p
				best_dist = d
				best_hp = hp
		return best
	var warden := _find_nearest_warden(state, enemy)
	return warden.position if warden != null else Vector2i(-1, -1)

static func _find_adjacent_attack_target_cell(state: BattleState, from: Vector2i) -> Vector2i:
	## Returns an adjacent protected building first, then adjacent warden.
	var best_building := Vector2i(-1, -1)
	for d in Grid.DIRS:
		var p := from + d
		if state.grid.get_tile(p) == Grid.TileType.BUILDING and state.is_protected_target(p):
			if best_building == Vector2i(-1, -1) or _cell_id(p) < _cell_id(best_building):
				best_building = p
	if best_building != Vector2i(-1, -1):
		return best_building
	var best: Unit = null
	for d in Grid.DIRS:
		var t := state.get_alive_unit_at(from + d)
		if t == null or not t.is_warden():
			continue
		if best == null or t.id < best.id:
			best = t
	return best.position if best != null else Vector2i(-1, -1)

static func _build_shadow_positions(state: BattleState, plans: Dictionary) -> Dictionary:
	var shadow: Dictionary = {}
	for u in state.enemies():
		var plan = plans.get(u.id, null)
		if plan != null and plan.move_to != Vector2i(-1, -1):
			shadow[u.id] = plan.move_to
		else:
			shadow[u.id] = u.position
	for u in state.wardens():
		shadow[u.id] = u.position
	return shadow

static func _update_claimed(claimed: Dictionary, enemy: Unit, plan: EnemyPlan) -> void:
	if plan.move_to == Vector2i(-1, -1) or plan.move_to == enemy.position:
		return
	claimed.erase(enemy.position)
	claimed[plan.move_to] = true

static func _blocked_minus_self(claimed: Dictionary, enemy: Unit) -> Dictionary:
	var b := claimed.duplicate()
	b.erase(enemy.position)
	return b

static func _new_plan(enemy: Unit) -> EnemyPlan:
	var plan := EnemyPlan.new()
	plan.origin_pos = enemy.position
	plan.move_to = enemy.position
	return plan

static func _is_ranged(def: UnitDef) -> bool:
	return def.attack_kind == UnitDef.AttackKind.RANGED_PUSH \
		or def.attack_kind == UnitDef.AttackKind.RANGED_PULL

static func _cell_id(p: Vector2i) -> int:
	return p.y * Grid.SIZE + p.x
