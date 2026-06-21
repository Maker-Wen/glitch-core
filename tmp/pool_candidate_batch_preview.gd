extends SceneTree
## Prints preview-only batch playtest results for map pool candidates.
##
## Usage:
##   godot --headless -s tmp/pool_candidate_batch_preview.gd

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const BattleCandidateBatchPlaytesterScript := preload("res://scripts/data/battle_candidate_batch_playtester.gd")

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
const TOP_BUCKET_LIMIT := 6

func _init() -> void:
	print("=== map pool batch preview ===")
	print("preview_only=true runtime_catalog_unchanged=true base_seed=%d seed_count=%d variant_count=%d" % [
		BASE_SEED,
		SEED_COUNT,
		VARIANT_COUNT,
	])
	var summary := BattleCandidateBatchPlaytesterScript.run_batch(CONFIG_IDS, BASE_SEED, SEED_COUNT, VARIANT_COUNT, _on_progress)
	_print_summary(summary)
	quit(0)

func _on_progress(record: Dictionary, summary: Dictionary) -> void:
	var total := int(summary.get("total", 0))
	if total % 5 != 0:
		return
	print("progress %d/%d latest=[%s] seed=%d variant=%d result=%s validation=%s solvability=%s" % [
		total,
		CONFIG_IDS.size() * SEED_COUNT * VARIANT_COUNT,
		String(record.get("config_id", "")),
		int(record.get("seed", 0)),
		int(record.get("variant_index", 0)),
		String(record.get("result", "")),
		String(record.get("validation_result", "")),
		String(record.get("solvability_result", "")),
	])

func _print_summary(summary: Dictionary) -> void:
	print("")
	print("total=%d result=%s validation=%s solvability=%s" % [
		int(summary.get("total", 0)),
		_counts_text(summary.get("result_counts", {})),
		_counts_text(summary.get("validation_counts", {})),
		_counts_text(summary.get("solvability_counts", {})),
	])
	_print_config_summaries(summary.get("by_config", {}))
	_print_bucket("top issues", summary.get("issue_counts", {}), TOP_BUCKET_LIMIT)
	_print_bucket("top warnings", summary.get("warning_counts", {}), TOP_BUCKET_LIMIT)
	_print_pool_risks(summary.get("pool_risks", {}))
	_print_examples(summary.get("by_config", {}))

func _print_config_summaries(by_config: Dictionary) -> void:
	print("")
	print("per map:")
	var config_ids := by_config.keys()
	config_ids.sort()
	for config_id in config_ids:
		var item: Dictionary = by_config.get(config_id, {})
		var total := int(item.get("total", 0))
		var counts: Dictionary = item.get("result_counts", {})
		var approved := int(counts.get(BattleCandidateBatchPlaytesterScript.RESULT_APPROVED, 0))
		var pass_rate := 0.0
		if total > 0:
			pass_rate = float(approved) / float(total) * 100.0
		print("  [%s] %s total=%d pass_rate=%.1f%% result=%s validation=%s solvability=%s" % [
			String(config_id),
			String(item.get("display_name", "")),
			total,
			pass_rate,
			_counts_text(counts),
			_counts_text(item.get("validation_counts", {})),
			_counts_text(item.get("solvability_counts", {})),
		])
		var diagnostics: Dictionary = item.get("diagnostics", {})
		print("    structure: worst_guard_path=%d opening_pressure=%d pressure_types=%s max_intercept_path=%d unguarded=%d element_coverage=%s" % [
			int(diagnostics.get("max_worst_guard_path", 0)),
			int(diagnostics.get("opening_pressure_count", 0)),
			_counts_text(diagnostics.get("opening_pressure_types", {})),
			int(diagnostics.get("max_opening_intercept_path", 0)),
			int(diagnostics.get("unguarded_count", 0)),
			_counts_text(diagnostics.get("element_pool_counts", {})),
		])

func _print_pool_risks(pool_risks: Dictionary) -> void:
	print("")
	print("pool risk summary:")
	var rows: Array = []
	for pool_id in pool_risks.keys():
		var item: Dictionary = pool_risks.get(pool_id, {})
		var counts: Dictionary = item.get("result_counts", {})
		var rejected := int(counts.get(BattleCandidateBatchPlaytesterScript.RESULT_REJECTED, 0))
		var review := int(counts.get(BattleCandidateBatchPlaytesterScript.RESULT_REVIEW, 0))
		rows.append({
			"pool_id": String(pool_id),
			"score": rejected * 1000 + review * 100 + int(item.get("total", 0)),
			"item": item,
		})
	rows.sort_custom(func(a, b): return int(a.score) > int(b.score))
	if rows.is_empty():
		print("  -")
		return
	for row in rows.slice(0, mini(TOP_BUCKET_LIMIT, rows.size())):
		var item: Dictionary = row.item
		print("  %s total=%d result=%s issues=%s warnings=%s" % [
			String(row.pool_id),
			int(item.get("total", 0)),
			_counts_text(item.get("result_counts", {})),
			_top_text(item.get("issue_counts", {}), 2),
			_top_text(item.get("warning_counts", {}), 2),
		])

func _print_examples(by_config: Dictionary) -> void:
	var any_example := false
	for config_id in by_config.keys():
		var item: Dictionary = by_config.get(config_id, {})
		if not item.get("examples", []).is_empty():
			any_example = true
			break
	if not any_example:
		print("")
		print("examples: none")
		return
	print("")
	print("examples needing review:")
	var config_ids := by_config.keys()
	config_ids.sort()
	for config_id in config_ids:
		var item: Dictionary = by_config.get(config_id, {})
		for example in item.get("examples", []):
			print("  [%s] seed=%d variant=%d result=%s validation=%s solvability=%s pools=%s" % [
				String(config_id),
				int(example.get("seed", 0)),
				int(example.get("variant_index", 0)),
				String(example.get("result", "")),
				String(example.get("validation_result", "")),
				String(example.get("solvability_result", "")),
				", ".join(_string_array(example.get("source_pools", []))),
			])
			print("    elements: %s" % _elements_text(example.get("selected_elements", {})))
			print("    initial: %s" % _entry_list_text(example.get("initial_enemies", [])))
			print("    scripted: %s" % _entry_list_text(example.get("scripted_spawns", [])))
			print("    rifts: %s" % _entry_list_text(example.get("rift_schedule", [])))
			if not example.get("issues", []).is_empty():
				print("    issues: %s" % " | ".join(_string_array(example.get("issues", []))))
			if not example.get("warnings", []).is_empty():
				print("    warnings: %s" % " | ".join(_string_array(example.get("warnings", []))))
			print("    diagnostics: %s" % _diagnostics_text(example.get("diagnostics", {})))
			print("    sim: outcome=%s dmg=%d destroyed=%d deaths=%d left=%d max_threat=%d rounds=%s" % [
				String(example.get("outcome", "")),
				int(example.get("total_protected_damage", 0)),
				int(example.get("destroyed", 0)),
				int(example.get("warden_deaths", 0)),
				int(example.get("enemies_left", 0)),
				int(example.get("max_threat", 0)),
				_round_list_text(example.get("rounds", [])),
			])

func _print_bucket(label: String, bucket: Dictionary, limit: int) -> void:
	print("")
	print("%s:" % label)
	var text := _top_text(bucket, limit)
	if text == "-":
		print("  -")
		return
	for part in text.split("; "):
		print("  %s" % part)

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

func _elements_text(elements: Dictionary) -> String:
	if elements.is_empty():
		return "-"
	var keys := elements.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s=%s" % [String(key), String(elements.get(key, ""))])
	return "; ".join(parts)

func _entry_list_text(entries: Array) -> String:
	if entries.is_empty():
		return "-"
	var parts: Array[String] = []
	for entry in entries:
		var round := int(entry.get("round", 1))
		var enemy_id := String(entry.get("enemy_id", ""))
		var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
		var source_pool := String(entry.get("source_pool", ""))
		parts.append("R%d %s@%s/%s" % [round, enemy_id, _v(pos), source_pool])
	return "; ".join(parts)

func _round_list_text(rounds: Array) -> String:
	if rounds.is_empty():
		return "-"
	var parts: Array[String] = []
	for entry in rounds:
		var round: Dictionary = entry
		parts.append("R%d threat=%d dmg=%d left=%d actions=%d" % [
			int(round.get("round", 0)),
			int(round.get("threat", 0)),
			int(round.get("protected_damage", 0)),
			int(round.get("enemies_left", 0)),
			round.get("actions", []).size(),
		])
	return " | ".join(parts)

func _diagnostics_text(diagnostics: Dictionary) -> String:
	if diagnostics.is_empty():
		return "-"
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

func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

func _increment(bucket: Dictionary, key: String) -> void:
	if key.is_empty():
		key = "unknown"
	bucket[key] = int(bucket.get(key, 0)) + 1

func _v(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]
