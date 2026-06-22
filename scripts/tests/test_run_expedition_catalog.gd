extends RefCounted
## Expedition catalog regressions for random route map pool configuration.

const RunExpeditionCatalogScript := preload("res://scripts/data/run_expedition_catalog.gd")
const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")

static func run(tr) -> void:
	_test_expedition_configs_are_complete(tr)
	_test_map_pool_entries_have_contract_fields(tr)
	_test_config_is_defensive_copy(tr)

static func _test_expedition_configs_are_complete(tr) -> void:
	tr.assert_eq("expedition count", RunExpeditionCatalogScript.expedition_ids().size(), 3)
	for expedition_id in RunExpeditionCatalogScript.expedition_ids():
		var config := RunExpeditionCatalogScript.get_config(expedition_id)
		tr.assert_true("%s display name" % expedition_id, not String(config.get("display_name", "")).is_empty())
		tr.assert_true("%s node pools" % expedition_id, not config.get("node_pools", {}).is_empty())
		tr.assert_true("%s map pool" % expedition_id, not config.get("map_pool", {}).is_empty())
		tr.assert_true("%s pressure budget" % expedition_id, not config.get("pressure_budget", {}).is_empty())
		for pool_key in [
			RunExpeditionCatalogScript.MAP_POOL_START,
			RunExpeditionCatalogScript.MAP_POOL_NORMAL,
			RunExpeditionCatalogScript.MAP_POOL_ELITE,
			RunExpeditionCatalogScript.MAP_POOL_BOSS,
		]:
			tr.assert_true("%s has %s map pool" % [expedition_id, pool_key], config.get("map_pool", {}).get(pool_key, []).size() > 0)

static func _test_map_pool_entries_have_contract_fields(tr) -> void:
	for expedition_id in RunExpeditionCatalogScript.expedition_ids():
		var config := RunExpeditionCatalogScript.get_config(expedition_id)
		var map_pool: Dictionary = config.get("map_pool", {})
		for pool_key in map_pool.keys():
			for entry in map_pool.get(pool_key, []):
				var config_id := String(entry.get("config_id", ""))
				tr.assert_true("%s %s config exists %s" % [expedition_id, pool_key, config_id], not BattleConfigCatalogScript.get_config(config_id).is_empty())
				tr.assert_true("%s %s weight %s" % [expedition_id, pool_key, config_id], int(entry.get("weight", 0)) > 0)
				tr.assert_true("%s %s node types %s" % [expedition_id, pool_key, config_id], entry.get("allowed_node_types", []).size() > 0)
				tr.assert_true("%s %s layer range %s" % [expedition_id, pool_key, config_id], int(entry.get("min_layer", 0)) <= int(entry.get("max_layer", 0)))
				tr.assert_true("%s %s pressure tags %s" % [expedition_id, pool_key, config_id], entry.get("pressure_tags", []).size() > 0)
				tr.assert_eq("%s %s pressure cost %s" % [expedition_id, pool_key, config_id], int(entry.get("pressure_cost", -1)), entry.get("pressure_tags", []).size())
				tr.assert_true("%s %s repeat group %s" % [expedition_id, pool_key, config_id], not String(entry.get("no_repeat_group", "")).is_empty())
				tr.assert_true("%s %s archetype %s" % [expedition_id, pool_key, config_id], not String(entry.get("archetype", "")).is_empty())
				tr.assert_true("%s %s enemy hint %s" % [expedition_id, pool_key, config_id], not String(entry.get("enemy_family_hint", "")).is_empty())

static func _test_config_is_defensive_copy(tr) -> void:
	var first := RunExpeditionCatalogScript.get_config(RunExpeditionCatalogScript.EXPEDITION_BROKEN_WALL)
	first["display_name"] = "mutated"
	first.get("node_pools", {})["start"] = "mutated"
	var second := RunExpeditionCatalogScript.get_config(RunExpeditionCatalogScript.EXPEDITION_BROKEN_WALL)
	tr.assert_eq("catalog display name is defensive copy", second.get("display_name", ""), "断墙外环")
	tr.assert_eq("catalog node pools are defensive copy", second.get("node_pools", {}).get("start", ""), "outer_wall_01")
