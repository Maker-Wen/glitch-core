class_name RunMapPoolAuditor extends RefCounted
## Structured audit report for expedition battle map pool assignments.

const RunStateScript := preload("res://scripts/run/run_state.gd")
const RunExpeditionCatalogScript := preload("res://scripts/data/run_expedition_catalog.gd")

const DEFAULT_SEEDS := [1, 7, 19]

static func audit(expedition_ids: Array = [], seeds: Array = DEFAULT_SEEDS) -> Dictionary:
	var selected_expeditions := _selected_expedition_ids(expedition_ids)
	var selected_seeds := _selected_seeds(seeds)
	var report := {
		"seeds": selected_seeds,
		"expedition_ids": selected_expeditions,
		"total_runs": 0,
		"total_battles": 0,
		"total_relaxed": 0,
		"expeditions": {},
	}
	for expedition_id in selected_expeditions:
		var expedition_report := _empty_expedition_report(expedition_id)
		for seed in selected_seeds:
			var run = RunStateScript.new()
			run.setup_new_random_route(int(seed), expedition_id)
			var run_rows := run.battle_map_assignment_debug_rows()
			var run_report := _run_report(run, run_rows)
			expedition_report["runs"].append(run_report)
			_add_rows_to_expedition(expedition_report, run_rows)
			report["total_runs"] = int(report.get("total_runs", 0)) + 1
			report["total_battles"] = int(report.get("total_battles", 0)) + run_rows.size()
			report["total_relaxed"] = int(report.get("total_relaxed", 0)) + int(run_report.get("relaxed_count", 0))
		report["expeditions"][expedition_id] = expedition_report
	return report

static func text_report(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Map Pool Audit")
	lines.append("seeds=%s runs=%d battles=%d relaxed=%d" % [
		_join_values(report.get("seeds", [])),
		int(report.get("total_runs", 0)),
		int(report.get("total_battles", 0)),
		int(report.get("total_relaxed", 0)),
	])
	var expedition_ids: Array = report.get("expedition_ids", [])
	var expeditions: Dictionary = report.get("expeditions", {})
	for expedition_id in expedition_ids:
		var exp: Dictionary = expeditions.get(String(expedition_id), {})
		if exp.is_empty():
			continue
		lines.append("")
		lines.append("[%s] %s" % [String(exp.get("expedition_id", "")), String(exp.get("display_name", ""))])
		lines.append("battles=%d relaxed=%d pressure=%d" % [
			int(exp.get("battle_count", 0)),
			int(exp.get("relaxed_count", 0)),
			int(exp.get("pressure_total", 0)),
		])
		lines.append("configured pools: %s" % _format_counts(exp.get("configured_pool_counts", {})))
		lines.append("pools: %s" % _format_counts(exp.get("pool_counts", {})))
		lines.append("configs: %s" % _format_counts(exp.get("config_counts", {})))
		lines.append("repeat groups: %s" % _format_counts(exp.get("repeat_group_counts", {})))
		lines.append("relaxed: %s" % _format_counts(exp.get("relaxed_counts", {})))
		lines.append("pressure by pool: %s" % _format_counts(exp.get("pressure_by_pool", {})))
		for run_report in exp.get("runs", []):
			lines.append("  seed=%d battles=%d relaxed=%d pressure=%d" % [
				int(run_report.get("seed", 0)),
				int(run_report.get("battle_count", 0)),
				int(run_report.get("relaxed_count", 0)),
				int(run_report.get("pressure_total", 0)),
			])
			for row in run_report.get("rows", []):
				lines.append("    L%d %-6s %-28s pool=%-6s config=%-34s pressure=%d repeat=%s relaxed=%s" % [
					int(row.get("layer", 0)),
					String(row.get("node_type", "")),
					String(row.get("node_id", "")),
					String(row.get("pool_key", "")),
					String(row.get("config_id", "")),
					int(row.get("pressure_cost", 0)),
					String(row.get("repeat_group", "")),
					_relaxed_label(String(row.get("assignment_relaxed", ""))),
				])
	return "\n".join(lines)

static func _selected_expedition_ids(expedition_ids: Array) -> Array[String]:
	if expedition_ids.is_empty():
		return RunExpeditionCatalogScript.expedition_ids()
	var result: Array[String] = []
	for expedition_id in expedition_ids:
		var id := String(expedition_id)
		if id.is_empty():
			continue
		if not (id in result):
			result.append(id)
	return result

static func _selected_seeds(seeds: Array) -> Array[int]:
	var result: Array[int] = []
	for seed in seeds:
		result.append(int(seed))
	if result.is_empty():
		for seed in DEFAULT_SEEDS:
			result.append(int(seed))
	return result

static func _empty_expedition_report(expedition_id: String) -> Dictionary:
	return {
		"expedition_id": expedition_id,
		"display_name": RunExpeditionCatalogScript.display_name(expedition_id),
		"runs": [],
		"rows": [],
		"battle_count": 0,
		"relaxed_count": 0,
		"pressure_total": 0,
		"pool_counts": {},
		"configured_pool_counts": _configured_pool_counts(expedition_id),
		"config_counts": {},
		"repeat_group_counts": {},
		"relaxed_counts": {},
		"pressure_by_pool": {},
	}

static func _run_report(run: RunStateScript, rows: Array[Dictionary]) -> Dictionary:
	var result := {
		"seed": run.run_seed,
		"expedition_id": run.expedition_id,
		"display_name": run.expedition_name,
		"battle_count": rows.size(),
		"relaxed_count": 0,
		"pressure_total": 0,
		"pool_counts": {},
		"config_counts": {},
		"relaxed_counts": {},
		"rows": [],
	}
	for row in rows:
		var normalized := row.duplicate(true)
		normalized["relaxed_label"] = _relaxed_label(String(row.get("assignment_relaxed", "")))
		result["rows"].append(normalized)
		_add_row_counts(result, row)
	return result

static func _add_rows_to_expedition(expedition_report: Dictionary, rows: Array[Dictionary]) -> void:
	for row in rows:
		expedition_report["rows"].append(row.duplicate(true))
		expedition_report["battle_count"] = int(expedition_report.get("battle_count", 0)) + 1
		_add_row_counts(expedition_report, row)

static func _add_row_counts(target: Dictionary, row: Dictionary) -> void:
	var pool_key := String(row.get("pool_key", ""))
	var config_id := String(row.get("config_id", ""))
	var repeat_group := String(row.get("repeat_group", ""))
	var relaxed := _relaxed_label(String(row.get("assignment_relaxed", "")))
	var pressure := int(row.get("pressure_cost", 0))
	_increment(target.get("pool_counts", {}), pool_key)
	_increment(target.get("config_counts", {}), config_id)
	if target.has("repeat_group_counts"):
		_increment(target.get("repeat_group_counts", {}), repeat_group)
	_increment(target.get("relaxed_counts", {}), relaxed)
	target["pressure_total"] = int(target.get("pressure_total", 0)) + pressure
	if target.has("pressure_by_pool"):
		var pressure_by_pool: Dictionary = target.get("pressure_by_pool", {})
		pressure_by_pool[pool_key] = int(pressure_by_pool.get(pool_key, 0)) + pressure
	if relaxed != "strict":
		target["relaxed_count"] = int(target.get("relaxed_count", 0)) + 1

static func _increment(counts: Dictionary, key: String) -> void:
	if key.is_empty():
		key = "<empty>"
	counts[key] = int(counts.get(key, 0)) + 1

static func _configured_pool_counts(expedition_id: String) -> Dictionary:
	var result := {}
	var config := RunExpeditionCatalogScript.get_config(expedition_id)
	var map_pool: Dictionary = config.get("map_pool", {})
	for pool_key in map_pool.keys():
		result[String(pool_key)] = map_pool.get(pool_key, []).size()
	return result

static func _relaxed_label(value: String) -> String:
	return "strict" if value.is_empty() else value

static func _format_counts(counts: Dictionary) -> String:
	if counts.is_empty():
		return "-"
	var keys := counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s=%d" % [String(key), int(counts.get(key, 0))])
	return ", ".join(parts)

static func _join_values(values: Array) -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append(str(value))
	return ",".join(parts)
