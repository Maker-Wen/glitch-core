class_name BattleCandidateBatchPlaytester extends RefCounted
## Preview-only batch runner for generated map pool candidates.
##
## This wraps BattlePoolCandidateGenerator and BattleCandidatePlaytester so
## designers can scan multiple seeds, see fairness failures, and route risky
## pools back into map tuning. It is not part of runtime battle selection.

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const BattlePoolCandidateGeneratorScript := preload("res://scripts/data/battle_pool_candidate_generator.gd")
const BattleCandidatePlaytesterScript := preload("res://scripts/data/battle_candidate_playtester.gd")

const RESULT_APPROVED := "approved"
const RESULT_REVIEW := "review"
const RESULT_REJECTED := "rejected"

const MAX_EXAMPLES_PER_BUCKET := 4

static func run_batch(config_ids: Array, base_seed: int, seed_count: int, variant_count: int, progress_callback: Callable = Callable()) -> Dictionary:
	var summary := _empty_summary(base_seed, seed_count, variant_count)
	for config_id_value in config_ids:
		var config := _config_from_input(config_id_value)
		var config_id := String(config.get("config_id", ""))
		if config.is_empty():
			_add_global_issue(summary, "missing config: %s" % _input_label(config_id_value))
			continue
		_ensure_config_summary(summary, config_id, String(config.get("display_name", "")))
		for seed_offset in range(maxi(0, seed_count)):
			var seed := base_seed + seed_offset
			for variant_index in range(maxi(0, variant_count)):
				var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, seed, variant_index)
				var simulation := BattleCandidatePlaytesterScript.evaluate_candidate(config, candidate)
				var record := _candidate_record(config, candidate, simulation)
				_add_record(summary, record)
				if progress_callback.is_valid():
					progress_callback.call(record, summary)
	return summary

static func _config_from_input(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return BattleConfigCatalogScript.get_config(String(value))

static func _input_label(value) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		return String(value.get("config_id", "<dictionary>"))
	return String(value)

static func _empty_summary(base_seed: int, seed_count: int, variant_count: int) -> Dictionary:
	return {
		"base_seed": base_seed,
		"seed_count": seed_count,
		"variant_count": variant_count,
		"total": 0,
		"result_counts": _result_count_bucket(),
		"validation_counts": {},
		"solvability_counts": _result_count_bucket(),
		"issue_counts": {},
		"warning_counts": {},
		"pool_risks": {},
		"by_config": {},
		"records": [],
		"global_issues": [],
	}

static func _result_count_bucket() -> Dictionary:
	return {
		RESULT_APPROVED: 0,
		RESULT_REVIEW: 0,
		RESULT_REJECTED: 0,
	}

static func _candidate_record(config: Dictionary, candidate: Dictionary, simulation: Dictionary) -> Dictionary:
	var validation: Dictionary = candidate.get("validation", {})
	var diagnostics: Dictionary = validation.get("diagnostics", {})
	var validation_result := String(validation.get("result", ""))
	var solvability_result := String(simulation.get("result", ""))
	var issues := _prefixed_messages("static", validation.get("issues", [])) + _prefixed_messages("sim", simulation.get("issues", []))
	var warnings := _prefixed_messages("static", validation.get("warnings", [])) + _prefixed_messages("sim", simulation.get("warnings", []))
	var result := _combined_result(validation_result, solvability_result)
	return {
		"config_id": String(config.get("config_id", candidate.get("config_id", ""))),
		"display_name": String(config.get("display_name", candidate.get("display_name", ""))),
		"seed": int(candidate.get("seed", 0)),
		"variant_index": int(candidate.get("variant_index", 0)),
		"result": result,
		"validation_result": validation_result,
		"solvability_result": solvability_result,
		"issues": issues,
		"warnings": warnings,
		"diagnostics": diagnostics.duplicate(true),
		"source_pools": _source_pools(candidate),
		"selected_elements": _selected_element_ids(candidate.get("selected_elements", {})),
		"initial_enemies": candidate.get("initial_enemies", []).duplicate(true),
		"scripted_spawns": candidate.get("scripted_spawns", []).duplicate(true),
		"rift_schedule": candidate.get("rift_schedule", []).duplicate(true),
		"outcome": String(simulation.get("outcome", "")),
		"total_protected_damage": int(simulation.get("total_protected_damage", 0)),
		"destroyed": int(simulation.get("destroyed", 0)),
		"warden_deaths": int(simulation.get("warden_deaths", 0)),
		"enemies_left": int(simulation.get("enemies_left", 0)),
		"max_threat": int(simulation.get("max_threat", 0)),
		"boss": String(simulation.get("boss", "")),
		"deployment": simulation.get("deployment", []).duplicate(),
		"rounds": simulation.get("rounds", []).duplicate(true),
	}

static func _combined_result(validation_result: String, solvability_result: String) -> String:
	if validation_result == BattlePoolCandidateGeneratorScript.RESULT_REJECTED or solvability_result == BattleCandidatePlaytesterScript.RESULT_REJECTED:
		return RESULT_REJECTED
	if validation_result == BattlePoolCandidateGeneratorScript.RESULT_ADJUSTED or solvability_result == BattleCandidatePlaytesterScript.RESULT_REVIEW:
		return RESULT_REVIEW
	if solvability_result == BattleCandidatePlaytesterScript.RESULT_APPROVED:
		return RESULT_APPROVED
	return RESULT_REVIEW

static func _add_record(summary: Dictionary, record: Dictionary) -> void:
	summary["total"] = int(summary.get("total", 0)) + 1
	summary["records"].append(record)
	_increment(summary.get("result_counts", {}), String(record.get("result", "")))
	_increment(summary.get("validation_counts", {}), String(record.get("validation_result", "")))
	_increment(summary.get("solvability_counts", {}), String(record.get("solvability_result", "")))
	for issue in record.get("issues", []):
		_increment(summary.get("issue_counts", {}), String(issue))
	for warning in record.get("warnings", []):
		_increment(summary.get("warning_counts", {}), String(warning))
	var config_summary := _ensure_config_summary(summary, String(record.get("config_id", "")), String(record.get("display_name", "")))
	_add_record_to_config_summary(config_summary, record)
	_add_record_to_pool_risks(summary.get("pool_risks", {}), record)

static func _add_record_to_config_summary(config_summary: Dictionary, record: Dictionary) -> void:
	config_summary["total"] = int(config_summary.get("total", 0)) + 1
	_increment(config_summary.get("result_counts", {}), String(record.get("result", "")))
	_increment(config_summary.get("validation_counts", {}), String(record.get("validation_result", "")))
	_increment(config_summary.get("solvability_counts", {}), String(record.get("solvability_result", "")))
	for issue in record.get("issues", []):
		_increment(config_summary.get("issue_counts", {}), String(issue))
	for warning in record.get("warnings", []):
		_increment(config_summary.get("warning_counts", {}), String(warning))
	_add_record_to_diagnostics_summary(config_summary.get("diagnostics", {}), record)
	_add_record_to_pool_risks(config_summary.get("pool_risks", {}), record)
	if String(record.get("result", "")) != RESULT_APPROVED:
		_maybe_add_example(config_summary.get("examples", []), record)

static func _empty_diagnostics_summary() -> Dictionary:
	return {
		"max_worst_guard_path": 0,
		"max_opening_intercept_path": 0,
		"opening_pressure_count": 0,
		"opening_pressure_types": {},
		"unguarded_count": 0,
		"element_pool_counts": {},
		"max_feature_score": 0,
		"feature_core_counts": {},
		"feature_support_counts": {},
		"feature_risk_counts": {},
		"hazard_type_counts": {},
		"spawn_pressure_type_counts": {},
		"selected_element_counts": {},
	}

static func _add_record_to_diagnostics_summary(summary: Dictionary, record: Dictionary) -> void:
	var diagnostics: Dictionary = record.get("diagnostics", {})
	summary["max_worst_guard_path"] = maxi(
		int(summary.get("max_worst_guard_path", 0)),
		int(diagnostics.get("worst_guard_path", 0))
	)
	summary["opening_pressure_count"] = int(summary.get("opening_pressure_count", 0)) + int(diagnostics.get("opening_pressure_count", 0))
	var pressure_types: Dictionary = summary.get("opening_pressure_types", {})
	for row in diagnostics.get("opening_pressure", []):
		var pressure_type := String(row.get("pressure_type", "unknown"))
		_increment(pressure_types, pressure_type)
		var intercept_path := int(row.get("intercept_path", 99))
		if intercept_path < 99:
			summary["max_opening_intercept_path"] = maxi(
				int(summary.get("max_opening_intercept_path", 0)),
				intercept_path
			)
	summary["unguarded_count"] = int(summary.get("unguarded_count", 0)) + diagnostics.get("unguarded_targets", []).size()
	var element_counts: Dictionary = summary.get("element_pool_counts", {})
	var coverage: Dictionary = diagnostics.get("element_coverage", {})
	for pool_id in coverage.keys():
		_increment(element_counts, String(pool_id))
	var feature_profile: Dictionary = diagnostics.get("feature_profile", {})
	var feature_coverage: Dictionary = feature_profile.get("coverage", {})
	summary["max_feature_score"] = maxi(
		int(summary.get("max_feature_score", 0)),
		int(feature_coverage.get("score", 0))
	)
	_add_counts(summary.get("feature_core_counts", {}), feature_profile.get("core_features", []))
	_add_counts(summary.get("feature_support_counts", {}), feature_profile.get("support_features", []))
	_add_counts(summary.get("feature_risk_counts", {}), feature_profile.get("risk_sources", []))
	_add_counts_from_dict(summary.get("hazard_type_counts", {}), feature_profile.get("hazard_types", {}))
	_add_counts_from_dict(summary.get("spawn_pressure_type_counts", {}), feature_profile.get("spawn_pressure_types", {}))
	_add_counts(summary.get("selected_element_counts", {}), feature_profile.get("selected_element_ids", []))

static func _add_record_to_pool_risks(pool_risks: Dictionary, record: Dictionary) -> void:
	for pool_id in record.get("source_pools", []):
		if not pool_risks.has(pool_id):
			pool_risks[pool_id] = {
				"total": 0,
				"result_counts": _result_count_bucket(),
				"issue_counts": {},
				"warning_counts": {},
				"examples": [],
			}
		var entry: Dictionary = pool_risks.get(pool_id, {})
		entry["total"] = int(entry.get("total", 0)) + 1
		_increment(entry.get("result_counts", {}), String(record.get("result", "")))
		for issue in record.get("issues", []):
			_increment(entry.get("issue_counts", {}), String(issue))
		for warning in record.get("warnings", []):
			_increment(entry.get("warning_counts", {}), String(warning))
		if String(record.get("result", "")) != RESULT_APPROVED:
			_maybe_add_example(entry.get("examples", []), record)

static func _ensure_config_summary(summary: Dictionary, config_id: String, display_name: String) -> Dictionary:
	var by_config: Dictionary = summary.get("by_config", {})
	if not by_config.has(config_id):
		by_config[config_id] = {
			"config_id": config_id,
			"display_name": display_name,
			"total": 0,
			"result_counts": _result_count_bucket(),
			"validation_counts": {},
			"solvability_counts": _result_count_bucket(),
			"issue_counts": {},
			"warning_counts": {},
			"pool_risks": {},
			"diagnostics": _empty_diagnostics_summary(),
			"examples": [],
		}
	return by_config.get(config_id, {})

static func _maybe_add_example(examples: Array, record: Dictionary) -> void:
	if examples.size() >= MAX_EXAMPLES_PER_BUCKET:
		return
	examples.append({
		"config_id": String(record.get("config_id", "")),
		"display_name": String(record.get("display_name", "")),
		"seed": int(record.get("seed", 0)),
		"variant_index": int(record.get("variant_index", 0)),
		"result": String(record.get("result", "")),
		"validation_result": String(record.get("validation_result", "")),
		"solvability_result": String(record.get("solvability_result", "")),
		"issues": record.get("issues", []).duplicate(),
		"warnings": record.get("warnings", []).duplicate(),
		"diagnostics": record.get("diagnostics", {}).duplicate(true),
		"source_pools": record.get("source_pools", []).duplicate(),
		"selected_elements": record.get("selected_elements", {}).duplicate(true),
		"initial_enemies": record.get("initial_enemies", []).duplicate(true),
		"scripted_spawns": record.get("scripted_spawns", []).duplicate(true),
		"rift_schedule": record.get("rift_schedule", []).duplicate(true),
		"outcome": String(record.get("outcome", "")),
		"total_protected_damage": int(record.get("total_protected_damage", 0)),
		"destroyed": int(record.get("destroyed", 0)),
		"warden_deaths": int(record.get("warden_deaths", 0)),
		"enemies_left": int(record.get("enemies_left", 0)),
		"max_threat": int(record.get("max_threat", 0)),
		"rounds": record.get("rounds", []).duplicate(true),
	})

static func _source_pools(candidate: Dictionary) -> Array[String]:
	var pools: Array[String] = []
	for group_id in ["initial_enemies", "scripted_spawns", "rift_schedule"]:
		for entry in candidate.get(group_id, []):
			var pool_id := String(entry.get("source_pool", group_id))
			if pool_id.is_empty():
				pool_id = group_id
			if not (pool_id in pools):
				pools.append(pool_id)
	pools.sort()
	return pools

static func _selected_element_ids(elements: Dictionary) -> Dictionary:
	var result := {}
	for pool_id in elements.keys():
		var entry: Dictionary = elements.get(pool_id, {})
		result[String(pool_id)] = String(entry.get("id", ""))
	return result

static func _prefixed_messages(prefix: String, values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		var text := String(value)
		if text.is_empty():
			continue
		result.append("%s: %s" % [prefix, text])
	return result

static func _increment(bucket: Dictionary, key: String) -> void:
	if key.is_empty():
		key = "unknown"
	bucket[key] = int(bucket.get(key, 0)) + 1

static func _add_counts(bucket: Dictionary, values: Array) -> void:
	for value in values:
		_increment(bucket, String(value))

static func _add_counts_from_dict(bucket: Dictionary, counts: Dictionary) -> void:
	for key in counts.keys():
		bucket[String(key)] = int(bucket.get(String(key), 0)) + int(counts.get(key, 0))

static func _add_global_issue(summary: Dictionary, issue: String) -> void:
	summary["global_issues"].append(issue)
	_increment(summary.get("issue_counts", {}), issue)
