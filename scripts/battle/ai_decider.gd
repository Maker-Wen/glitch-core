class_name AIDecider extends RefCounted
## Enemy AI planning. Strictly deterministic; same state in -> same plan out.
##
## Behavior by attack_kind:
##   MELEE_BUMP / MELEE_PUSH:
##     - Score protected buildings and wardens as candidate targets.
##     - Walk toward the best target; if landing adjacent, queue attack.
##   RANGED_PUSH / RANGED_PULL:
##     - Cardinal-line scan within attack_range.
##     - Protected building / warden in line -> stand still + attack along that direction.
##     - Otherwise -> walk to a cell with LOS to the best target (or fall back to adjacency).
##
## See docs/game_design.md §4.5, docs/design/round_flow_and_intent.md, and
## docs/design/ui_decision_rules.md §1 for the AI tie-break rules.

const _BattlePathing = preload("res://scripts/battle/battle_pathing.gd")
const _EnemyTargeting = preload("res://scripts/battle/enemy_targeting.gd")

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
	var blocked_by_opponents := _BattlePathing.opponent_blockers_for_enemies(state)
	for enemy in melee:
		var plan := _plan_melee(state, enemy, claimed, blocked_by_opponents)
		plans[enemy.id] = plan
		_update_claimed(claimed, enemy, plan)

	# Phase 2: ranged. Use shadow positions reflecting where melee enemies
	# will be after their moves resolve.
	var shadow := _build_shadow_positions(state, plans)
	for enemy in ranged:
		var plan := _plan_ranged(state, enemy, claimed, blocked_by_opponents, shadow)
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
		plan.attack_pos = _EnemyTargeting.scan_line_for_attack_target(state, enemy.position, enemy.def.attack_range, enemy.id)
	else:
		plan.attack_pos = _EnemyTargeting.adjacent_attack_target_cell(state, enemy.position, enemy)


# ---------- melee planner ----------

static func _plan_melee(state: BattleState, enemy: Unit, claimed: Dictionary, blocked: Dictionary) -> EnemyPlan:
	var plan := _new_plan(enemy)
	var target_pos := _EnemyTargeting.best_attack_target_pos(state, enemy)
	if target_pos == Vector2i(-1, -1):
		return plan
	if Grid.manhattan(enemy.position, target_pos) == 1:
		plan.attack_pos = target_pos
		return plan
	# Move toward the cell adjacent to the target.
	var goal := _BattlePathing.shortest_adjacent_cell_to_pos(state, enemy, target_pos, blocked, claimed)
	if goal == Vector2i(-1, -1):
		return plan
	plan.move_to = _BattlePathing.best_step_toward(state, enemy, goal, blocked, claimed)
	if Grid.manhattan(plan.move_to, target_pos) == 1:
		plan.attack_pos = target_pos
	return plan


# ---------- ranged planner ----------

static func _plan_ranged(state: BattleState, enemy: Unit, claimed: Dictionary, blocked: Dictionary, shadow: Dictionary) -> EnemyPlan:
	var plan := _new_plan(enemy)
	# Try to shoot from the current position first, using post-melee-move shadow.
	plan.attack_pos = _EnemyTargeting.scan_with_shadow(state, enemy.position, enemy.def.attack_range, enemy.id, shadow)
	if plan.has_attack():
		return plan
	# No target -> walk toward a protected target / warden, prefer cells with line-of-sight.
	var target_pos := _EnemyTargeting.best_attack_target_pos(state, enemy)
	if target_pos == Vector2i(-1, -1):
		return plan
	var goal := _BattlePathing.shortest_line_of_sight_cell_to_pos(state, enemy, target_pos, blocked, claimed, shadow)
	if goal == Vector2i(-1, -1):
		goal = _BattlePathing.shortest_adjacent_cell_to_pos(state, enemy, target_pos, blocked, claimed)
	if goal == Vector2i(-1, -1):
		return plan
	plan.move_to = _BattlePathing.best_step_toward(state, enemy, goal, blocked, claimed)
	# Re-check after the projected move.
	if plan.move_to != Vector2i(-1, -1):
		plan.attack_pos = _EnemyTargeting.scan_with_shadow(state, plan.move_to, enemy.def.attack_range, enemy.id, shadow)
	return plan

# ---------- shared helpers ----------

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

static func _new_plan(enemy: Unit) -> EnemyPlan:
	var plan := EnemyPlan.new()
	plan.origin_pos = enemy.position
	plan.move_to = enemy.position
	return plan

static func _is_ranged(def: UnitDef) -> bool:
	return def.attack_kind == UnitDef.AttackKind.RANGED_PUSH \
		or def.attack_kind == UnitDef.AttackKind.RANGED_PULL
