extends RefCounted
## Regression coverage for Demo Run battle map/encounter catalog wiring.

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const RunStateScript := preload("res://scripts/run/run_state.gd")

static func run(tr) -> void:
	_test_catalog_contains_fixed_route_configs(tr)
	_test_fixed_route_nodes_reference_catalog_configs(tr)
	_test_protected_targets_and_rounds_match_runtime_config(tr)
	_test_catalog_constructs_grid_enemies_and_rifts(tr)
	_test_enemy_ids_resolve_to_distinct_runtime_defs(tr)
	_test_outer_bell_scripted_boss_spawns_keep_source(tr)
	_test_outer_bell_boss_objects_map_to_runtime_boss_config(tr)

static func _test_catalog_contains_fixed_route_configs(tr) -> void:
	var expected := [
		BattleConfigCatalogScript.CONFIG_OUTER_WALL,
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
		BattleConfigCatalogScript.CONFIG_IRON_GATE,
		BattleConfigCatalogScript.CONFIG_OUTER_BELL,
	]
	for config_id in expected:
		var config := BattleConfigCatalogScript.get_config(config_id)
		tr.assert_true("catalog has %s" % config_id, not config.is_empty())
		tr.assert_eq("%s has matching config id" % config_id, config.get("config_id", ""), config_id)
		tr.assert_true("%s has map id" % config_id, not String(config.get("map_id", "")).is_empty())
		tr.assert_true("%s has protected targets" % config_id, config.get("protected_targets", []).size() > 0)

static func _test_fixed_route_nodes_reference_catalog_configs(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var expected_by_node := {
		"outer_wall_01": {
			"config_id": BattleConfigCatalogScript.CONFIG_OUTER_WALL,
			"map_id": "map_demo_broken_wall_outpost",
		},
		"crack_courtyard_03": {
			"config_id": BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
			"map_id": "map_demo_rift_courtyard",
		},
		"iron_gate_04": {
			"config_id": BattleConfigCatalogScript.CONFIG_IRON_GATE,
			"map_id": "map_demo_ironhorn_gate",
		},
		"boss_outer_bell_01": {
			"config_id": BattleConfigCatalogScript.CONFIG_OUTER_BELL,
			"map_id": "map_demo_outer_bell_ring",
		},
	}
	for node in run.route_nodes:
		if not run.is_battle_node(node):
			continue
		var node_id := String(node.get("node_id", ""))
		var expected: Dictionary = expected_by_node.get(node_id, {})
		tr.assert_true("%s expected battle node" % node_id, not expected.is_empty())
		var battle: Dictionary = node.get("battle", {})
		tr.assert_eq("%s config id" % node_id, battle.get("config_id", ""), expected.get("config_id", ""))
		tr.assert_eq("%s map id" % node_id, battle.get("map_id", ""), expected.get("map_id", ""))
		var config := BattleConfigCatalogScript.resolve_battle_config(node_id, battle)
		tr.assert_true("%s resolves config" % node_id, not config.is_empty())
		tr.assert_eq("%s node map matches config" % node_id, battle.get("map_id", ""), config.get("map_id", ""))

static func _test_protected_targets_and_rounds_match_runtime_config(tr) -> void:
	var expectations := {
		BattleConfigCatalogScript.CONFIG_OUTER_WALL: {"rounds": 5, "targets": 3},
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD: {"rounds": 5, "targets": 4},
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
		BattleConfigCatalogScript.CONFIG_OUTER_WALL: {"enemies": 4, "rifts": 0, "schedule": 0, "scripted": 3},
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD: {"enemies": 3, "rifts": 2, "schedule": 3, "scripted": 2},
		BattleConfigCatalogScript.CONFIG_IRON_GATE: {"enemies": 4, "rifts": 2, "schedule": 3, "scripted": 4},
		BattleConfigCatalogScript.CONFIG_OUTER_BELL: {"enemies": 4, "rifts": 3, "schedule": 4, "scripted": 5},
	}
	for config_id in expectations.keys():
		var config := BattleConfigCatalogScript.get_config(config_id)
		var runtime := BattleConfigCatalogScript.build_runtime_config(config)
		var expected: Dictionary = expectations[config_id]
		tr.assert_eq("%s initial enemy count" % config_id, runtime.get("initial_enemies", []).size(), expected.get("enemies", 0))
		tr.assert_eq("%s rift count" % config_id, runtime.get("rift_positions", []).size(), expected.get("rifts", 0))
		tr.assert_eq("%s rift schedule count" % config_id, runtime.get("rift_schedule", []).size(), expected.get("schedule", 0))
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
			tr.assert_true("%s scripted spawn has positive round" % config_id, int(entry.get("round", 0)) > 0)

static func _test_outer_bell_scripted_boss_spawns_keep_source(tr) -> void:
	var config := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_OUTER_BELL)
	var scripted := BattleConfigCatalogScript.build_scripted_spawns(config)
	var rounds: Array[int] = []
	for entry in scripted:
		tr.assert_eq("outer bell scripted source", entry.get("source", ""), "boss_summon")
		rounds.append(int(entry.get("round", 0)))
	tr.assert_eq("outer bell scripted round count", rounds.size(), 5)
	tr.assert_eq("outer bell scripted round 1", rounds[0], 3)
	tr.assert_eq("outer bell scripted round 2", rounds[1], 3)
	tr.assert_eq("outer bell scripted round 3", rounds[2], 5)
	tr.assert_eq("outer bell scripted round 4", rounds[3], 5)
	tr.assert_eq("outer bell scripted round 5", rounds[4], 6)

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
			"hp": 2,
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
			"move": 2,
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
		tr.assert_true("%s appears in fixed route runtime data" % enemy_id, defs_by_enemy_id.has(enemy_id))
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
	tr.assert_eq("outer bell boss anchors from catalog", boss_config.get("anchor_positions", []), [Vector2i(1, 2), Vector2i(6, 2)])
	tr.assert_eq("outer bell boss anchor hp from catalog", boss_config.get("anchor_hp", 0), 2)
	tr.assert_eq("outer bell heart from catalog", boss_config.get("heart_position", Vector2i(-1, -1)), Vector2i(4, 2))
	scene.free()
