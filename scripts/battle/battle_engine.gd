class_name BattleEngine extends RefCounted
## State-machine entry point. Validates and applies player + system actions.
## Emits BattleEvent streams that the view layer animates.
##
## Architecture:
##   - state: BattleState (mutable). Source of truth.
##   - apply_action(): real mutation + auto-advance turn.
##   - preview_action(): runs on a clone, returns events, no side effects.
##   - undo(): restores the current formal undo-window snapshot.
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
const HAZARD_CHARGE_LANE := "charge_lane"
const HAZARD_BELL_WAVE := "bell_wave"
const WardenSkillCatalogScript := preload("res://scripts/battle/warden_skill_catalog.gd")

var state: BattleState
var _turn_undo_history: Array[BattleState] = []


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
	abyss_edges: Dictionary = {},
	bell_wave_schedule: Array = [],
	warden_upgrades: Array = [],
) -> Array[BattleEvent]:
	state = BattleState.new()
	state.grid = grid
	state.max_rounds = max_rounds
	for entry in enemies:
		_spawn_unit(entry["def"], entry["pos"])
	state.pending_warden_defs.clear()
	state.pending_warden_starting_hp.clear()
	state.pending_warden_upgrades.clear()
	for d in warden_defs:
		state.pending_warden_defs.append(d)
	for i in range(warden_defs.size()):
		var def: UnitDef = warden_defs[i]
		var hp := def.max_hp if def != null else 1
		if i < warden_starting_hp.size():
			hp = int(warden_starting_hp[i])
		state.pending_warden_starting_hp.append(clampi(hp, 1, def.max_hp if def != null else hp))
		var upgrades: Array = []
		if i < warden_upgrades.size() and typeof(warden_upgrades[i]) == TYPE_ARRAY:
			upgrades = warden_upgrades[i].duplicate()
		state.pending_warden_upgrades.append(upgrades)
	state.placed_warden_ids.clear()
	state.deploy_zone.clear()
	for c in deploy_zone:
		state.deploy_zone[c] = true
	state.rift_positions = rift_positions.duplicate()
	for r in rift_positions:
		state.grid.set_tile(r, Grid.TileType.RIFT)
	state.rift_schedule = rift_schedule.duplicate(true)
	state.pending_rift_spawns.clear()
	state.bell_wave_schedule = bell_wave_schedule.duplicate(true)
	state.pending_bell_wave.clear()
	state.abyss_edges = abyss_edges.duplicate(true)
	state.scripted_spawn_schedule = scripted_spawn_schedule.duplicate(true)
	if protected_targets.is_empty():
		state.protected_targets = state.grid.cells_of_type(Grid.TileType.BUILDING)
	else:
		state.protected_targets = protected_targets.duplicate()
	for p in state.protected_targets:
		if state.grid.get_tile(p) == Grid.TileType.BUILDING and not state.grid.tile_hp.has(p):
			state.grid.tile_hp[p] = Grid.DEFAULT_BUILDING_HP
	state.capture_protected_initial_hp()
	state.configure_boss(boss_config)
	state.set_reward_tasks(reward_tasks)
	state.phase = BattleState.Phase.GARRISON
	_clear_all_history()
	events_produced.emit([])
	state_changed.emit()
	return []


# ---------- public API ----------

## Apply a player or system action to the real state. Emits events.
func apply_action(action: BattleAction) -> Array[BattleEvent]:
	if action.kind == BattleAction.Kind.UNDO:
		return undo()
	var start_round := state.current_round if state != null else 0
	var start_phase := state.phase if state != null else BattleState.Phase.BATTLE_END
	var formal_pushed := _records_formal_undo(action)
	if formal_pushed:
		_push_turn_undo_history()
	var events := _dispatch_action(state, action)
	if events.is_empty():
		_discard_empty_action_history(formal_pushed)
	else:
		_finalize_formal_undo_window(action, start_phase, start_round)
	if action.kind == BattleAction.Kind.MOVE or action.kind == BattleAction.Kind.ATTACK or action.kind == BattleAction.Kind.SKILL:
		_check_battle_end(state, events)
		if state.outcome == BattleState.Outcome.UNDECIDED:
			_maybe_end_player_turn(state, events)
		_finalize_formal_undo_window(action, start_phase, start_round)
	state_changed.emit()
	events_produced.emit(events)
	return events

## Preview an action on a clone. Returns events, no side effects. The clone
## is discarded. Used by the view layer for hover-time predictions.
func preview_action(action: BattleAction) -> Array[BattleEvent]:
	return _dispatch_action(state.clone(), action)

func debug_force_victory() -> Array[BattleEvent]:
	if state == null or state.outcome != BattleState.Outcome.UNDECIDED:
		return []
	var events: Array[BattleEvent] = []
	_set_outcome(state, events, BattleState.Outcome.VICTORY)
	state_changed.emit()
	events_produced.emit(events)
	return events

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

func can_undo() -> bool:
	return _can_formal_undo()

## Undo to the most recent formal history snapshot. View should hard-rebuild
## from `state` (no event animation).
func undo() -> Array[BattleEvent]:
	if not _can_formal_undo():
		return []
	state = _turn_undo_history.pop_back()
	state_changed.emit()
	return []

# ---------- legality queries (used by view layer + input) ----------

func get_legal_moves(unit_id: int) -> Array[Vector2i]:
	var u := state.find_unit(unit_id)
	if u == null or not u.is_warden() or u.has_acted or u.has_moved:
		return []
	if state.phase != BattleState.Phase.PLAYER_ACTION:
		return []
	var cells := state.grid.reachable_cells(u.position, u.def.move, state.opposing_occupied_cells(u))
	var legal: Array[Vector2i] = []
	for cell in cells:
		if state.get_unit_at(cell) == null:
			legal.append(cell)
	return legal

func get_legal_attack_targets(unit_id: int) -> Array[Vector2i]:
	var u := state.find_unit(unit_id)
	if u == null or not u.is_warden() or state.phase != BattleState.Phase.PLAYER_ACTION:
		return []
	var primary := WardenSkillCatalogScript.primary_skill_id_for_warden(u.def.def_id)
	if primary != &"":
		return get_legal_skill_targets(unit_id, primary)
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

func get_legal_skill_targets(unit_id: int, skill_id: StringName) -> Array[Vector2i]:
	var u := state.find_unit(unit_id)
	if u == null or not u.is_warden() or u.has_acted:
		return []
	if state.phase != BattleState.Phase.PLAYER_ACTION:
		return []
	if not _can_use_skill(state, u, skill_id):
		return []
	return _legal_skill_targets_for_state(state, u, skill_id)

func get_skill_target_range(unit_id: int, skill_id: StringName) -> Array[Vector2i]:
	var u := state.find_unit(unit_id)
	if u == null or not u.is_warden():
		return []
	var skill := _skill_for_unit(state, u, skill_id)
	if skill.is_empty():
		return []
	return _skill_target_range_for_state(state, u, skill_id)

func get_skill_availability(unit_id: int, skill_id: StringName) -> Dictionary:
	var result: Dictionary = {
		"usable": false,
		"reason": "不可用",
		"reason_code": "unknown",
		"cooldown_remaining": 0,
		"uses_remaining": 0,
		"max_uses": 0,
		"legal_targets": [],
		"range_cells": [],
	}
	var u := state.find_unit(unit_id)
	if u == null or not u.is_warden() or u.def == null:
		result["reason"] = "未选择守卫者"
		result["reason_code"] = "no_warden"
		return result
	var skill := _skill_for_unit(state, u, skill_id)
	if skill.is_empty() or not _warden_has_skill(state, u, skill_id):
		result["reason"] = "未装备"
		result["reason_code"] = "not_equipped"
		return result
	var max_uses := int(skill.get("max_uses_per_battle", 0))
	var uses := state.skill_use_count(u.id, skill_id)
	var uses_remaining := -1
	if max_uses > 0:
		uses_remaining = maxi(0, max_uses - uses)
	result["max_uses"] = max_uses
	result["uses_remaining"] = uses_remaining
	result["cooldown_remaining"] = state.skill_cooldown_remaining(u.id, skill_id)
	result["range_cells"] = _skill_target_range_for_state(state, u, skill_id)
	if state.phase != BattleState.Phase.PLAYER_ACTION:
		result["reason"] = "非玩家回合"
		result["reason_code"] = "wrong_phase"
		return result
	if u.has_acted:
		result["reason"] = "已行动"
		result["reason_code"] = "acted"
		return result
	if max_uses > 0 and uses >= max_uses:
		result["reason"] = "次数用尽"
		result["reason_code"] = "uses_exhausted"
		return result
	var cooldown_remaining := state.skill_cooldown_remaining(u.id, skill_id)
	if cooldown_remaining > 0:
		result["reason"] = "冷却 %d 回合" % cooldown_remaining
		result["reason_code"] = "cooldown"
		return result
	var legal: Array[Vector2i] = _legal_skill_targets_for_state(state, u, skill_id)
	result["legal_targets"] = legal
	if legal.is_empty():
		result["reason"] = _no_skill_target_reason(skill)
		result["reason_code"] = "no_target"
		return result
	result["usable"] = true
	result["reason"] = ""
	result["reason_code"] = ""
	return result

func get_legal_skill_targets_for_selected(unit_id: int) -> Dictionary:
	var result: Dictionary = {}
	var u := state.find_unit(unit_id)
	if u == null or u.def == null:
		return result
	for skill in WardenSkillCatalogScript.skills_for_warden(u.def.def_id, state.upgrades_for_warden(u.id)):
		var skill_id: StringName = skill.get("id", &"")
		result[skill_id] = get_legal_skill_targets(unit_id, skill_id)
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
		BattleAction.Kind.SKILL:
			return _do_skill(s, action)
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
	var legal := s.grid.reachable_cells(u.position, u.def.move, s.opposing_occupied_cells(u))
	if a.target_pos != u.position and not (a.target_pos in legal):
		return []
	if a.target_pos != u.position and s.get_unit_at(a.target_pos) != null:
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
	var primary := WardenSkillCatalogScript.primary_skill_id_for_warden(u.def.def_id)
	if primary != &"":
		return _do_skill(s, BattleAction.skill(a.actor_id, primary, a.target_pos))
	if not _warden_can_attack_pos(s, u, a.target_pos):
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

func _do_skill(s: BattleState, a: BattleAction) -> Array[BattleEvent]:
	var u := s.find_unit(a.actor_id)
	if u == null or not u.is_warden() or u.has_acted:
		return []
	if s.phase != BattleState.Phase.PLAYER_ACTION:
		return []
	if not _can_use_skill(s, u, a.skill_id):
		return []
	if not (a.target_pos in _legal_skill_targets_for_state(s, u, a.skill_id)):
		return []
	var events: Array[BattleEvent] = []
	match a.skill_id:
		WardenSkillCatalogScript.BOUNTY_CHAIN_STRIKE:
			events = _resolve_bounty_chain_strike(s, u, a.target_pos)
		WardenSkillCatalogScript.BOUNTY_GUARD_SHOULDER:
			events = _resolve_bounty_guard_shoulder(s, u, a.target_pos)
		WardenSkillCatalogScript.BOUNTY_EXECUTE:
			events = _resolve_bounty_execute(s, u, a.target_pos)
		WardenSkillCatalogScript.GRAVEROBBER_HOOK_ROPE:
			events = _resolve_graverobber_hook_rope(s, u, a.target_pos)
		WardenSkillCatalogScript.GRAVEROBBER_RIFT_WEDGE:
			events = _resolve_graverobber_rift_wedge(s, u, a.target_pos)
		WardenSkillCatalogScript.GRAVEROBBER_BACKHAND_THROW:
			events = _resolve_graverobber_backhand_throw(s, u, a.target_pos)
		WardenSkillCatalogScript.MAGE_REPULSION_BOLT:
			events = _resolve_mage_repulsion_bolt(s, u, a.target_pos)
		WardenSkillCatalogScript.MAGE_WARD_FIRE:
			events = _resolve_mage_ward_fire(s, u, a.target_pos)
		WardenSkillCatalogScript.MAGE_SIGIL:
			events = _resolve_mage_sigil(s, u, a.target_pos)
		_:
			return []
	s.record_skill_use(u.id, a.skill_id)
	var skill := _skill_for_unit(s, u, a.skill_id)
	s.start_skill_cooldown(u.id, a.skill_id, int(skill.get("cooldown_rounds", 0)))
	u.has_acted = true
	return events

func _warden_can_attack_pos(s: BattleState, u: Unit, target_pos: Vector2i) -> bool:
	if _is_melee(u.def):
		if abs(target_pos.x - u.position.x) + abs(target_pos.y - u.position.y) != 1:
			return false
	else:
		var dir := Direction.from_cells(u.position, target_pos)
		if dir == Vector2i.ZERO:
			return false
		var distance := absi(target_pos.x - u.position.x) + absi(target_pos.y - u.position.y)
		if distance > u.def.attack_range:
			return false
		for step in range(1, distance):
			var p: Vector2i = u.position + dir * step
			if s.grid.blocks_movement(p) or s.get_unit_at(p) != null:
				return false
	if _is_warden_attackable_tile(s, target_pos):
		return true
	var target := s.get_alive_unit_at(target_pos)
	return target != null and target.is_enemy()

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
		result["boss_anchor"] = true
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

func _can_use_skill(s: BattleState, u: Unit, skill_id: StringName) -> bool:
	if u == null or u.def == null or skill_id == &"":
		return false
	var skill := _skill_for_unit(s, u, skill_id)
	if skill.is_empty():
		return false
	if not _warden_has_skill(s, u, skill_id):
		return false
	var max_uses := int(skill.get("max_uses_per_battle", 0))
	if max_uses > 0 and s.skill_use_count(u.id, skill_id) >= max_uses:
		return false
	if s.skill_cooldown_remaining(u.id, skill_id) > 0:
		return false
	return true

func _skill_for_unit(s: BattleState, u: Unit, skill_id: StringName) -> Dictionary:
	var upgrades: Array = []
	if s != null and u != null:
		upgrades = s.upgrades_for_warden(u.id)
	return WardenSkillCatalogScript.get_skill(skill_id, upgrades)

func _warden_has_skill(s: BattleState, u: Unit, skill_id: StringName) -> bool:
	if u == null or u.def == null:
		return false
	var upgrades: Array = s.upgrades_for_warden(u.id) if s != null else []
	for candidate in WardenSkillCatalogScript.skills_for_warden(u.def.def_id, upgrades):
		if candidate.get("id", &"") == skill_id:
			return true
	return false

func _legal_skill_targets_for_state(s: BattleState, u: Unit, skill_id: StringName) -> Array[Vector2i]:
	if not _can_use_skill(s, u, skill_id):
		return []
	var skill := _skill_for_unit(s, u, skill_id)
	var target_rule: StringName = skill.get("target_rule", &"")
	var range_steps := int(skill.get("range", 1))
	match target_rule:
		WardenSkillCatalogScript.TARGET_ADJACENT_ENEMY_OR_BOSS:
			return _legal_adjacent_enemy_or_boss_targets(s, u, true)
		WardenSkillCatalogScript.TARGET_ADJACENT_ENEMY:
			return _legal_adjacent_enemy_or_boss_targets(s, u, false)
		WardenSkillCatalogScript.TARGET_ADJACENT_UNIT:
			return _legal_adjacent_unit_targets(s, u)
		WardenSkillCatalogScript.TARGET_LINE_ENEMY_OR_BOSS_RANGE_3:
			return _legal_line_enemy_or_boss_targets(s, u, range_steps, true)
		WardenSkillCatalogScript.TARGET_LINE_ENEMY_OR_BOSS_UNLIMITED:
			return _legal_line_enemy_or_boss_targets(s, u, _line_range_limit(s, u), true)
		WardenSkillCatalogScript.TARGET_LINE_ENEMY_RANGE_2:
			return _legal_line_enemy_or_boss_targets(s, u, range_steps, false)
		WardenSkillCatalogScript.TARGET_RIFT_RANGE_3:
			return _legal_rift_wedge_targets(s, u, range_steps)
		WardenSkillCatalogScript.TARGET_PROTECTED_BUILDING_RANGE_2:
			return _legal_ward_fire_targets(s, u, range_steps)
		WardenSkillCatalogScript.TARGET_EMPTY_RANGE_3:
			return _legal_sigil_targets(s, u, range_steps)
	return []

func _skill_target_range_for_state(s: BattleState, u: Unit, skill_id: StringName) -> Array[Vector2i]:
	var skill := _skill_for_unit(s, u, skill_id)
	var target_rule: StringName = skill.get("target_rule", &"")
	var range_steps := int(skill.get("range", 1))
	match target_rule:
		WardenSkillCatalogScript.TARGET_ADJACENT_ENEMY_OR_BOSS:
			return _cells_in_manhattan_range(s, u.position, 1)
		WardenSkillCatalogScript.TARGET_ADJACENT_ENEMY:
			return _cells_in_manhattan_range(s, u.position, 1)
		WardenSkillCatalogScript.TARGET_ADJACENT_UNIT:
			return _cells_in_manhattan_range(s, u.position, 1)
		WardenSkillCatalogScript.TARGET_LINE_ENEMY_OR_BOSS_RANGE_3:
			return _line_range_cells(s, u, range_steps)
		WardenSkillCatalogScript.TARGET_LINE_ENEMY_OR_BOSS_UNLIMITED:
			return _line_range_cells(s, u, _line_range_limit(s, u))
		WardenSkillCatalogScript.TARGET_LINE_ENEMY_RANGE_2:
			return _line_range_cells(s, u, range_steps)
		WardenSkillCatalogScript.TARGET_RIFT_RANGE_3:
			return _cells_in_manhattan_range(s, u.position, range_steps)
		WardenSkillCatalogScript.TARGET_EMPTY_RANGE_3:
			return _cells_in_manhattan_range(s, u.position, range_steps)
		WardenSkillCatalogScript.TARGET_PROTECTED_BUILDING_RANGE_2:
			return _cells_in_manhattan_range(s, u.position, range_steps)
	return []

func _cells_in_manhattan_range(s: BattleState, origin: Vector2i, range_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(Grid.SIZE):
		for x in range(Grid.SIZE):
			var p := Vector2i(x, y)
			if p == origin:
				continue
			if Grid.manhattan(origin, p) <= range_steps:
				result.append(p)
	return result

func _line_range_cells(s: BattleState, u: Unit, range_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in Grid.DIRS:
		for step in range(1, range_steps + 1):
			var p: Vector2i = u.position + d * step
			if not s.grid.in_bounds(p):
				break
			result.append(p)
			if s.grid.blocks_movement(p) or s.get_unit_at(p) != null:
				break
	return result

func _no_skill_target_reason(skill: Dictionary) -> String:
	var target_rule: StringName = skill.get("target_rule", &"")
	match target_rule:
		WardenSkillCatalogScript.TARGET_ADJACENT_ENEMY_OR_BOSS:
			return "无相邻敌人"
		WardenSkillCatalogScript.TARGET_ADJACENT_ENEMY:
			return "无相邻敌人"
		WardenSkillCatalogScript.TARGET_ADJACENT_UNIT:
			return "无相邻单位"
		WardenSkillCatalogScript.TARGET_LINE_ENEMY_OR_BOSS_RANGE_3:
			return "直线无目标"
		WardenSkillCatalogScript.TARGET_LINE_ENEMY_OR_BOSS_UNLIMITED:
			return "直线无目标"
		WardenSkillCatalogScript.TARGET_LINE_ENEMY_RANGE_2:
			return "直线无目标"
		WardenSkillCatalogScript.TARGET_RIFT_RANGE_3:
			return "范围内无可压制裂隙"
		WardenSkillCatalogScript.TARGET_PROTECTED_BUILDING_RANGE_2:
			return "范围内无可守护建筑"
		WardenSkillCatalogScript.TARGET_EMPTY_RANGE_3:
			return "范围内无可布置空地"
	return "无有效目标"

func _legal_adjacent_enemy_or_boss_targets(s: BattleState, u: Unit, include_boss: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in Grid.DIRS:
		var p := u.position + d
		if include_boss and _is_warden_attackable_tile(s, p):
			result.append(p)
			continue
		var target := s.get_alive_unit_at(p)
		if target != null and target.is_enemy():
			result.append(p)
	return result

func _legal_adjacent_unit_targets(s: BattleState, u: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in Grid.DIRS:
		var p := u.position + d
		var target := s.get_alive_unit_at(p)
		if target != null and target.id != u.id:
			result.append(p)
	return result

func _line_range_limit(s: BattleState, u: Unit) -> int:
	if s == null or s.grid == null or u == null:
		return 0
	return Grid.SIZE - 1

func _legal_line_enemy_or_boss_targets(s: BattleState, u: Unit, range_steps: int, include_boss: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in Grid.DIRS:
		for step in range(1, range_steps + 1):
			var p: Vector2i = u.position + d * step
			if not s.grid.in_bounds(p):
				break
			if include_boss and _is_warden_attackable_tile(s, p):
				result.append(p)
				break
			if s.grid.blocks_movement(p):
				break
			var target := s.get_alive_unit_at(p)
			if target == null:
				continue
			if target.is_enemy():
				result.append(p)
			break
	return result

func _legal_rift_wedge_targets(s: BattleState, u: Unit, range_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p in s.grid.cells_of_type(Grid.TileType.RIFT):
		if Grid.manhattan(u.position, p) > range_steps:
			continue
		if s.get_alive_unit_at(p) != null or _has_rift_spawn_to_delay(s, p):
			result.append(p)
	return result

func _legal_ward_fire_targets(s: BattleState, u: Unit, range_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for p in s.alive_protected_targets():
		if Grid.manhattan(u.position, p) > range_steps:
			continue
		if not s.has_protected_shield(p):
			result.append(p)
	return result

func _legal_sigil_targets(s: BattleState, u: Unit, range_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(Grid.SIZE):
		for x in range(Grid.SIZE):
			var p := Vector2i(x, y)
			if Grid.manhattan(u.position, p) > range_steps:
				continue
			if s.grid.blocks_movement(p) or s.grid.get_tile(p) == Grid.TileType.RIFT:
				continue
			if s.is_boss_anchor(p) or p == s.heart_position:
				continue
			if s.get_unit_at(p) != null or s.has_sigil_at(p):
				continue
			result.append(p)
	return result

func _resolve_bounty_chain_strike(s: BattleState, u: Unit, target_pos: Vector2i) -> Array[BattleEvent]:
	return _resolve_push_or_pull_skill(s, u, target_pos, false, WardenSkillCatalogScript.BOUNTY_CHAIN_STRIKE)

func _resolve_graverobber_hook_rope(s: BattleState, u: Unit, target_pos: Vector2i) -> Array[BattleEvent]:
	return _resolve_push_or_pull_skill(s, u, target_pos, true, WardenSkillCatalogScript.GRAVEROBBER_HOOK_ROPE)

func _resolve_mage_repulsion_bolt(s: BattleState, u: Unit, target_pos: Vector2i) -> Array[BattleEvent]:
	return _resolve_push_or_pull_skill(s, u, target_pos, false, WardenSkillCatalogScript.MAGE_REPULSION_BOLT)

func _resolve_push_or_pull_skill(s: BattleState, u: Unit, target_pos: Vector2i, pull: bool, skill_id: StringName) -> Array[BattleEvent]:
	var skill := _skill_for_unit(s, u, skill_id)
	var target := s.get_alive_unit_at(target_pos)
	if target == null:
		if _is_warden_attackable_tile(s, target_pos):
			return _resolve_warden_tile_attack(s, u, target_pos)
		return []
	var dir := Direction.from_cells(u.position, target.position)
	if dir == Vector2i.ZERO:
		return []
	var force := int(skill.get("force", u.def.attack_force))
	var damage := int(skill.get("damage", u.def.attack_damage))
	return PhysicsResolver.resolve_attack(s, u, target, -dir if pull else dir, force, damage)

func _resolve_bounty_guard_shoulder(s: BattleState, u: Unit, target_pos: Vector2i) -> Array[BattleEvent]:
	var skill := _skill_for_unit(s, u, WardenSkillCatalogScript.BOUNTY_GUARD_SHOULDER)
	var target := s.get_alive_unit_at(target_pos)
	if target == null:
		return []
	var events: Array[BattleEvent] = []
	var u_from := u.position
	var target_from := target.position
	u.position = target_from
	target.position = u_from
	var move_u := BattleEvent.make(BattleEvent.Type.UNIT_MOVED)
	move_u.unit_id = u.id
	move_u.from_pos = u_from
	move_u.to_pos = u.position
	events.append(move_u)
	var move_t := BattleEvent.make(BattleEvent.Type.UNIT_MOVED)
	move_t.unit_id = target.id
	move_t.from_pos = target_from
	move_t.to_pos = target.position
	events.append(move_t)
	if target.is_enemy():
		events.append_array(PhysicsResolver.resolve_environment_damage(s, target, int(skill.get("damage", 1)), &"direct"))
	return events

func _resolve_bounty_execute(s: BattleState, u: Unit, target_pos: Vector2i) -> Array[BattleEvent]:
	var skill := _skill_for_unit(s, u, WardenSkillCatalogScript.BOUNTY_EXECUTE)
	var target := s.get_alive_unit_at(target_pos)
	if target == null or not target.is_enemy():
		return []
	var before_alive := target.alive
	var before_id := target.id
	var events := PhysicsResolver.resolve_environment_damage(s, target, int(skill.get("damage", 1)), &"direct")
	if before_alive and s.find_unit(before_id) == null:
		s.record_bounty_execute(u.id)
	return events

func _resolve_graverobber_rift_wedge(s: BattleState, u: Unit, target_pos: Vector2i) -> Array[BattleEvent]:
	var skill := _skill_for_unit(s, u, WardenSkillCatalogScript.GRAVEROBBER_RIFT_WEDGE)
	var events: Array[BattleEvent] = []
	var target := s.get_alive_unit_at(target_pos)
	if target != null and target.is_enemy():
		events.append_array(PhysicsResolver.resolve_environment_damage(s, target, int(skill.get("damage", 1)), &"direct"))
	if _delay_next_rift_spawn(s, target_pos):
		var ev := BattleEvent.make(BattleEvent.Type.PHASE_CHANGED)
		ev.to_pos = target_pos
		ev.extra = {"rift_wedge": true}
		events.append(ev)
	return events

func _resolve_graverobber_backhand_throw(s: BattleState, u: Unit, target_pos: Vector2i) -> Array[BattleEvent]:
	var skill := _skill_for_unit(s, u, WardenSkillCatalogScript.GRAVEROBBER_BACKHAND_THROW)
	var target := s.get_alive_unit_at(target_pos)
	if target == null or not target.is_enemy():
		return []
	var dir := Direction.from_cells(u.position, target.position)
	if dir == Vector2i.ZERO:
		return []
	var target_id := target.id
	var events := PhysicsResolver.resolve_attack(s, u, target, -dir, int(skill.get("force", u.def.attack_force)), int(skill.get("damage", u.def.attack_damage)))
	var moved_target := s.find_unit(target_id)
	if moved_target == null or not moved_target.alive:
		return events
	if Grid.manhattan(u.position, moved_target.position) != 1:
		return events
	var side_dirs := _side_dirs_for_forward(Direction.from_cells(u.position, moved_target.position))
	for side_dir in side_dirs:
		var to := moved_target.position + side_dir
		if not _can_forced_move_to(s, moved_target, to):
			continue
		var from := moved_target.position
		moved_target.position = to
		var ev := BattleEvent.make(BattleEvent.Type.UNIT_PUSHED)
		ev.unit_id = moved_target.id
		ev.from_pos = from
		ev.to_pos = to
		ev.extra = {"backhand_throw": true}
		events.append(ev)
		break
	return events

func _resolve_mage_ward_fire(s: BattleState, u: Unit, target_pos: Vector2i) -> Array[BattleEvent]:
	var skill := _skill_for_unit(s, u, WardenSkillCatalogScript.MAGE_WARD_FIRE)
	var events: Array[BattleEvent] = []
	var shield_amount := int(skill.get("shield_amount", 1))
	if s.add_protected_shield(target_pos, shield_amount):
		var shield := BattleEvent.make(BattleEvent.Type.TILE_SHIELDED)
		shield.to_pos = target_pos
		shield.amount = shield_amount
		events.append(shield)
	return events

func _resolve_mage_sigil(s: BattleState, u: Unit, target_pos: Vector2i) -> Array[BattleEvent]:
	var skill := _skill_for_unit(s, u, WardenSkillCatalogScript.MAGE_SIGIL)
	var events: Array[BattleEvent] = []
	if s.add_sigil(target_pos, u.id, int(skill.get("duration_rounds", 2))):
		var ev := BattleEvent.make(BattleEvent.Type.PHASE_CHANGED)
		ev.to_pos = target_pos
		ev.extra = {"sigil_placed": true}
		events.append(ev)
	return events

func _has_rift_spawn_to_delay(s: BattleState, pos: Vector2i) -> bool:
	for entry in s.pending_rift_spawns:
		if entry.get("pos", Vector2i(-1, -1)) == pos:
			return true
	for entry in s.rift_schedule:
		if entry.get("pos", Vector2i(-1, -1)) == pos and int(entry.get("round", 0)) >= s.current_round:
			return true
	return false

func _delay_next_rift_spawn(s: BattleState, pos: Vector2i) -> bool:
	var best_pending := -1
	var best_pending_round := 1 << 30
	for i in range(s.pending_rift_spawns.size()):
		var entry: Dictionary = s.pending_rift_spawns[i]
		if entry.get("pos", Vector2i(-1, -1)) != pos:
			continue
		var round := int(entry.get("round", s.current_round + 1))
		if round < best_pending_round:
			best_pending_round = round
			best_pending = i
	if best_pending >= 0:
		var entry: Dictionary = s.pending_rift_spawns[best_pending]
		entry["round"] = int(entry.get("round", s.current_round + 1)) + 1
		s.pending_rift_spawns[best_pending] = entry
		return true
	var best_schedule := -1
	var best_schedule_round := 1 << 30
	for i in range(s.rift_schedule.size()):
		var entry: Dictionary = s.rift_schedule[i]
		if entry.get("pos", Vector2i(-1, -1)) != pos:
			continue
		var round := int(entry.get("round", 0))
		if round < s.current_round:
			continue
		if round < best_schedule_round:
			best_schedule_round = round
			best_schedule = i
	if best_schedule >= 0:
		var entry: Dictionary = s.rift_schedule[best_schedule]
		entry["round"] = int(entry.get("round", 0)) + 1
		s.rift_schedule[best_schedule] = entry
		return true
	return false

func _side_dirs_for_forward(forward: Vector2i) -> Array[Vector2i]:
	if forward == Vector2i.ZERO:
		return []
	var left := Vector2i(forward.y, -forward.x)
	var right := Vector2i(-forward.y, forward.x)
	return [left, right]

func _can_forced_move_to(s: BattleState, unit: Unit, pos: Vector2i) -> bool:
	if unit == null or not s.grid.in_bounds(pos):
		return false
	if s.grid.blocks_movement(pos):
		return false
	var occupant := s.get_unit_at(pos)
	return occupant == null or occupant.id == unit.id

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
	if not s.pending_warden_upgrades.is_empty():
		var upgrades = s.pending_warden_upgrades.pop_front()
		if typeof(upgrades) == TYPE_ARRAY:
			s.set_warden_upgrades(u.id, upgrades)
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
	##   1. Resolve hazards predicted last round.
	##   2. Spawn scripted enemies and rifts predicted last round.
	##   3. Plan all enemies (move + attack target).
	##   4. EXECUTE ALL MOVES (visible).
	##   5. Re-plan attacks based on post-move state (handles
	##      "ranged enemy's target moved" cases).
	##   6. Predict NEXT round's spawns/hazards -> board markers.
	##   7. Reset warden flags + player turn.
	var events: Array[BattleEvent] = []
	events.append(_make_round_event(BattleEvent.Type.ROUND_STARTED, s.current_round))
	s.refresh_boss_heart_exposure()
	events.append_array(_resolve_pending_bell_wave(s))
	_check_battle_end(s, events)
	if s.outcome != BattleState.Outcome.UNDECIDED:
		return events
	events.append_array(_spawn_scripted_for_round(s))
	events.append_array(_spawn_pending_rifts(s))
	s.enemy_warnings = AIDecider.plan_enemy_turn(s)
	events.append_array(_execute_enemy_moves(s))
	_replan_attacks_post_move(s)
	_queue_rift_predictions(s)
	_queue_bell_wave_predictions(s)
	_reset_warden_turn_flags(s)
	s.phase = BattleState.Phase.PLAYER_ACTION
	return events

func _enter_enemy_execute(s: BattleState) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	s.phase = BattleState.Phase.ENEMY_EXECUTE
	events.append_array(_execute_enemy_attacks(s))
	s.clear_protected_shields()
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
	s.decrement_sigils_after_enemy_moves()
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
			s.record_enemy_attack_miss()
			var miss := BattleEvent.make(BattleEvent.Type.ENEMY_ATTACK_MISSED)
			miss.unit_id = enemy.id
			miss.from_pos = enemy.position
			miss.to_pos = actual_attack_pos
			events.append(miss)
			continue
		var dir := _locked_attack_dir_for_plan(enemy, plan)
		var target := s.get_alive_unit_at(actual_attack_pos)
		if target != null and target.is_warden():
			if _is_bone_grub(enemy):
				continue
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
	var damage := enemy.def.attack_damage
	if s.consume_protected_crack(target_pos):
		damage += 1
	var shield_blocked := s.consume_protected_shield(target_pos, damage)
	if shield_blocked > 0:
		damage = maxi(0, damage - shield_blocked)
	if damage <= 0:
		return events
	var result := s.grid.damage_tile(target_pos, damage)
	var damaged: int = result.get("damaged", 0)
	if damaged <= 0:
		return events
	var ed := BattleEvent.make(BattleEvent.Type.TILE_DAMAGED)
	ed.to_pos = target_pos
	ed.amount = damaged
	events.append(ed)
	var destroyed: bool = result.get("destroyed", false)
	s.record_protected_tile_damage(target_pos, damaged, destroyed)
	if _is_bell_thrall(enemy) and not destroyed:
		s.crack_protected_target(target_pos)
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
	if bool(result.get("boss_anchor", false)):
		ed.extra = {"boss_anchor": true}
	events.append(ed)
	if bool(result.get("destroyed", false)):
		var ex := BattleEvent.make(BattleEvent.Type.TILE_DESTROYED)
		ex.to_pos = target_pos
		ex.amount = result.get("tile", Grid.TileType.EMPTY)
		if bool(result.get("boss_anchor", false)):
			ex.extra = {"boss_anchor_destroyed": true}
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
			s.record_rift_suppression()
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

func _resolve_pending_bell_wave(s: BattleState) -> Array[BattleEvent]:
	return _resolve_pending_unit_hazard(s, s.pending_bell_wave, StringName(HAZARD_BELL_WAVE))

func _resolve_pending_unit_hazard(s: BattleState, pending_cells: Array[Vector2i], hazard_type: StringName) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var cells := pending_cells.duplicate()
	pending_cells.clear()
	var damaged_units: Dictionary = {}
	for cell in cells:
		if not s.grid.in_bounds(cell):
			continue
		var unit := s.get_alive_unit_at(cell)
		if unit == null or damaged_units.has(unit.id):
			continue
		damaged_units[unit.id] = true
		events.append_array(PhysicsResolver.resolve_environment_damage(s, unit, 1, hazard_type))
	return events

func _queue_bell_wave_predictions(s: BattleState) -> void:
	_queue_unit_hazard_predictions(s, s.bell_wave_schedule, s.pending_bell_wave)

func _queue_unit_hazard_predictions(s: BattleState, schedule: Array, pending_cells: Array[Vector2i]) -> void:
	var warned: Dictionary = {}
	for entry in schedule:
		if int(entry.get("round", 0)) != s.current_round:
			continue
		var cells: Array = entry.get("cells", [])
		if cells.is_empty() and entry.has("pos"):
			cells = [entry.get("pos", Vector2i(-1, -1))]
		for raw in cells:
			var cell: Vector2i = raw
			if not s.grid.in_bounds(cell):
				continue
			if s.grid.blocks_movement(cell):
				continue
			if warned.has(cell):
				continue
			warned[cell] = true
			pending_cells.append(cell)

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
		var hazard_type := ""
		var hazard_cells: Array[Vector2i] = []
		if plan != null:
			post_move = _project_enemy_post_move_for_state(s, enemy, plan)
			attack_pos = _actual_attack_pos_for_plan(s, enemy, plan)
			target_info = _target_info_for_plan(s, enemy, plan)
			if plan.has_attack():
				attack_fires = attack_pos != Vector2i(-1, -1)
				status = INTENT_STATUS_HIT if _plan_will_hit(s, enemy, plan) else INTENT_STATUS_MISS
				hazard_type = _hazard_type_for_plan(enemy, plan)
				hazard_cells = _hazard_cells_for_plan(s, enemy, plan, attack_pos, hazard_type)
		rows.append({
			"enemy_id": eid,
			"enemy_name": enemy.def.display_name if enemy.def != null else "敌人",
			"enemy_def": enemy.def,
			"enemy_hp": enemy.hp,
			"enemy_max_hp": enemy.def.max_hp if enemy.def != null else enemy.hp,
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
			"hazard_type": hazard_type,
			"hazard_cells": hazard_cells,
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
			"enemy_hp": original.hp if original != null else 0,
			"enemy_max_hp": original.def.max_hp if original != null and original.def != null else 0,
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
			"hazard_type": "",
			"hazard_cells": [],
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

func _hazard_type_for_plan(enemy: Unit, plan) -> String:
	if enemy == null or enemy.def == null or plan == null or not plan.has_attack():
		return ""
	if enemy.def.def_id == BattleState.DEF_IRONHORN:
		return HAZARD_CHARGE_LANE
	return ""

func _hazard_cells_for_plan(s: BattleState, enemy: Unit, plan, attack_pos: Vector2i, hazard_type: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if hazard_type != HAZARD_CHARGE_LANE:
		return cells
	var dir := _locked_attack_dir_for_plan(enemy, plan)
	if dir == Vector2i.ZERO:
		return cells
	var max_steps := maxi(1, enemy.def.attack_range if enemy != null and enemy.def != null else 1)
	for step in range(1, max_steps + 1):
		var p: Vector2i = enemy.position + dir * step
		if not s.grid.in_bounds(p):
			break
		cells.append(p)
		if p == attack_pos:
			break
	return cells


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
	if s.apply_boss_heart_doom_reduction():
		var ev := BattleEvent.make(BattleEvent.Type.PHASE_CHANGED)
		ev.amount = s.doom_count
		ev.extra = {"boss_heart_doom_reduction": true, "heart_hits": s.heart_hits}
		events.append(ev)
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

func _clear_all_history() -> void:
	_turn_undo_history.clear()

func _push_turn_undo_history() -> void:
	_turn_undo_history.append(state.clone())
	if _turn_undo_history.size() > MAX_UNDO:
		_turn_undo_history.pop_front()

func _records_formal_undo(action: BattleAction) -> bool:
	if state == null or state.phase == BattleState.Phase.BATTLE_END:
		return false
	match action.kind:
		BattleAction.Kind.DEPLOY:
			return state.phase == BattleState.Phase.GARRISON
		BattleAction.Kind.MOVE, BattleAction.Kind.ATTACK, BattleAction.Kind.SKILL:
			return state.phase == BattleState.Phase.PLAYER_ACTION
	return false

func _can_formal_undo() -> bool:
	if state == null or state.phase == BattleState.Phase.BATTLE_END:
		return false
	if not (state.phase == BattleState.Phase.GARRISON or state.phase == BattleState.Phase.PLAYER_ACTION):
		return false
	return not _turn_undo_history.is_empty()

func _discard_empty_action_history(formal_pushed: bool) -> void:
	if formal_pushed and not _turn_undo_history.is_empty():
		_turn_undo_history.pop_back()

func _finalize_formal_undo_window(action: BattleAction, start_phase: int, start_round: int) -> void:
	if state == null:
		_turn_undo_history.clear()
		return
	if state.phase == BattleState.Phase.BATTLE_END:
		_turn_undo_history.clear()
		return
	if action.kind == BattleAction.Kind.CONFIRM_DEPLOY or action.kind == BattleAction.Kind.END_TURN:
		_turn_undo_history.clear()
		return
	if start_phase == BattleState.Phase.PLAYER_ACTION and state.current_round != start_round:
		_turn_undo_history.clear()
		return
	if start_phase == BattleState.Phase.GARRISON and state.phase != BattleState.Phase.GARRISON:
		_turn_undo_history.clear()
		return
	if state.phase != BattleState.Phase.GARRISON and state.phase != BattleState.Phase.PLAYER_ACTION:
		_turn_undo_history.clear()


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

func _is_bone_grub(unit: Unit) -> bool:
	return unit != null and unit.def != null and unit.def.def_id == BattleState.DEF_BONE_GRUB

func _is_bell_thrall(unit: Unit) -> bool:
	return unit != null and unit.def != null and unit.def.def_id == BattleState.DEF_BELL_THRALL

func _is_warden_attackable_tile(s: BattleState, pos: Vector2i) -> bool:
	return s.is_boss_anchor_alive(pos) or s.is_boss_heart_attackable(pos)
