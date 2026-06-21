class_name BattlePoolCandidateGenerator extends RefCounted
## Preview-only generator for map element/spawn pools.
##
## This does not replace BattleConfigCatalog's fixed runtime tables. It builds
## seedable candidate encounter tables for design previews and fairness checks.

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")

const RESULT_VALID := "valid"
const RESULT_ADJUSTED := "adjusted"
const RESULT_REJECTED := "rejected"
const MAX_GUARD_PATH_DISTANCE := 3
const MAX_OPENING_INTERCEPT_PATH := 2

static func generate_candidate(config: Dictionary, seed: int, variant_index: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = max(1, seed + variant_index * 7919)
	var runtime := BattleConfigCatalogScript.build_runtime_config(config)
	var selected_elements := _select_element_pool_entries(runtime.get("element_pools", {}), rng)
	var spawn_tables := _generate_spawn_tables(config, runtime, rng)
	var validation := validate_candidate(config, runtime, spawn_tables, selected_elements)
	return {
		"config_id": String(config.get("config_id", "")),
		"display_name": String(config.get("display_name", "")),
		"seed": seed,
		"variant_index": variant_index,
		"selected_elements": selected_elements,
		"initial_enemies": spawn_tables.get("initial_enemies", []),
		"scripted_spawns": spawn_tables.get("scripted_spawns", []),
		"rift_schedule": spawn_tables.get("rift_schedule", []),
		"validation": validation,
	}

static func validate_candidate(config: Dictionary, runtime: Dictionary, spawn_tables: Dictionary, selected_elements: Dictionary = {}) -> Dictionary:
	var issues: Array[String] = []
	var warnings: Array[String] = []
	var diagnostics := _build_diagnostics(config, runtime, spawn_tables, selected_elements)
	var grid: Grid = runtime.get("grid", null)
	if grid == null:
		issues.append("missing runtime grid")
		return {"result": RESULT_REJECTED, "issues": issues, "warnings": warnings, "diagnostics": diagnostics}
	_validate_spawn_positions(grid, spawn_tables, issues)
	_validate_deploy_protection(runtime, diagnostics, issues, warnings)
	_validate_opening_pressure(config, runtime, spawn_tables, issues, warnings)
	_validate_rift_warnings(spawn_tables, issues)
	_validate_hard_threat_budget(spawn_tables, warnings)
	_validate_element_pool_coverage(runtime, selected_elements, diagnostics, issues, warnings)
	var result := RESULT_VALID
	if not issues.is_empty():
		result = RESULT_REJECTED
	elif not warnings.is_empty():
		result = RESULT_ADJUSTED
	return {"result": result, "issues": issues, "warnings": warnings, "diagnostics": diagnostics}

static func _select_element_pool_entries(element_pools: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var selected := {}
	for pool_id in element_pools.keys():
		var entries: Array = element_pools.get(pool_id, [])
		if entries.is_empty():
			continue
		selected[String(pool_id)] = _weighted_pick(entries, rng).duplicate(true)
	return selected

static func _generate_spawn_tables(config: Dictionary, runtime: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var initial_enemies: Array = []
	var scripted_spawns: Array = []
	var rift_schedule: Array = []
	var used_round_cells: Dictionary = {}
	var spawn_pools: Dictionary = runtime.get("spawn_pools", {})
	for pool_id in spawn_pools.keys():
		var pool: Dictionary = spawn_pools.get(pool_id, {})
		var rounds: Array = pool.get("rounds", [])
		if rounds.is_empty():
			continue
		var max_per_round := maxi(1, int(pool.get("max_per_round", 1)))
		for round_value in rounds:
			var round := int(round_value)
			for _i in range(max_per_round):
				var enemy_id := _weighted_enemy_id(pool.get("enemy_weights", {}), rng)
				if enemy_id.is_empty():
					continue
				var pos := _spawn_pos_for_pool(config, pool, rng)
				if pos == Vector2i(-1, -1):
					continue
				var round_key := "%d:%s" % [round, str(pos)]
				if used_round_cells.has(round_key):
					continue
				used_round_cells[round_key] = true
				var entry := {"round": round, "enemy_id": enemy_id, "pos": pos, "source_pool": String(pool_id)}
				if bool(pool.get("warns_before_spawn", false)):
					entry["rift_id"] = _rift_id_for_pos(config, pos)
					rift_schedule.append(entry)
				elif round <= 1:
					initial_enemies.append({"id": "cand_%s_%d_%d" % [String(pool_id), pos.x, pos.y], "enemy_id": enemy_id, "pos": pos, "source_pool": String(pool_id)})
				else:
					scripted_spawns.append(entry)
	return {
		"initial_enemies": initial_enemies,
		"scripted_spawns": scripted_spawns,
		"rift_schedule": rift_schedule,
	}

static func _validate_spawn_positions(grid: Grid, spawn_tables: Dictionary, issues: Array[String]) -> void:
	for group_id in ["initial_enemies", "scripted_spawns", "rift_schedule"]:
		for entry in spawn_tables.get(group_id, []):
			var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
			if not grid.in_bounds(pos):
				issues.append("%s spawn out of bounds at %s" % [group_id, str(pos)])
			elif grid.blocks_movement(pos):
				issues.append("%s spawn blocked by terrain at %s" % [group_id, str(pos)])

static func _build_diagnostics(config: Dictionary, runtime: Dictionary, spawn_tables: Dictionary, selected_elements: Dictionary) -> Dictionary:
	var grid: Grid = runtime.get("grid", null)
	var deploy_zone: Array = runtime.get("deploy_zone", [])
	var protected_targets: Array = runtime.get("protected_targets", [])
	var target_rows := _protected_target_guard_rows(grid, deploy_zone, protected_targets)
	var worst_guard_path := 0
	var unguarded_targets: Array[String] = []
	for row in target_rows:
		var dist := int(row.get("guard_path_distance", 99))
		if dist >= 99:
			unguarded_targets.append(str(row.get("target", Vector2i(-1, -1))))
		else:
			worst_guard_path = maxi(worst_guard_path, dist)
	var opening_rows := _opening_pressure_rows(config, runtime, spawn_tables)
	return {
		"protected_target_count": protected_targets.size(),
		"deploy_cell_count": deploy_zone.size(),
		"protected_target_guards": target_rows,
		"worst_guard_path": worst_guard_path if unguarded_targets.is_empty() else 99,
		"unguarded_targets": unguarded_targets,
		"opening_pressure": opening_rows,
		"opening_pressure_count": opening_rows.size(),
		"element_coverage": _element_coverage(runtime, selected_elements),
		"source_pool_counts": _source_pool_counts(spawn_tables),
	}

static func _validate_deploy_protection(runtime: Dictionary, diagnostics: Dictionary, issues: Array[String], warnings: Array[String]) -> void:
	var deploy_zone: Array = runtime.get("deploy_zone", [])
	var protected_targets: Array = runtime.get("protected_targets", [])
	if deploy_zone.is_empty():
		issues.append("deploy zone is empty")
		return
	if protected_targets.is_empty():
		warnings.append("no protected targets to validate")
		return
	if int(diagnostics.get("worst_guard_path", 99)) > MAX_GUARD_PATH_DISTANCE:
		issues.append("deploy zone cannot protect every building quickly enough; worst guard path=%d targets=%s" % [
			int(diagnostics.get("worst_guard_path", 99)),
			", ".join(_string_array(diagnostics.get("unguarded_targets", []))),
		])
	for row in diagnostics.get("protected_target_guards", []):
		var dist := int(row.get("guard_path_distance", 99))
		if dist > MAX_GUARD_PATH_DISTANCE:
			continue
		if dist == MAX_GUARD_PATH_DISTANCE:
			warnings.append("protected target has narrow deployment response at %s distance=%d" % [str(row.get("target", Vector2i(-1, -1))), dist])

static func _validate_opening_pressure(config: Dictionary, runtime: Dictionary, spawn_tables: Dictionary, issues: Array[String], warnings: Array[String]) -> void:
	var protected_targets: Array = runtime.get("protected_targets", [])
	var deploy_zone: Array = runtime.get("deploy_zone", [])
	var grid: Grid = runtime.get("grid", null)
	for entry in spawn_tables.get("initial_enemies", []):
		var enemy_id := String(entry.get("enemy_id", ""))
		var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
		var nearest_building := _nearest_distance(pos, protected_targets)
		var nearest_deploy := _nearest_distance(pos, deploy_zone)
		if enemy_id == "plague_archer":
			var archer_line := _opening_archer_line_status(pos, protected_targets, deploy_zone, grid)
			if bool(archer_line.get("uninterceptable", false)):
				issues.append("opening archer has direct building line outside deployment response at %s intercept_path=%d" % [
					str(pos),
					int(archer_line.get("intercept_path", 99)),
				])
			elif bool(archer_line.get("interceptable", false)):
				warnings.append("opening archer line can be blocked from deploy zone at %s intercept_path=%d" % [
					str(pos),
					int(archer_line.get("intercept_path", 99)),
				])
		if nearest_building <= 1 and nearest_deploy > 2:
			issues.append("opening enemy can pressure building before deployment response at %s" % str(pos))
		elif nearest_building <= 2 and nearest_deploy > 3:
			warnings.append("opening enemy starts close to buildings at %s" % str(pos))

static func _validate_rift_warnings(spawn_tables: Dictionary, issues: Array[String]) -> void:
	for entry in spawn_tables.get("rift_schedule", []):
		if int(entry.get("round", 0)) <= 1:
			issues.append("rift pool generated round 1 warning/spawn at %s" % str(entry.get("pos", Vector2i(-1, -1))))

static func _validate_hard_threat_budget(spawn_tables: Dictionary, warnings: Array[String]) -> void:
	var per_round := {}
	for group_id in ["scripted_spawns", "rift_schedule"]:
		for entry in spawn_tables.get(group_id, []):
			var round := int(entry.get("round", 0))
			per_round[round] = int(per_round.get(round, 0)) + 1
	for round in per_round.keys():
		if int(per_round[round]) > 2:
			warnings.append("round %d has %d scheduled threats" % [int(round), int(per_round[round])])

static func _validate_element_pool_coverage(runtime: Dictionary, selected_elements: Dictionary, diagnostics: Dictionary, issues: Array[String], warnings: Array[String]) -> void:
	var element_pools: Dictionary = runtime.get("element_pools", {})
	if element_pools.is_empty():
		return
	if selected_elements.is_empty():
		warnings.append("map has element pools but no element selected")
	var coverage: Dictionary = diagnostics.get("element_coverage", {})
	for pool_id in element_pools.keys():
		var pool_key := String(pool_id)
		if not coverage.has(pool_key):
			warnings.append("element pool %s has no selected coverage" % pool_key)
			continue
		var entry: Dictionary = coverage.get(pool_key, {})
		if int(entry.get("cell_count", 0)) <= 0 and int(entry.get("rift_count", 0)) <= 0:
			warnings.append("element pool %s selected empty element %s" % [pool_key, String(entry.get("id", ""))])
		if entry.get("roles", []).is_empty() and String(entry.get("hazard_type", "")).is_empty():
			warnings.append("element pool %s selected element lacks terrain role or hazard type" % pool_key)

static func _protected_target_guard_rows(grid: Grid, deploy_zone: Array, protected_targets: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for raw_target in protected_targets:
		var target: Vector2i = raw_target
		var guard_cells := _guard_cells_for_target(grid, target)
		var best := {
			"target": target,
			"guard_cell": Vector2i(-1, -1),
			"deploy_cell": Vector2i(-1, -1),
			"guard_path_distance": 99,
			"guard_cell_count": guard_cells.size(),
		}
		for raw_deploy in deploy_zone:
			var deploy: Vector2i = raw_deploy
			for guard in guard_cells:
				var dist := _path_distance(grid, deploy, guard)
				if dist < int(best.get("guard_path_distance", 99)):
					best["guard_path_distance"] = dist
					best["guard_cell"] = guard
					best["deploy_cell"] = deploy
		rows.append(best)
	return rows

static func _guard_cells_for_target(grid: Grid, target: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if grid == null:
		return cells
	for d in Grid.DIRS:
		var p := target + d
		if not grid.in_bounds(p) or grid.blocks_movement(p):
			continue
		if not (p in cells):
			cells.append(p)
	return cells

static func _path_distance(grid: Grid, from: Vector2i, to: Vector2i) -> int:
	if grid == null or from == Vector2i(-1, -1) or to == Vector2i(-1, -1):
		return 99
	if from == to:
		return 0
	if not grid.in_bounds(from) or not grid.in_bounds(to):
		return 99
	if grid.blocks_movement(from) or grid.blocks_movement(to):
		return 99
	var path := grid.find_path(from, to, {})
	return path.size() if not path.is_empty() else 99

static func _opening_pressure_rows(config: Dictionary, runtime: Dictionary, spawn_tables: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var protected_targets: Array = runtime.get("protected_targets", [])
	var deploy_zone: Array = runtime.get("deploy_zone", [])
	var grid: Grid = runtime.get("grid", null)
	for entry in spawn_tables.get("initial_enemies", []):
		var enemy_id := String(entry.get("enemy_id", ""))
		var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
		var nearest_building := _nearest_distance(pos, protected_targets)
		var nearest_deploy := _nearest_distance(pos, deploy_zone)
		var archer_line := {}
		if enemy_id == "plague_archer":
			archer_line = _opening_archer_line_status(pos, protected_targets, deploy_zone, grid)
		var intercept_path := int(archer_line.get("intercept_path", 99))
		var pressure_type := "none"
		if bool(archer_line.get("uninterceptable", false)):
			pressure_type = "uninterceptable_line"
		elif bool(archer_line.get("interceptable", false)):
			pressure_type = "interceptable_line"
		elif nearest_building <= 2:
			pressure_type = "near_building"
		if pressure_type != "none":
			rows.append({
				"enemy_id": enemy_id,
				"pos": pos,
				"source_pool": String(entry.get("source_pool", "")),
				"nearest_building": nearest_building,
				"nearest_deploy": nearest_deploy,
				"pressure_type": pressure_type,
				"intercept_path": intercept_path,
				"intercept_cells": archer_line.get("intercept_cells", []).duplicate(),
			})
	return rows

static func _nearest_intercept_path(grid: Grid, deploy_zone: Array, intercept_cells: Array) -> int:
	if intercept_cells.is_empty():
		return 99
	var best := 99
	for deploy in deploy_zone:
		for intercept in intercept_cells:
			best = mini(best, _path_distance(grid, deploy, intercept))
	return best

static func _element_coverage(runtime: Dictionary, selected_elements: Dictionary) -> Dictionary:
	var coverage := {}
	for pool_id in selected_elements.keys():
		var entry: Dictionary = selected_elements.get(pool_id, {})
		coverage[String(pool_id)] = {
			"id": String(entry.get("id", "")),
			"cell_count": entry.get("cells", []).size(),
			"rift_count": entry.get("rift_ids", []).size(),
			"roles": _string_array(entry.get("roles", [])),
			"hazard_type": String(entry.get("hazard_type", "")),
			"stage": String(entry.get("stage", "")),
		}
	return coverage

static func _source_pool_counts(spawn_tables: Dictionary) -> Dictionary:
	var counts := {}
	for group_id in ["initial_enemies", "scripted_spawns", "rift_schedule"]:
		for entry in spawn_tables.get(group_id, []):
			var pool_id := String(entry.get("source_pool", group_id))
			if pool_id.is_empty():
				pool_id = group_id
			counts[pool_id] = int(counts.get(pool_id, 0)) + 1
	return counts

static func _spawn_pos_for_pool(config: Dictionary, pool: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var cells: Array = pool.get("cells", [])
	if not cells.is_empty():
		return cells[rng.randi_range(0, cells.size() - 1)]
	var rift_ids: Array = pool.get("rift_ids", [])
	if rift_ids.is_empty():
		return Vector2i(-1, -1)
	var rift_id := String(rift_ids[rng.randi_range(0, rift_ids.size() - 1)])
	return _rift_pos_for_id(config, rift_id)

static func _rift_id_for_pos(config: Dictionary, pos: Vector2i) -> String:
	for rift in config.get("rifts", []):
		if rift.get("pos", Vector2i(-1, -1)) == pos:
			return String(rift.get("id", ""))
	return ""

static func _rift_pos_for_id(config: Dictionary, rift_id: String) -> Vector2i:
	for rift in config.get("rifts", []):
		if String(rift.get("id", "")) == rift_id:
			return rift.get("pos", Vector2i(-1, -1))
	return Vector2i(-1, -1)

static func _weighted_enemy_id(enemy_weights: Dictionary, rng: RandomNumberGenerator) -> String:
	if enemy_weights.is_empty():
		return ""
	var keys := enemy_weights.keys()
	var total := 0
	for key in keys:
		total += maxi(0, int(enemy_weights.get(key, 0)))
	if total <= 0:
		return ""
	var roll := rng.randi_range(1, total)
	var cursor := 0
	for key in keys:
		cursor += maxi(0, int(enemy_weights.get(key, 0)))
		if roll <= cursor:
			return String(key)
	return String(keys[0])

static func _weighted_pick(entries: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0
	for entry in entries:
		total += maxi(0, int(entry.get("weight", 1)))
	if total <= 0:
		return entries[0]
	var roll := rng.randi_range(1, total)
	var cursor := 0
	for entry in entries:
		cursor += maxi(0, int(entry.get("weight", 1)))
		if roll <= cursor:
			return entry
	return entries[0]

static func _nearest_distance(from: Vector2i, cells: Array) -> int:
	if cells.is_empty() or from == Vector2i(-1, -1):
		return 99
	var best := 99
	for cell in cells:
		best = mini(best, Grid.manhattan(from, cell))
	return best

static func _opening_archer_line_status(from: Vector2i, targets: Array, deploy_zone: Array, grid: Grid) -> Dictionary:
	var status := {
		"has_line": false,
		"interceptable": false,
		"uninterceptable": false,
		"intercept_cells": [],
		"intercept_path": 99,
	}
	if grid == null:
		return status
	var best_intercept_path := 99
	for target in targets:
		var dir := Direction.from_cells(from, target)
		if dir == Vector2i.ZERO:
			continue
		var distance := Grid.manhattan(from, target)
		if distance > 3:
			continue
		var blocked := false
		for step in range(1, distance):
			var p := from + dir * step
			if grid.blocks_movement(p):
				blocked = true
				break
		if not blocked:
			status["has_line"] = true
			var line_cells := _line_intercept_cells(from, dir, distance, grid)
			var line_intercept_path := _nearest_intercept_path(grid, deploy_zone, line_cells)
			best_intercept_path = mini(best_intercept_path, line_intercept_path)
			if line_intercept_path <= MAX_OPENING_INTERCEPT_PATH:
				status["interceptable"] = true
			else:
				status["uninterceptable"] = true
			for intercept in line_cells:
				if not (intercept in status["intercept_cells"]):
					status["intercept_cells"].append(intercept)
	if bool(status.get("has_line", false)):
		status["intercept_path"] = best_intercept_path
	return status

static func _line_intercept_cells(from: Vector2i, dir: Vector2i, distance: int, grid: Grid) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for step in range(1, distance):
		var p := from + dir * step
		if grid.in_bounds(p) and not grid.blocks_movement(p):
			cells.append(p)
	return cells

static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
