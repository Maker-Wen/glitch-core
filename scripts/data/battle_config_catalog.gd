class_name BattleConfigCatalog extends RefCounted
## Data catalog for Demo Run battle node map and encounter setup.

const CONFIG_OUTER_WALL := "battle_outer_wall_01"
const CONFIG_RIFT_COURTYARD := "battle_crack_courtyard_03"
const CONFIG_IRON_GATE := "battle_iron_gate_04"
const CONFIG_OUTER_BELL := "battle_boss_outer_bell_01"

const NODE_TO_CONFIG := {
	"outer_wall_01": CONFIG_OUTER_WALL,
	"crack_courtyard_03": CONFIG_RIFT_COURTYARD,
	"iron_gate_04": CONFIG_IRON_GATE,
	"boss_outer_bell_01": CONFIG_OUTER_BELL,
}

const ENEMY_RUNTIME_DEF_PATHS := {
	"rot_beast": "res://scripts/data/defs/enemy_carrion_spawn.tres",
	"plague_archer": "res://scripts/data/defs/enemy_plague_archer.tres",
	"bone_grub": "res://scripts/data/defs/enemy_bone_grub.tres",
	"ironhorn": "res://scripts/data/defs/enemy_ironhorn.tres",
	"shell_beetle": "res://scripts/data/defs/enemy_shell_beetle.tres",
	"bell_thrall": "res://scripts/data/defs/enemy_bell_thrall.tres",
}

const SUPPORTED_REWARD_TASKS := {
	"perfect_defense": true,
	"terminal_clear": true,
	"physical_kills_3": true,
}

const CONFIGS := {
	"battle_outer_wall_01": {
		"config_id": "battle_outer_wall_01",
		"node_id": "outer_wall_01",
		"map_id": "map_demo_broken_wall_outpost",
		"display_name": "断墙前哨",
		"max_rounds": 5,
		"rift_strength": 0,
		"pressure_tags": ["基础防守", "远程线压"],
		"warden_spawns": [Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)],
		"protected_targets": [
			{"id": "b_well", "kind": "building", "pos": Vector2i(3, 3), "hp": 2},
			{"id": "b_store", "kind": "building", "pos": Vector2i(4, 3), "hp": 2},
			{"id": "b_shrine", "kind": "building", "pos": Vector2i(3, 4), "hp": 2},
		],
		"pillars": [
			{"id": "s_nw", "pos": Vector2i(2, 2)},
			{"id": "s_ne", "pos": Vector2i(5, 2)},
			{"id": "s_sw", "pos": Vector2i(2, 6)},
			{"id": "s_se", "pos": Vector2i(5, 6)},
		],
		"rifts": [],
		"initial_enemies": [
			{"id": "e_rot_left", "enemy_id": "rot_beast", "pos": Vector2i(1, 1)},
			{"id": "e_rot_right", "enemy_id": "rot_beast", "pos": Vector2i(6, 1)},
			{"id": "e_rot_low", "enemy_id": "rot_beast", "pos": Vector2i(1, 6)},
			{"id": "e_archer_top", "enemy_id": "plague_archer", "pos": Vector2i(4, 0)},
		],
		"scripted_spawns": [
			{"round": 2, "enemy_id": "rot_beast", "pos": Vector2i(7, 3)},
			{"round": 3, "enemy_id": "plague_archer", "pos": Vector2i(0, 4)},
			{"round": 4, "enemy_id": "rot_beast", "pos": Vector2i(6, 6)},
		],
		"rift_schedule": [],
		"reward_tasks": ["perfect_defense", "push_threat", "all_wardens_survive"],
		"runtime_reward_tasks": ["perfect_defense", "terminal_clear", "physical_kills_3"],
	},
	"battle_crack_courtyard_03": {
		"config_id": "battle_crack_courtyard_03",
		"node_id": "crack_courtyard_03",
		"map_id": "map_demo_rift_courtyard",
		"display_name": "裂缝庭院",
		"max_rounds": 5,
		"rift_strength": 1,
		"pressure_tags": ["基础防守", "裂隙压力", "远程线压"],
		"warden_spawns": [Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6)],
		"protected_targets": [
			{"id": "b_nw", "kind": "building", "pos": Vector2i(3, 3), "hp": 2},
			{"id": "b_ne", "kind": "building", "pos": Vector2i(4, 3), "hp": 2},
			{"id": "b_sw", "kind": "building", "pos": Vector2i(3, 4), "hp": 2},
			{"id": "b_se", "kind": "building", "pos": Vector2i(4, 4), "hp": 2},
		],
		"pillars": [
			{"id": "s_left", "pos": Vector2i(1, 3)},
			{"id": "s_right", "pos": Vector2i(6, 4)},
		],
		"rifts": [
			{"id": "r_nw", "pos": Vector2i(2, 2)},
			{"id": "r_se", "pos": Vector2i(5, 5)},
		],
		"initial_enemies": [
			{"id": "e_rot_top", "enemy_id": "rot_beast", "pos": Vector2i(1, 1)},
			{"id": "e_archer_top", "enemy_id": "plague_archer", "pos": Vector2i(6, 1)},
			{"id": "e_grub_low", "enemy_id": "bone_grub", "pos": Vector2i(6, 6)},
		],
		"scripted_spawns": [
			{"round": 3, "enemy_id": "plague_archer", "pos": Vector2i(7, 2)},
			{"round": 4, "enemy_id": "rot_beast", "pos": Vector2i(0, 5)},
		],
		"rift_schedule": [
			{"round": 2, "rift_id": "r_nw", "enemy_id": "rot_beast"},
			{"round": 3, "rift_id": "r_se", "enemy_id": "bone_grub"},
			{"round": 4, "rift_id": "r_nw", "enemy_id": "rot_beast"},
		],
		"reward_tasks": ["rift_suppression", "low_loss_line", "terminal_clear"],
		"runtime_reward_tasks": ["perfect_defense", "terminal_clear", "physical_kills_3"],
	},
	"battle_iron_gate_04": {
		"config_id": "battle_iron_gate_04",
		"node_id": "iron_gate_04",
		"map_id": "map_demo_ironhorn_gate",
		"display_name": "铁角闸门",
		"max_rounds": 5,
		"rift_strength": 1,
		"pressure_tags": ["精英冲撞", "堵路拥挤", "裂隙压力"],
		"warden_spawns": [Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6)],
		"protected_targets": [
			{"id": "b_left", "kind": "building", "pos": Vector2i(3, 3), "hp": 2},
			{"id": "b_right", "kind": "building", "pos": Vector2i(4, 3), "hp": 2},
			{"id": "k_gate", "kind": "key_building", "pos": Vector2i(3, 4), "hp": 3},
		],
		"pillars": [
			{"id": "s_top_l", "pos": Vector2i(3, 1)},
			{"id": "s_top_r", "pos": Vector2i(4, 1)},
			{"id": "s_mid_l", "pos": Vector2i(2, 2)},
			{"id": "s_mid_r", "pos": Vector2i(5, 2)},
			{"id": "s_gate_l", "pos": Vector2i(2, 4)},
			{"id": "s_gate_r", "pos": Vector2i(5, 4)},
		],
		"rifts": [
			{"id": "r_left", "pos": Vector2i(1, 5)},
			{"id": "r_right", "pos": Vector2i(6, 5)},
		],
		"initial_enemies": [
			{"id": "e_ironhorn_top", "enemy_id": "ironhorn", "pos": Vector2i(3, 0)},
			{"id": "e_rot_left", "enemy_id": "rot_beast", "pos": Vector2i(1, 1)},
			{"id": "e_rot_right", "enemy_id": "rot_beast", "pos": Vector2i(6, 1)},
			{"id": "e_archer_right", "enemy_id": "plague_archer", "pos": Vector2i(6, 3)},
		],
		"scripted_spawns": [
			{"round": 2, "enemy_id": "plague_archer", "pos": Vector2i(0, 2)},
			{"round": 3, "enemy_id": "shell_beetle", "pos": Vector2i(7, 4)},
			{"round": 4, "enemy_id": "ironhorn", "pos": Vector2i(4, 0)},
			{"round": 5, "enemy_id": "rot_beast", "pos": Vector2i(0, 6)},
		],
		"rift_schedule": [
			{"round": 2, "rift_id": "r_left", "enemy_id": "rot_beast"},
			{"round": 3, "rift_id": "r_right", "enemy_id": "rot_beast"},
			{"round": 4, "rift_id": "r_left", "enemy_id": "bone_grub"},
		],
		"reward_tasks": ["elite_hunt", "key_target_undamaged", "all_wardens_survive"],
		"runtime_reward_tasks": ["perfect_defense", "terminal_clear", "physical_kills_3"],
	},
	"battle_boss_outer_bell_01": {
		"config_id": "battle_boss_outer_bell_01",
		"node_id": "boss_outer_bell_01",
		"map_id": "map_demo_outer_bell_ring",
		"boss_config_id": "knell_lord_demo_01",
		"display_name": "钟楼外环",
		"max_rounds": 6,
		"rift_strength": 2,
		"pressure_tags": ["Boss 脚本", "裂隙压力", "远程线压"],
		"warden_spawns": [Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6)],
		"protected_targets": [
			{"id": "b_left", "kind": "building", "pos": Vector2i(2, 3), "hp": 2},
			{"id": "b_right", "kind": "building", "pos": Vector2i(5, 3), "hp": 2},
			{"id": "b_back", "kind": "building", "pos": Vector2i(3, 5), "hp": 2},
			{"id": "k_bell_gate", "kind": "key_building", "pos": Vector2i(4, 4), "hp": 3},
		],
		"boss_objects": [
			{"id": "a_left", "kind": "anchor", "pos": Vector2i(1, 2), "hp": 2},
			{"id": "a_right", "kind": "anchor", "pos": Vector2i(6, 2), "hp": 2},
			{"id": "h_heart_bell", "kind": "heart_bell", "pos": Vector2i(4, 2), "hp": 0},
		],
		"pillars": [
			{"id": "s_lantern_l", "pos": Vector2i(2, 1)},
			{"id": "s_lantern_r", "pos": Vector2i(5, 1)},
			{"id": "s_back_l", "pos": Vector2i(1, 5)},
			{"id": "s_back_r", "pos": Vector2i(6, 5)},
		],
		"rifts": [
			{"id": "r_left", "pos": Vector2i(0, 3)},
			{"id": "r_right", "pos": Vector2i(7, 3)},
			{"id": "r_top", "pos": Vector2i(3, 0)},
		],
		"initial_enemies": [
			{"id": "e_rot_l", "enemy_id": "rot_beast", "pos": Vector2i(2, 0)},
			{"id": "e_rot_r", "enemy_id": "rot_beast", "pos": Vector2i(5, 0)},
			{"id": "e_archer_r", "enemy_id": "plague_archer", "pos": Vector2i(7, 5)},
			{"id": "e_rot_low", "enemy_id": "rot_beast", "pos": Vector2i(0, 5)},
		],
		"scripted_spawns": [
			{"round": 3, "source": "boss_summon", "enemy_id": "rot_beast", "pos": Vector2i(3, 1)},
			{"round": 3, "source": "boss_summon", "enemy_id": "rot_beast", "pos": Vector2i(4, 1)},
			{"round": 5, "source": "boss_summon", "enemy_id": "bell_thrall", "pos": Vector2i(0, 4)},
			{"round": 5, "source": "boss_summon", "enemy_id": "bell_thrall", "pos": Vector2i(7, 4)},
			{"round": 6, "source": "boss_summon", "enemy_id": "rot_beast", "pos": Vector2i(3, 0)},
		],
		"rift_schedule": [
			{"round": 2, "rift_id": "r_left", "enemy_id": "bone_grub"},
			{"round": 3, "rift_id": "r_top", "enemy_id": "rot_beast"},
			{"round": 4, "rift_id": "r_right", "enemy_id": "plague_archer"},
			{"round": 5, "rift_id": "r_left", "enemy_id": "rot_beast"},
		],
		"reward_tasks": ["anchor_destroy", "perfect_watch", "all_wardens_survive"],
		"runtime_reward_tasks": ["perfect_defense", "terminal_clear", "physical_kills_3"],
	},
}

static func config_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in CONFIGS.keys():
		ids.append(String(key))
	ids.sort()
	return ids

static func get_config(config_id: String) -> Dictionary:
	if not CONFIGS.has(config_id):
		return {}
	return CONFIGS[config_id].duplicate(true)

static func config_for_node_id(node_id: String) -> Dictionary:
	var config_id := String(NODE_TO_CONFIG.get(node_id, ""))
	return get_config(config_id)

static func resolve_battle_config(node_id: String, battle_ref: Dictionary) -> Dictionary:
	var config_id := String(battle_ref.get("config_id", ""))
	if not config_id.is_empty():
		return get_config(config_id)
	var map_id := String(battle_ref.get("map_id", ""))
	if not map_id.is_empty():
		for config in CONFIGS.values():
			if String(config.get("map_id", "")) == map_id:
				return config.duplicate(true)
	if not node_id.is_empty():
		return config_for_node_id(node_id)
	return {}

static func build_runtime_config(config: Dictionary) -> Dictionary:
	var grid_data := build_grid(config)
	var rift_data := build_rifts(config)
	return {
		"grid": grid_data.get("grid"),
		"protected_targets": grid_data.get("protected_targets", []),
		"initial_enemies": build_initial_enemies(config),
		"deploy_zone": build_deploy_zone(),
		"rift_positions": rift_data.get("positions", []),
		"rift_schedule": rift_data.get("schedule", []),
		"scripted_spawn_schedule": build_scripted_spawns(config),
		"max_rounds": int(config.get("max_rounds", 5)),
		"reward_tasks": runtime_reward_tasks(config),
	}

static func build_grid(config: Dictionary) -> Dictionary:
	var grid := Grid.new()
	var protected_targets: Array[Vector2i] = []
	for pillar in config.get("pillars", []):
		grid.set_tile(_entry_pos(pillar), Grid.TileType.PILLAR)
	for target in config.get("protected_targets", []):
		var pos := _entry_pos(target)
		grid.set_tile(pos, Grid.TileType.BUILDING, int(target.get("hp", Grid.DEFAULT_BUILDING_HP)))
		protected_targets.append(pos)
	for rift in config.get("rifts", []):
		grid.set_tile(_entry_pos(rift), Grid.TileType.RIFT)
	return {"grid": grid, "protected_targets": protected_targets}

static func build_initial_enemies(config: Dictionary) -> Array:
	var result: Array = []
	for enemy in config.get("initial_enemies", []):
		var enemy_id := String(enemy.get("enemy_id", ""))
		var def := _enemy_def_for(enemy_id)
		if def == null:
			continue
		result.append({
			"def": def,
			"pos": _entry_pos(enemy),
			"enemy_id": enemy_id,
			"config_enemy_id": String(enemy.get("id", "")),
		})
	return result

static func build_rifts(config: Dictionary) -> Dictionary:
	var positions: Array[Vector2i] = []
	for rift in config.get("rifts", []):
		positions.append(_entry_pos(rift))
	var schedule: Array = []
	for entry in config.get("rift_schedule", []):
		var enemy_id := String(entry.get("enemy_id", ""))
		var def := _enemy_def_for(enemy_id)
		if def == null:
			continue
		var pos := _entry_pos(entry)
		if pos == Vector2i(-1, -1):
			pos = _rift_pos_for_id(config, String(entry.get("rift_id", "")))
		if pos == Vector2i(-1, -1):
			continue
		schedule.append({
			"round": int(entry.get("round", 0)),
			"pos": pos,
			"def": def,
			"enemy_id": enemy_id,
			"rift_id": String(entry.get("rift_id", "")),
		})
	return {"positions": positions, "schedule": schedule}

static func build_scripted_spawns(config: Dictionary) -> Array:
	var schedule: Array = []
	for entry in config.get("scripted_spawns", []):
		var enemy_id := String(entry.get("enemy_id", ""))
		var def := _enemy_def_for(enemy_id)
		if def == null:
			continue
		var pos := _entry_pos(entry)
		if pos == Vector2i(-1, -1):
			continue
		schedule.append({
			"round": int(entry.get("round", 0)),
			"pos": pos,
			"def": def,
			"enemy_id": enemy_id,
			"source": String(entry.get("source", "scripted")),
			"config_spawn_id": String(entry.get("id", "")),
		})
	return schedule

static func build_deploy_zone() -> Array[Vector2i]:
	var deploy_zone: Array[Vector2i] = []
	for y in [6, 7]:
		for x in range(Grid.SIZE):
			deploy_zone.append(Vector2i(x, y))
	return deploy_zone

static func runtime_reward_tasks(config: Dictionary) -> Array:
	var configured: Array = config.get("runtime_reward_tasks", config.get("reward_tasks", []))
	var result: Array = []
	for task in configured:
		var task_id := String(task)
		if SUPPORTED_REWARD_TASKS.has(task_id):
			result.append(task_id)
	return result

static func _enemy_def_for(enemy_id: String) -> UnitDef:
	var path := String(ENEMY_RUNTIME_DEF_PATHS.get(enemy_id, ""))
	if path.is_empty():
		return null
	return load(path)

static func _entry_pos(entry: Dictionary) -> Vector2i:
	return _cell(entry.get("pos", Vector2i(-1, -1)))

static func _cell(value) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_VECTOR2:
		return Vector2i(int(value.x), int(value.y))
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))
	return Vector2i(-1, -1)

static func _rift_pos_for_id(config: Dictionary, rift_id: String) -> Vector2i:
	if rift_id.is_empty():
		return Vector2i(-1, -1)
	for rift in config.get("rifts", []):
		if String(rift.get("id", "")) == rift_id:
			return _entry_pos(rift)
	return Vector2i(-1, -1)
