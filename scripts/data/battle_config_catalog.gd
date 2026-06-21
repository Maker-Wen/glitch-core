class_name BattleConfigCatalog extends RefCounted
## Data catalog for Demo Run battle node map and encounter setup.

const CONFIG_OUTER_WALL := "battle_outer_wall_01"
const CONFIG_RIFT_COURTYARD := "battle_crack_courtyard_03"
const CONFIG_IRON_GATE := "battle_iron_gate_04"
const CONFIG_OUTER_BELL := "battle_boss_outer_bell_01"
const CONFIG_PILLAR_GRAVEYARD := "battle_pillar_graveyard_03"
const CONFIG_BROKEN_BRIDGE_EDGE := "battle_candidate_broken_bridge_edge"

const NODE_TO_CONFIG := {
	"outer_wall_01": CONFIG_OUTER_WALL,
	"crack_courtyard_03": CONFIG_RIFT_COURTYARD,
	"pillar_graveyard_03": CONFIG_PILLAR_GRAVEYARD,
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
	"push_threat": true,
	"all_wardens_survive": true,
	"rift_suppression": true,
	"low_loss_line": true,
	"elite_hunt": true,
	"key_target_undamaged": true,
	"anchor_destroy": true,
	"perfect_watch": true,
	"heart_window": true,
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
		"terrain_roles": [
			{"role": "attack_lane", "cells": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(6, 0), Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 3)]},
			{"role": "protect_ring", "cells": [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)]},
			{"role": "choke", "cells": [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]},
			{"role": "push_pocket", "cells": [Vector2i(0, 3), Vector2i(1, 3), Vector2i(6, 4), Vector2i(7, 4)]},
			{"role": "deploy_buffer", "cells": [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)]},
		],
		"element_pools": {
			"blocker_cluster": [
				{"id": "broken_wall_teaching_ruins", "weight": 1, "cells": [Vector2i(2, 1), Vector2i(5, 1)], "roles": ["choke"]},
			],
			"push_cluster": [
				{"id": "side_push_pockets", "weight": 1, "cells": [Vector2i(0, 3), Vector2i(1, 3), Vector2i(6, 4), Vector2i(7, 4)], "roles": ["push_pocket"]},
			],
		},
		"spawn_pools": {
			"front_lane_pool": {"cells": [Vector2i(1, 0), Vector2i(6, 0)], "enemy_weights": {"rot_beast": 3}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
			"left_flank_pool": {"cells": [Vector2i(0, 4)], "enemy_weights": {"plague_archer": 1}, "rounds": [3], "warns_before_spawn": false, "max_per_round": 1},
			"right_flank_pool": {"cells": [Vector2i(6, 6)], "enemy_weights": {"rot_beast": 2}, "rounds": [4], "warns_before_spawn": false, "max_per_round": 1},
		},
		"deploy_zone": [
			Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
			Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
			Vector2i(3, 6), Vector2i(4, 6),
		],
		"warden_spawns": [Vector2i(2, 4), Vector2i(3, 4), Vector2i(2, 5)],
		"protected_targets": [
			{"id": "b_well", "kind": "building", "pos": Vector2i(2, 2), "hp": 2},
			{"id": "b_store", "kind": "building", "pos": Vector2i(3, 2), "hp": 2},
			{"id": "b_shrine", "kind": "building", "pos": Vector2i(2, 3), "hp": 2},
		],
		"pillars": [
			{"id": "s_wall_l", "pos": Vector2i(2, 1)},
			{"id": "s_wall_r", "pos": Vector2i(5, 1)},
		],
		"rifts": [],
		"initial_enemies": [
			{"id": "e_rot_left", "enemy_id": "rot_beast", "pos": Vector2i(1, 0)},
			{"id": "e_rot_right", "enemy_id": "rot_beast", "pos": Vector2i(6, 0)},
			{"id": "e_archer_right", "enemy_id": "plague_archer", "pos": Vector2i(6, 3)},
		],
		"scripted_spawns": [
			{"round": 2, "enemy_id": "rot_beast", "pos": Vector2i(7, 3)},
			{"round": 3, "enemy_id": "plague_archer", "pos": Vector2i(0, 4)},
			{"round": 4, "enemy_id": "rot_beast", "pos": Vector2i(6, 6)},
		],
		"rift_schedule": [],
		"reward_tasks": ["perfect_defense", "push_threat", "all_wardens_survive"],
		"runtime_reward_tasks": ["perfect_defense", "push_threat", "all_wardens_survive"],
	},
	"battle_crack_courtyard_03": {
		"config_id": "battle_crack_courtyard_03",
		"node_id": "crack_courtyard_03",
		"map_id": "map_demo_rift_courtyard",
		"display_name": "裂缝庭院",
		"max_rounds": 5,
		"rift_strength": 1,
		"pressure_tags": ["基础防守", "裂隙压力", "远程线压"],
		"terrain_roles": [
			{"role": "rift_influence", "cells": [Vector2i(3, 0), Vector2i(3, 1), Vector2i(4, 0), Vector2i(4, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3), Vector2i(4, 3)]},
			{"role": "protect_ring", "cells": [Vector2i(1, 2), Vector2i(2, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(5, 2), Vector2i(6, 2), Vector2i(5, 3), Vector2i(6, 3)]},
			{"role": "attack_lane", "cells": [Vector2i(2, 0), Vector2i(2, 1), Vector2i(6, 0), Vector2i(7, 0), Vector2i(0, 6), Vector2i(1, 6), Vector2i(6, 6), Vector2i(7, 6)]},
			{"role": "choke", "cells": [Vector2i(2, 3), Vector2i(5, 3)]},
			{"role": "deploy_buffer", "cells": [Vector2i(1, 4), Vector2i(2, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(1, 5), Vector2i(2, 5), Vector2i(5, 5), Vector2i(6, 5)]},
		],
		"element_pools": {
			"rift_cluster": [
				{"id": "midline_rift_stack", "weight": 2, "rift_ids": ["r_top", "r_mid", "r_lower"], "roles": ["rift_influence"]},
				{"id": "lower_rift_pressure", "weight": 1, "rift_ids": ["r_lower"], "roles": ["rift_influence", "hazard_preview"]},
			],
			"hazard_cluster": [
				{"id": "cracked_midline_candidate", "weight": 1, "cells": [Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3), Vector2i(4, 3)], "hazard_type": "cracked_ground", "stage": "preview_only"},
			],
			"flank_cluster": [
				{"id": "split_bank_flanks", "weight": 1, "cells": [Vector2i(0, 6), Vector2i(7, 4), Vector2i(7, 6)], "roles": ["attack_lane"]},
			],
		},
		"spawn_pools": {
			"front_lane_pool": {"cells": [Vector2i(2, 0)], "enemy_weights": {"rot_beast": 2}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
			"left_flank_pool": {"cells": [Vector2i(0, 6)], "enemy_weights": {"plague_archer": 1}, "rounds": [3], "warns_before_spawn": false, "max_per_round": 1},
			"right_flank_pool": {"cells": [Vector2i(7, 4), Vector2i(7, 6)], "enemy_weights": {"rot_beast": 2, "plague_archer": 1}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
			"rift_pool": {"rift_ids": ["r_top", "r_mid", "r_lower"], "enemy_weights": {"rot_beast": 2, "bone_grub": 1}, "rounds": [2, 3, 4], "warns_before_spawn": true, "max_per_round": 1},
		},
		"deploy_zone": [
			Vector2i(2, 3), Vector2i(5, 3),
			Vector2i(1, 4), Vector2i(2, 4), Vector2i(5, 4), Vector2i(6, 4),
			Vector2i(1, 5), Vector2i(2, 5), Vector2i(5, 5), Vector2i(6, 5),
			Vector2i(2, 6), Vector2i(5, 6),
		],
		"warden_spawns": [Vector2i(2, 4), Vector2i(6, 4), Vector2i(5, 5)],
		"protected_targets": [
			{"id": "b_left_n", "kind": "building", "pos": Vector2i(1, 2), "hp": 2},
			{"id": "b_right_n", "kind": "building", "pos": Vector2i(6, 2), "hp": 2},
			{"id": "b_left_s", "kind": "building", "pos": Vector2i(1, 3), "hp": 2},
			{"id": "b_right_s", "kind": "building", "pos": Vector2i(6, 3), "hp": 2},
		],
		"pillars": [
			{"id": "s_left", "pos": Vector2i(1, 1)},
			{"id": "s_right", "pos": Vector2i(6, 1)},
			{"id": "s_chasm_ne", "pos": Vector2i(4, 0)},
			{"id": "s_chasm_e", "pos": Vector2i(4, 1)},
			{"id": "s_chasm_mid_l", "pos": Vector2i(3, 2)},
			{"id": "s_chasm_mid_r", "pos": Vector2i(4, 2)},
		],
		"rifts": [
			{"id": "r_top", "pos": Vector2i(3, 0)},
			{"id": "r_mid", "pos": Vector2i(3, 1)},
			{"id": "r_lower", "pos": Vector2i(3, 3)},
		],
		"initial_enemies": [
			{"id": "e_rot_top", "enemy_id": "rot_beast", "pos": Vector2i(2, 0)},
			{"id": "e_archer_low", "enemy_id": "plague_archer", "pos": Vector2i(7, 6)},
		],
		"scripted_spawns": [
			{"round": 3, "enemy_id": "plague_archer", "pos": Vector2i(0, 6)},
			{"round": 4, "enemy_id": "rot_beast", "pos": Vector2i(7, 4)},
		],
		"rift_schedule": [
			{"round": 2, "rift_id": "r_mid", "enemy_id": "rot_beast"},
			{"round": 3, "rift_id": "r_lower", "enemy_id": "bone_grub"},
			{"round": 4, "rift_id": "r_top", "enemy_id": "rot_beast"},
		],
		"cracked_ground_schedule": [
			{"round": 2, "cells": [Vector2i(4, 3), Vector2i(3, 4)]},
			{"round": 3, "cells": [Vector2i(4, 4), Vector2i(5, 4)]},
		],
		"reward_tasks": ["rift_suppression", "low_loss_line", "terminal_clear"],
		"runtime_reward_tasks": ["rift_suppression", "low_loss_line", "terminal_clear"],
	},
	"battle_iron_gate_04": {
		"config_id": "battle_iron_gate_04",
		"node_id": "iron_gate_04",
		"map_id": "map_demo_ironhorn_gate",
		"display_name": "铁角闸门",
		"max_rounds": 5,
		"rift_strength": 1,
		"pressure_tags": ["精英冲撞", "堵路拥挤", "裂隙压力"],
		"terrain_roles": [
			{"role": "attack_lane", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(7, 6)]},
			{"role": "hazard_preview", "hazard_type": "charge_lane", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)]},
			{"role": "choke", "cells": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 5)]},
			{"role": "protect_ring", "cells": [Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(2, 5), Vector2i(4, 5), Vector2i(5, 5)]},
			{"role": "rift_influence", "cells": [Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(7, 3), Vector2i(7, 4), Vector2i(6, 3)]},
			{"role": "deploy_buffer", "cells": [Vector2i(1, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(6, 4), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(6, 6)]},
			{"role": "push_pocket", "cells": [Vector2i(1, 3), Vector2i(2, 3), Vector2i(5, 3), Vector2i(6, 3)]},
		],
		"element_pools": {
			"hazard_cluster": [
				{"id": "ironhorn_charge_lane", "weight": 2, "hazard_type": "charge_lane", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)], "stage": "preview_only"},
			],
			"rift_cluster": [
				{"id": "side_gate_rifts", "weight": 1, "rift_ids": ["r_left", "r_right"], "roles": ["rift_influence"]},
			],
			"flank_cluster": [
				{"id": "gate_side_pressure", "weight": 1, "cells": [Vector2i(0, 2), Vector2i(7, 6)], "roles": ["attack_lane"]},
			],
		},
		"spawn_pools": {
			"elite_pool": {"cells": [Vector2i(0, 0)], "enemy_weights": {"ironhorn": 1}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
			"front_lane_pool": {"cells": [Vector2i(1, 0)], "enemy_weights": {"rot_beast": 2}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
			"left_flank_pool": {"cells": [Vector2i(0, 2)], "enemy_weights": {"plague_archer": 1}, "rounds": [3], "warns_before_spawn": false, "max_per_round": 1},
			"right_flank_pool": {"cells": [Vector2i(7, 6)], "enemy_weights": {"rot_beast": 1}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
			"early_rift_pool": {"rift_ids": ["r_right"], "enemy_weights": {"bone_grub": 1}, "rounds": [2], "warns_before_spawn": true, "max_per_round": 1},
			"late_rift_pool": {"rift_ids": ["r_left", "r_right"], "enemy_weights": {"rot_beast": 2, "bone_grub": 1}, "rounds": [4], "warns_before_spawn": true, "max_per_round": 1},
		},
		"deploy_zone": [
			Vector2i(1, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(6, 4),
			Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5),
			Vector2i(1, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(6, 6),
		],
		"warden_spawns": [Vector2i(1, 5), Vector2i(3, 5), Vector2i(6, 5)],
		"protected_targets": [
			{"id": "b_left_store", "kind": "building", "pos": Vector2i(2, 4), "hp": 2},
			{"id": "b_right_store", "kind": "building", "pos": Vector2i(5, 4), "hp": 2},
			{"id": "k_gate_core", "kind": "key_building", "pos": Vector2i(4, 5), "hp": 3},
		],
		"pillars": [
			{"id": "s_wall_l", "pos": Vector2i(1, 1)},
			{"id": "s_wall_r", "pos": Vector2i(6, 1)},
			{"id": "s_left_shard", "pos": Vector2i(1, 2)},
			{"id": "s_right_shard", "pos": Vector2i(6, 2)},
			{"id": "s_gate_l", "pos": Vector2i(3, 3)},
			{"id": "s_gate_r", "pos": Vector2i(4, 3)},
			{"id": "s_gate_back", "pos": Vector2i(3, 4)},
		],
		"rifts": [
			{"id": "r_left", "pos": Vector2i(0, 3)},
			{"id": "r_right", "pos": Vector2i(7, 3)},
		],
		"initial_enemies": [
			{"id": "e_ironhorn_left", "enemy_id": "ironhorn", "pos": Vector2i(0, 0)},
			{"id": "e_rot_left", "enemy_id": "rot_beast", "pos": Vector2i(1, 0)},
			{"id": "e_rot_right", "enemy_id": "rot_beast", "pos": Vector2i(7, 6)},
		],
		"scripted_spawns": [
			{"round": 3, "enemy_id": "plague_archer", "pos": Vector2i(0, 2)},
		],
		"rift_schedule": [
			{"round": 2, "rift_id": "r_right", "enemy_id": "rot_beast"},
			{"round": 4, "rift_id": "r_left", "enemy_id": "bone_grub"},
		],
		"reward_tasks": ["elite_hunt", "key_target_undamaged", "all_wardens_survive"],
		"runtime_reward_tasks": ["elite_hunt", "key_target_undamaged", "all_wardens_survive"],
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
		"terrain_roles": [
			{"role": "boss_window", "cells": [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3)]},
			{"role": "attack_lane", "cells": [Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4), Vector2i(3, 0), Vector2i(3, 1)]},
			{"role": "protect_ring", "cells": [Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4), Vector2i(3, 5), Vector2i(4, 5)]},
			{"role": "rift_influence", "cells": [Vector2i(0, 2), Vector2i(1, 2), Vector2i(7, 2), Vector2i(6, 2), Vector2i(3, 0), Vector2i(4, 0)]},
			{"role": "choke", "cells": [Vector2i(2, 3), Vector2i(5, 3)]},
			{"role": "deploy_buffer", "cells": [Vector2i(1, 4), Vector2i(2, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5)]},
		],
		"element_pools": {
			"boss_cluster": [
				{"id": "anchor_heart_window", "weight": 2, "cells": [Vector2i(1, 3), Vector2i(4, 3), Vector2i(6, 3)], "roles": ["boss_window"]},
			],
			"hazard_cluster": [
				{"id": "bell_wave_cross", "weight": 1, "hazard_type": "bell_wave", "cells": [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)], "stage": "preview_only"},
			],
			"rift_cluster": [
				{"id": "outer_ring_rifts", "weight": 1, "rift_ids": ["r_left", "r_right", "r_top"], "roles": ["rift_influence"]},
			],
		},
		"spawn_pools": {
			"left_flank_pool": {"cells": [Vector2i(0, 3)], "enemy_weights": {"rot_beast": 2, "bell_thrall": 1}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
			"right_flank_pool": {"cells": [Vector2i(7, 3)], "enemy_weights": {"rot_beast": 2}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
			"rift_pool": {"rift_ids": ["r_top"], "enemy_weights": {"bone_grub": 1}, "rounds": [2, 4], "warns_before_spawn": true, "max_per_round": 1},
			"boss_summon_pool": {"cells": [Vector2i(3, 1)], "enemy_weights": {"rot_beast": 2, "bell_thrall": 1}, "rounds": [4], "warns_before_spawn": false, "max_per_round": 1},
		},
		"deploy_zone": [
			Vector2i(1, 4), Vector2i(2, 4), Vector2i(5, 4), Vector2i(6, 4),
			Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5),
			Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),
		],
		"warden_spawns": [Vector2i(2, 5), Vector2i(5, 5), Vector2i(6, 5)],
		"protected_targets": [
			{"id": "b_left", "kind": "building", "pos": Vector2i(2, 4), "hp": 2},
			{"id": "b_right", "kind": "building", "pos": Vector2i(5, 4), "hp": 2},
			{"id": "b_back", "kind": "building", "pos": Vector2i(3, 5), "hp": 2},
			{"id": "k_bell_gate", "kind": "key_building", "pos": Vector2i(4, 5), "hp": 3},
		],
		"boss_objects": [
			{"id": "a_left", "kind": "anchor", "pos": Vector2i(1, 3), "hp": 2},
			{"id": "a_right", "kind": "anchor", "pos": Vector2i(6, 3), "hp": 2},
			{"id": "h_heart_bell", "kind": "heart_bell", "pos": Vector2i(4, 3), "hp": 0},
		],
		"pillars": [
			{"id": "s_lantern_l", "pos": Vector2i(2, 1)},
			{"id": "s_lantern_r", "pos": Vector2i(5, 1)},
			{"id": "s_side_l", "pos": Vector2i(1, 2)},
			{"id": "s_side_r", "pos": Vector2i(6, 2)},
		],
		"rifts": [
			{"id": "r_left", "pos": Vector2i(0, 2)},
			{"id": "r_right", "pos": Vector2i(7, 2)},
			{"id": "r_top", "pos": Vector2i(3, 0)},
		],
		"initial_enemies": [
			{"id": "e_rot_l", "enemy_id": "rot_beast", "pos": Vector2i(0, 3)},
			{"id": "e_rot_r", "enemy_id": "rot_beast", "pos": Vector2i(7, 3)},
		],
		"scripted_spawns": [
			{"round": 4, "source": "boss_summon", "enemy_id": "bell_thrall", "pos": Vector2i(3, 1)},
		],
		"rift_schedule": [
			{"round": 2, "rift_id": "r_top", "enemy_id": "bone_grub"},
			{"round": 4, "rift_id": "r_top", "enemy_id": "bone_grub"},
		],
		"bell_wave_schedule": [
			{"round": 3, "cells": [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)]},
			{"round": 5, "cells": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)]},
		],
		"reward_tasks": ["anchor_destroy", "heart_window", "perfect_watch"],
		"runtime_reward_tasks": ["anchor_destroy", "heart_window", "perfect_watch"],
	},
	"battle_pillar_graveyard_03": {
		"config_id": "battle_pillar_graveyard_03",
		"node_id": "pillar_graveyard_03",
		"map_id": "map_demo_pillar_graveyard",
		"display_name": "石柱墓园",
		"candidate_only": false,
		"max_rounds": 5,
		"rift_strength": 1,
		"pressure_tags": ["堵路拥挤", "裂隙压力", "推撞连锁"],
		"preview_flags": ["路线地图", "石柱密集", "连锁推撞"],
		"terrain_roles": [
			{"role": "attack_lane", "cells": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(5, 0), Vector2i(6, 0), Vector2i(0, 3), Vector2i(7, 3), Vector2i(6, 6)]},
			{"role": "choke", "cells": [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(3, 3), Vector2i(4, 3)]},
			{"role": "push_pocket", "cells": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(1, 3), Vector2i(6, 3), Vector2i(3, 4), Vector2i(4, 4)]},
			{"role": "protect_ring", "cells": [Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(5, 3), Vector2i(5, 4)]},
			{"role": "rift_influence", "cells": [Vector2i(0, 3), Vector2i(1, 3), Vector2i(7, 3), Vector2i(6, 3), Vector2i(3, 1)]},
			{"role": "deploy_buffer", "cells": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(6, 5), Vector2i(7, 5)]},
		],
		"element_pools": {
			"blocker_cluster": [
				{"id": "graveyard_pillar_lanes", "weight": 2, "cells": [Vector2i(2, 0), Vector2i(5, 0), Vector2i(1, 1), Vector2i(6, 1), Vector2i(3, 3), Vector2i(4, 3)], "roles": ["choke"]},
			],
			"push_cluster": [
				{"id": "center_push_chain", "weight": 2, "cells": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(3, 4), Vector2i(4, 4)], "roles": ["push_pocket"]},
			],
			"rift_cluster": [
				{"id": "graveyard_side_rifts", "weight": 1, "rift_ids": ["r_top", "r_left", "r_right"], "roles": ["rift_influence"]},
			],
		},
		"spawn_pools": {
			"front_lane_pool": {"cells": [Vector2i(1, 0), Vector2i(6, 0)], "enemy_weights": {"rot_beast": 2}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
			"right_flank_pool": {"cells": [Vector2i(6, 6), Vector2i(7, 5)], "enemy_weights": {"rot_beast": 1}, "rounds": [1, 3], "warns_before_spawn": false, "max_per_round": 1},
			"rift_pool": {"rift_ids": ["r_top", "r_left", "r_right"], "enemy_weights": {"bone_grub": 2, "rot_beast": 1}, "rounds": [3], "warns_before_spawn": true, "max_per_round": 1},
		},
		"deploy_zone": [
			Vector2i(0, 4), Vector2i(1, 4), Vector2i(6, 4), Vector2i(7, 4),
			Vector2i(0, 5), Vector2i(1, 5), Vector2i(6, 5), Vector2i(7, 5),
			Vector2i(0, 6), Vector2i(1, 6), Vector2i(6, 6), Vector2i(7, 6),
		],
		"warden_spawns": [Vector2i(1, 4), Vector2i(6, 4), Vector2i(6, 5)],
		"protected_targets": [
			{"id": "b_center_l", "kind": "building", "pos": Vector2i(2, 3), "hp": 2},
			{"id": "b_center_r", "kind": "building", "pos": Vector2i(5, 3), "hp": 2},
			{"id": "b_lower", "kind": "building", "pos": Vector2i(2, 4), "hp": 2},
		],
		"pillars": [
			{"id": "s_nw", "pos": Vector2i(2, 0)},
			{"id": "s_ne", "pos": Vector2i(5, 0)},
			{"id": "s_l", "pos": Vector2i(1, 1)},
			{"id": "s_r", "pos": Vector2i(6, 1)},
			{"id": "s_mid_l", "pos": Vector2i(3, 3)},
			{"id": "s_mid_r", "pos": Vector2i(4, 3)},
		],
		"rifts": [
			{"id": "r_top", "pos": Vector2i(3, 1)},
			{"id": "r_left", "pos": Vector2i(0, 3)},
			{"id": "r_right", "pos": Vector2i(7, 3)},
		],
		"initial_enemies": [
			{"id": "e_rot_top_l", "enemy_id": "rot_beast", "pos": Vector2i(1, 0)},
			{"id": "e_rot_top_r", "enemy_id": "rot_beast", "pos": Vector2i(6, 0)},
			{"id": "e_archer_side", "enemy_id": "plague_archer", "pos": Vector2i(7, 4)},
		],
		"scripted_spawns": [
			{"round": 3, "enemy_id": "rot_beast", "pos": Vector2i(6, 6)},
		],
		"rift_schedule": [
			{"round": 3, "rift_id": "r_right", "enemy_id": "bone_grub"},
			{"round": 4, "rift_id": "r_top", "enemy_id": "rot_beast"},
		],
		"reward_tasks": ["physical_kills_3", "push_threat", "low_loss_line"],
		"runtime_reward_tasks": ["physical_kills_3", "push_threat", "low_loss_line"],
		"design_notes": [
			"第一章正式普通战配置，使用现有运行时敌人替代尚未实现的腐爆囊。",
			"总敌人 9 个，符合普通战预算；石柱密度用于验证推撞连锁。",
		],
	},
	"battle_candidate_broken_bridge_edge": {
		"config_id": "battle_candidate_broken_bridge_edge",
		"node_id": "",
		"map_id": "map_demo_broken_bridge_edge",
		"display_name": "断桥边缘",
		"candidate_only": true,
		"max_rounds": 5,
		"rift_strength": 1,
		"pressure_tags": ["深渊边缘", "裂隙压力", "推撞处决"],
		"preview_flags": ["候补地图", "深渊边缘", "高风险"],
		"terrain_roles": [
			{"role": "hazard_preview", "hazard_type": "abyss_edge", "cells": [Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4), Vector2i(7, 5)]},
			{"role": "rift_influence", "cells": [Vector2i(3, 1), Vector2i(4, 6), Vector2i(3, 2), Vector2i(4, 5)]},
			{"role": "push_pocket", "cells": [Vector2i(0, 3), Vector2i(1, 3), Vector2i(6, 4), Vector2i(7, 4)]},
			{"role": "protect_ring", "cells": [Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(5, 3), Vector2i(5, 4)]},
			{"role": "deploy_buffer", "cells": [Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6)]},
		],
		"element_pools": {
			"hazard_cluster": [
				{"id": "bridge_abyss_edges", "weight": 2, "hazard_type": "abyss_edge", "cells": [Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4), Vector2i(7, 5)], "stage": "metadata_only"},
			],
			"rift_cluster": [
				{"id": "broken_bridge_rifts", "weight": 1, "rift_ids": ["r_top_l", "r_bottom_r"], "roles": ["rift_influence"]},
			],
			"push_cluster": [
				{"id": "edge_execution_pockets", "weight": 2, "cells": [Vector2i(0, 3), Vector2i(1, 3), Vector2i(6, 4), Vector2i(7, 4)], "roles": ["push_pocket"]},
			],
		},
		"spawn_pools": {
			"front_lane_pool": {"cells": [Vector2i(1, 1), Vector2i(6, 1)], "enemy_weights": {"rot_beast": 2, "plague_archer": 1}, "rounds": [1], "warns_before_spawn": false, "max_per_round": 1},
			"right_flank_pool": {"cells": [Vector2i(6, 6), Vector2i(7, 5)], "enemy_weights": {"rot_beast": 2, "shell_beetle": 1}, "rounds": [1, 4], "warns_before_spawn": false, "max_per_round": 1},
			"rift_pool": {"rift_ids": ["r_top_l", "r_bottom_r"], "enemy_weights": {"rot_beast": 2, "bone_grub": 1}, "rounds": [2, 3, 4], "warns_before_spawn": true, "max_per_round": 1},
		},
		"warden_spawns": [Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6)],
		"protected_targets": [
			{"id": "b_left", "kind": "building", "pos": Vector2i(2, 3), "hp": 2},
			{"id": "b_right", "kind": "building", "pos": Vector2i(5, 3), "hp": 2},
			{"id": "b_lower", "kind": "building", "pos": Vector2i(2, 4), "hp": 2},
		],
		"pillars": [
			{"id": "s_nw", "pos": Vector2i(1, 2)},
			{"id": "s_ne", "pos": Vector2i(6, 2)},
			{"id": "s_sw", "pos": Vector2i(1, 5)},
			{"id": "s_se", "pos": Vector2i(6, 5)},
		],
		"rifts": [
			{"id": "r_top_l", "pos": Vector2i(3, 1)},
			{"id": "r_bottom_r", "pos": Vector2i(4, 6)},
		],
		"void_cells": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)],
		"abyss_edges": [
			{"axis": "x", "value": 0, "direction": "W", "cells": [Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5)]},
			{"axis": "x", "value": 7, "direction": "E", "cells": [Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4), Vector2i(7, 5)]},
		],
		"initial_enemies": [
			{"id": "e_rot_left", "enemy_id": "rot_beast", "pos": Vector2i(1, 1)},
			{"id": "e_archer_right", "enemy_id": "plague_archer", "pos": Vector2i(6, 1)},
			{"id": "e_rot_low", "enemy_id": "rot_beast", "pos": Vector2i(6, 6)},
		],
		"scripted_spawns": [
			{"round": 2, "enemy_id": "rot_beast", "pos": Vector2i(3, 0)},
			{"round": 4, "enemy_id": "shell_beetle", "pos": Vector2i(7, 5)},
		],
		"rift_schedule": [
			{"round": 2, "rift_id": "r_top_l", "enemy_id": "rot_beast"},
			{"round": 3, "rift_id": "r_bottom_r", "enemy_id": "bone_grub"},
			{"round": 4, "rift_id": "r_top_l", "enemy_id": "rot_beast"},
		],
		"reward_tasks": ["physical_kills_3", "perfect_defense", "all_wardens_survive"],
		"runtime_reward_tasks": ["physical_kills_3", "perfect_defense", "all_wardens_survive"],
		"design_notes": [
			"候补地图，左右边缘接入 abyss_edge 运行时标记，用于推撞处决和战术边界显示。",
			"普通战版本移除早期铁角兽，避免第一章候补池过压。",
		],
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
		"deploy_zone": build_deploy_zone(config),
		"rift_positions": rift_data.get("positions", []),
		"rift_schedule": rift_data.get("schedule", []),
		"cracked_ground_schedule": build_cracked_ground_schedule(config, grid_data.get("grid")),
		"bell_wave_schedule": build_bell_wave_schedule(config, grid_data.get("grid")),
		"abyss_edges": build_abyss_edges(config),
		"scripted_spawn_schedule": build_scripted_spawns(config),
		"terrain_roles": build_terrain_roles(config),
		"element_pools": build_element_pools(config),
		"spawn_pools": build_spawn_pools(config),
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

static func build_cracked_ground_schedule(config: Dictionary, grid: Grid = null) -> Array:
	return _build_unit_hazard_schedule(config, "cracked_ground_schedule", BattleEngine.HAZARD_CRACKED_GROUND, grid)

static func build_bell_wave_schedule(config: Dictionary, grid: Grid = null) -> Array:
	return _build_unit_hazard_schedule(config, "bell_wave_schedule", BattleEngine.HAZARD_BELL_WAVE, grid)

static func _build_unit_hazard_schedule(config: Dictionary, key: String, hazard_type: String, grid: Grid = null) -> Array:
	var schedule: Array = []
	for entry in config.get(key, []):
		var cells := _cells(entry.get("cells", []))
		var pos := _entry_pos(entry)
		if cells.is_empty() and pos != Vector2i(-1, -1):
			cells.append(pos)
		var filtered: Array[Vector2i] = []
		for cell in cells:
			if grid != null:
				if grid.blocks_movement(cell):
					continue
				if grid.get_tile(cell) == Grid.TileType.RIFT:
					continue
			filtered.append(cell)
		if filtered.is_empty():
			continue
		schedule.append({
			"round": int(entry.get("round", 0)),
			"cells": filtered,
			"hazard_type": hazard_type,
			"source": String(entry.get("source", key)),
		})
	return schedule

static func build_abyss_edges(config: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for entry in config.get("abyss_edges", []):
		var direction := _direction_from_string(String(entry.get("direction", "")))
		if direction == Vector2i.ZERO:
			continue
		var cells := _cells(entry.get("cells", []))
		if cells.is_empty():
			cells = _abyss_cells_from_axis(entry)
		for cell in cells:
			if not _cell_in_bounds(cell):
				continue
			var dirs: Dictionary = result.get(cell, {})
			dirs[direction] = true
			result[cell] = dirs
	return result

static func build_deploy_zone(config: Dictionary = {}) -> Array[Vector2i]:
	var deploy_zone: Array[Vector2i] = []
	for cell in config.get("deploy_zone", []):
		deploy_zone.append(_cell(cell))
	if not deploy_zone.is_empty():
		return deploy_zone
	for y in [6, 7]:
		for x in range(Grid.SIZE):
			deploy_zone.append(Vector2i(x, y))
	return deploy_zone

static func build_terrain_roles(config: Dictionary) -> Array:
	var roles: Array = []
	for entry in config.get("terrain_roles", []):
		var cells := _cells(entry.get("cells", []))
		if cells.is_empty():
			continue
		roles.append({
			"role": String(entry.get("role", "")),
			"cells": cells,
			"hazard_type": String(entry.get("hazard_type", "")),
		})
	return roles

static func build_element_pools(config: Dictionary) -> Dictionary:
	var result := {}
	var pools: Dictionary = config.get("element_pools", {})
	for pool_id in pools.keys():
		var entries: Array = []
		for entry in pools.get(pool_id, []):
			var normalized := _normalize_pool_entry(entry)
			if normalized.is_empty():
				continue
			entries.append(normalized)
		if not entries.is_empty():
			result[String(pool_id)] = entries
	return result

static func build_spawn_pools(config: Dictionary) -> Dictionary:
	var result := {}
	var pools: Dictionary = config.get("spawn_pools", {})
	for pool_id in pools.keys():
		var entry: Dictionary = pools.get(pool_id, {})
		var cells := _cells(entry.get("cells", []))
		var rift_ids := _strings_from_array(entry.get("rift_ids", []))
		if cells.is_empty() and rift_ids.is_empty():
			continue
		result[String(pool_id)] = {
			"cells": cells,
			"rift_ids": rift_ids,
			"enemy_weights": entry.get("enemy_weights", {}).duplicate(true),
			"rounds": _ints_from_array(entry.get("rounds", [])),
			"warns_before_spawn": bool(entry.get("warns_before_spawn", false)),
			"max_per_round": int(entry.get("max_per_round", 1)),
		}
	return result

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

static func _cells(values) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		var cell := _cell(value)
		if _cell_in_bounds(cell):
			result.append(cell)
	return result

static func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < Grid.SIZE and cell.y >= 0 and cell.y < Grid.SIZE

static func _strings_from_array(values) -> Array[String]:
	var result: Array[String] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		var text := String(value)
		if not text.is_empty():
			result.append(text)
	return result

static func _ints_from_array(values) -> Array[int]:
	var result: Array[int] = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		result.append(int(value))
	return result

static func _abyss_cells_from_axis(entry: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var axis := String(entry.get("axis", ""))
	var value := int(entry.get("value", -1))
	if axis == "x" and value >= 0 and value < Grid.SIZE:
		for y in range(Grid.SIZE):
			cells.append(Vector2i(value, y))
	elif axis == "y" and value >= 0 and value < Grid.SIZE:
		for x in range(Grid.SIZE):
			cells.append(Vector2i(x, value))
	return cells

static func _direction_from_string(value: String) -> Vector2i:
	match value.to_upper():
		"N":
			return Vector2i(0, -1)
		"E":
			return Vector2i(1, 0)
		"S":
			return Vector2i(0, 1)
		"W":
			return Vector2i(-1, 0)
	return Vector2i.ZERO

static func _normalize_pool_entry(entry: Dictionary) -> Dictionary:
	var cells := _cells(entry.get("cells", []))
	var rift_ids := _strings_from_array(entry.get("rift_ids", []))
	if cells.is_empty() and rift_ids.is_empty():
		return {}
	return {
		"id": String(entry.get("id", "")),
		"weight": int(entry.get("weight", 1)),
		"cells": cells,
		"rift_ids": rift_ids,
		"roles": _strings_from_array(entry.get("roles", [])),
		"hazard_type": String(entry.get("hazard_type", "")),
		"stage": String(entry.get("stage", "")),
	}

static func _rift_pos_for_id(config: Dictionary, rift_id: String) -> Vector2i:
	if rift_id.is_empty():
		return Vector2i(-1, -1)
	for rift in config.get("rifts", []):
		if String(rift.get("id", "")) == rift_id:
			return _entry_pos(rift)
	return Vector2i(-1, -1)
