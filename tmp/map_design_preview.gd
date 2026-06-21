extends SceneTree

const CONTROL_SEARCH_DEPTH := 6
const CONTROL_BEAM_WIDTH := 80
const CONTROL_BRANCH_WIDTH := 18

const MAPS := [
	{
		"id": "broken_wall_gap",
		"name": "断墙缺口",
		"max_rounds": 5,
		"buildings": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)],
		"pillars": [Vector2i(2, 1), Vector2i(5, 1)],
		"rifts": [],
		"deploy": [Vector2i(2, 4), Vector2i(3, 4), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(3, 6), Vector2i(4, 6)],
		"warden_spawns": [Vector2i(2, 4), Vector2i(4, 5), Vector2i(3, 6)],
		"candidate_spawns": [
			[Vector2i(2, 4), Vector2i(3, 4), Vector2i(2, 5)],
			[Vector2i(1, 3), Vector2i(4, 4), Vector2i(5, 4)],
		],
		"enemies": [
			{"type": "rot", "pos": Vector2i(1, 0)},
			{"type": "rot", "pos": Vector2i(6, 0)},
			{"type": "archer", "pos": Vector2i(6, 3)},
		],
		"scripted_spawns": [
			{"round": 2, "type": "rot", "pos": Vector2i(7, 3)},
			{"round": 3, "type": "archer", "pos": Vector2i(0, 4)},
			{"round": 4, "type": "rot", "pos": Vector2i(6, 6)},
		],
		"rift_schedule": [],
	},
	{
		"id": "two_bank_courtyard",
		"name": "双岸庭院",
		"max_rounds": 5,
		"buildings": [Vector2i(1, 2), Vector2i(6, 2), Vector2i(1, 3), Vector2i(6, 3)],
		"pillars": [Vector2i(1, 1), Vector2i(6, 1)],
		"rifts": [Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 3)],
		"blocked": [Vector2i(4, 0), Vector2i(4, 1), Vector2i(3, 2), Vector2i(4, 2)],
		"deploy": [Vector2i(2, 3), Vector2i(5, 3), Vector2i(1, 4), Vector2i(2, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(1, 5), Vector2i(2, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(2, 6), Vector2i(5, 6)],
		"warden_spawns": [Vector2i(1, 4), Vector2i(5, 4), Vector2i(2, 5)],
		"candidate_spawns": [
			[Vector2i(2, 3), Vector2i(5, 3), Vector2i(2, 5)],
			[Vector2i(1, 4), Vector2i(5, 4), Vector2i(2, 5)],
			[Vector2i(2, 4), Vector2i(6, 4), Vector2i(5, 5)],
		],
		"enemies": [
			{"type": "rot", "pos": Vector2i(1, 0)},
			{"type": "archer", "pos": Vector2i(7, 6)},
		],
		"scripted_spawns": [
			{"round": 3, "type": "archer", "pos": Vector2i(0, 6)},
			{"round": 4, "type": "rot", "pos": Vector2i(7, 4)},
		],
		"rift_schedule": [
			{"round": 2, "type": "rot", "pos": Vector2i(3, 1)},
			{"round": 3, "type": "bone", "pos": Vector2i(3, 3)},
			{"round": 4, "type": "rot", "pos": Vector2i(3, 0)},
		],
	},
	{
		"id": "rift_pillar_graveyard",
		"name": "裂柱墓园",
		"max_rounds": 5,
		"buildings": [Vector2i(2, 2), Vector2i(5, 2), Vector2i(2, 4)],
		"pillars": [Vector2i(2, 0), Vector2i(5, 0), Vector2i(1, 1), Vector2i(6, 1), Vector2i(3, 3), Vector2i(4, 3)],
		"rifts": [Vector2i(3, 1), Vector2i(0, 3), Vector2i(7, 3)],
		"blocked": [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)],
		"deploy": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(0, 6), Vector2i(1, 6), Vector2i(6, 6), Vector2i(7, 6)],
		"warden_spawns": [Vector2i(1, 5), Vector2i(6, 5), Vector2i(0, 6)],
		"candidate_spawns": [
			[Vector2i(1, 5), Vector2i(6, 5), Vector2i(0, 6)],
			[Vector2i(1, 4), Vector2i(7, 4), Vector2i(6, 5)],
			[Vector2i(3, 5), Vector2i(6, 5), Vector2i(7, 5)],
		],
		"enemies": [
			{"type": "rot", "pos": Vector2i(1, 0)},
			{"type": "rot", "pos": Vector2i(6, 0)},
			{"type": "archer", "pos": Vector2i(7, 4)},
		],
		"scripted_spawns": [
			{"round": 2, "type": "shell", "pos": Vector2i(0, 2)},
			{"round": 3, "type": "rot", "pos": Vector2i(6, 6)},
			{"round": 4, "type": "shell", "pos": Vector2i(1, 4)},
		],
		"rift_schedule": [
			{"round": 2, "type": "rot", "pos": Vector2i(0, 3)},
			{"round": 3, "type": "bone", "pos": Vector2i(7, 3)},
			{"round": 4, "type": "rot", "pos": Vector2i(3, 1)},
		],
	},
	{
		"id": "broken_iron_gate",
		"name": "破裂闸门",
		"max_rounds": 5,
		"buildings": [Vector2i(2, 2), Vector2i(5, 2)],
		"key_buildings": [Vector2i(3, 4), Vector2i(4, 4)],
		"pillars": [Vector2i(1, 1), Vector2i(6, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(5, 3)],
		"rifts": [Vector2i(0, 3), Vector2i(7, 3)],
		"blocked": [Vector2i(2, 0), Vector2i(5, 0), Vector2i(2, 1), Vector2i(5, 1)],
		"deploy": [Vector2i(0, 5), Vector2i(1, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(1, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(6, 6)],
		"warden_spawns": [Vector2i(1, 5), Vector2i(3, 5), Vector2i(6, 5)],
		"candidate_spawns": [
			[Vector2i(1, 5), Vector2i(3, 5), Vector2i(6, 5)],
			[Vector2i(1, 4), Vector2i(3, 4), Vector2i(6, 4)],
			[Vector2i(2, 4), Vector2i(4, 4), Vector2i(6, 5)],
		],
		"enemies": [
			{"type": "rot", "pos": Vector2i(1, 0)},
			{"type": "iron", "pos": Vector2i(0, 0)},
		],
		"scripted_spawns": [
			{"round": 2, "type": "archer", "pos": Vector2i(0, 2)},
			{"round": 3, "type": "shell", "pos": Vector2i(7, 4)},
			{"round": 4, "type": "rot", "pos": Vector2i(6, 6)},
		],
		"rift_schedule": [
			{"round": 2, "type": "rot", "pos": Vector2i(0, 3)},
			{"round": 3, "type": "rot", "pos": Vector2i(7, 3)},
			{"round": 4, "type": "bone", "pos": Vector2i(0, 3)},
		],
	},
	{
		"id": "cracked_bell_ring",
		"name": "裂钟环廊",
		"max_rounds": 5,
		"buildings": [Vector2i(2, 2), Vector2i(5, 2), Vector2i(2, 4), Vector2i(5, 4)],
		"key_buildings": [Vector2i(3, 3), Vector2i(4, 3)],
		"pillars": [Vector2i(3, 1), Vector2i(5, 1)],
		"rifts": [Vector2i(0, 0), Vector2i(7, 0), Vector2i(0, 3), Vector2i(7, 3)],
		"blocked": [Vector2i(1, 1), Vector2i(6, 1)],
		"deploy": [Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(1, 6), Vector2i(2, 6), Vector2i(5, 6), Vector2i(6, 6)],
		"warden_spawns": [Vector2i(2, 5), Vector2i(4, 5), Vector2i(6, 5)],
		"candidate_spawns": [
			[Vector2i(2, 5), Vector2i(4, 5), Vector2i(6, 5)],
			[Vector2i(2, 4), Vector2i(4, 4), Vector2i(6, 4)],
			[Vector2i(1, 5), Vector2i(3, 5), Vector2i(5, 5)],
		],
		"enemies": [
			{"type": "rot", "pos": Vector2i(0, 2)},
			{"type": "rot", "pos": Vector2i(7, 2)},
		],
		"scripted_spawns": [
			{"round": 3, "type": "rot", "pos": Vector2i(3, 1)},
			{"round": 3, "type": "rot", "pos": Vector2i(4, 1)},
			{"round": 5, "type": "bell", "pos": Vector2i(0, 4)},
			{"round": 5, "type": "bell", "pos": Vector2i(7, 4)},
		],
		"rift_schedule": [
			{"round": 2, "type": "bone", "pos": Vector2i(0, 3)},
			{"round": 3, "type": "rot", "pos": Vector2i(0, 0)},
			{"round": 4, "type": "archer", "pos": Vector2i(7, 3)},
		],
	},
]

func _init() -> void:
	print("=== map design preview ===")
	for map_data in MAPS:
		_preview_map(map_data)
	_preview_variants()
	quit(0)

func _preview_map(map_data: Dictionary) -> void:
	var engine := _start(map_data)
	var baseline := _protected_damage_from_rows(engine.get_enemy_intent_ui_state())
	var best_single := _best_single_action_reduction(map_data)
	var best_turn := _best_turn_reduction(map_data)
	var best_deploy := _best_deployment_reduction(map_data)
	print("")
	print("[%s] %s" % [map_data.id, map_data.name])
	print("  baseline_damage=%d targets=%s" % [_sum_damage(baseline), _damage_cells_text(baseline)])
	print("  enemy_intents=%s" % _intent_summary(engine.get_enemy_intent_ui_state()))
	print("  best_single_action_damage=%d action=%s targets=%s" % [
		int(best_single.get("damage", 999)),
		String(best_single.get("action", "none")),
		_damage_cells_text(best_single.get("damage_map", {})),
	])
	print("  best_full_turn_damage=%d actions=%s targets=%s" % [
		int(best_turn.get("damage", 999)),
		"none" if best_turn.get("actions", []).is_empty() else " ; ".join(best_turn.get("actions", [])),
		_damage_cells_text(best_turn.get("damage_map", {})),
	])
	print("  best_deploy_full_turn_damage=%d deploy=%s actions=%s targets=%s" % [
		int(best_deploy.get("damage", 999)),
		"none" if best_deploy.get("deploy", []).is_empty() else " ; ".join(best_deploy.get("deploy", [])),
		"none" if best_deploy.get("actions", []).is_empty() else " ; ".join(best_deploy.get("actions", [])),
		_damage_cells_text(best_deploy.get("damage_map", {})),
	])
	print("  verdict=%s" % _verdict(_sum_damage(baseline), int(best_turn.get("damage", 999)), int(best_deploy.get("damage", 999))))
	var default_multi := _simulate_battle(map_data, map_data.get("warden_spawns", []))
	var best_multi := _best_multi_deploy(map_data)
	print("  multi_default=%s" % _multi_summary(default_multi))
	print("  multi_best_deploy=%s" % _multi_summary(best_multi))
	print("  multi_verdict=%s" % _multi_verdict(default_multi, best_multi))

func _preview_variants() -> void:
	print("")
	print("=== map design variants ===")
	var variants := [
		{
			"source": "rift_pillar_graveyard",
			"name": "裂柱墓园 / 前置部署",
			"overrides": {
				"deploy": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(0, 6), Vector2i(1, 6), Vector2i(6, 6), Vector2i(7, 6)],
				"warden_spawns": [Vector2i(1, 4), Vector2i(7, 4), Vector2i(6, 5)],
				"candidate_spawns": [
					[Vector2i(1, 4), Vector2i(7, 4), Vector2i(6, 5)],
					[Vector2i(1, 5), Vector2i(6, 5), Vector2i(0, 6)],
				],
			},
		},
		{
			"source": "rift_pillar_graveyard",
			"name": "裂柱墓园 / 前置部署+裂缝可通行",
			"overrides": {
				"blocked": [],
				"deploy": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(0, 6), Vector2i(1, 6), Vector2i(6, 6), Vector2i(7, 6)],
				"warden_spawns": [Vector2i(1, 4), Vector2i(7, 4), Vector2i(6, 5)],
				"candidate_spawns": [
					[Vector2i(1, 4), Vector2i(7, 4), Vector2i(6, 5)],
					[Vector2i(1, 5), Vector2i(6, 5), Vector2i(0, 6)],
				],
			},
		},
		{
			"source": "rift_pillar_graveyard",
			"name": "裂柱墓园 / 轻量出怪",
			"overrides": {
				"blocked": [],
				"deploy": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(0, 6), Vector2i(1, 6), Vector2i(6, 6), Vector2i(7, 6)],
				"warden_spawns": [Vector2i(1, 4), Vector2i(6, 4), Vector2i(6, 5)],
				"candidate_spawns": [
					[Vector2i(1, 4), Vector2i(6, 4), Vector2i(6, 5)],
				],
				"scripted_spawns": [
					{"round": 3, "type": "rot", "pos": Vector2i(6, 6)},
				],
				"rift_schedule": [
					{"round": 3, "type": "bone", "pos": Vector2i(7, 3)},
					{"round": 4, "type": "rot", "pos": Vector2i(3, 1)},
				],
			},
		},
		{
			"source": "rift_pillar_graveyard",
			"name": "裂柱墓园 / 建筑后移+轻量出怪",
			"overrides": {
				"buildings": [Vector2i(2, 3), Vector2i(5, 3), Vector2i(2, 4)],
				"blocked": [],
				"deploy": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(0, 6), Vector2i(1, 6), Vector2i(6, 6), Vector2i(7, 6)],
				"warden_spawns": [Vector2i(1, 4), Vector2i(6, 4), Vector2i(6, 5)],
				"candidate_spawns": [
					[Vector2i(1, 4), Vector2i(6, 4), Vector2i(6, 5)],
					[Vector2i(1, 5), Vector2i(6, 5), Vector2i(0, 6)],
				],
				"scripted_spawns": [
					{"round": 3, "type": "rot", "pos": Vector2i(6, 6)},
				],
				"rift_schedule": [
					{"round": 3, "type": "bone", "pos": Vector2i(7, 3)},
					{"round": 4, "type": "rot", "pos": Vector2i(3, 1)},
				],
			},
		},
		{
			"source": "rift_pillar_graveyard",
			"name": "裂柱墓园 / 弓手后置+轻量出怪",
			"overrides": {
				"enemies": [
					{"type": "rot", "pos": Vector2i(1, 0)},
					{"type": "rot", "pos": Vector2i(6, 0)},
					{"type": "archer", "pos": Vector2i(7, 6)},
				],
				"blocked": [],
				"deploy": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(6, 5), Vector2i(7, 5), Vector2i(0, 6), Vector2i(1, 6), Vector2i(6, 6), Vector2i(7, 6)],
				"warden_spawns": [Vector2i(1, 4), Vector2i(6, 4), Vector2i(6, 5)],
				"candidate_spawns": [
					[Vector2i(1, 4), Vector2i(6, 4), Vector2i(6, 5)],
				],
				"scripted_spawns": [
					{"round": 3, "type": "rot", "pos": Vector2i(6, 6)},
				],
				"rift_schedule": [
					{"round": 3, "type": "bone", "pos": Vector2i(7, 3)},
					{"round": 4, "type": "rot", "pos": Vector2i(3, 1)},
				],
			},
		},
		{
			"source": "broken_iron_gate",
			"name": "破裂闸门 / 移除第4回合侧刷",
			"overrides": {
				"scripted_spawns": [
					{"round": 2, "type": "archer", "pos": Vector2i(0, 2)},
					{"round": 3, "type": "shell", "pos": Vector2i(7, 4)},
				],
			},
		},
		{
			"source": "broken_iron_gate",
			"name": "破裂闸门 / 只保留两次地裂",
			"overrides": {
				"rift_schedule": [
					{"round": 2, "type": "rot", "pos": Vector2i(0, 3)},
					{"round": 4, "type": "bone", "pos": Vector2i(0, 3)},
				],
			},
		},
		{
			"source": "cracked_bell_ring",
			"name": "裂钟环廊 / 轻量Boss脚本",
			"overrides": {
				"scripted_spawns": [
					{"round": 4, "type": "rot", "pos": Vector2i(3, 1)},
					{"round": 5, "type": "bell", "pos": Vector2i(0, 4)},
				],
			},
		},
		{
			"source": "cracked_bell_ring",
			"name": "裂钟环廊 / 轻量地裂",
			"overrides": {
				"rift_schedule": [
					{"round": 2, "type": "bone", "pos": Vector2i(0, 3)},
					{"round": 4, "type": "archer", "pos": Vector2i(7, 3)},
				],
			},
		},
		{
			"source": "cracked_bell_ring",
			"name": "裂钟环廊 / 双轻量",
			"overrides": {
				"scripted_spawns": [
					{"round": 4, "type": "rot", "pos": Vector2i(3, 1)},
					{"round": 5, "type": "bell", "pos": Vector2i(0, 4)},
				],
				"rift_schedule": [
					{"round": 2, "type": "bone", "pos": Vector2i(0, 3)},
					{"round": 4, "type": "archer", "pos": Vector2i(7, 3)},
				],
			},
		},
		{
			"source": "cracked_bell_ring",
			"name": "裂钟环廊 / 极轻Boss",
			"overrides": {
				"scripted_spawns": [
					{"round": 4, "type": "rot", "pos": Vector2i(3, 1)},
					{"round": 5, "type": "bell", "pos": Vector2i(0, 4)},
				],
				"rift_schedule": [
					{"round": 2, "type": "bone", "pos": Vector2i(0, 3)},
				],
			},
		},
		{
			"source": "cracked_bell_ring",
			"name": "裂钟环廊 / 环内建筑+双轻量",
			"overrides": {
				"buildings": [Vector2i(2, 3), Vector2i(5, 3), Vector2i(2, 4), Vector2i(5, 4)],
				"key_buildings": [Vector2i(3, 2), Vector2i(4, 2)],
				"scripted_spawns": [
					{"round": 4, "type": "rot", "pos": Vector2i(3, 1)},
					{"round": 5, "type": "bell", "pos": Vector2i(0, 4)},
				],
				"rift_schedule": [
					{"round": 2, "type": "bone", "pos": Vector2i(0, 3)},
					{"round": 4, "type": "archer", "pos": Vector2i(7, 3)},
				],
			},
		},
		{
			"source": "cracked_bell_ring",
			"name": "裂钟环廊 / 环内建筑+极轻Boss",
			"overrides": {
				"buildings": [Vector2i(2, 3), Vector2i(5, 3), Vector2i(2, 4), Vector2i(5, 4)],
				"key_buildings": [Vector2i(3, 2), Vector2i(4, 2)],
				"scripted_spawns": [
					{"round": 4, "type": "rot", "pos": Vector2i(3, 1)},
					{"round": 5, "type": "bell", "pos": Vector2i(0, 4)},
				],
				"rift_schedule": [
					{"round": 2, "type": "bone", "pos": Vector2i(0, 3)},
				],
			},
		},
		{
			"source": "cracked_bell_ring",
			"name": "裂钟环廊 / 侧断墙+双轻量",
			"overrides": {
				"pillars": [Vector2i(1, 2), Vector2i(3, 1), Vector2i(5, 1), Vector2i(6, 2)],
				"blocked": [Vector2i(1, 1), Vector2i(6, 1)],
				"scripted_spawns": [
					{"round": 4, "type": "rot", "pos": Vector2i(3, 1)},
					{"round": 5, "type": "bell", "pos": Vector2i(0, 4)},
				],
				"rift_schedule": [
					{"round": 2, "type": "bone", "pos": Vector2i(0, 3)},
					{"round": 4, "type": "archer", "pos": Vector2i(7, 3)},
				],
			},
		},
		{
			"source": "cracked_bell_ring",
			"name": "裂钟环廊 / 侧断墙+极轻Boss",
			"overrides": {
				"pillars": [Vector2i(1, 2), Vector2i(3, 1), Vector2i(5, 1), Vector2i(6, 2)],
				"blocked": [Vector2i(1, 1), Vector2i(6, 1)],
				"scripted_spawns": [
					{"round": 4, "type": "rot", "pos": Vector2i(3, 1)},
					{"round": 5, "type": "bell", "pos": Vector2i(0, 4)},
				],
				"rift_schedule": [
					{"round": 2, "type": "bone", "pos": Vector2i(0, 3)},
				],
			},
		},
	]
	for variant in variants:
		var map_data := _variant_map(String(variant.source), variant.overrides)
		var best := _best_multi_deploy(map_data)
		var first := _best_deployment_reduction(map_data)
		print("[%s] first_best=%d multi=%s verdict=%s" % [
			String(variant.name),
			int(first.get("damage", 999)),
			_multi_summary(best),
			_multi_verdict(best, best),
		])

func _variant_map(source_id: String, overrides: Dictionary) -> Dictionary:
	var map_data := _map_by_id(source_id).duplicate(true)
	for k in overrides.keys():
		map_data[k] = overrides[k]
	return map_data

func _map_by_id(source_id: String) -> Dictionary:
	for map_data in MAPS:
		if String(map_data.id) == source_id:
			return map_data
	return {}

func _start(map_data: Dictionary) -> BattleEngine:
	return _start_with_spawns(map_data, map_data.get("warden_spawns", []))

func _start_with_spawns(map_data: Dictionary, spawns: Array) -> BattleEngine:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var protected: Array[Vector2i] = []
	for p in map_data.get("blocked", []):
		grid.set_tile(p, Grid.TileType.PILLAR)
	for p in map_data.get("pillars", []):
		grid.set_tile(p, Grid.TileType.PILLAR)
	for p in map_data.get("buildings", []):
		grid.set_tile(p, Grid.TileType.BUILDING, 2)
		protected.append(p)
	for p in map_data.get("key_buildings", []):
		grid.set_tile(p, Grid.TileType.BUILDING, 3)
		protected.append(p)
	for p in map_data.get("rifts", []):
		grid.set_tile(p, Grid.TileType.RIFT)
	var enemies: Array = []
	for raw in map_data.get("enemies", []):
		enemies.append({"def": _enemy_def(String(raw.type)), "pos": raw.pos})
	var deploy_zone: Array[Vector2i] = []
	for p in map_data.get("deploy", []):
		deploy_zone.append(p)
	var rift_positions: Array[Vector2i] = []
	for p in map_data.get("rifts", []):
		rift_positions.append(p)
	engine.start_battle(
		grid,
		[_warden_melee(), _warden_pull(), _warden_ranged()],
		enemies,
		deploy_zone,
		rift_positions,
		_build_schedule(map_data.get("rift_schedule", [])),
		int(map_data.get("max_rounds", 5)),
		protected,
		[],
		[],
		{},
		_build_schedule(map_data.get("scripted_spawns", [])),
		map_data.get("cracked_ground_schedule", []),
		{},
		map_data.get("bell_wave_schedule", [])
	)
	for p in spawns:
		engine.apply_action(BattleAction.deploy(p))
	engine.apply_action(BattleAction.confirm_deploy())
	return engine

func _build_schedule(raw_entries: Array) -> Array:
	var schedule: Array = []
	for raw in raw_entries:
		var kind := String(raw.get("type", raw.get("enemy_id", "rot")))
		schedule.append({
			"round": int(raw.get("round", 0)),
			"pos": raw.get("pos", Vector2i(-1, -1)),
			"def": _enemy_def(kind),
		})
	return schedule

func _best_single_action_reduction(map_data: Dictionary) -> Dictionary:
	var engine := _start(map_data)
	var best_damage := _sum_damage(_protected_damage_from_rows(engine.get_enemy_intent_ui_state()))
	var best_action := "none"
	var best_damage_map := _protected_damage_from_rows(engine.get_enemy_intent_ui_state())
	for w in engine.state.wardens():
		var moves := engine.get_legal_moves(w.id)
		for p in moves:
			var rows := engine.preview_enemy_intent_ui_state(BattleAction.move(w.id, p))
			var damage_map := _protected_damage_from_rows(rows)
			var damage := _sum_damage(damage_map)
			if damage < best_damage:
				best_damage = damage
				best_action = "%s move %s->%s" % [w.def.display_name, _v(w.position), _v(p)]
				best_damage_map = damage_map
		var targets := engine.get_legal_attack_targets(w.id)
		for p in targets:
			var rows := engine.preview_enemy_intent_ui_state(BattleAction.attack(w.id, p))
			var damage_map := _protected_damage_from_rows(rows)
			var damage := _sum_damage(damage_map)
			if damage < best_damage:
				best_damage = damage
				best_action = "%s attack %s" % [w.def.display_name, _v(p)]
				best_damage_map = damage_map
	return {"damage": best_damage, "action": best_action, "damage_map": best_damage_map}

func _best_turn_reduction(map_data: Dictionary) -> Dictionary:
	var engine := _start(map_data)
	return _best_turn_for_engine(engine)

func _best_turn_for_engine(engine: BattleEngine) -> Dictionary:
	var start_damage_map := _protected_damage_from_rows(engine.get_enemy_intent_ui_state())
	var best := {
		"damage": _sum_damage(start_damage_map),
		"actions": [],
		"damage_map": start_damage_map,
	}
	var seen: Dictionary = {}
	_search_turn(engine, [], best, seen, 0)
	return best

func _best_deployment_reduction(map_data: Dictionary) -> Dictionary:
	var deploy_sets: Array = map_data.get("candidate_spawns", [map_data.get("warden_spawns", [])])
	var best := {
		"damage": 999,
		"deploy": [],
		"actions": [],
		"damage_map": {},
	}
	for spawns in deploy_sets:
		if spawns.size() < 3:
			continue
		var engine := _start_with_spawns(map_data, spawns)
		if engine.state.wardens().size() < 3:
			continue
		var result := _best_turn_for_engine(engine)
		var damage := int(result.get("damage", 999))
		if damage < int(best.get("damage", 999)):
			best["damage"] = damage
			best["deploy"] = [
				"赏金猎人@%s" % _v(spawns[0]),
				"盗墓人@%s" % _v(spawns[1]),
				"大魔法师@%s" % _v(spawns[2]),
			]
			best["actions"] = result.get("actions", [])
			best["damage_map"] = result.get("damage_map", {})
			if damage <= 0:
				return best
	return best

func _simulate_battle(map_data: Dictionary, spawns: Array) -> Dictionary:
	var engine := _start_with_spawns(map_data, spawns)
	var result := {
		"deploy": _deploy_text(spawns),
		"valid": true,
		"rounds": [],
		"outcome": "running",
		"total_protected_damage": 0,
		"destroyed": 0,
		"warden_deaths": 0,
		"enemies_left": 0,
		"damage_by_pos": {},
		"final_score": 0,
	}
	if engine.state.wardens().size() < 3 or engine.state.phase != BattleState.Phase.PLAYER_ACTION:
		result["valid"] = false
		result["outcome"] = "invalid_deploy"
		result["final_score"] = 1 << 30
		return result
	while engine.state.phase == BattleState.Phase.PLAYER_ACTION and engine.state.outcome == BattleState.Outcome.UNDECIDED:
		var round := engine.state.current_round
		var before_damage := engine.state.protected_damage_taken
		var before_destroyed := engine.state.destroyed_protected_count
		var threat_before := _sum_damage(_protected_damage_from_rows(engine.get_enemy_intent_ui_state()))
		var choice := _choose_turn_control(engine)
		for action in choice.get("actions_raw", []):
			if engine.state.phase != BattleState.Phase.PLAYER_ACTION:
				break
			if engine.state.current_round != round:
				break
			engine.apply_action(action)
			if engine.state.current_round != round:
				break
		if engine.state.phase == BattleState.Phase.PLAYER_ACTION and engine.state.current_round == round:
			engine.apply_action(BattleAction.end_turn())
		result["rounds"].append({
			"round": round,
			"threat_before": threat_before,
			"actions": choice.get("actions", []),
			"round_damage": engine.state.protected_damage_taken - before_damage,
			"round_destroyed": engine.state.destroyed_protected_count - before_destroyed,
			"score": int(choice.get("score", 0)),
			"enemies_left": engine.state.enemies().size(),
		})
		if round >= int(map_data.get("max_rounds", 5)) + 1:
			break
	result["outcome"] = _outcome_text(engine.state.outcome)
	result["total_protected_damage"] = engine.state.protected_damage_taken
	result["destroyed"] = engine.state.destroyed_protected_count
	result["warden_deaths"] = engine.state.warden_deaths
	result["enemies_left"] = engine.state.enemies().size()
	result["damage_by_pos"] = engine.state.protected_damage_by_pos.duplicate()
	result["final_score"] = _battle_score(engine)
	return result

func _best_multi_deploy(map_data: Dictionary) -> Dictionary:
	var deploy_sets: Array = map_data.get("candidate_spawns", [map_data.get("warden_spawns", [])])
	var best: Dictionary = {}
	var best_score := 1 << 30
	for spawns in deploy_sets:
		if spawns.size() < 3:
			continue
		var result := _simulate_battle(map_data, spawns)
		if not bool(result.get("valid", false)):
			continue
		var score := int(result.get("final_score", 1 << 30))
		if best.is_empty() or score < best_score:
			best = result
			best_score = score
	return best

func _choose_turn_control(engine: BattleEngine) -> Dictionary:
	var root := BattleEngine.new()
	root.state = engine.state.clone()
	var start_score := _turn_score(root)
	var best := {
		"score": start_score,
		"actions": [],
		"actions_raw": [],
	}
	var frontier: Array = [{
		"engine": root,
		"actions": [],
		"actions_raw": [],
		"score": start_score,
	}]
	var seen: Dictionary = {}
	for _depth in range(CONTROL_SEARCH_DEPTH):
		var candidates: Array = []
		for node in frontier:
			var cur_engine: BattleEngine = node.engine
			var sig := _state_signature(cur_engine)
			if seen.has(sig):
				continue
			seen[sig] = true
			if int(node.score) < int(best.score):
				best = {
					"score": int(node.score),
					"actions": node.actions.duplicate(),
					"actions_raw": node.actions_raw.duplicate(),
				}
			var actions := _candidate_actions_ranked(cur_engine)
			for entry in actions:
				var next := BattleEngine.new()
				next.state = cur_engine.state.clone()
				next._dispatch_action(next.state, entry.action)
				var score := _turn_score(next)
				var next_node := {
					"engine": next,
					"actions": node.actions + [String(entry.text)],
					"actions_raw": node.actions_raw + [entry.action],
					"score": score,
				}
				candidates.append(next_node)
				if score < int(best.score):
					best = {
						"score": score,
						"actions": next_node.actions.duplicate(),
						"actions_raw": next_node.actions_raw.duplicate(),
					}
		if candidates.is_empty():
			break
		candidates.sort_custom(func(a, b): return int(a.score) < int(b.score))
		frontier = candidates.slice(0, mini(CONTROL_BEAM_WIDTH, candidates.size()))
	return best

func _candidate_actions_ranked(engine: BattleEngine) -> Array:
	var actions := _candidate_actions(engine)
	for entry in actions:
		var next := BattleEngine.new()
		next.state = engine.state.clone()
		next._dispatch_action(next.state, entry.action)
		entry["score"] = _turn_score(next)
	actions.sort_custom(func(a, b): return int(a.score) < int(b.score))
	return actions.slice(0, mini(CONTROL_BRANCH_WIDTH, actions.size()))

func _turn_score(engine: BattleEngine) -> int:
	var damage_map := _protected_damage_from_rows(engine.get_enemy_intent_ui_state())
	var pending_damage := _sum_damage(damage_map)
	var warden_pending_damage := _warden_damage_from_rows(engine.get_enemy_intent_ui_state())
	var immediate_damage := engine.state.protected_damage_taken
	var destroyed := engine.state.destroyed_protected_count
	var enemy_count := engine.state.enemies().size()
	var enemy_hp := _enemy_hp_total(engine)
	var active_threats := _active_threat_count(engine.get_enemy_intent_ui_state())
	var weak_enemies := _weak_enemy_count(engine)
	var warden_hp_lost := _warden_hp_lost(engine)
	var acted := _acted_warden_count(engine)
	var movement_tiebreak := _warden_distance_to_live_threats(engine)
	return immediate_damage * 100000 \
		+ destroyed * 70000 \
		+ pending_damage * 12000 \
		+ warden_pending_damage * 1400 \
		+ warden_hp_lost * 800 \
		+ active_threats * 300 \
		+ enemy_count * 160 \
		+ enemy_hp * 35 \
		- weak_enemies * 25 \
		+ acted * 5 \
		+ movement_tiebreak

func _battle_score(engine: BattleEngine) -> int:
	return engine.state.protected_damage_taken * 100000 \
		+ engine.state.destroyed_protected_count * 70000 \
		+ engine.state.warden_deaths * 50000 \
		+ engine.state.enemies().size() * 700 \
		+ _enemy_hp_total(engine) * 100 \
		+ engine.state.current_round

func _enemy_hp_total(engine: BattleEngine) -> int:
	var total := 0
	for e in engine.state.enemies():
		total += e.hp
	return total

func _warden_hp_lost(engine: BattleEngine) -> int:
	var total := 0
	for w in engine.state.wardens():
		if w.def != null:
			total += maxi(0, w.def.max_hp - w.hp)
	total += engine.state.warden_deaths * 3
	return total

func _weak_enemy_count(engine: BattleEngine) -> int:
	var total := 0
	for e in engine.state.enemies():
		if e.hp <= 1:
			total += 1
	return total

func _acted_warden_count(engine: BattleEngine) -> int:
	var total := 0
	for w in engine.state.wardens():
		if w.has_acted:
			total += 1
	return total

func _active_threat_count(rows: Array) -> int:
	var total := 0
	for row in rows:
		if bool(row.get("has_attack", false)) and String(row.get("status", "")) == BattleEngine.INTENT_STATUS_HIT:
			total += 1
	return total

func _warden_damage_from_rows(rows: Array) -> int:
	var total := 0
	for row in rows:
		if String(row.get("target_kind", "")) == BattleEngine.TARGET_KIND_UNIT:
			total += int(row.get("target_damage", 0))
	return total

func _warden_distance_to_live_threats(engine: BattleEngine) -> int:
	var enemies := engine.state.enemies()
	if enemies.is_empty():
		return 0
	var total := 0
	for w in engine.state.wardens():
		var best := 99
		for e in enemies:
			best = mini(best, Grid.manhattan(w.position, e.position))
		total += best
	return total

func _deploy_text(spawns: Array) -> Array:
	if spawns.size() < 3:
		return []
	return [
		"赏金猎人@%s" % _v(spawns[0]),
		"盗墓人@%s" % _v(spawns[1]),
		"大魔法师@%s" % _v(spawns[2]),
	]

func _multi_summary(result: Dictionary) -> String:
	if result.is_empty():
		return "none"
	if not bool(result.get("valid", true)):
		return "invalid_deploy deploy=%s" % ["none" if result.get("deploy", []).is_empty() else " ; ".join(result.get("deploy", []))]
	var round_parts: Array[String] = []
	for raw in result.get("rounds", []):
		var r: Dictionary = raw
		round_parts.append("R%d threat=%d dmg=%d left=%d actions=%d" % [
			int(r.get("round", 0)),
			int(r.get("threat_before", 0)),
			int(r.get("round_damage", 0)),
			int(r.get("enemies_left", 0)),
			r.get("actions", []).size(),
		])
	return "outcome=%s total_dmg=%d destroyed=%d damage=%s warden_deaths=%d enemies_left=%d deploy=%s rounds=[%s]" % [
		String(result.get("outcome", "")),
		int(result.get("total_protected_damage", 0)),
		int(result.get("destroyed", 0)),
		_damage_cells_text(result.get("damage_by_pos", {})),
		int(result.get("warden_deaths", 0)),
		int(result.get("enemies_left", 0)),
		"none" if result.get("deploy", []).is_empty() else " ; ".join(result.get("deploy", [])),
		" | ".join(round_parts),
	]

func _multi_verdict(default_result: Dictionary, best_result: Dictionary) -> String:
	if best_result.is_empty() or not bool(best_result.get("valid", false)):
		return "RISK: no valid deployment candidate completed the preview"
	if int(best_result.get("total_protected_damage", 999)) == 0 and int(best_result.get("warden_deaths", 999)) == 0:
		if int(default_result.get("total_protected_damage", 999)) == 0:
			return "OK: searched multi-round line can keep protected targets clean"
		return "OK: clean line exists, but recommended deployment differs from default"
	if int(best_result.get("destroyed", 999)) == 0 and int(best_result.get("warden_deaths", 999)) == 0:
		return "WATCH: no destroyed targets, but some protected damage remains"
	return "RISK: multi-round pressure may be over budget"

func _outcome_text(outcome: int) -> String:
	match outcome:
		BattleState.Outcome.VICTORY:
			return "victory"
		BattleState.Outcome.DEFEAT:
			return "defeat"
	return "undecided"

func _search_turn(engine: BattleEngine, actions_so_far: Array, best: Dictionary, seen: Dictionary, depth: int) -> void:
	var current_damage_map := _protected_damage_from_rows(engine.get_enemy_intent_ui_state())
	var current_damage := _sum_damage(current_damage_map)
	if current_damage < int(best.get("damage", 999)):
		best["damage"] = current_damage
		best["actions"] = actions_so_far.duplicate()
		best["damage_map"] = current_damage_map
	if current_damage <= 0:
		return
	if depth >= 6:
		return
	var sig := _state_signature(engine)
	if seen.has(sig):
		return
	seen[sig] = true
	var actions := _candidate_actions(engine)
	for entry in actions:
		var next := BattleEngine.new()
		next.state = engine.state.clone()
		next._dispatch_action(next.state, entry.action)
		_search_turn(next, actions_so_far + [String(entry.text)], best, seen, depth + 1)

func _candidate_actions(engine: BattleEngine) -> Array:
	var actions: Array = []
	for w in engine.state.wardens():
		if w.has_acted:
			continue
		for target in engine.get_legal_attack_targets(w.id):
			actions.append({
				"action": BattleAction.attack(w.id, target),
				"text": "%s attack %s" % [w.def.display_name, _v(target)],
			})
		if not w.has_moved:
			for target in engine.get_legal_moves(w.id):
				actions.append({
					"action": BattleAction.move(w.id, target),
					"text": "%s move %s->%s" % [w.def.display_name, _v(w.position), _v(target)],
				})
	return actions

func _state_signature(engine: BattleEngine) -> String:
	var unit_parts: Array[String] = []
	for u in engine.state.units:
		unit_parts.append("%d:%s:%s:%d:%s:%s" % [
			u.id,
			String(u.def.def_id if u.def != null else &""),
			_v(u.position),
			u.hp,
			str(u.has_moved),
			str(u.has_acted),
		])
	unit_parts.sort()
	var damage := _protected_damage_from_rows(engine.get_enemy_intent_ui_state())
	return "%s|%s" % [";".join(unit_parts), _damage_cells_text(damage)]

func _protected_damage_from_rows(rows: Array) -> Dictionary:
	var damage: Dictionary = {}
	for row in rows:
		if String(row.get("target_kind", "")) == BattleEngine.TARGET_KIND_BUILDING:
			var pos: Vector2i = row.get("target_pos", Vector2i(-1, -1))
			damage[pos] = int(damage.get(pos, 0)) + int(row.get("target_damage", 0))
	return damage

func _sum_damage(damage: Dictionary) -> int:
	var total := 0
	for amount in damage.values():
		total += int(amount)
	return total

func _intent_summary(rows: Array) -> String:
	var parts: Array[String] = []
	for row in rows:
		if not bool(row.get("has_attack", false)):
			continue
		parts.append("%s@%s -> %s %s dmg=%d status=%s" % [
			String(row.get("enemy_name", "")),
			_v(row.get("enemy_pos", Vector2i(-1, -1))),
			String(row.get("target_kind", "")),
			_v(row.get("target_pos", Vector2i(-1, -1))),
			int(row.get("target_damage", 0)),
			String(row.get("status", "")),
		])
	return "none" if parts.is_empty() else " | ".join(parts)

func _damage_cells_text(damage: Dictionary) -> String:
	if damage.is_empty():
		return "none"
	var parts: Array[String] = []
	for p in damage.keys():
		parts.append("%s:%d" % [_v(p), int(damage[p])])
	return ", ".join(parts)

func _verdict(baseline: int, best: int, best_deploy: int) -> String:
	if baseline == 0:
		return "OK: no immediate building damage"
	if best == 0:
		return "OK: threatened, but full player turn can prevent first damage"
	if best_deploy == 0:
		return "OK: default spawn bad, but custom deployment can prevent first damage"
	return "RISK: first damage remains after searched player turn"

func _v(p: Vector2i) -> String:
	return "(%d,%d)" % [p.x, p.y]

func _enemy_def(kind: String) -> UnitDef:
	match kind:
		"archer":
			return _archer()
		"plague_archer":
			return _archer()
		"iron":
			return _ironhorn()
		"ironhorn":
			return _ironhorn()
		"bone":
			return _bone_grub()
		"bone_grub":
			return _bone_grub()
		"shell":
			return _shell_beetle()
		"shell_beetle":
			return _shell_beetle()
		"bell":
			return _bell_thrall()
		"bell_thrall":
			return _bell_thrall()
	return _rot()

func _rot() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"enemy_carrion_spawn"
	d.display_name = "腐食兽"
	d.faction = UnitDef.Faction.ENEMY
	d.max_hp = 2
	d.move = 3
	d.attack_kind = UnitDef.AttackKind.MELEE_BUMP
	d.attack_range = 1
	d.attack_damage = 1
	return d

func _archer() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"enemy_plague_archer"
	d.display_name = "瘟疫弓手"
	d.faction = UnitDef.Faction.ENEMY
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.RANGED_PUSH
	d.attack_range = 3
	d.attack_damage = 1
	d.attack_force = 0
	return d

func _ironhorn() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"enemy_ironhorn"
	d.display_name = "铁角兽"
	d.faction = UnitDef.Faction.ENEMY
	d.max_hp = 3
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.RANGED_PUSH
	d.attack_range = 3
	d.attack_damage = 1
	d.attack_force = 2
	return d

func _bone_grub() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"enemy_bone_grub"
	d.display_name = "蚀骨蛆群"
	d.faction = UnitDef.Faction.ENEMY
	d.max_hp = 1
	d.move = 4
	d.attack_kind = UnitDef.AttackKind.MELEE_BUMP
	d.attack_range = 1
	d.attack_damage = 1
	return d

func _shell_beetle() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"enemy_shell_beetle"
	d.display_name = "护壳虫"
	d.faction = UnitDef.Faction.ENEMY
	d.max_hp = 4
	d.move = 1
	d.attack_kind = UnitDef.AttackKind.MELEE_BUMP
	d.attack_range = 1
	d.attack_damage = 1
	return d

func _bell_thrall() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"enemy_bell_thrall"
	d.display_name = "钟奴"
	d.faction = UnitDef.Faction.ENEMY
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.MELEE_BUMP
	d.attack_range = 1
	d.attack_damage = 1
	return d

func _warden_melee() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"warden_bountyhunter"
	d.display_name = "赏金猎人"
	d.faction = UnitDef.Faction.WARDEN
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.MELEE_PUSH
	d.attack_range = 1
	d.attack_damage = 1
	d.attack_force = 1
	return d

func _warden_pull() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"warden_graverobber"
	d.display_name = "盗墓人"
	d.faction = UnitDef.Faction.WARDEN
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.RANGED_PULL
	d.attack_range = 3
	d.attack_damage = 1
	d.attack_force = 1
	return d

func _warden_ranged() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"warden_mage"
	d.display_name = "大魔法师"
	d.faction = UnitDef.Faction.WARDEN
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.RANGED_PUSH
	d.attack_range = 3
	d.attack_damage = 1
	d.attack_force = 1
	return d
