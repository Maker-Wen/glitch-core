extends SceneTree
## Fast preview-only static validation for map pool candidates.
##
## Usage:
##   godot --headless -s tmp/pool_candidate_static_preview.gd

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const BattlePoolCandidateGeneratorScript := preload("res://scripts/data/battle_pool_candidate_generator.gd")

const CONFIG_IDS := [
	BattleConfigCatalogScript.CONFIG_OUTER_WALL,
	BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
	BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD,
	BattleConfigCatalogScript.CONFIG_IRON_GATE,
	BattleConfigCatalogScript.CONFIG_OUTER_BELL,
]

const BASE_SEED := 240620
const SEED_COUNT := 5
const VARIANT_COUNT := 3

func _init() -> void:
	print("=== map pool static preview ===")
	print("preview_only=true runtime_catalog_unchanged=true base_seed=%d seed_count=%d variant_count=%d" % [
		BASE_SEED,
		SEED_COUNT,
		VARIANT_COUNT,
	])
	var summary := _run_static_preview()
	_print_summary(summary)
	quit(0 if int(summary.get("rejected", 0)) == 0 else 1)

func _run_static_preview() -> Dictionary:
	var summary := {
		"total": 0,
		"valid": 0,
		"adjusted": 0,
		"rejected": 0,
		"by_config": {},
		"issues": {},
		"warnings": {},
		"examples": [],
	}
	for config_id in CONFIG_IDS:
		var config := BattleConfigCatalogScript.get_config(config_id)
		_ensure_config(summary, String(config_id), String(config.get("display_name", "")))
		for seed_offset in range(SEED_COUNT):
			var seed := BASE_SEED + seed_offset
			for variant_index in range(VARIANT_COUNT):
				var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, seed, variant_index)
				_add_candidate(summary, candidate)
	return summary

func _ensure_config(summary: Dictionary, config_id: String, display_name: String) -> Dictionary:
	var by_config: Dictionary = summary.get("by_config", {})
	if not by_config.has(config_id):
		by_config[config_id] = {
			"config_id": config_id,
			"display_name": display_name,
			"total": 0,
			"valid": 0,
			"adjusted": 0,
			"rejected": 0,
			"max_worst_guard_path": 0,
			"max_opening_intercept_path": 0,
			"opening_pressure_count": 0,
			"opening_pressure_types": {},
			"unguarded_count": 0,
			"element_pool_counts": {},
		}
	return by_config.get(config_id, {})

func _add_candidate(summary: Dictionary, candidate: Dictionary) -> void:
	var validation: Dictionary = candidate.get("validation", {})
	var diagnostics: Dictionary = validation.get("diagnostics", {})
	var result := String(validation.get("result", ""))
	var config_id := String(candidate.get("config_id", ""))
	var config_summary := _ensure_config(summary, config_id, String(candidate.get("display_name", "")))
	summary["total"] = int(summary.get("total", 0)) + 1
	config_summary["total"] = int(config_summary.get("total", 0)) + 1
	if result == BattlePoolCandidateGeneratorScript.RESULT_REJECTED:
		summary["rejected"] = int(summary.get("rejected", 0)) + 1
		config_summary["rejected"] = int(config_summary.get("rejected", 0)) + 1
	elif result == BattlePoolCandidateGeneratorScript.RESULT_ADJUSTED:
		summary["adjusted"] = int(summary.get("adjusted", 0)) + 1
		config_summary["adjusted"] = int(config_summary.get("adjusted", 0)) + 1
	else:
		summary["valid"] = int(summary.get("valid", 0)) + 1
		config_summary["valid"] = int(config_summary.get("valid", 0)) + 1
	for issue in validation.get("issues", []):
		_increment(summary.get("issues", {}), String(issue))
	for warning in validation.get("warnings", []):
		_increment(summary.get("warnings", {}), String(warning))
	if result != BattlePoolCandidateGeneratorScript.RESULT_VALID and summary.get("examples", []).size() < 8:
		summary.get("examples", []).append({
			"config_id": config_id,
			"seed": int(candidate.get("seed", 0)),
			"variant_index": int(candidate.get("variant_index", 0)),
			"result": result,
			"issues": validation.get("issues", []).duplicate(),
			"warnings": validation.get("warnings", []).duplicate(),
			"diagnostics": diagnostics.duplicate(true),
		})
	config_summary["max_worst_guard_path"] = maxi(
		int(config_summary.get("max_worst_guard_path", 0)),
		int(diagnostics.get("worst_guard_path", 0))
	)
	config_summary["opening_pressure_count"] = int(config_summary.get("opening_pressure_count", 0)) + int(diagnostics.get("opening_pressure_count", 0))
	config_summary["unguarded_count"] = int(config_summary.get("unguarded_count", 0)) + diagnostics.get("unguarded_targets", []).size()
	for row in diagnostics.get("opening_pressure", []):
		_increment(config_summary.get("opening_pressure_types", {}), String(row.get("pressure_type", "unknown")))
		var intercept_path := int(row.get("intercept_path", 99))
		if intercept_path < 99:
			config_summary["max_opening_intercept_path"] = maxi(int(config_summary.get("max_opening_intercept_path", 0)), intercept_path)
	var coverage: Dictionary = diagnostics.get("element_coverage", {})
	for pool_id in coverage.keys():
		_increment(config_summary.get("element_pool_counts", {}), String(pool_id))

func _print_summary(summary: Dictionary) -> void:
	print("")
	print("total=%d valid=%d adjusted=%d rejected=%d" % [
		int(summary.get("total", 0)),
		int(summary.get("valid", 0)),
		int(summary.get("adjusted", 0)),
		int(summary.get("rejected", 0)),
	])
	print("")
	print("per map:")
	var config_ids: Array = summary.get("by_config", {}).keys()
	config_ids.sort()
	for config_id in config_ids:
		var item: Dictionary = summary.get("by_config", {}).get(config_id, {})
		print("  [%s] %s total=%d valid=%d adjusted=%d rejected=%d" % [
			String(config_id),
			String(item.get("display_name", "")),
			int(item.get("total", 0)),
			int(item.get("valid", 0)),
			int(item.get("adjusted", 0)),
			int(item.get("rejected", 0)),
		])
		print("    structure: worst_guard_path=%d opening_pressure=%d pressure_types=%s max_intercept_path=%d unguarded=%d element_coverage=%s" % [
			int(item.get("max_worst_guard_path", 0)),
			int(item.get("opening_pressure_count", 0)),
			_counts_text(item.get("opening_pressure_types", {})),
			int(item.get("max_opening_intercept_path", 0)),
			int(item.get("unguarded_count", 0)),
			_counts_text(item.get("element_pool_counts", {})),
		])
	_print_bucket("top issues", summary.get("issues", {}), 6)
	_print_bucket("top warnings", summary.get("warnings", {}), 6)
	_print_examples(summary.get("examples", []))

func _print_bucket(label: String, bucket: Dictionary, limit: int) -> void:
	print("")
	print("%s:" % label)
	var text := _top_text(bucket, limit)
	if text == "-":
		print("  -")
		return
	for part in text.split("; "):
		print("  %s" % part)

func _print_examples(examples: Array) -> void:
	print("")
	if examples.is_empty():
		print("examples: none")
		return
	print("examples:")
	for example in examples:
		print("  [%s] seed=%d variant=%d result=%s issues=%s warnings=%s diagnostics=%s" % [
			String(example.get("config_id", "")),
			int(example.get("seed", 0)),
			int(example.get("variant_index", 0)),
			String(example.get("result", "")),
			" | ".join(_string_array(example.get("issues", []))),
			" | ".join(_string_array(example.get("warnings", []))),
			_diagnostics_text(example.get("diagnostics", {})),
		])

func _diagnostics_text(diagnostics: Dictionary) -> String:
	return "worst_guard_path=%d opening_pressure=%d pressure_types=%s max_intercept_path=%d unguarded=%s" % [
		int(diagnostics.get("worst_guard_path", 0)),
		int(diagnostics.get("opening_pressure_count", 0)),
		_pressure_types_text(diagnostics.get("opening_pressure", [])),
		_max_intercept_path(diagnostics.get("opening_pressure", [])),
		", ".join(_string_array(diagnostics.get("unguarded_targets", []))),
	]

func _pressure_types_text(rows: Array) -> String:
	if rows.is_empty():
		return "-"
	var counts := {}
	for row in rows:
		_increment(counts, String(row.get("pressure_type", "unknown")))
	return _counts_text(counts)

func _max_intercept_path(rows: Array) -> int:
	var best := 0
	for row in rows:
		var value := int(row.get("intercept_path", 99))
		if value < 99:
			best = maxi(best, value)
	return best

func _counts_text(counts: Dictionary) -> String:
	if counts.is_empty():
		return "-"
	var keys := counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s=%d" % [String(key), int(counts.get(key, 0))])
	return ", ".join(parts)

func _top_text(bucket: Dictionary, limit: int) -> String:
	if bucket.is_empty():
		return "-"
	var rows: Array = []
	for key in bucket.keys():
		rows.append({"key": String(key), "count": int(bucket.get(key, 0))})
	rows.sort_custom(func(a, b):
		if int(a.count) != int(b.count):
			return int(a.count) > int(b.count)
		return String(a.key) < String(b.key)
	)
	var parts: Array[String] = []
	for row in rows.slice(0, mini(limit, rows.size())):
		parts.append("%s=%d" % [String(row.key), int(row.count)])
	return "; ".join(parts)

func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

func _increment(bucket: Dictionary, key: String) -> void:
	if key.is_empty():
		key = "unknown"
	bucket[key] = int(bucket.get(key, 0)) + 1
