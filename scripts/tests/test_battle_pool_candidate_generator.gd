extends RefCounted
## Preview-only coverage for map element/spawn pool candidate generation.

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const BattlePoolCandidateGeneratorScript := preload("res://scripts/data/battle_pool_candidate_generator.gd")
const BattleCandidatePlaytesterScript := preload("res://scripts/data/battle_candidate_playtester.gd")
const BattleCandidateBatchPlaytesterScript := preload("res://scripts/data/battle_candidate_batch_playtester.gd")

static func run(tr) -> void:
	_test_candidate_generation_is_seeded(tr)
	_test_candidate_generation_produces_spawn_tables(tr)
	_test_candidate_generation_validates_basic_fairness(tr)
	_test_candidate_generation_reports_structural_diagnostics(tr)
	_test_candidate_generation_reports_feature_profile(tr)
	_test_far_deploy_zone_rejects_unguarded_building(tr)
	_test_interceptable_opening_archer_is_warning_not_rejection(tr)
	_test_movable_intercept_opening_archer_is_warning_not_rejection(tr)
	_test_uninterceptable_opening_archer_is_rejected(tr)
	_test_candidate_playtester_approves_fixed_seed_preview_set(tr)
	_test_batch_playtester_summarizes_small_sample(tr)
	_test_candidate_generation_does_not_replace_fixed_runtime(tr)

static func _test_candidate_generation_is_seeded(tr) -> void:
	var config := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD)
	var first := BattlePoolCandidateGeneratorScript.generate_candidate(config, 240620, 1)
	var second := BattlePoolCandidateGeneratorScript.generate_candidate(config, 240620, 1)
	tr.assert_eq("same seed candidate initial enemies", _entry_signature(first.get("initial_enemies", [])), _entry_signature(second.get("initial_enemies", [])))
	tr.assert_eq("same seed candidate scripted spawns", _entry_signature(first.get("scripted_spawns", [])), _entry_signature(second.get("scripted_spawns", [])))
	tr.assert_eq("same seed candidate rift schedule", _entry_signature(first.get("rift_schedule", [])), _entry_signature(second.get("rift_schedule", [])))
	var changed := BattlePoolCandidateGeneratorScript.generate_candidate(config, 240620, 2)
	var same_signature := _entry_signature(first.get("initial_enemies", [])) == _entry_signature(changed.get("initial_enemies", [])) \
		and _entry_signature(first.get("scripted_spawns", [])) == _entry_signature(changed.get("scripted_spawns", [])) \
		and _entry_signature(first.get("rift_schedule", [])) == _entry_signature(changed.get("rift_schedule", []))
	tr.assert_true("different variant can alter candidate tables", not same_signature)

static func _test_candidate_generation_produces_spawn_tables(tr) -> void:
	var checked := 0
	for config_id in _candidate_generation_config_ids():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, 3000 + checked, 0)
		if not config.get("element_pools", {}).is_empty():
			tr.assert_true("%s candidate selects elements" % config_id, not candidate.get("selected_elements", {}).is_empty())
		tr.assert_true("%s candidate has initial enemies" % config_id, candidate.get("initial_enemies", []).size() > 0)
		tr.assert_true("%s candidate has scheduled pressure" % config_id, candidate.get("scripted_spawns", []).size() + candidate.get("rift_schedule", []).size() > 0)
		for entry in candidate.get("rift_schedule", []):
			tr.assert_true("%s candidate rift round is warned after opening" % config_id, int(entry.get("round", 0)) > 1)
		checked += 1

static func _test_candidate_generation_validates_basic_fairness(tr) -> void:
	for config_id in _candidate_generation_config_ids():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, 9100, 1)
		var validation: Dictionary = candidate.get("validation", {})
		tr.assert_true("%s candidate has validation result" % config_id, not String(validation.get("result", "")).is_empty())
		tr.assert_true("%s candidate has no rejection issues" % config_id, validation.get("issues", []).is_empty())

static func _test_candidate_generation_reports_structural_diagnostics(tr) -> void:
	for config_id in _candidate_generation_config_ids():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, 9100, 1)
		var diagnostics: Dictionary = candidate.get("validation", {}).get("diagnostics", {})
		tr.assert_eq("%s guard rows match protected targets" % config_id, diagnostics.get("protected_target_guards", []).size(), diagnostics.get("protected_target_count", 0))
		tr.assert_true("%s worst guard path is bounded" % config_id, int(diagnostics.get("worst_guard_path", 99)) <= 3)
		tr.assert_true("%s reports source pool counts" % config_id, not diagnostics.get("source_pool_counts", {}).is_empty())
		if not config.get("element_pools", {}).is_empty():
			tr.assert_true("%s reports element coverage" % config_id, not diagnostics.get("element_coverage", {}).is_empty())

static func _test_candidate_generation_reports_feature_profile(tr) -> void:
	for config_id in _candidate_generation_config_ids():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, 9100, 1)
		var feature_profile: Dictionary = candidate.get("validation", {}).get("diagnostics", {}).get("feature_profile", {})
		var coverage: Dictionary = feature_profile.get("coverage", {})
		tr.assert_true("%s reports feature profile" % config_id, not feature_profile.is_empty())
		tr.assert_true("%s has core feature coverage" % config_id, int(coverage.get("core", 0)) > 0)
		tr.assert_true("%s has support feature coverage" % config_id, int(coverage.get("support", 0)) > 0)
		tr.assert_true("%s has risk source coverage" % config_id, int(coverage.get("risk", 0)) > 0)
		tr.assert_true("%s has selected element coverage" % config_id, int(coverage.get("selected_elements", 0)) > 0)

static func _test_far_deploy_zone_rejects_unguarded_building(tr) -> void:
	var config := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_OUTER_WALL)
	config["deploy_zone"] = [Vector2i(7, 7), Vector2i(6, 7), Vector2i(7, 6)]
	config["warden_spawns"] = [Vector2i(7, 7), Vector2i(6, 7), Vector2i(7, 6)]
	config["spawn_pools"] = {
		"front_lane_pool": {"cells": [Vector2i(1, 0)], "enemy_weights": {"rot_beast": 1}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
	}
	var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, 9100, 1)
	var validation: Dictionary = candidate.get("validation", {})
	var diagnostics: Dictionary = validation.get("diagnostics", {})
	tr.assert_eq("far deploy zone is rejected", validation.get("result", ""), BattlePoolCandidateGeneratorScript.RESULT_REJECTED)
	tr.assert_true("far deploy zone reports unguarded buildings", diagnostics.get("unguarded_targets", []).size() > 0 or int(diagnostics.get("worst_guard_path", 0)) > 3)
	tr.assert_true("far deploy zone names guard path issue", _contains_text(validation.get("issues", []), "deploy zone cannot protect every building"))

static func _test_interceptable_opening_archer_is_warning_not_rejection(tr) -> void:
	var config := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_IRON_GATE)
	config["terrain_roles"] = []
	config["element_pools"] = {}
	config["spawn_pools"] = {
		"right_flank_pool": {"cells": [Vector2i(7, 4)], "enemy_weights": {"plague_archer": 1}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
	}
	var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, 9100, 1)
	var validation: Dictionary = candidate.get("validation", {})
	tr.assert_eq("interceptable opening archer is adjusted", validation.get("result", ""), BattlePoolCandidateGeneratorScript.RESULT_ADJUSTED)
	tr.assert_true("interceptable opening archer has no issues", validation.get("issues", []).is_empty())
	tr.assert_true("interceptable opening archer warns", _contains_text(validation.get("warnings", []), "opening archer line can be blocked"))

static func _test_movable_intercept_opening_archer_is_warning_not_rejection(tr) -> void:
	var config := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_IRON_GATE)
	config["terrain_roles"] = []
	config["element_pools"] = {}
	config["deploy_zone"] = [
		Vector2i(1, 4), Vector2i(3, 4), Vector2i(4, 4),
		Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5),
		Vector2i(1, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(6, 6),
	]
	config["warden_spawns"] = [Vector2i(1, 5), Vector2i(3, 5), Vector2i(6, 5)]
	config["spawn_pools"] = {
		"right_flank_pool": {"cells": [Vector2i(7, 4)], "enemy_weights": {"plague_archer": 1}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
	}
	var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, 9100, 1)
	var validation: Dictionary = candidate.get("validation", {})
	var diagnostics: Dictionary = validation.get("diagnostics", {})
	var pressure: Array = diagnostics.get("opening_pressure", [])
	tr.assert_eq("movable intercept opening archer is adjusted", validation.get("result", ""), BattlePoolCandidateGeneratorScript.RESULT_ADJUSTED)
	tr.assert_true("movable intercept opening archer has no issues", validation.get("issues", []).is_empty())
	tr.assert_true("movable intercept opening archer warns", _contains_text(validation.get("warnings", []), "opening archer line can be blocked"))
	tr.assert_true("movable intercept reports path", not pressure.is_empty() and int(pressure[0].get("intercept_path", 0)) == 1)

static func _test_uninterceptable_opening_archer_is_rejected(tr) -> void:
	var config := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_OUTER_WALL)
	config["terrain_roles"] = []
	config["element_pools"] = {}
	config["pillars"] = []
	config["rifts"] = []
	config["protected_targets"] = [
		{"id": "b_direct_line", "kind": "building", "pos": Vector2i(4, 4), "hp": 2},
	]
	config["deploy_zone"] = [Vector2i(0, 4)]
	config["warden_spawns"] = [Vector2i(0, 4)]
	config["spawn_pools"] = {
		"front_lane_pool": {"cells": [Vector2i(2, 4)], "enemy_weights": {"plague_archer": 1}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
	}
	var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, 9100, 1)
	var validation: Dictionary = candidate.get("validation", {})
	var diagnostics: Dictionary = validation.get("diagnostics", {})
	var pressure: Array = diagnostics.get("opening_pressure", [])
	tr.assert_eq("uninterceptable opening archer is rejected", validation.get("result", ""), BattlePoolCandidateGeneratorScript.RESULT_REJECTED)
	tr.assert_true("uninterceptable opening archer has direct-line issue", _contains_text(validation.get("issues", []), "opening archer has direct building line"))
	tr.assert_true("uninterceptable opening archer reports long path", not pressure.is_empty() and int(pressure[0].get("intercept_path", 0)) == 3)

static func _test_candidate_playtester_approves_fixed_seed_preview_set(tr) -> void:
	for config_id in [
		BattleConfigCatalogScript.CONFIG_OUTER_WALL,
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
		BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD,
		BattleConfigCatalogScript.CONFIG_IRON_GATE,
		BattleConfigCatalogScript.CONFIG_OUTER_BELL,
	]:
		var config := BattleConfigCatalogScript.get_config(config_id)
		for variant_index in range(3):
			var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, 240620, variant_index)
			var simulation := BattleCandidatePlaytesterScript.evaluate_candidate(config, candidate)
			var label := "%s variant %d solvability" % [config_id, variant_index]
			if config_id == BattleConfigCatalogScript.CONFIG_OUTER_BELL:
				tr.assert_true("%s approved or review" % label, simulation.get("result", "") in [BattleCandidatePlaytesterScript.RESULT_APPROVED, BattleCandidatePlaytesterScript.RESULT_REVIEW])
			else:
				tr.assert_eq("%s approved" % label, simulation.get("result", ""), BattleCandidatePlaytesterScript.RESULT_APPROVED)
			tr.assert_eq("%s no protected damage" % label, int(simulation.get("total_protected_damage", -1)), 0)
			tr.assert_eq("%s no destroyed protected targets" % label, int(simulation.get("destroyed", -1)), 0)
			if config_id != BattleConfigCatalogScript.CONFIG_OUTER_BELL:
				tr.assert_eq("%s no warden deaths" % label, int(simulation.get("warden_deaths", -1)), 0)
			tr.assert_eq("%s victory" % label, simulation.get("outcome", ""), "victory")

static func _candidate_generation_config_ids() -> Array[String]:
	return BattleConfigCatalogScript.config_ids()

static func _test_batch_playtester_summarizes_small_sample(tr) -> void:
	var config_ids := [
		BattleConfigCatalogScript.CONFIG_OUTER_WALL,
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
	]
	var summary := BattleCandidateBatchPlaytesterScript.run_batch(config_ids, 240620, 2, 2)
	tr.assert_eq("batch summary total", int(summary.get("total", -1)), 8)
	tr.assert_eq("batch result counts sum", _count_sum(summary.get("result_counts", {})), 8)
	tr.assert_eq("batch solvability counts sum", _count_sum(summary.get("solvability_counts", {})), 8)
	tr.assert_eq("batch records size", summary.get("records", []).size(), 8)
	tr.assert_true("batch has no global issues", summary.get("global_issues", []).is_empty())
	tr.assert_true("batch has per config summary", summary.get("by_config", {}).has(BattleConfigCatalogScript.CONFIG_OUTER_WALL))
	tr.assert_true("batch has pool risk summary", not summary.get("pool_risks", {}).is_empty())
	var first: Dictionary = summary.get("records", [])[0]
	tr.assert_true("batch record has result", not String(first.get("result", "")).is_empty())
	tr.assert_true("batch record has validation result", not String(first.get("validation_result", "")).is_empty())
	tr.assert_true("batch record has solvability result", not String(first.get("solvability_result", "")).is_empty())
	tr.assert_true("batch record has source pools", not first.get("source_pools", []).is_empty())
	tr.assert_true("batch record carries structural diagnostics", not first.get("diagnostics", {}).is_empty())
	var config_summary: Dictionary = summary.get("by_config", {}).get(BattleConfigCatalogScript.CONFIG_OUTER_WALL, {})
	tr.assert_true("batch config summary carries diagnostics", not config_summary.get("diagnostics", {}).is_empty())
	tr.assert_true("batch config summary carries opening pressure types", config_summary.get("diagnostics", {}).has("opening_pressure_types"))
	tr.assert_true("batch config summary carries feature profile counts", config_summary.get("diagnostics", {}).has("feature_core_counts"))
	tr.assert_true("batch config summary carries selected element counts", config_summary.get("diagnostics", {}).has("selected_element_counts"))

static func _test_candidate_generation_does_not_replace_fixed_runtime(tr) -> void:
	var config := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_IRON_GATE)
	var runtime_before := BattleConfigCatalogScript.build_runtime_config(config)
	var fixed_initial_before := _runtime_enemy_signature(runtime_before.get("initial_enemies", []))
	var fixed_scripted_before := _runtime_entry_signature(runtime_before.get("scripted_spawn_schedule", []))
	var fixed_rifts_before := _runtime_entry_signature(runtime_before.get("rift_schedule", []))
	BattlePoolCandidateGeneratorScript.generate_candidate(config, 5100, 2)
	var runtime_after := BattleConfigCatalogScript.build_runtime_config(config)
	tr.assert_eq("candidate generation keeps fixed initial table", _runtime_enemy_signature(runtime_after.get("initial_enemies", [])), fixed_initial_before)
	tr.assert_eq("candidate generation keeps fixed scripted table", _runtime_entry_signature(runtime_after.get("scripted_spawn_schedule", [])), fixed_scripted_before)
	tr.assert_eq("candidate generation keeps fixed rift table", _runtime_entry_signature(runtime_after.get("rift_schedule", [])), fixed_rifts_before)

static func _entry_signature(entries: Array) -> String:
	var parts: Array[String] = []
	for entry in entries:
		parts.append("%s@%s#%d:%s" % [
			String(entry.get("enemy_id", "")),
			str(entry.get("pos", Vector2i(-1, -1))),
			int(entry.get("round", 1)),
			String(entry.get("source_pool", "")),
		])
	parts.sort()
	return "|".join(parts)

static func _runtime_enemy_signature(entries: Array) -> String:
	var parts: Array[String] = []
	for entry in entries:
		parts.append("%s@%s" % [String(entry.get("enemy_id", "")), str(entry.get("pos", Vector2i(-1, -1)))])
	parts.sort()
	return "|".join(parts)

static func _runtime_entry_signature(entries: Array) -> String:
	var parts: Array[String] = []
	for entry in entries:
		parts.append("%s@%s#%d" % [String(entry.get("enemy_id", "")), str(entry.get("pos", Vector2i(-1, -1))), int(entry.get("round", 0))])
	parts.sort()
	return "|".join(parts)

static func _contains_text(values: Array, needle: String) -> bool:
	for value in values:
		if String(value).contains(needle):
			return true
	return false

static func _count_sum(counts: Dictionary) -> int:
	var total := 0
	for value in counts.values():
		total += int(value)
	return total
