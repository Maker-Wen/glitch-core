extends RefCounted
## Audit report coverage for expedition battle map pool assignments.

const RunMapPoolAuditorScript := preload("res://scripts/data/run_map_pool_auditor.gd")
const RunExpeditionCatalogScript := preload("res://scripts/data/run_expedition_catalog.gd")

static func run(tr) -> void:
	_test_single_expedition_audit_report(tr)
	_test_default_audit_covers_all_expeditions(tr)
	_test_text_report_is_readable(tr)

static func _test_single_expedition_audit_report(tr) -> void:
	var expedition_id := RunExpeditionCatalogScript.EXPEDITION_BROKEN_WALL
	var report := RunMapPoolAuditorScript.audit([expedition_id], [1, 7])
	tr.assert_eq("single expedition audit run count", int(report.get("total_runs", 0)), 2)
	tr.assert_true("single expedition audit has battles", int(report.get("total_battles", 0)) > 0)
	tr.assert_true("single expedition report stored", report.get("expeditions", {}).has(expedition_id))
	var expedition_report: Dictionary = report.get("expeditions", {}).get(expedition_id, {})
	tr.assert_eq("single expedition battle count mirrors total", int(expedition_report.get("battle_count", 0)), int(report.get("total_battles", 0)))
	tr.assert_eq("single expedition run reports", expedition_report.get("runs", []).size(), 2)
	tr.assert_true("single expedition has pool counts", not expedition_report.get("pool_counts", {}).is_empty())
	tr.assert_true("single expedition has configured pool counts", not expedition_report.get("configured_pool_counts", {}).is_empty())
	tr.assert_true("single expedition has config counts", not expedition_report.get("config_counts", {}).is_empty())
	tr.assert_true("single expedition has repeat group counts", not expedition_report.get("repeat_group_counts", {}).is_empty())
	tr.assert_true("single expedition has pressure by pool", not expedition_report.get("pressure_by_pool", {}).is_empty())
	for run_report in expedition_report.get("runs", []):
		tr.assert_true("run report has battle rows seed %d" % int(run_report.get("seed", 0)), run_report.get("rows", []).size() > 0)
		tr.assert_true("run report has pool counts seed %d" % int(run_report.get("seed", 0)), not run_report.get("pool_counts", {}).is_empty())
		tr.assert_true("run report has config counts seed %d" % int(run_report.get("seed", 0)), not run_report.get("config_counts", {}).is_empty())

static func _test_default_audit_covers_all_expeditions(tr) -> void:
	var report := RunMapPoolAuditorScript.audit()
	tr.assert_eq("default audit expedition count", report.get("expedition_ids", []).size(), RunExpeditionCatalogScript.expedition_ids().size())
	tr.assert_eq("default audit run count", int(report.get("total_runs", 0)), RunExpeditionCatalogScript.expedition_ids().size() * RunMapPoolAuditorScript.DEFAULT_SEEDS.size())
	tr.assert_true("default audit has battles", int(report.get("total_battles", 0)) > 0)
	for expedition_id in RunExpeditionCatalogScript.expedition_ids():
		tr.assert_true("default audit includes %s" % expedition_id, report.get("expeditions", {}).has(expedition_id))

static func _test_text_report_is_readable(tr) -> void:
	var expedition_id := RunExpeditionCatalogScript.EXPEDITION_RIFT_CORRIDOR
	var report := RunMapPoolAuditorScript.audit([expedition_id], [7])
	var text := RunMapPoolAuditorScript.text_report(report)
	tr.assert_true("audit text has title", text.contains("Map Pool Audit"))
	tr.assert_true("audit text has expedition id", text.contains(expedition_id))
	tr.assert_true("audit text has expedition name", text.contains(RunExpeditionCatalogScript.display_name(expedition_id)))
	tr.assert_true("audit text has configured pools", text.contains("configured pools:"))
	tr.assert_true("audit text has pool fields", text.contains("pool="))
	tr.assert_true("audit text has config fields", text.contains("config="))
	tr.assert_true("audit text has repeat groups", text.contains("repeat groups:"))
	tr.assert_true("audit text has pressure by pool", text.contains("pressure by pool:"))
	tr.assert_true("audit text has relaxed status", text.contains("strict") or text.contains("relaxed="))
