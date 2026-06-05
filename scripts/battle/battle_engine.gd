class_name BattleEngine extends RefCounted
## State-machine entry point. Validates and applies player + system actions.
## Emits BattleEvent streams that the view layer animates.
##
## Architecture:
##   - state: BattleState (mutable). Source of truth.
##   - apply_action(): real mutation + auto-advance turn.
##   - preview_action(): runs on a clone, returns events, no side effects.
##   - undo(): pops the history stack.
##
## Round flow is documented in docs/design/round_flow_and_intent.md.

signal events_produced(events: Array)
signal state_changed()

const MAX_UNDO := 50
const INTENT_STATUS_NO_ATTACK := "no_attack"
const INTENT_STATUS_HIT := "hit"
const INTENT_STATUS_MISS := "miss"
const INTENT_STATUS_REMOVED := "removed"
const TARGET_KIND_NONE := "none"
const TARGET_KIND_UNIT := "unit"
const TARGET_KIND_BUILDING := "building"

var state: BattleState
var _history: Array[BattleState] = []


# ---------- battle setup ----------

## Begin a new battle. Spawns enemies and enters GARRISON phase. Wardens are
## not placed yet -- the player deploys them via DEPLOY actions.
func start_battle(
	grid: Grid,
	warden_defs: Array,
	enemies: Array,
	deploy_zone: Array[Vector2i],
	rift_positions: Array[Vector2i] = [],
	rift_schedule: Array = [],
	max_rounds: int = 5,
	protected_targets: Array[Vector2i] = [],
	reward_tasks: Array = [],
	warden_starting_hp: Array[int] = [],
	boss_config: Dictionary = {},
	scripted_spawn_schedule: Array = [],
) -> Array[BattleEvent]:
	state = BattleState.new()
	state.grid = grid
	state.max_rounds = max_rounds
	for entry in enemies:
		_spawn_unit(entry["def"], entry["pos"])
	state.pending_warden_defs.clear()
	state.pending_warden_starting_hp.clear()
	for d in warden_defs:
		state.pending_warden_defs.append(d)
	for i in range(warden_defs.size()):
		var def: UnitDef = warden_defs[i]
		var hp := def.max_hp if def != null else 1
		if i < warden_starting_hp.size():
			hp = int(warden_starting_hp[i])
		state.pending_warden_starting_hp.append(clampi(hp, 1, def.max_hp if def != null else hp))
	state.placed_warden_ids.clear()
	state.deploy_zone.clear()
	for c in deploy_zone:
		state.deploy_zone[c] = true
	state.rift_positions = rift_positions.duplicate()
	for r in rift_positions:
		state.grid.set_tile(r, Grid.TileType.RIFT)
	state.rift_schedule = rift_schedule.duplicate(true)
	state.pending_rift_spawns.clear()
	state.scripted_spawn_schedule = scripted_spawn_schedule.duplicate(true)
	if protected_targets.is_empty():
		state.protected_targets = state.grid.cells_of_type(Grid.TileType.BUILDING)
	else:
		state.protected_targets = protected_targets.duplicate()
	for p in state.protected_targets:
		if state.grid.get_tile(p) == Grid.TileType.BUILDING and not state.grid.tile_hp.has(p):
			state.grid.tile_hp[p] = Grid.DEFAULT_BUILDING_HP
	state.configure_boss(boss_config)
	state.set_reward_tasks(reward_tasks)
	state.phase = BattleState.Phase.GARRISON
	_history.clear()
	events_produced.emit([])
	state_changed.emit()
	return []


# ---------- public API ----------

## Apply a player or system action to the real state. Emits events.
func apply_action(action: BattleAction) -> Array[BattleEvent]:
	if action.kind == BattleAction.Kind.UNDO:
		return undo()
	_push_history()
	var events := _dispatch_action(state, action)
	if action.kind == BattleAction.Kind.MOVE or action.kind == BattleAction.Kind.ATTACK:
		_check_battle_end(state, events)
		if state.outcome == BattleState.Outcome.UNDECIDED:
			_maybe_end_player_turn(state, events)
	state_changed.emit()
	events_produced.emit(events)
	return events

## Preview an action on a clone. Returns events, no side effects. The clone
## is discarded. Used by the view layer for hover-time predictions.
func preview_action(action: BattleAction) -> Array[BattleEvent]:
	return _dispatch_action(state.clone(), action)

## Returns the enemy intent rows consumed by board overlays and the HUD stack.
## Rows include non-hitting slots so UI can explain "this enemy still resolves,
## but the player has already made it miss."
func get_enemy_intent_ui_state() -> Array[Dictionary]:
	return _enemy_intent_ui_state_for_state(state)

## Preview a player action and return the resulting enemy intent rows without
## mutating the real battle state.
func preview_enemy_intent_ui_state(action: BattleAction) -> Array[Dictionary]:
	var clone := state.clone()
	var events := _dispatch_action(clone, action)
	return _merge_preview_intent_rows(
		_enemy_intent_ui_state_for_state(clone),
		_removed_enemy_ids_from_events(events),
		state,
	)

## Undo to the most recent history snapshot. View should hard-rebuild from
## `state` (no event animation).
func undo() -> Array[BattleEvent]:
	if _history.is_empty():
		return []
	state = _history.pop_back()
	state_changed.emit()
	return []


# ---------- legality queries (used by view layer + input) ----------

func get_legal_moves(unit_id: int) -> Array[Vector2i]:
	var u := state.find_unit(unit_id)
	if u == null or not u.is_warden() or u.has_acted or u.has_moved:
		return []
	if state.phase != BattleState.Phase.PLAYER_ACTION:
		return []
	return state.grid.reachable_cells(u.position, u.def.move, state.occupied_cells(u.id))

func get_legal_attack_targets(unit_id: int) -> Array[Vector2i]:
	var u := state.find_unit(unit_id)
	if u == null or not u.is_warden() or state.phase != BattleState.Phase.PLAYER_ACTION:
		return []
	var result: Array[Vector2i] = []
	if _is_melee(u.def):
		for d in Grid.DIRS:
			var target_pos := u.position + d
			if _is_warden_attackable_tile(state, target_pos):
				result.append(target_pos)
				continue
			var t := state.get_alive_unit_at(target_pos)
			if t != null and t.is_enemy():
				result.append(target_pos)
	else:
		# Ranged: scan each cardinal line; lock first ENEMY in range. UI never
		# exposes friendly targets (friendly-fire is disabled in the slice).
		for d in Grid.DIRS:
			for step in range(1, u.def.attack_range + 1):
				var p: Vector2i = u.position + d * step
				if not state.grid.in_bounds(p):
					break
				if _is_warden_attackable_tile(state, p):
					result.append(p)
					break
				if state.grid.blocks_movement(p):
					break
				var t := state.get_alive_unit_at(p)
				if t == null:
					continue
				if t.is_enemy():
					result.append(p)
				break  # line blocked even by friendlies (UI clarity)
	return result

func is_plan_actionable(enemy_id: int) -> bool:
	var enemy := state.find_unit(enemy_id)
	if enemy == null or not enemy.alive:
		return false
	var plan = state.enemy_warnings.get(enemy_id, null)
	if plan == null:
		return false
	return _actual_attack_pos_for_plan(state, enemy, plan) != Vector2i(-1, -1)

func current_enemy_attack_pos(enemy_id: int) -> Vector2i:
	var enemy := state.find_unit(enemy_id)
	if enemy == null or not enemy.alive:
		return Vector2i(-1, -1)
	var plan = state.enemy_warnings.get(enemy_id, null)
	return _actual_attack_pos_for_plan(state, enemy, plan)

func project_enemy_post_move(enemy_id: int) -> Vector2i:
	var enemy := state.find_unit(enemy_id)
	if enemy == null or not enemy.alive:
		return Vector2i(-1, -1)
	var plan = state.enemy_warnings.get(enemy_id, null)
	if plan == null:
		return enemy.position
	return _project_enemy_post_move_for_state(state, enemy, plan)

func _project_enemy_post_move_for_state(s: BattleState, enemy: Unit, plan) -> Vector2i:
	# After moves resolve, plan.move_to == enemy.position. This helper still
	# returns the planned cell for cases where the move hasn't run yet
	# (theoretical; in current flow they're always equal post-move).
	if plan.move_to == Vector2i(-1, -1) or plan.move_to == enemy.position:
		return enemy.position
	if s.get_unit_at(plan.move_to) == null and not s.grid.blocks_movement(plan.move_to):
		return plan.move_to
	return enemy.position

func enemy_execution_order() -> Array[int]:
	var ids: Array[int] = []
	for u in state.enemies():
		ids.append(u.id)
	ids.sort()
	return ids

func _enemy_execution_order_for_state(s: BattleState) -> Array[int]:
	var ids: Array[int] = []
	for u in s.enemies():
		ids.append(u.id)
	ids.sort()
	return ids

## Deploy-phase helpers (used by InputController + view).
func can_deploy_at(p: Vector2i) -> bool:
	if state == null:
		return false
	if state.get_unit_at(p) != null:
		return false
	if state.grid.blocks_movement(p):
		return false
	return state.deploy_zone.has(p)

func get_deploy_zone() -> Array[Vector2i]:
	var arr: Array[Vector2i] = []
	if state == null:
		return arr
	for k in state.deploy_zone.keys():
		if can_deploy_at(k):
			arr.append(k)
	return arr


# ---------- action dispatch ----------

func _dispatch_action(s: BattleState, action: BattleAction) -> Array[BattleEvent]:
	match action.kind:
		BattleAction.Kind.MOVE:
			return _do_move(s, action)
		BattleAction.Kind.ATTACK:
			return _do_attack(s, action)
		BattleAction.Kind.END_TURN:
			return _do_end_turn(s)
		BattleAction.Kind.DEPLOY:
			return _do_deploy(s, action)
		BattleAction.Kind.CONFIRM_DEPLOY:
			return _do_confirm_deploy(s)
	return []

func _do_move(s: BattleState, a: BattleAction) -> Array[BattleEvent]:
	var u := s.find_unit(a.actor_id)
	if u == null or not u.is_warden() or u.has_acted or u.has_moved:
		return []
	if s.phase != BattleState.Phase.PLAYER_ACTION:
		return []
	var legal := s.grid.reachable_cells(u.position, u.def.move, s.occupied_cells(u.id))
	if a.target_pos != u.position and not (a.target_pos in legal):
		return []
	var events := PhysicsResolver.resolve_move(s, u, a.target_pos)
	u.has_moved = true
	return events

func _do_attack(s: BattleState, a: BattleAction) -> Array[BattleEvent]:
	var u := s.find_unit(a.actor_id)
	if u == null or not u.is_warden() or u.has_acted:
		return []
	if s.phase != BattleState.Phase.PLAYER_ACTION:
		return []
	var target := s.get_alive_unit_at(a.target_pos)
	if target == null:
		if _is_warden_attackable_tile(s, a.target_pos):
			var dir_to_tile := Direction.from_cells(u.position, a.target_pos)
			if dir_to_tile == Vector2i.ZERO:
				return []
			var events := _resolve_warden_tile_attack(s, u, a.target_pos)
			u.has_acted = true
			return events
		return []
	var dir := Direction.from_cells(u.position, target.position)
	if dir == Vector2i.ZERO:
		return []
	var events := _resolve_warden_attack(s, u, target, dir)
	u.has_acted = true
	return events

func _resolve_warden_attack(s: BattleState, u: Unit, target: Unit, dir: Vector2i) -> Array[BattleEvent]:
	match u.def.attack_kind:
		UnitDef.AttackKind.MELEE_BUMP:
			return PhysicsResolver.resolve_attack(s, u, target, dir, 0, u.def.attack_damage)
		UnitDef.AttackKind.MELEE_PUSH, UnitDef.AttackKind.RANGED_PUSH:
			return PhysicsResolver.resolve_attack(s, u, target, dir, u.def.attack_force, u.def.attack_damage)
		UnitDef.AttackKind.RANGED_PULL:
			# Pull = push toward attacker.
			return PhysicsResolver.resolve_attack(s, u, target, -dir, u.def.attack_force, u.def.attack_damage)
	return []

func _resolve_warden_tile_attack(s: BattleState, u: Unit, target_pos: Vector2i) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if s.is_boss_anchor_alive(target_pos):
		var result := s.damage_boss_anchor(target_pos, u.def.attack_damage)
		_append_tile_damage_events(events, target_pos, result)
		return events
	if s.is_boss_heart_attackable(target_pos):
		s.record_boss_heart_hit(u.def.attack_damage)
		var ed := BattleEvent.make(BattleEvent.Type.TILE_DAMAGED)
		ed.to_pos = target_pos
		ed.amount = u.def.attack_damage
		ed.extra = {"boss_heart_hit": true}
		events.append(ed)
	return events

func _do_end_turn(s: BattleState) -> Array[BattleEvent]:
	if s.phase != BattleState.Phase.PLAYER_ACTION:
		return []
	for w in s.wardens():
		w.has_acted = true
	return _enter_enemy_execute(s)

func _do_deploy(s: BattleState, a: BattleAction) -> Array[BattleEvent]:
	if s.phase != BattleState.Phase.GARRISON or s.pending_warden_defs.is_empty():
		return []
	if not s.deploy_zone.has(a.target_pos):
		return []
	if s.get_unit_at(a.target_pos) != null or s.grid.blocks_movement(a.target_pos):
		return []
	var def: UnitDef = s.pending_warden_defs.pop_front()
	var u := Unit.new(s.allocate_unit_id(), def, a.target_pos)
	if not s.pending_warden_starting_hp.is_empty():
		u.hp = s.pending_warden_starting_hp.pop_front()
	s.units.append(u)
	s.placed_warden_ids.append(u.id)
	var ev := BattleEvent.make(BattleEvent.Type.UNIT_SPAWNED)
	ev.unit_id = u.id
	ev.to_pos = u.position
	return [ev]

func _do_confirm_deploy(s: BattleState) -> Array[BattleEvent]:
	if s.phase != BattleState.Phase.GARRISON or not s.pending_warden_defs.is_empty():
		return []
	return _begin_round(s)


# ---------- turn flow ----------

func _maybe_end_player_turn(s: BattleState, events: Array[BattleEvent]) -> void:
	for w in s.wardens():
		if not w.has_acted:
			return  # some warden still has an action
	events.append_array(_enter_enemy_execute(s))

func _begin_round(s: BattleState) -> Array[BattleEvent]:
	## ITB-style round start. Order:
	##   1. Spawn scripted enemies and rifts predicted last round.
	##   2. Plan all enemies (move + attack target).
	##   3. EXECUTE ALL MOVES (visible).
	##   4. Re-plan attacks based on post-move state (handles
	##      "ranged enemy's target moved" cases).
	##   5. Predict NEXT round's spawns -> golden ↑ markers.
	##   6. Reset warden flags + player turn.
	var events: Array[BattleEvent] = []
	events.append(_make_round_event(BattleEvent.Type.ROUND_STARTED, s.current_round))
	events.append_array(_spawn_scripted_for_round(s))
	events.append_array(_spawn_pending_rifts(s))
	s.enemy_warnings = AIDecider.plan_enemy_turn(s)
	events.append_array(_execute_enemy_moves(s))
	_replan_attacks_post_move(s)
	_queue_rift_predictions(s)
	_reset_warden_turn_flags(s)
	s.phase = BattleState.Phase.PLAYER_ACTION
	return events

func _enter_enemy_execute(s: BattleState) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	s.phase = BattleState.Phase.ENEMY_EXECUTE
	events.append_array(_execute_enemy_attacks(s))
	events.append_array(_resolve_boss_script_for_round(s, s.current_round))
	_check_battle_end(s, events)
	if s.outcome != BattleState.Outcome.UNDECIDED:
		return events
	events.append(_make_round_event(BattleEvent.Type.ROUND_ENDED, s.current_round))
	s.current_round += 1
	if s.current_round > s.max_rounds:
		_settle_max_round_outcome(s, events)
	else:
		events.append_array(_begin_round(s))
	return events


# ---------- enemy actions (move + attack sub-phases) ----------

func _execute_enemy_moves(s: BattleState) -> Array[BattleEvent]:
	## Round-start MOVE phase. Each enemy moves to its plan.move_to (if free).
	## Determinism: ascending id order.
	var events: Array[BattleEvent] = []
	for eid in _enemy_ids_sorted(s):
		var enemy := s.find_unit(eid)
		if enemy == null or not enemy.alive:
			continue
		var plan = s.enemy_warnings.get(eid, null)
		if plan == null or plan.move_to == Vector2i(-1, -1) or plan.move_to == enemy.position:
			continue
		if s.get_unit_at(plan.move_to) != null:
			continue  # another enemy claimed this cell first
		if s.grid.blocks_movement(plan.move_to):
			continue
		events.append_array(PhysicsResolver.resolve_move(s, enemy, plan.move_to))
	return events

func _execute_enemy_attacks(s: BattleState) -> Array[BattleEvent]:
	## Round-end ATTACK phase. Each enemy resolves its locked attack slot in
	## deterministic order. Missing/blocked/displaced attacks emit a miss event
	## so UI can explain the slot instead of silently skipping it.
	var events: Array[BattleEvent] = []
	for eid in _enemy_ids_sorted(s):
		var enemy := s.find_unit(eid)
		if enemy == null or not enemy.alive:
			continue
		var plan = s.enemy_warnings.get(eid, null)
		if plan == null or not plan.has_attack():
			continue
		var start := BattleEvent.make(BattleEvent.Type.ENEMY_ATTACK_STARTED)
		start.unit_id = enemy.id
		start.from_pos = enemy.position
		var actual_attack_pos := _actual_attack_pos_for_plan(s, enemy, plan)
		start.to_pos = actual_attack_pos
		events.append(start)
		if not _plan_will_hit(s, enemy, plan):
			var miss := BattleEvent.make(BattleEvent.Type.ENEMY_ATTACK_MISSED)
			miss.unit_id = enemy.id
			miss.from_pos = enemy.position
			miss.to_pos = actual_attack_pos
			events.append(miss)
			continue
		var dir := _locked_attack_dir_for_plan(enemy, plan)
		var target := s.get_alive_unit_at(actual_attack_pos)
		if target != null and target.is_warden():
			events.append_array(_resolve_enemy_attack(s, enemy, target, dir))
		elif _is_attackable_building(s, actual_attack_pos):
			events.append_array(_resolve_enemy_building_attack(s, enemy, actual_attack_pos))
	return events

func _resolve_enemy_attack(s: BattleState, enemy: Unit, target: Unit, dir: Vector2i) -> Array[BattleEvent]:
	match enemy.def.attack_kind:
		UnitDef.AttackKind.MELEE_BUMP:
			return PhysicsResolver.resolve_attack(s, enemy, target, dir, 0, enemy.def.attack_damage)
		_:
			return PhysicsResolver.resolve_attack(s, enemy, target, dir, enemy.def.attack_force, enemy.def.attack_damage)

func _resolve_enemy_building_attack(s: BattleState, enemy: Unit, target_pos: Vector2i) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var result := s.grid.damage_tile(target_pos, enemy.def.attack_damage)
	var damaged: int = result.get("damaged", 0)
	if damaged <= 0:
		return events
	var ed := BattleEvent.make(BattleEvent.Type.TILE_DAMAGED)
	ed.to_pos = target_pos
	ed.amount = damaged
	events.append(ed)
	var destroyed: bool = result.get("destroyed", false)
	s.record_protected_tile_damage(target_pos, damaged, destroyed)
	if destroyed:
		var ex := BattleEvent.make(BattleEvent.Type.TILE_DESTROYED)
		ex.to_pos = target_pos
		ex.amount = result.get("tile", Grid.TileType.EMPTY)
		events.append(ex)
	return events

func _append_tile_damage_events(events: Array[BattleEvent], target_pos: Vector2i, result: Dictionary) -> void:
	var damaged: int = result.get("damaged", 0)
	if damaged <= 0:
		return
	var ed := BattleEvent.make(BattleEvent.Type.TILE_DAMAGED)
	ed.to_pos = target_pos
	ed.amount = damaged
	events.append(ed)
	if bool(result.get("destroyed", false)):
		var ex := BattleEvent.make(BattleEvent.Type.TILE_DESTROYED)
		ex.to_pos = target_pos
		ex.amount = result.get("tile", Grid.TileType.EMPTY)
		events.append(ex)

func _replan_attacks_post_move(s: BattleState) -> void:
	## After all enemy moves execute, ranged enemies' planned targets may have
	## moved away. Re-evaluate each enemy's attack target from their actual
	## post-move position.
	for enemy in s.enemies():
		var plan = s.enemy_warnings.get(enemy.id, null)
		if plan == null:
			continue
		AIDecider.replan_attack_only(s, enemy, plan)


# ---------- scheduled spawning ----------

func _spawn_scripted_for_round(s: BattleState) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	for entry in s.scripted_spawn_schedule:
		if int(entry.get("round", 0)) != s.current_round:
			continue
		if entry.get("def", null) == null:
			continue
		var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
		if not s.grid.in_bounds(pos):
			continue
		if s.get_unit_at(pos) != null:
			entry["round"] = s.current_round + 1
			continue
		events.append(_spawn_scheduled_enemy(s, entry, {"scripted_spawn": true}))
	return events

func _spawn_pending_rifts(s: BattleState) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var still_pending: Array = []
	for entry in s.pending_rift_spawns:
		if entry.get("def", null) == null:
			continue
		var pos: Vector2i = entry.pos
		if s.get_unit_at(pos) != null:
			still_pending.append(entry)  # defer 1 round (occupied)
			continue
		events.append(_spawn_scheduled_enemy(s, entry, {"from_rift": true}))
	s.pending_rift_spawns = still_pending
	return events

func _queue_rift_predictions(s: BattleState) -> void:
	## Schedule entries with round == current_round become predictions for
	## the next round's spawning (visible during THIS round's player turn).
	for entry in s.rift_schedule:
		if entry.round == s.current_round:
			s.pending_rift_spawns.append({"pos": entry.pos, "def": entry.def})

func _spawn_scheduled_enemy(s: BattleState, entry: Dictionary, extra: Dictionary) -> BattleEvent:
	var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
	var u := Unit.new(s.allocate_unit_id(), entry.get("def", null), pos)
	s.units.append(u)
	var ev := BattleEvent.make(BattleEvent.Type.UNIT_SPAWNED)
	ev.unit_id = u.id
	ev.to_pos = pos
	ev.extra = extra.duplicate()
	return ev


# ---------- displacement check ----------

## True iff the enemy can no longer execute its locked attack plan.
## The attack direction is locked, not the original target cell. If the player
## pushes the enemy, the attack line moves with the enemy and resolves from the
## enemy's current position.
func _is_enemy_displaced(s: BattleState, enemy: Unit, plan) -> bool:
	return not _plan_will_hit(s, enemy, plan)

func _is_attackable_building(s: BattleState, p: Vector2i) -> bool:
	return s.grid.get_tile(p) == Grid.TileType.BUILDING \
		and s.is_protected_target(p) \
		and int(s.grid.tile_hp.get(p, 0)) > 0

func _enemy_intent_ui_state_for_state(s: BattleState) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var order := _enemy_execution_order_for_state(s)
	for idx in range(order.size()):
		var eid: int = order[idx]
		var enemy := s.find_unit(eid)
		if enemy == null:
			continue
		var plan = s.enemy_warnings.get(eid, null)
		var post_move := enemy.position
		var attack_pos := Vector2i(-1, -1)
		var target_info := {
			"kind": TARGET_KIND_NONE,
			"id": -1,
			"name": "",
			"hp": 0,
			"damage": 0,
			"pos": Vector2i(-1, -1),
		}
		var status := INTENT_STATUS_NO_ATTACK
		var attack_fires := false
		if plan != null:
			post_move = _project_enemy_post_move_for_state(s, enemy, plan)
			attack_pos = _actual_attack_pos_for_plan(s, enemy, plan)
			target_info = _target_info_for_plan(s, enemy, plan)
			if plan.has_attack():
				attack_fires = attack_pos != Vector2i(-1, -1)
				status = INTENT_STATUS_HIT if _plan_will_hit(s, enemy, plan) else INTENT_STATUS_MISS
		rows.append({
			"enemy_id": eid,
			"enemy_name": enemy.def.display_name if enemy.def != null else "敌人",
			"enemy_def": enemy.def,
			"order": idx + 1,
			"enemy_pos": enemy.position,
			"post_move": post_move,
			"move_to": plan.move_to if plan != null else Vector2i(-1, -1),
			"attack_pos": attack_pos,
			"status": status,
			"target_kind": target_info.get("kind", TARGET_KIND_NONE),
			"target_id": target_info.get("id", -1),
			"target_name": target_info.get("name", ""),
			"target_hp": target_info.get("hp", 0),
			"target_damage": target_info.get("damage", 0),
			"target_pos": target_info.get("pos", Vector2i(-1, -1)),
			"has_attack": plan != null and plan.has_attack(),
			"attack_fires": attack_fires,
		})
	return rows

func _target_info_for_plan(s: BattleState, enemy: Unit, plan) -> Dictionary:
	var info := {
		"kind": TARGET_KIND_NONE,
		"id": -1,
		"name": "",
		"hp": 0,
		"damage": 0,
		"pos": Vector2i(-1, -1),
	}
	if plan == null or not plan.has_attack():
		return info
	var actual_attack_pos := _actual_attack_pos_for_plan(s, enemy, plan)
	var target := s.get_alive_unit_at(actual_attack_pos)
	if target != null and target.is_warden():
		info["kind"] = TARGET_KIND_UNIT
		info["id"] = target.id
		info["name"] = target.def.display_name if target.def != null else "守卫者"
		info["hp"] = target.hp
		info["damage"] = enemy.def.attack_damage if enemy != null and enemy.def != null else 0
		info["pos"] = target.position
		return info
	if s.grid.get_tile(actual_attack_pos) == Grid.TileType.BUILDING and s.is_protected_target(actual_attack_pos):
		info["kind"] = TARGET_KIND_BUILDING
		info["name"] = "建筑"
		info["hp"] = int(s.grid.tile_hp.get(actual_attack_pos, 0))
		info["damage"] = enemy.def.attack_damage if enemy != null and enemy.def != null else 0
		info["pos"] = actual_attack_pos
	return info

func _merge_preview_intent_rows(preview_rows: Array[Dictionary], removed_ids: Dictionary, base_state: BattleState) -> Array[Dictionary]:
	if removed_ids.is_empty():
		return preview_rows
	var by_id: Dictionary = {}
	for row in preview_rows:
		by_id[row.get("enemy_id", -1)] = row
	var order := enemy_execution_order()
	for idx in range(order.size()):
		var eid: int = order[idx]
		if not removed_ids.has(eid) or by_id.has(eid):
			continue
		var original := base_state.find_unit(eid)
		var plan = base_state.enemy_warnings.get(eid, null)
		preview_rows.append({
			"enemy_id": eid,
			"enemy_name": original.def.display_name if original != null and original.def != null else "敌人",
			"enemy_def": original.def if original != null else null,
			"order": idx + 1,
			"enemy_pos": original.position if original != null else Vector2i(-1, -1),
			"post_move": original.position if original != null else Vector2i(-1, -1),
			"move_to": plan.move_to if plan != null else Vector2i(-1, -1),
			"attack_pos": plan.attack_pos if plan != null else Vector2i(-1, -1),
			"status": INTENT_STATUS_REMOVED,
			"target_kind": TARGET_KIND_NONE,
			"target_id": -1,
			"target_name": "",
			"target_hp": 0,
			"target_damage": 0,
			"target_pos": plan.attack_pos if plan != null else Vector2i(-1, -1),
			"has_attack": plan != null and plan.has_attack(),
			"attack_fires": false,
		})
	preview_rows.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	return preview_rows

func _removed_enemy_ids_from_events(events: Array) -> Dictionary:
	var removed: Dictionary = {}
	for raw in events:
		var e: BattleEvent = raw
		if e.type != BattleEvent.Type.UNIT_REMOVED and e.type != BattleEvent.Type.UNIT_FELL:
			continue
		var original := state.find_unit(e.unit_id)
		if original != null and original.is_enemy():
			removed[e.unit_id] = true
	return removed

func _plan_will_hit(s: BattleState, enemy: Unit, plan) -> bool:
	if enemy == null or not enemy.alive or plan == null or not plan.has_attack():
		return false
	var actual_attack_pos := _actual_attack_pos_for_plan(s, enemy, plan)
	if not s.grid.in_bounds(actual_attack_pos):
		return false
	if enemy.def == null:
		return false
	return _is_damageable_target_at(s, actual_attack_pos)

func _actual_attack_pos_for_plan(s: BattleState, enemy: Unit, plan) -> Vector2i:
	if enemy == null or enemy.def == null or plan == null or not plan.has_attack():
		return Vector2i(-1, -1)
	var dir := _locked_attack_dir_for_plan(enemy, plan)
	if dir == Vector2i.ZERO:
		return Vector2i(-1, -1)
	if _is_ranged(enemy.def):
		for step in range(1, enemy.def.attack_range + 1):
			var p: Vector2i = enemy.position + dir * step
			if not s.grid.in_bounds(p):
				return p
			if s.grid.blocks_movement(p):
				return p
			var target := s.get_alive_unit_at(p)
			if target == null or target.id == enemy.id:
				continue
			return p
		return enemy.position + dir * enemy.def.attack_range
	return enemy.position + dir

func _locked_attack_dir_for_plan(enemy: Unit, plan) -> Vector2i:
	if enemy == null or plan == null or not plan.has_attack():
		return Vector2i.ZERO
	var planned_from: Vector2i = plan.move_to
	if planned_from == Vector2i(-1, -1):
		planned_from = plan.origin_pos
	if planned_from == Vector2i(-1, -1):
		planned_from = enemy.position
	return Direction.from_cells(planned_from, plan.attack_pos)

func _plan_has_damageable_target(s: BattleState, plan) -> bool:
	if plan == null or not plan.has_attack():
		return false
	return _is_damageable_target_at(s, plan.attack_pos)

func _is_damageable_target_at(s: BattleState, pos: Vector2i) -> bool:
	var target := s.get_alive_unit_at(pos)
	return (target != null and target.is_warden()) or _is_attackable_building(s, pos)


# ---------- boss script ----------

func _resolve_boss_script_for_round(s: BattleState, round_number: int) -> Array[BattleEvent]:
	if not s.has_boss() or s.outcome != BattleState.Outcome.UNDECIDED:
		return []
	if s.boss_script_resolved_rounds.has(round_number):
		return []
	var increase := 0
	match round_number:
		3:
			if s.boss_alive_anchor_count() >= 2:
				increase = 1
		5:
			if s.boss_alive_anchor_count() >= 1:
				increase = 1
		6:
			if s.heart_hits < 1:
				increase = 1
	if increase <= 0:
		s.boss_script_resolved_rounds[round_number] = "suppressed"
		return []
	s.doom_count = mini(s.doom_count + increase, s.doom_count_max)
	s.boss_script_resolved_rounds[round_number] = "doom"
	var ev := BattleEvent.make(BattleEvent.Type.PHASE_CHANGED)
	ev.amount = s.doom_count
	ev.extra = {"boss_doom": true, "round": round_number}
	return [ev]


# ---------- victory / defeat ----------

func _check_battle_end(s: BattleState, events: Array[BattleEvent]) -> void:
	if s.outcome != BattleState.Outcome.UNDECIDED:
		return
	if s.wardens().is_empty():
		_set_outcome(s, events, BattleState.Outcome.DEFEAT)
		return
	if s.is_boss_doom_breached():
		s.boss_breached = true
		_set_outcome(s, events, BattleState.Outcome.DEFEAT)
		return
	if s.has_protected_targets() and s.alive_protected_targets().is_empty():
		_set_outcome(s, events, BattleState.Outcome.DEFEAT)

func _settle_max_round_outcome(s: BattleState, events: Array[BattleEvent]) -> void:
	var boss_ok := not s.is_boss_doom_breached()
	var outcome := BattleState.Outcome.VICTORY \
		if not s.wardens().is_empty() and boss_ok \
		else BattleState.Outcome.DEFEAT
	if not boss_ok:
		s.boss_breached = true
	_set_outcome(s, events, outcome)

func _set_outcome(s: BattleState, events: Array[BattleEvent], outcome: int) -> void:
	s.outcome = outcome
	s.finalize_reward_tasks()
	var e := BattleEvent.make(BattleEvent.Type.BATTLE_ENDED)
	e.amount = outcome
	events.append(e)
	s.phase = BattleState.Phase.BATTLE_END


# ---------- history ----------

func _push_history() -> void:
	_history.append(state.clone())
	if _history.size() > MAX_UNDO:
		_history.pop_front()


# ---------- small helpers ----------

func _spawn_unit(def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(state.allocate_unit_id(), def, pos)
	state.units.append(u)
	return u

func _enemy_ids_sorted(s: BattleState) -> Array:
	var ids: Array = []
	for u in s.enemies():
		ids.append(u.id)
	ids.sort()
	return ids

func _reset_warden_turn_flags(s: BattleState) -> void:
	for w in s.wardens():
		w.has_acted = false
		w.has_moved = false

func _make_round_event(type: int, round: int) -> BattleEvent:
	var e := BattleEvent.make(type)
	e.amount = round
	return e

func _is_melee(def: UnitDef) -> bool:
	return def.attack_kind == UnitDef.AttackKind.MELEE_BUMP \
		or def.attack_kind == UnitDef.AttackKind.MELEE_PUSH

func _is_ranged(def: UnitDef) -> bool:
	return def.attack_kind == UnitDef.AttackKind.RANGED_PUSH \
		or def.attack_kind == UnitDef.AttackKind.RANGED_PULL

func _is_warden_attackable_tile(s: BattleState, pos: Vector2i) -> bool:
	return s.is_boss_anchor_alive(pos) or s.is_boss_heart_attackable(pos)
