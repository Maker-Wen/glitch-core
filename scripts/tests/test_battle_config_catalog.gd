extends RefCounted
## Regression coverage for Demo Run battle map/encounter catalog wiring.

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const RunStateScript := preload("res://scripts/run/run_state.gd")

static func run(tr) -> void:
	_test_catalog_contains_fixed_route_configs(tr)
	_test_configured_route_nodes_reference_catalog_configs(tr)
	_test_expedition_map_pools_reference_catalog_configs(tr)
	_test_protected_targets_and_rounds_match_runtime_config(tr)
	_test_catalog_constructs_grid_enemies_and_rifts(tr)
	_test_catalog_deploy_zones_cover_configured_spawns(tr)
	_test_void_cells_are_filtered_from_runtime_entry_points(tr)
	_test_runtime_rifts_match_active_spawn_schedule(tr)
	_test_runtime_reward_tasks_match_map_design(tr)
	_test_map_feature_metadata_available_for_preview(tr)
	_test_map_feature_metadata_only_changes_authored_runtime_tiles(tr)
	_test_enemy_ids_resolve_to_distinct_runtime_defs(tr)
	_test_outer_bell_scripted_boss_spawns_keep_source(tr)
	_test_outer_bell_boss_objects_map_to_runtime_boss_config(tr)
	_test_candidate_map_configs_are_available_in_configured_route_pools(tr)

static func _test_catalog_contains_fixed_route_configs(tr) -> void:
	var expected := [
		BattleConfigCatalogScript.CONFIG_OUTER_WALL,
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
		BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD,
		BattleConfigCatalogScript.CONFIG_IRON_GATE,
		BattleConfigCatalogScript.CONFIG_OUTER_BELL,
	]
	for config_id in expected:
		var config := BattleConfigCatalogScript.get_config(config_id)
		tr.assert_true("catalog has %s" % config_id, not config.is_empty())
		tr.assert_eq("%s has matching config id" % config_id, config.get("config_id", ""), config_id)
		tr.assert_true("%s has map id" % config_id, not String(config.get("map_id", "")).is_empty())
		tr.assert_true("%s has protected targets" % config_id, config.get("protected_targets", []).size() > 0)
	var bridge := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE)
	tr.assert_true("catalog has candidate %s" % BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE, not bridge.is_empty())
	tr.assert_true("%s candidate only" % BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE, bool(bridge.get("candidate_only", false)))
	tr.assert_true("%s has preview flags" % BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE, bridge.get("preview_flags", []).size() > 0)
	for config_id in [
		BattleConfigCatalogScript.CONFIG_SUPPLY_RELAY_YARD,
		BattleConfigCatalogScript.CONFIG_BONE_RIFT_NEST,
	]:
		var config := BattleConfigCatalogScript.get_config(config_id)
		tr.assert_true("catalog has candidate %s" % config_id, not config.is_empty())
		tr.assert_true("%s candidate only" % config_id, bool(config.get("candidate_only", false)))
		tr.assert_true("%s has preview flags" % config_id, config.get("preview_flags", []).size() > 0)

static func _test_configured_route_nodes_reference_catalog_configs(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var battle_count := 0
	var config_ids := {}
	for node in run.route_nodes:
		if not run.is_battle_node(node):
			continue
		battle_count += 1
		var node_id := String(node.get("node_id", ""))
		var battle: Dictionary = node.get("battle", {})
		var pool_key := String(battle.get("map_pool_key", ""))
		var config_id := String(battle.get("config_id", ""))
		var allowed_config_ids := run.expedition_map_pool_config_ids(run.expedition_id, pool_key)
		tr.assert_true("%s has map pool key" % node_id, not pool_key.is_empty())
		tr.assert_true("%s uses map from configured pool" % node_id, config_id in allowed_config_ids)
		var config := BattleConfigCatalogScript.resolve_battle_config(node_id, battle)
		tr.assert_true("%s resolves config" % node_id, not config.is_empty())
		tr.assert_eq("%s node map matches config" % node_id, battle.get("map_id", ""), config.get("map_id", ""))
		tr.assert_eq("%s battle config id matches catalog" % node_id, config_id, config.get("config_id", ""))
		config_ids[config_id] = true
	tr.assert_eq("configured demo battle node count", battle_count, 11)
	tr.assert_true("configured demo includes intro map", config_ids.has(BattleConfigCatalogScript.CONFIG_OUTER_WALL))
	tr.assert_true("configured demo includes boss map", config_ids.has(BattleConfigCatalogScript.CONFIG_OUTER_BELL))
	tr.assert_true("configured demo exercises candidate maps", config_ids.has(BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE) or config_ids.has(BattleConfigCatalogScript.CONFIG_SUPPLY_RELAY_YARD) or config_ids.has(BattleConfigCatalogScript.CONFIG_BONE_RIFT_NEST))

static func _test_expedition_map_pools_reference_catalog_configs(tr) -> void:
	var run = RunStateScript.new()
	var referenced := {}
	for expedition_id in [
		RunStateScript.EXPEDITION_BROKEN_WALL,
		RunStateScript.EXPEDITION_RIFT_CORRIDOR,
		RunStateScript.EXPEDITION_SUPPLY_LINE,
	]:
		for pool_key in [
			RunStateScript.MAP_POOL_START,
			RunStateScript.MAP_POOL_NORMAL,
			RunStateScript.MAP_POOL_ELITE,
			RunStateScript.MAP_POOL_BOSS,
		]:
			var config_ids := run.expedition_map_pool_config_ids(expedition_id, pool_key)
			tr.assert_true("%s %s map pool is not empty" % [expedition_id, pool_key], not config_ids.is_empty())
			for config_id in config_ids:
				var config := BattleConfigCatalogScript.get_config(config_id)
				tr.assert_true("%s %s map pool config exists %s" % [expedition_id, pool_key, config_id], not config.is_empty())
				referenced[config_id] = true
	for config_id in BattleConfigCatalogScript.config_ids():
		tr.assert_true("%s is reachable from an expedition map pool" % config_id, referenced.has(config_id))

static func _test_protected_targets_and_rounds_match_runtime_config(tr) -> void:
	var expectations := {
		BattleConfigCatalogScript.CONFIG_OUTER_WALL: {"rounds": 5, "targets": 3},
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD: {"rounds": 5, "targets": 4},
		BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD: {"rounds": 5, "targets": 3},
		BattleConfigCatalogScript.CONFIG_IRON_GATE: {"rounds": 5, "targets": 3},
		BattleConfigCatalogScript.CONFIG_OUTER_BELL: {"rounds": 6, "targets": 4},
	}
	for config_id in expectations.keys():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var runtime := BattleConfigCatalogScript.build_runtime_config(config)
		var expected: Dictionary = expectations[config_id]
		tr.assert_eq("%s configured max rounds" % config_id, config.get("max_rounds", 0), expected.get("rounds", 0))
		tr.assert_eq("%s runtime max rounds" % config_id, runtime.get("max_rounds", 0), expected.get("rounds", 0))
		tr.assert_eq("%s configured protected count" % config_id, config.get("protected_targets", []).size(), expected.get("targets", 0))
		tr.assert_eq("%s runtime protected count" % config_id, runtime.get("protected_targets", []).size(), expected.get("targets", 0))
		var grid: Grid = runtime.get("grid", null)
		tr.assert_true("%s runtime grid exists" % config_id, grid != null)
		for p in runtime.get("protected_targets", []):
			tr.assert_eq("%s protected target is building %s" % [config_id, str(p)], grid.get_tile(p), Grid.TileType.BUILDING)

static func _test_catalog_constructs_grid_enemies_and_rifts(tr) -> void:
	var expectations := {
		BattleConfigCatalogScript.CONFIG_OUTER_WALL: {"enemies": 3, "rifts": 0, "schedule": 0, "scripted": 3},
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD: {"enemies": 2, "rifts": 3, "schedule": 3, "scripted": 2},
		BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD: {"enemies": 3, "rifts": 2, "schedule": 2, "scripted": 1},
		BattleConfigCatalogScript.CONFIG_IRON_GATE: {"enemies": 3, "rifts": 2, "schedule": 2, "scripted": 1},
		BattleConfigCatalogScript.CONFIG_OUTER_BELL: {"enemies": 2, "rifts": 1, "schedule": 2, "scripted": 1},
	}
	for config_id in expectations.keys():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var runtime := BattleConfigCatalogScript.build_runtime_config(config)
		var expected: Dictionary = expectations[config_id]
		tr.assert_eq("%s initial enemy count" % config_id, runtime.get("initial_enemies", []).size(), expected.get("enemies", 0))
		tr.assert_eq("%s rift count" % config_id, runtime.get("rift_positions", []).size(), expected.get("rifts", 0))
		tr.assert_eq("%s rift schedule count" % config_id, runtime.get("rift_schedule", []).size(), expected.get("schedule", 0))
		var expected_bell_waves := 2 if config_id == BattleConfigCatalogScript.CONFIG_OUTER_BELL else 0
		tr.assert_eq("%s bell wave schedule count" % config_id, runtime.get("bell_wave_schedule", []).size(), expected_bell_waves)
		tr.assert_eq("%s scripted spawn count" % config_id, runtime.get("scripted_spawn_schedule", []).size(), expected.get("scripted", 0))
		for enemy in runtime.get("initial_enemies", []):
			tr.assert_true("%s enemy has runtime def" % config_id, enemy.get("def", null) != null)
			tr.assert_true("%s enemy position in bounds" % config_id, runtime.get("grid").in_bounds(enemy.get("pos", Vector2i(-1, -1))))
		for entry in runtime.get("rift_schedule", []):
			tr.assert_true("%s rift spawn has def" % config_id, entry.get("def", null) != null)
			tr.assert_true("%s rift spawn position in bounds" % config_id, runtime.get("grid").in_bounds(entry.get("pos", Vector2i(-1, -1))))
		for entry in runtime.get("scripted_spawn_schedule", []):
			tr.assert_true("%s scripted spawn has def" % config_id, entry.get("def", null) != null)
			tr.assert_true("%s scripted spawn position in bounds" % config_id, runtime.get("grid").in_bounds(entry.get("pos", Vector2i(-1, -1))))
			tr.assert_true("%s scripted spawn avoids void %s" % [config_id, str(entry.get("pos", Vector2i(-1, -1)))], runtime.get("grid").get_tile(entry.get("pos", Vector2i(-1, -1))) != Grid.TileType.VOID)
			tr.assert_true("%s scripted spawn has positive round" % config_id, int(entry.get("round", 0)) > 0)
		for entry in runtime.get("bell_wave_schedule", []):
			tr.assert_eq("%s bell wave hazard type" % config_id, entry.get("hazard_type", ""), BattleEngine.HAZARD_BELL_WAVE)
			tr.assert_true("%s bell wave has positive round" % config_id, int(entry.get("round", 0)) > 0)
			for cell in entry.get("cells", []):
				tr.assert_true("%s bell wave in bounds %s" % [config_id, str(cell)], runtime.get("grid").in_bounds(cell))
				tr.assert_true("%s bell wave is walkable %s" % [config_id, str(cell)], not runtime.get("grid").blocks_movement(cell))
				tr.assert_true("%s bell wave avoids rifts %s" % [config_id, str(cell)], runtime.get("grid").get_tile(cell) != Grid.TileType.RIFT)

static func _test_catalog_deploy_zones_cover_configured_spawns(tr) -> void:
	for config_id in BattleConfigCatalogScript.config_ids():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var runtime := BattleConfigCatalogScript.build_runtime_config(config)
		var deploy_zone: Array = runtime.get("deploy_zone", [])
		tr.assert_true("%s deploy zone is not empty" % config_id, not deploy_zone.is_empty())
		var grid: Grid = runtime.get("grid", null)
		for spawn in config.get("warden_spawns", []):
			tr.assert_true("%s warden spawn in deploy zone %s" % [config_id, str(spawn)], spawn in deploy_zone)
			tr.assert_true("%s warden spawn is not blocked %s" % [config_id, str(spawn)], grid != null and not grid.blocks_movement(spawn))
			tr.assert_true("%s warden spawn is not void %s" % [config_id, str(spawn)], grid != null and grid.get_tile(spawn) != Grid.TileType.VOID)
	var custom_deploy_expectations := {
		BattleConfigCatalogScript.CONFIG_OUTER_WALL: [Vector2i(2, 4), Vector2i(3, 4), Vector2i(2, 5)],
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD: [Vector2i(2, 4), Vector2i(6, 4), Vector2i(5, 5)],
		BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD: [Vector2i(1, 4), Vector2i(6, 4), Vector2i(6, 5)],
		BattleConfigCatalogScript.CONFIG_IRON_GATE: [Vector2i(1, 5), Vector2i(3, 5), Vector2i(6, 5)],
		BattleConfigCatalogScript.CONFIG_OUTER_BELL: [Vector2i(2, 5), Vector2i(5, 5), Vector2i(6, 5)],
	}
	for config_id in custom_deploy_expectations.keys():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var runtime := BattleConfigCatalogScript.build_runtime_config(config)
		tr.assert_eq("%s configured warden spawns" % config_id, config.get("warden_spawns", []), custom_deploy_expectations[config_id])
		for cell in custom_deploy_expectations[config_id]:
			tr.assert_true("%s custom deploy includes %s" % [config_id, str(cell)], cell in runtime.get("deploy_zone", []))

static func _test_void_cells_are_filtered_from_runtime_entry_points(tr) -> void:
	var config := {
		"config_id": "test_void_filter",
		"max_rounds": 3,
		"void_cells": [Vector2i(3, 3)],
		"deploy_zone": [Vector2i(3, 3), Vector2i(3, 4)],
		"protected_targets": [
			{"id": "bad_building", "pos": Vector2i(3, 3), "hp": 2},
			{"id": "good_building", "pos": Vector2i(4, 4), "hp": 2},
		],
		"pillars": [
			{"id": "bad_pillar", "pos": Vector2i(3, 3)},
			{"id": "good_pillar", "pos": Vector2i(2, 2)},
		],
		"rifts": [
			{"id": "bad_rift", "pos": Vector2i(3, 3)},
			{"id": "good_rift", "pos": Vector2i(5, 5)},
		],
		"initial_enemies": [
			{"id": "bad_enemy", "enemy_id": "rot_beast", "pos": Vector2i(3, 3)},
			{"id": "good_enemy", "enemy_id": "rot_beast", "pos": Vector2i(1, 1)},
		],
		"scripted_spawns": [
			{"round": 2, "enemy_id": "rot_beast", "pos": Vector2i(3, 3)},
			{"round": 2, "enemy_id": "rot_beast", "pos": Vector2i(1, 2)},
		],
		"rift_schedule": [
			{"round": 2, "rift_id": "bad_rift", "enemy_id": "rot_beast"},
			{"round": 2, "rift_id": "good_rift", "enemy_id": "rot_beast"},
		],
		"spawn_pools": {
			"void_filter_pool": {
				"cells": [Vector2i(3, 3), Vector2i(6, 6)],
				"rift_ids": ["bad_rift", "good_rift"],
				"enemy_weights": {"rot_beast": 1},
				"rounds": [1],
				"max_per_round": 1,
			},
		},
		"reward_tasks": [],
	}
	var runtime := BattleConfigCatalogScript.build_runtime_config(config)
	var grid: Grid = runtime.get("grid", null)
	tr.assert_eq("void filter keeps authored void terrain", grid.get_tile(Vector2i(3, 3)), Grid.TileType.VOID)
	tr.assert_true("void filter omits protected target on void", not (Vector2i(3, 3) in runtime.get("protected_targets", [])))
	tr.assert_true("void filter keeps non-void protected target", Vector2i(4, 4) in runtime.get("protected_targets", []))
	tr.assert_true("void filter omits deploy cell on void", not (Vector2i(3, 3) in runtime.get("deploy_zone", [])))
	tr.assert_true("void filter keeps non-void deploy cell", Vector2i(3, 4) in runtime.get("deploy_zone", []))
	tr.assert_true("void filter omits initial enemy on void", _runtime_positions(runtime.get("initial_enemies", [])).find(Vector2i(3, 3)) == -1)
	tr.assert_true("void filter keeps non-void initial enemy", Vector2i(1, 1) in _runtime_positions(runtime.get("initial_enemies", [])))
	tr.assert_true("void filter omits scripted spawn on void", _runtime_positions(runtime.get("scripted_spawn_schedule", [])).find(Vector2i(3, 3)) == -1)
	tr.assert_true("void filter keeps non-void scripted spawn", Vector2i(1, 2) in _runtime_positions(runtime.get("scripted_spawn_schedule", [])))
	tr.assert_true("void filter omits rift position on void", not (Vector2i(3, 3) in runtime.get("rift_positions", [])))
	tr.assert_true("void filter keeps non-void rift position", Vector2i(5, 5) in runtime.get("rift_positions", []))
	tr.assert_true("void filter omits rift spawn on void", _runtime_positions(runtime.get("rift_schedule", [])).find(Vector2i(3, 3)) == -1)
	tr.assert_true("void filter keeps non-void rift spawn", Vector2i(5, 5) in _runtime_positions(runtime.get("rift_schedule", [])))
	var spawn_pool: Dictionary = runtime.get("spawn_pools", {}).get("void_filter_pool", {})
	tr.assert_true("void filter removes spawn-pool void cell", not (Vector2i(3, 3) in spawn_pool.get("cells", [])))
	tr.assert_true("void filter keeps spawn-pool non-void cell", Vector2i(6, 6) in spawn_pool.get("cells", []))
	tr.assert_true("void filter removes spawn-pool void rift id", not ("bad_rift" in spawn_pool.get("rift_ids", [])))
	tr.assert_true("void filter keeps spawn-pool non-void rift id", "good_rift" in spawn_pool.get("rift_ids", []))

static func _test_runtime_rifts_match_active_spawn_schedule(tr) -> void:
	for config_id in BattleConfigCatalogScript.config_ids():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var runtime := BattleConfigCatalogScript.build_runtime_config(config)
		var grid: Grid = runtime.get("grid", null)
		tr.assert_true("%s runtime grid exists for rift audit" % config_id, grid != null)
		var scheduled_positions := _unique_runtime_positions(runtime.get("rift_schedule", []))
		tr.assert_eq("%s runtime rifts are exactly scheduled rifts" % config_id, _sorted_cells(runtime.get("rift_positions", [])), _sorted_cells(scheduled_positions))
		tr.assert_eq("%s grid rift tiles are exactly scheduled rifts" % config_id, _sorted_cells(grid.cells_of_type(Grid.TileType.RIFT)), _sorted_cells(scheduled_positions))
		for rift in config.get("rifts", []):
			var pos: Vector2i = rift.get("pos", Vector2i(-1, -1))
			if pos in scheduled_positions:
				continue
			tr.assert_true("%s unused rift id %s stays normal terrain" % [config_id, String(rift.get("id", ""))], grid.get_tile(pos) != Grid.TileType.RIFT)

static func _test_outer_bell_scripted_boss_spawns_keep_source(tr) -> void:
	var config := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_OUTER_BELL)
	var scripted := BattleConfigCatalogScript.build_scripted_spawns(config)
	var rounds: Array[int] = []
	for entry in scripted:
		tr.assert_eq("outer bell scripted source", entry.get("source", ""), "boss_summon")
		rounds.append(int(entry.get("round", 0)))
	tr.assert_eq("outer bell scripted round count", rounds.size(), 1)
	tr.assert_eq("outer bell scripted round 1", rounds[0], 4)

static func _test_runtime_reward_tasks_match_map_design(tr) -> void:
	var expected := {
		BattleConfigCatalogScript.CONFIG_OUTER_WALL: [
			BattleState.REWARD_PERFECT_DEFENSE,
			BattleState.REWARD_PUSH_THREAT,
			BattleState.REWARD_ALL_WARDENS_SURVIVE,
		],
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD: [
			BattleState.REWARD_RIFT_SUPPRESSION,
			BattleState.REWARD_LOW_LOSS_LINE,
			BattleState.REWARD_TERMINAL_CLEAR,
		],
		BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD: [
			BattleState.REWARD_PHYSICAL_KILLS_3,
			BattleState.REWARD_PUSH_THREAT,
			BattleState.REWARD_LOW_LOSS_LINE,
		],
		BattleConfigCatalogScript.CONFIG_IRON_GATE: [
			BattleState.REWARD_ELITE_HUNT,
			BattleState.REWARD_KEY_TARGET_UNDAMAGED,
			BattleState.REWARD_ALL_WARDENS_SURVIVE,
		],
		BattleConfigCatalogScript.CONFIG_OUTER_BELL: [
			BattleState.REWARD_ANCHOR_DESTROY,
			BattleState.REWARD_HEART_WINDOW,
			BattleState.REWARD_PERFECT_WATCH,
		],
	}
	for config_id in expected.keys():
		var config := BattleConfigCatalogScript.get_config(config_id)
		tr.assert_eq(
			"%s runtime reward tasks" % config_id,
			_strings(BattleConfigCatalogScript.runtime_reward_tasks(config)),
			_strings(expected[config_id])
		)

static func _test_map_feature_metadata_available_for_preview(tr) -> void:
	var fixed_configs := [
		BattleConfigCatalogScript.CONFIG_OUTER_WALL,
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
		BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD,
		BattleConfigCatalogScript.CONFIG_IRON_GATE,
		BattleConfigCatalogScript.CONFIG_OUTER_BELL,
	]
	var configs_with_element_pools := 0
	var configs_with_spawn_pools := 0
	for config_id in fixed_configs:
		var config := BattleConfigCatalogScript.get_config(config_id)
		var runtime := BattleConfigCatalogScript.build_runtime_config(config)
		var roles: Array = runtime.get("terrain_roles", [])
		var element_pools: Dictionary = runtime.get("element_pools", {})
		var spawn_pools: Dictionary = runtime.get("spawn_pools", {})
		tr.assert_true("%s has terrain role metadata" % config_id, roles.size() >= 3)
		tr.assert_true("%s has protect ring role" % config_id, _has_role(roles, "protect_ring"))
		tr.assert_true("%s has attack lane or boss window role" % config_id, _has_role(roles, "attack_lane") or _has_role(roles, "boss_window"))
		if not element_pools.is_empty():
			configs_with_element_pools += 1
		if not spawn_pools.is_empty():
			configs_with_spawn_pools += 1
		for role in roles:
			tr.assert_true("%s role has cells" % config_id, role.get("cells", []).size() > 0)
			for cell in role.get("cells", []):
				tr.assert_true("%s role cell in bounds %s" % [config_id, str(cell)], cell.x >= 0 and cell.x < Grid.SIZE and cell.y >= 0 and cell.y < Grid.SIZE)
	tr.assert_true("at least three fixed maps have element pools", configs_with_element_pools >= 3)
	tr.assert_true("at least three fixed maps have spawn pools", configs_with_spawn_pools >= 3)
	var bridge := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE)
	var bridge_runtime := BattleConfigCatalogScript.build_runtime_config(bridge)
	tr.assert_true("broken bridge has abyss preview role", _has_role(bridge_runtime.get("terrain_roles", []), "hazard_preview"))
	tr.assert_true("broken bridge has element pools", not bridge_runtime.get("element_pools", {}).is_empty())

static func _test_map_feature_metadata_only_changes_authored_runtime_tiles(tr) -> void:
	for config_id in BattleConfigCatalogScript.config_ids():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var runtime := BattleConfigCatalogScript.build_runtime_config(config)
		var grid: Grid = runtime.get("grid", null)
		tr.assert_true("%s runtime grid exists for metadata tile check" % config_id, grid != null)
		for role in runtime.get("terrain_roles", []):
			var role_id := String(role.get("role", ""))
			if role_id in ["hazard_preview", "attack_lane", "protect_ring", "choke", "push_pocket", "rift_influence", "deploy_buffer"]:
				for cell in role.get("cells", []):
					var is_real_tile: bool = cell in runtime.get("protected_targets", [])
					is_real_tile = is_real_tile or cell in runtime.get("rift_positions", [])
					is_real_tile = is_real_tile or _cell_in_entries(cell, config.get("pillars", []))
					is_real_tile = is_real_tile or cell in config.get("void_cells", [])
					if is_real_tile:
						continue
					tr.assert_eq("%s metadata role leaves runtime tile empty %s" % [config_id, str(cell)], grid.get_tile(cell), Grid.TileType.EMPTY)

static func _has_role(roles: Array, role_id: String) -> bool:
	for role in roles:
		if String(role.get("role", "")) == role_id:
			return true
	return false

static func _runtime_positions(entries: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for entry in entries:
		result.append(entry.get("pos", Vector2i(-1, -1)))
	return result

static func _unique_runtime_positions(entries: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for entry in entries:
		var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
		if pos == Vector2i(-1, -1) or pos in result:
			continue
		result.append(pos)
	return result

static func _sorted_cells(cells: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells:
		result.append(cell)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)
	return result

static func _cell_in_entries(cell: Vector2i, entries: Array) -> bool:
	for entry in entries:
		if entry.get("pos", Vector2i(-1, -1)) == cell:
			return true
	return false

static func _strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

static func _test_enemy_ids_resolve_to_distinct_runtime_defs(tr) -> void:
	var expected := {
		"rot_beast": {
			"def_id": &"enemy_carrion_spawn",
			"name": "腐食兽",
			"hp": 2,
			"move": 3,
			"attack_kind": UnitDef.AttackKind.MELEE_BUMP,
			"range": 1,
			"force": 0,
		},
		"plague_archer": {
			"def_id": &"enemy_plague_archer",
			"name": "瘟疫弓手",
			"hp": 1,
			"move": 2,
			"attack_kind": UnitDef.AttackKind.RANGED_PUSH,
			"range": 3,
			"force": 0,
		},
		"bone_grub": {
			"def_id": &"enemy_bone_grub",
			"name": "蚀骨蛆群",
			"hp": 1,
			"move": 4,
			"attack_kind": UnitDef.AttackKind.MELEE_BUMP,
			"range": 1,
			"force": 0,
		},
		"ironhorn": {
			"def_id": &"enemy_ironhorn",
			"name": "铁角兽",
			"hp": 3,
			"move": 1,
			"attack_kind": UnitDef.AttackKind.RANGED_PUSH,
			"range": 3,
			"force": 2,
		},
		"shell_beetle": {
			"def_id": &"enemy_shell_beetle",
			"name": "护壳虫",
			"hp": 4,
			"move": 1,
			"attack_kind": UnitDef.AttackKind.MELEE_BUMP,
			"range": 1,
			"force": 0,
		},
		"bell_thrall": {
			"def_id": &"enemy_bell_thrall",
			"name": "钟奴",
			"hp": 2,
			"move": 2,
			"attack_kind": UnitDef.AttackKind.MELEE_BUMP,
			"range": 1,
			"force": 0,
		},
	}
	var defs_by_enemy_id := _runtime_defs_by_enemy_id()
	for enemy_id in expected.keys():
		tr.assert_true("%s appears in catalog runtime data" % enemy_id, defs_by_enemy_id.has(enemy_id))
		if not defs_by_enemy_id.has(enemy_id):
			continue
		var def: UnitDef = defs_by_enemy_id[enemy_id]
		var spec: Dictionary = expected[enemy_id]
		tr.assert_eq("%s runtime def id" % enemy_id, def.def_id, spec.get("def_id"))
		tr.assert_eq("%s display name" % enemy_id, def.display_name, spec.get("name"))
		tr.assert_eq("%s hp" % enemy_id, def.max_hp, spec.get("hp"))
		tr.assert_eq("%s move" % enemy_id, def.move, spec.get("move"))
		tr.assert_eq("%s attack kind" % enemy_id, def.attack_kind, spec.get("attack_kind"))
		tr.assert_eq("%s attack range" % enemy_id, def.attack_range, spec.get("range"))
		tr.assert_eq("%s attack force" % enemy_id, def.attack_force, spec.get("force"))

static func _runtime_defs_by_enemy_id() -> Dictionary:
	var result := {}
	for config_id in BattleConfigCatalogScript.config_ids():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var runtime := BattleConfigCatalogScript.build_runtime_config(config)
		for enemy in runtime.get("initial_enemies", []):
			var enemy_id := String(enemy.get("enemy_id", ""))
			if not enemy_id.is_empty():
				result[enemy_id] = enemy.get("def", null)
		for entry in runtime.get("rift_schedule", []):
			var enemy_id := String(entry.get("enemy_id", ""))
			if not enemy_id.is_empty():
				result[enemy_id] = entry.get("def", null)
		for entry in runtime.get("scripted_spawn_schedule", []):
			var enemy_id := String(entry.get("enemy_id", ""))
			if not enemy_id.is_empty():
				result[enemy_id] = entry.get("def", null)
	return result

static func _test_outer_bell_boss_objects_map_to_runtime_boss_config(tr) -> void:
	var scene := BattleScene.new()
	var config := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_OUTER_BELL)
	var boss_config: Dictionary = scene._boss_config_for_variant("boss", {}, config)
	tr.assert_eq("outer bell boss anchors from catalog", boss_config.get("anchor_positions", []), [Vector2i(1, 3), Vector2i(6, 3)])
	tr.assert_eq("outer bell boss anchor hp from catalog", boss_config.get("anchor_hp", 0), 2)
	tr.assert_eq("outer bell heart from catalog", boss_config.get("heart_position", Vector2i(-1, -1)), Vector2i(4, 3))
	scene.free()

static func _test_candidate_map_configs_are_available_in_configured_route_pools(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var configured_config_ids: Array[String] = []
	for node in run.route_nodes:
		if not run.is_battle_node(node):
			continue
		var battle: Dictionary = node.get("battle", {})
		configured_config_ids.append(String(battle.get("config_id", "")))
	tr.assert_true("%s can appear on configured demo route" % BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD, BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD in configured_config_ids)
	var pillar := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD)
	tr.assert_true("pillar graveyard is no longer candidate only", not bool(pillar.get("candidate_only", false)))
	var pillar_runtime := BattleConfigCatalogScript.build_runtime_config(pillar)
	tr.assert_true("pillar graveyard runtime grid exists", pillar_runtime.get("grid", null) != null)
	tr.assert_eq("pillar graveyard max rounds", pillar_runtime.get("max_rounds", 0), 5)
	tr.assert_eq("pillar graveyard protected target count", pillar_runtime.get("protected_targets", []).size(), 3)
	tr.assert_true("pillar graveyard keeps lightweight rift schedule", pillar_runtime.get("rift_schedule", []).size() >= 2)
	var config_id := BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE
	tr.assert_true("%s is available to configured demo route" % config_id, config_id in run.expedition_map_pool_config_ids(run.expedition_id, RunStateScript.MAP_POOL_NORMAL))
	var config := BattleConfigCatalogScript.get_config(config_id)
	var runtime := BattleConfigCatalogScript.build_runtime_config(config)
	tr.assert_true("%s runtime grid exists" % config_id, runtime.get("grid", null) != null)
	tr.assert_eq("%s candidate max rounds" % config_id, runtime.get("max_rounds", 0), 5)
	tr.assert_eq("%s candidate protected target count" % config_id, runtime.get("protected_targets", []).size(), 3)
	tr.assert_true("%s candidate has rift schedule" % config_id, runtime.get("rift_schedule", []).size() >= 3)
	for enemy in runtime.get("initial_enemies", []):
		tr.assert_true("%s candidate enemy has def" % config_id, enemy.get("def", null) != null)
	for entry in runtime.get("scripted_spawn_schedule", []):
		tr.assert_true("%s candidate scripted enemy has def" % config_id, entry.get("def", null) != null)
	var bridge := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE)
	tr.assert_eq("broken bridge void metadata count", bridge.get("void_cells", []).size(), 4)
	var bridge_runtime := BattleConfigCatalogScript.build_runtime_config(bridge)
	var grid: Grid = bridge_runtime.get("grid", null)
	for cell in bridge.get("void_cells", []):
		tr.assert_eq("broken bridge void becomes runtime terrain %s" % str(cell), grid.get_tile(cell), Grid.TileType.VOID)
		tr.assert_true("broken bridge void blocks movement %s" % str(cell), grid.blocks_movement(cell))
	var abyss_edges: Dictionary = bridge_runtime.get("abyss_edges", {})
	tr.assert_true("broken bridge runtime has abyss edges", not abyss_edges.is_empty())
	tr.assert_true("broken bridge left edge is abyss", bool(abyss_edges.get(Vector2i(0, 3), {}).get(Vector2i(-1, 0), false)))
	tr.assert_true("broken bridge right edge is abyss", bool(abyss_edges.get(Vector2i(7, 4), {}).get(Vector2i(1, 0), false)))
	for candidate_id in [
		BattleConfigCatalogScript.CONFIG_SUPPLY_RELAY_YARD,
		BattleConfigCatalogScript.CONFIG_BONE_RIFT_NEST,
	]:
		var candidate := BattleConfigCatalogScript.get_config(candidate_id)
		var candidate_runtime := BattleConfigCatalogScript.build_runtime_config(candidate)
		tr.assert_true("%s runtime grid exists" % candidate_id, candidate_runtime.get("grid", null) != null)
		tr.assert_eq("%s candidate max rounds" % candidate_id, candidate_runtime.get("max_rounds", 0), 5)
		tr.assert_eq("%s candidate protected target count" % candidate_id, candidate_runtime.get("protected_targets", []).size(), 3)
		tr.assert_true("%s candidate has initial pressure" % candidate_id, candidate_runtime.get("initial_enemies", []).size() >= 2)
		tr.assert_true("%s candidate has scheduled pressure" % candidate_id, candidate_runtime.get("scripted_spawn_schedule", []).size() + candidate_runtime.get("rift_schedule", []).size() >= 2)
