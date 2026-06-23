class_name BattleCandidatePlaytester extends RefCounted
## Preview-only solvability pass for generated map pool candidates.
##
## This runs candidate encounter tables through the real battle engine with a
## bounded beam-search controller. It is intentionally not part of runtime
## battle selection.

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")

const RESULT_APPROVED := "approved"
const RESULT_REVIEW := "review"
const RESULT_REJECTED := "rejected"

const CONTROL_SEARCH_DEPTH := 6
const CONTROL_BEAM_WIDTH := 80
const CONTROL_BRANCH_WIDTH := 18
const MAX_DEPLOYMENT_CANDIDATES := 8

const WARDEN_DEF_PATHS := [
	"res://scripts/data/defs/warden_bountyhunter.tres",
	"res://scripts/data/defs/warden_graverobber.tres",
	"res://scripts/data/defs/warden_mage.tres",
]

static func evaluate_candidate(config: Dictionary, candidate: Dictionary) -> Dictionary:
	var runtime := BattleConfigCatalogScript.build_runtime_config(config)
	var deployment_candidates := _deployment_candidates(config, runtime, candidate)
	if deployment_candidates.is_empty():
		return _rejected_simulation("no valid deployment candidate")
	var best: Dictionary = {}
	var best_score := 1 << 30
	for deploy_index in range(deployment_candidates.size()):
		var deploy_spawns: Array = deployment_candidates[deploy_index]
		var engine := _start_candidate_battle(config, candidate, deploy_spawns)
		var simulation := _simulate(engine)
		_finalize_simulation(simulation)
		simulation["deployment"] = deploy_spawns.duplicate()
		simulation["deployment_index"] = deploy_index
		var score := _simulation_score(simulation)
		if best.is_empty() or score < best_score:
			best = simulation
			best_score = score
		if String(simulation.get("result", "")) == RESULT_APPROVED:
			return simulation
	return best

static func _start_candidate_battle(config: Dictionary, candidate: Dictionary, deploy_spawns: Array) -> BattleEngine:
	var runtime := BattleConfigCatalogScript.build_runtime_config(config)
	var candidate_rift_schedule := _candidate_schedule(candidate.get("rift_schedule", []), true)
	var candidate_grid: Grid = runtime.get("grid").clone()
	var candidate_rift_positions := BattleConfigCatalogScript.positions_from_rift_schedule(candidate_rift_schedule)
	var engine := BattleEngine.new()
	engine.start_battle(
		candidate_grid,
		_load_warden_defs(),
		_candidate_initial_enemies(candidate.get("initial_enemies", [])),
		runtime.get("deploy_zone", []),
		candidate_rift_positions,
		candidate_rift_schedule,
		int(runtime.get("max_rounds", 5)),
		runtime.get("protected_targets", []),
		runtime.get("reward_tasks", []),
			[],
			_boss_config(config),
			_candidate_schedule(candidate.get("scripted_spawns", []), false),
			runtime.get("abyss_edges", {}),
			runtime.get("bell_wave_schedule", [])
		)
	for p in _deployment_spawns(runtime, candidate, deploy_spawns):
		engine.apply_action(BattleAction.deploy(p))
	engine.apply_action(BattleAction.confirm_deploy())
	return engine

static func _simulate(engine: BattleEngine) -> Dictionary:
	var result := {
		"rounds": [],
		"outcome": "running",
		"total_protected_damage": 0,
		"destroyed": 0,
		"warden_deaths": 0,
		"enemies_left": 0,
		"max_threat": 0,
		"boss": "",
	}
	var guard := 0
	while engine.state.phase == BattleState.Phase.PLAYER_ACTION and engine.state.outcome == BattleState.Outcome.UNDECIDED:
		guard += 1
		if guard > engine.state.max_rounds + 2:
			break
		var round := engine.state.current_round
		var before_damage := engine.state.protected_damage_taken
		var choice := _choose_turn_control(engine)
		result["max_threat"] = maxi(int(result.get("max_threat", 0)), int(choice.get("threat", 0)))
		for action in choice.get("actions_raw", []):
			if engine.state.phase != BattleState.Phase.PLAYER_ACTION or engine.state.current_round != round:
				break
			engine.apply_action(action)
			if engine.state.current_round != round:
				break
		if engine.state.phase == BattleState.Phase.PLAYER_ACTION and engine.state.current_round == round:
			engine.apply_action(BattleAction.end_turn())
		result["rounds"].append({
			"round": round,
			"threat": int(choice.get("threat", 0)),
			"protected_damage": engine.state.protected_damage_taken - before_damage,
			"enemies_left": engine.state.enemies().size(),
			"actions": choice.get("actions", []).duplicate(),
		})
	result["outcome"] = _outcome_text(engine.state.outcome)
	result["total_protected_damage"] = engine.state.protected_damage_taken
	result["destroyed"] = engine.state.destroyed_protected_count
	result["warden_deaths"] = engine.state.warden_deaths
	result["enemies_left"] = engine.state.enemies().size()
	result["boss"] = _boss_summary(engine)
	return result

static func _finalize_simulation(simulation: Dictionary) -> void:
	var issues := _simulation_issues(simulation)
	var warnings := _simulation_warnings(simulation)
	var result := RESULT_APPROVED
	if not issues.is_empty():
		result = RESULT_REJECTED
	elif not warnings.is_empty():
		result = RESULT_REVIEW
	simulation["result"] = result
	simulation["issues"] = issues
	simulation["warnings"] = warnings

static func _rejected_simulation(issue: String) -> Dictionary:
	return {
		"rounds": [],
		"outcome": "invalid",
		"total_protected_damage": 0,
		"destroyed": 0,
		"warden_deaths": 0,
		"enemies_left": 0,
		"max_threat": 0,
		"boss": "",
		"result": RESULT_REJECTED,
		"issues": [issue],
		"warnings": [],
		"deployment": [],
		"deployment_index": -1,
	}

static func _simulation_score(simulation: Dictionary) -> int:
	var outcome_penalty := 0 if String(simulation.get("outcome", "")) == "victory" else 900000
	return outcome_penalty \
		+ int(simulation.get("destroyed", 0)) * 180000 \
		+ int(simulation.get("total_protected_damage", 0)) * 110000 \
		+ int(simulation.get("warden_deaths", 0)) * 70000 \
		+ int(simulation.get("max_threat", 0)) * 2500 \
		+ int(simulation.get("enemies_left", 0)) * 900

static func _choose_turn_control(engine: BattleEngine) -> Dictionary:
	var root := BattleEngine.new()
	root.state = engine.state.clone()
	var start_score := _turn_score(root)
	var best := {
		"score": start_score,
		"actions": [],
		"actions_raw": [],
		"threat": _sum_damage(_protected_damage_from_rows(engine.get_enemy_intent_ui_state())),
	}
	var frontier: Array = [{
		"engine": root,
		"actions": [],
		"actions_raw": [],
		"score": start_score,
	}]
	var seen: Dictionary = {}
	for _depth in range(CONTROL_SEARCH_DEPTH):
		var candidates: Array = []
		for node in frontier:
			var cur_engine: BattleEngine = node.engine
			var sig := _state_signature(cur_engine)
			if seen.has(sig):
				continue
			seen[sig] = true
			if int(node.score) < int(best.score):
				best["score"] = int(node.score)
				best["actions"] = node.actions.duplicate()
				best["actions_raw"] = node.actions_raw.duplicate()
			for entry in _candidate_actions_ranked(cur_engine):
				var next := BattleEngine.new()
				next.state = cur_engine.state.clone()
				next._dispatch_action(next.state, entry.action)
				var score := _turn_score(next)
				candidates.append({
					"engine": next,
					"actions": node.actions + [String(entry.text)],
					"actions_raw": node.actions_raw + [entry.action],
					"score": score,
				})
				if score < int(best.score):
					best["score"] = score
					best["actions"] = node.actions + [String(entry.text)]
					best["actions_raw"] = node.actions_raw + [entry.action]
		if candidates.is_empty():
			break
		candidates.sort_custom(func(a, b): return int(a.score) < int(b.score))
		frontier = candidates.slice(0, mini(CONTROL_BEAM_WIDTH, candidates.size()))
	return best

static func _candidate_actions_ranked(engine: BattleEngine) -> Array:
	var actions: Array = []
	for w in engine.state.wardens():
		if w.has_acted:
			continue
		for target in engine.get_legal_attack_targets(w.id):
			actions.append({
				"action": BattleAction.attack(w.id, target),
				"text": "%s attack %s" % [w.def.display_name, _v(target)],
			})
		if not w.has_moved:
			for target in engine.get_legal_moves(w.id):
				actions.append({
					"action": BattleAction.move(w.id, target),
					"text": "%s move %s->%s" % [w.def.display_name, _v(w.position), _v(target)],
				})
	for entry in actions:
		var next := BattleEngine.new()
		next.state = engine.state.clone()
		next._dispatch_action(next.state, entry.action)
		entry["score"] = _turn_score(next)
	actions.sort_custom(func(a, b): return int(a.score) < int(b.score))
	return actions.slice(0, mini(CONTROL_BRANCH_WIDTH, actions.size()))

static func _turn_score(engine: BattleEngine) -> int:
	var pending_damage := _sum_damage(_protected_damage_from_rows(engine.get_enemy_intent_ui_state()))
	return engine.state.protected_damage_taken * 100000 \
		+ engine.state.destroyed_protected_count * 70000 \
		+ _boss_breach_risk(engine) * 60000 \
		+ pending_damage * 12000 \
		+ _warden_damage_from_rows(engine.get_enemy_intent_ui_state()) * 1400 \
		+ _warden_hp_lost(engine) * 800 \
		+ _active_threat_count(engine.get_enemy_intent_ui_state()) * 300 \
		+ engine.state.enemies().size() * 160 \
		+ _enemy_hp_total(engine) * 35 \
		+ _boss_anchor_hp_total(engine) * 320 \
		- engine.state.heart_hits * 520 \
		- _weak_enemy_count(engine) * 25 \
		+ _acted_warden_count(engine) * 5 \
		+ _warden_distance_to_live_threats(engine)

static func _simulation_issues(simulation: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	if String(simulation.get("outcome", "")) == "defeat":
		issues.append("simulation ends in defeat")
	if int(simulation.get("destroyed", 0)) > 0:
		issues.append("simulation destroys protected targets")
	if int(simulation.get("total_protected_damage", 0)) > 0:
		issues.append("simulation allows protected damage")
	return issues

static func _simulation_warnings(simulation: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	if String(simulation.get("outcome", "")) != "victory":
		warnings.append("simulation did not reach victory")
	if int(simulation.get("warden_deaths", 0)) > 0:
		warnings.append("simulation loses wardens")
	if int(simulation.get("max_threat", 0)) > 2:
		warnings.append("simulation has high visible threat")
	return warnings

static func _candidate_initial_enemies(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		var enemy_id := String(entry.get("enemy_id", ""))
		var def := _enemy_def_for(enemy_id)
		if def == null:
			continue
		result.append({
			"def": def,
			"pos": entry.get("pos", Vector2i(-1, -1)),
			"enemy_id": enemy_id,
		})
	return result

static func _candidate_schedule(entries: Array, include_rift_id: bool) -> Array:
	var result: Array = []
	for entry in entries:
		var enemy_id := String(entry.get("enemy_id", ""))
		var def := _enemy_def_for(enemy_id)
		if def == null:
			continue
		var normalized := {
			"round": int(entry.get("round", 0)),
			"pos": entry.get("pos", Vector2i(-1, -1)),
			"def": def,
			"enemy_id": enemy_id,
		}
		if include_rift_id:
			normalized["rift_id"] = String(entry.get("rift_id", ""))
		else:
			normalized["source"] = String(entry.get("source_pool", "candidate_pool"))
		result.append(normalized)
	return result

static func _deployment_spawns(runtime: Dictionary, candidate: Dictionary, requested_spawns: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var valid_cells := _valid_deploy_cells(runtime, candidate)
	for raw in requested_spawns:
		var p: Vector2i = raw
		if not (p in valid_cells):
			continue
		if p in result:
			continue
		result.append(p)
	if result.size() >= WARDEN_DEF_PATHS.size():
		return result.slice(0, WARDEN_DEF_PATHS.size())
	for cell in valid_cells:
		if cell in result:
			continue
		result.append(cell)
		if result.size() >= WARDEN_DEF_PATHS.size():
			break
	return result

static func _deployment_candidates(config: Dictionary, runtime: Dictionary, candidate: Dictionary) -> Array:
	var valid_cells := _valid_deploy_cells(runtime, candidate)
	var result: Array = []
	if valid_cells.size() < WARDEN_DEF_PATHS.size():
		return result
	_add_deployment_candidate(result, _deployment_spawns(runtime, candidate, config.get("warden_spawns", [])))
	var protected_targets: Array = runtime.get("protected_targets", [])
	var threat_cells := _candidate_threat_cells(candidate)
	_add_deployment_candidate(result, _targeted_deployment(valid_cells, protected_targets))
	_add_deployment_candidate(result, _targeted_deployment(valid_cells, threat_cells))
	_add_deployment_candidate(result, _role_deployment(valid_cells, protected_targets, threat_cells, "front"))
	_add_deployment_candidate(result, _role_deployment(valid_cells, protected_targets, threat_cells, "left"))
	_add_deployment_candidate(result, _role_deployment(valid_cells, protected_targets, threat_cells, "right"))
	_add_deployment_candidate(result, _role_deployment(valid_cells, protected_targets, threat_cells, "center"))
	_add_deployment_candidate(result, _spread_deployment(valid_cells, protected_targets))
	return result.slice(0, mini(MAX_DEPLOYMENT_CANDIDATES, result.size()))

static func _add_deployment_candidate(candidates: Array, spawns: Array) -> void:
	if spawns.size() < WARDEN_DEF_PATHS.size():
		return
	var trimmed := spawns.slice(0, WARDEN_DEF_PATHS.size())
	var sig := _cell_list_signature(trimmed)
	for existing in candidates:
		if _cell_list_signature(existing) == sig:
			return
	candidates.append(trimmed)

static func _valid_deploy_cells(runtime: Dictionary, candidate: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var grid: Grid = runtime.get("grid", null)
	var occupied := _candidate_initial_position_set(candidate)
	for raw in runtime.get("deploy_zone", []):
		var p: Vector2i = raw
		if grid != null and grid.blocks_movement(p):
			continue
		if occupied.has(p):
			continue
		if p in result:
			continue
		result.append(p)
	return result

static func _candidate_initial_position_set(candidate: Dictionary) -> Dictionary:
	var occupied := {}
	for entry in candidate.get("initial_enemies", []):
		occupied[entry.get("pos", Vector2i(-1, -1))] = true
	return occupied

static func _candidate_threat_cells(candidate: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for group_id in ["initial_enemies", "scripted_spawns", "rift_schedule"]:
		for entry in candidate.get(group_id, []):
			var p: Vector2i = entry.get("pos", Vector2i(-1, -1))
			if p == Vector2i(-1, -1):
				continue
			if not (p in cells):
				cells.append(p)
	return cells

static func _targeted_deployment(valid_cells: Array[Vector2i], targets: Array) -> Array:
	var result: Array[Vector2i] = []
	for raw in targets:
		if result.size() >= WARDEN_DEF_PATHS.size():
			break
		var target: Vector2i = raw
		var best := _nearest_unused_cell(valid_cells, target, result)
		if best != Vector2i(-1, -1):
			result.append(best)
	return _fill_deployment(result, valid_cells, targets)

static func _role_deployment(valid_cells: Array[Vector2i], protected_targets: Array, threat_cells: Array[Vector2i], mode: String) -> Array:
	var result: Array[Vector2i] = []
	result.append(_best_role_cell(valid_cells, result, protected_targets, threat_cells, "bounty", mode))
	result.append(_best_role_cell(valid_cells, result, protected_targets, threat_cells, "puller", mode))
	result.append(_best_role_cell(valid_cells, result, protected_targets, threat_cells, "pusher", mode))
	return _fill_deployment(result, valid_cells, protected_targets)

static func _spread_deployment(valid_cells: Array[Vector2i], protected_targets: Array) -> Array:
	var sorted := valid_cells.duplicate()
	sorted.sort_custom(func(a, b):
		var da: int = _nearest_distance(a, protected_targets)
		var db: int = _nearest_distance(b, protected_targets)
		if da != db:
			return da < db
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	var result: Array[Vector2i] = []
	var anchors := [1, 3, 6]
	for anchor_x in anchors:
		var best := Vector2i(-1, -1)
		var best_score := 1 << 30
		for cell in sorted:
			if cell in result:
				continue
			var score: int = absi(cell.x - anchor_x) * 20 + _nearest_distance(cell, protected_targets) * 10 + cell.y
			if score < best_score:
				best_score = score
				best = cell
		if best != Vector2i(-1, -1):
			result.append(best)
	return _fill_deployment(result, valid_cells, protected_targets)

static func _fill_deployment(current: Array, valid_cells: Array[Vector2i], targets: Array) -> Array:
	var result: Array[Vector2i] = []
	for cell in current:
		if cell == Vector2i(-1, -1) or cell in result or not (cell in valid_cells):
			continue
		result.append(cell)
	for cell in _ranked_guard_cells(valid_cells, targets):
		if result.size() >= WARDEN_DEF_PATHS.size():
			break
		if cell in result:
			continue
		result.append(cell)
	return result

static func _ranked_guard_cells(valid_cells: Array[Vector2i], targets: Array) -> Array[Vector2i]:
	var sorted := valid_cells.duplicate()
	sorted.sort_custom(func(a, b):
		var sa: int = _nearest_distance(a, targets) * 20 + a.y * 2 + absi(a.x - 3) * 3
		var sb: int = _nearest_distance(b, targets) * 20 + b.y * 2 + absi(b.x - 3) * 3
		return sa < sb
	)
	return sorted

static func _nearest_unused_cell(valid_cells: Array[Vector2i], target: Vector2i, used: Array) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := 1 << 30
	for cell in valid_cells:
		if cell in used:
			continue
		var score := Grid.manhattan(cell, target) * 20 + cell.y + absi(cell.x - target.x)
		if score < best_score:
			best_score = score
			best = cell
	return best

static func _best_role_cell(valid_cells: Array[Vector2i], used: Array, protected_targets: Array, threat_cells: Array[Vector2i], role: String, mode: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := 1 << 30
	for cell in valid_cells:
		if cell in used:
			continue
		var score := _role_cell_score(cell, protected_targets, threat_cells, role, mode)
		if score < best_score:
			best_score = score
			best = cell
	return best

static func _role_cell_score(cell: Vector2i, protected_targets: Array, threat_cells: Array[Vector2i], role: String, mode: String) -> int:
	var protect_dist: int = _nearest_distance(cell, protected_targets)
	var threat_dist: int = _nearest_distance(cell, threat_cells)
	var score: int = protect_dist * 36 + threat_dist * 12 + cell.y * 2 + absi(cell.x - 3) * 2
	match role:
		"bounty":
			score += protect_dist * 10 + threat_dist * 8 + cell.y * 4
		"puller":
			score += absi(cell.x - 2) * 3
		"pusher":
			score += absi(cell.x - 5) * 3
	match mode:
		"front":
			score += cell.y * 10
		"left":
			score += cell.x * 8
		"right":
			score += (Grid.SIZE - 1 - cell.x) * 8
		"center":
			score += absi(cell.x - 3) * 10
	return score

static func _cell_list_signature(cells: Array) -> String:
	var parts: Array[String] = []
	for cell in cells:
		parts.append(_v(cell))
	return "|".join(parts)

static func _nearest_distance(from: Vector2i, cells: Array) -> int:
	if cells.is_empty() or from == Vector2i(-1, -1):
		return 99
	var best := 99
	for raw in cells:
		var cell: Vector2i = raw
		if cell == Vector2i(-1, -1):
			continue
		best = mini(best, Grid.manhattan(from, cell))
	return best

static func _load_warden_defs() -> Array:
	var defs: Array = []
	for path in WARDEN_DEF_PATHS:
		defs.append(load(path))
	return defs

static func _enemy_def_for(enemy_id: String) -> UnitDef:
	var path := String(BattleConfigCatalogScript.ENEMY_RUNTIME_DEF_PATHS.get(enemy_id, ""))
	if path.is_empty():
		return null
	return load(path)

static func _state_signature(engine: BattleEngine) -> String:
	var unit_parts: Array[String] = []
	for u in engine.state.units:
		unit_parts.append("%d:%s:%s:%d:%s:%s" % [
			u.id,
			String(u.def.def_id if u.def != null else &""),
			_v(u.position),
			u.hp,
			str(u.has_moved),
			str(u.has_acted),
		])
	unit_parts.sort()
	return ";".join(unit_parts)

static func _protected_damage_from_rows(rows: Array) -> Dictionary:
	var damage: Dictionary = {}
	for row in rows:
		if String(row.get("target_kind", "")) == BattleEngine.TARGET_KIND_BUILDING:
			var pos: Vector2i = row.get("target_pos", Vector2i(-1, -1))
			damage[pos] = int(damage.get(pos, 0)) + int(row.get("target_damage", 0))
	return damage

static func _sum_damage(damage: Dictionary) -> int:
	var total := 0
	for amount in damage.values():
		total += int(amount)
	return total

static func _warden_damage_from_rows(rows: Array) -> int:
	var total := 0
	for row in rows:
		if String(row.get("target_kind", "")) == BattleEngine.TARGET_KIND_UNIT:
			total += int(row.get("target_damage", 0))
	return total

static func _active_threat_count(rows: Array) -> int:
	var total := 0
	for row in rows:
		if bool(row.get("has_attack", false)) and String(row.get("status", "")) == BattleEngine.INTENT_STATUS_HIT:
			total += 1
	return total

static func _enemy_hp_total(engine: BattleEngine) -> int:
	var total := 0
	for e in engine.state.enemies():
		total += e.hp
	return total

static func _warden_hp_lost(engine: BattleEngine) -> int:
	var total := 0
	for w in engine.state.wardens():
		if w.def != null:
			total += maxi(0, w.def.max_hp - w.hp)
	total += engine.state.warden_deaths * _average_warden_max_hp()
	return total

static func _average_warden_max_hp() -> int:
	var defs := _load_warden_defs()
	var total := 0
	var count := 0
	for def in defs:
		if def == null:
			continue
		total += int(def.max_hp)
		count += 1
	return maxi(1, int(round(float(total) / float(maxi(1, count)))))

static func _weak_enemy_count(engine: BattleEngine) -> int:
	var total := 0
	for e in engine.state.enemies():
		if e.hp <= 1:
			total += 1
	return total

static func _acted_warden_count(engine: BattleEngine) -> int:
	var total := 0
	for w in engine.state.wardens():
		if w.has_acted:
			total += 1
	return total

static func _warden_distance_to_live_threats(engine: BattleEngine) -> int:
	var enemies := engine.state.enemies()
	if enemies.is_empty():
		return 0
	var total := 0
	for w in engine.state.wardens():
		var best := 99
		for e in enemies:
			best = mini(best, Grid.manhattan(w.position, e.position))
		total += best
	return total

static func _boss_config(config: Dictionary) -> Dictionary:
	if String(config.get("boss_config_id", "")).is_empty():
		return {}
	var anchors: Array[Vector2i] = []
	var anchor_hp := -1
	var heart := Vector2i(-1, -1)
	for raw in config.get("boss_objects", []):
		var entry: Dictionary = raw
		var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
		match String(entry.get("kind", "")):
			"anchor":
				anchors.append(pos)
				anchor_hp = maxi(anchor_hp, int(entry.get("hp", -1)))
			"heart_bell":
				heart = pos
	return {
		"boss_config_id": String(config.get("boss_config_id", "knell_lord_demo_01")),
		"boss_script_id": String(config.get("boss_script_id", "knell_lord_demo_six_round")),
		"doom_count_initial": int(config.get("doom_count_initial", 0)),
		"doom_count_max": int(config.get("doom_count_max", 3)),
		"anchor_positions": anchors,
		"anchor_hp": anchor_hp if anchor_hp > 0 else 2,
		"heart_position": heart,
		"heart_hit_cap": int(config.get("heart_hit_cap", 3)),
	}

static func _boss_anchor_hp_total(engine: BattleEngine) -> int:
	if not engine.state.has_boss():
		return 0
	var total := 0
	for hp in engine.state.boss_anchor_hp.values():
		total += maxi(0, int(hp))
	return total

static func _boss_breach_risk(engine: BattleEngine) -> int:
	if not engine.state.has_boss():
		return 0
	var remaining: int = max(0, engine.state.doom_count_max - engine.state.doom_count)
	return engine.state.doom_count * 2 + maxi(0, _boss_anchor_hp_total(engine) - remaining)

static func _boss_summary(engine: BattleEngine) -> String:
	if not engine.state.has_boss():
		return ""
	return "anchors:%d/%d heart:%d doom:%d/%d" % [
		engine.state.boss_destroyed_anchor_count(),
		engine.state.boss_anchor_positions.size(),
		engine.state.heart_hits,
		engine.state.doom_count,
		engine.state.doom_count_max,
	]

static func _outcome_text(outcome: int) -> String:
	match outcome:
		BattleState.Outcome.VICTORY:
			return "victory"
		BattleState.Outcome.DEFEAT:
			return "defeat"
	return "undecided"

static func _v(p: Vector2i) -> String:
	return "(%d,%d)" % [p.x, p.y]
