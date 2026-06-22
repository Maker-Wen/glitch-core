class_name RunExpeditionCatalog extends RefCounted
## Expedition route, node pool, and battle map pool configuration.

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")

const EXPEDITION_BROKEN_WALL := "broken_wall"
const EXPEDITION_RIFT_CORRIDOR := "rift_corridor"
const EXPEDITION_SUPPLY_LINE := "supply_line"

const MAP_POOL_START := "start"
const MAP_POOL_NORMAL := "normal"
const MAP_POOL_ELITE := "elite"
const MAP_POOL_BOSS := "boss"

const NODE_NORMAL := "normal"
const NODE_ELITE := "elite"
const NODE_BOSS := "boss"

static func expedition_ids() -> Array[String]:
	return [
		EXPEDITION_BROKEN_WALL,
		EXPEDITION_RIFT_CORRIDOR,
		EXPEDITION_SUPPLY_LINE,
	]

static func get_config(selected_expedition_id: String) -> Dictionary:
	match selected_expedition_id:
		EXPEDITION_RIFT_CORRIDOR:
			return _rift_corridor_config().duplicate(true)
		EXPEDITION_SUPPLY_LINE:
			return _supply_line_config().duplicate(true)
	return _broken_wall_config().duplicate(true)

static func display_name(selected_expedition_id: String) -> String:
	return String(get_config(selected_expedition_id).get("display_name", "断墙外环"))

static func route_pools(selected_expedition_id: String) -> Dictionary:
	return get_config(selected_expedition_id).get("node_pools", {}).duplicate(true)

static func map_pool_config_ids(selected_expedition_id: String, pool_key: String) -> Array[String]:
	var result: Array[String] = []
	var map_pool: Dictionary = get_config(selected_expedition_id).get("map_pool", {})
	for entry in map_pool.get(pool_key, []):
		var config_id := String(entry.get("config_id", ""))
		if config_id.is_empty():
			continue
		result.append(config_id)
	return result

static func _rift_corridor_config() -> Dictionary:
	return {
		"display_name": "裂隙回廊",
		"node_pools": {
			"start": "outer_wall_01",
			"early": ["crack_courtyard_03", "extinguished_beacon_02", "quartermaster_cache_02"],
			"middle": ["pillar_graveyard_03", "broken_bridge_edge", "scout_ritual_03", "crack_courtyard_03"],
			"elite": ["iron_gate_04", "broken_bridge_edge"],
			"extra_elite": ["pillar_graveyard_03", "crack_courtyard_03"],
			"prep": ["ember_camp_05", "last_watch_event_05", "quartermaster_cache_05"],
		},
		"map_pool": {
			MAP_POOL_START: [_map_pool_entry(BattleConfigCatalogScript.CONFIG_OUTER_WALL, 1, 1, 7, "intro", "首战前哨。先读建筑 HP、远程线压和保护目标。")],
			MAP_POOL_NORMAL: [
				_map_pool_entry(BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD, 4, 2, 7, "archer", "裂隙庭院。浅裂隙和弓手长线制造持续压迫。"),
				_map_pool_entry(BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD, 2, 3, 8, "pillar", "石柱墓园。密集阻挡物和推撞口袋考验站位。"),
				_map_pool_entry(BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE, 2, 3, 8, "bridge", "断桥边缘。边缘处决和裂隙节奏制造高压普通战。"),
			],
			MAP_POOL_ELITE: [_map_pool_entry(BattleConfigCatalogScript.CONFIG_IRON_GATE, 1, 3, 11, "elite", "铁角闸门。精英冲撞配合侧翼裂隙压缩防线。")],
			MAP_POOL_BOSS: [_map_pool_entry(BattleConfigCatalogScript.CONFIG_OUTER_BELL, 1, 5, 14, "boss", "钟楼外环。Boss 脚本和心脏钟窗口决定终局节奏。")],
		},
		"pressure_budget": _default_map_pressure_budget(),
	}

static func _supply_line_config() -> Dictionary:
	return {
		"display_name": "废弃军需线",
		"node_pools": {
			"start": "outer_wall_01",
			"early": ["quartermaster_cache_02", "extinguished_beacon_02", "crack_courtyard_03"],
			"middle": ["ember_camp_03", "scout_ritual_03", "pillar_graveyard_03", "quartermaster_cache_02"],
			"elite": ["iron_gate_04"],
			"extra_elite": ["ember_camp_03", "pillar_graveyard_03"],
			"prep": ["quartermaster_cache_05", "ember_camp_05", "last_watch_event_05"],
		},
		"map_pool": {
			MAP_POOL_START: [_map_pool_entry(BattleConfigCatalogScript.CONFIG_OUTER_WALL, 1, 1, 7, "intro", "首战前哨。先读建筑 HP、远程线压和保护目标。")],
			MAP_POOL_NORMAL: [
				_map_pool_entry(BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD, 2, 2, 7, "archer", "裂隙庭院。浅裂隙和弓手长线制造持续压迫。"),
				_map_pool_entry(BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD, 3, 3, 8, "pillar", "石柱墓园。密集阻挡物和推撞口袋考验站位。"),
			],
			MAP_POOL_ELITE: [_map_pool_entry(BattleConfigCatalogScript.CONFIG_IRON_GATE, 1, 3, 11, "elite", "铁角闸门。精英冲撞配合侧翼裂隙压缩防线。")],
			MAP_POOL_BOSS: [_map_pool_entry(BattleConfigCatalogScript.CONFIG_OUTER_BELL, 1, 5, 14, "boss", "钟楼外环。Boss 脚本和心脏钟窗口决定终局节奏。")],
		},
		"pressure_budget": _default_map_pressure_budget(),
	}

static func _broken_wall_config() -> Dictionary:
	return {
		"display_name": "断墙外环",
		"node_pools": {
			"start": "outer_wall_01",
			"early": ["extinguished_beacon_02", "quartermaster_cache_02", "crack_courtyard_03"],
			"middle": ["pillar_graveyard_03", "ember_camp_03", "scout_ritual_03", "broken_bridge_edge"],
			"elite": ["iron_gate_04"],
			"extra_elite": ["pillar_graveyard_03", "broken_bridge_edge"],
			"prep": ["ember_camp_05", "quartermaster_cache_05", "last_watch_event_05"],
		},
		"map_pool": {
			MAP_POOL_START: [_map_pool_entry(BattleConfigCatalogScript.CONFIG_OUTER_WALL, 1, 1, 7, "intro", "首战前哨。先读建筑 HP、远程线压和保护目标。")],
			MAP_POOL_NORMAL: [
				_map_pool_entry(BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD, 2, 2, 7, "archer", "裂隙庭院。浅裂隙和弓手长线制造持续压迫。"),
				_map_pool_entry(BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD, 2, 3, 8, "pillar", "石柱墓园。密集阻挡物和推撞口袋考验站位。"),
				_map_pool_entry(BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE, 1, 3, 8, "bridge", "断桥边缘。边缘处决和裂隙节奏制造高压普通战。"),
			],
			MAP_POOL_ELITE: [_map_pool_entry(BattleConfigCatalogScript.CONFIG_IRON_GATE, 1, 3, 11, "elite", "铁角闸门。精英冲撞配合侧翼裂隙压缩防线。")],
			MAP_POOL_BOSS: [_map_pool_entry(BattleConfigCatalogScript.CONFIG_OUTER_BELL, 1, 5, 14, "boss", "钟楼外环。Boss 脚本和心脏钟窗口决定终局节奏。")],
		},
		"pressure_budget": _default_map_pressure_budget(),
	}

static func _default_map_pressure_budget() -> Dictionary:
	return {
		MAP_POOL_START: 2,
		MAP_POOL_NORMAL: 3,
		MAP_POOL_ELITE: 3,
		MAP_POOL_BOSS: 3,
	}

static func _map_pool_entry(config_id: String, weight: int, risk_level: int, base_embers: int, variant: String, summary: String, options: Dictionary = {}) -> Dictionary:
	var config := BattleConfigCatalogScript.get_config(config_id)
	var pressure_tags: Array = options.get("pressure_tags", config.get("pressure_tags", []))
	var allowed_node_types: Array = options.get("allowed_node_types", _default_map_allowed_node_types(config_id))
	var layer_range := _default_map_layer_range(config_id)
	var preview_flags: Array = options.get("preview_flags", [])
	return {
		"config_id": config_id,
		"weight": maxi(1, weight),
		"risk_level": risk_level,
		"base_embers": base_embers,
		"variant": variant,
		"summary": summary,
		"archetype": String(options.get("archetype", variant)),
		"allowed_node_types": allowed_node_types.duplicate(),
		"min_layer": int(options.get("min_layer", layer_range.x)),
		"max_layer": int(options.get("max_layer", layer_range.y)),
		"pressure_tags": pressure_tags.duplicate(),
		"pressure_cost": int(options.get("pressure_cost", pressure_tags.size())),
		"no_repeat_group": String(options.get("no_repeat_group", config_id)),
		"enemy_family_hint": String(options.get("enemy_family_hint", _default_enemy_family_hint(config_id))),
		"preview_flags": preview_flags.duplicate(),
	}

static func _default_map_allowed_node_types(config_id: String) -> Array[String]:
	match config_id:
		BattleConfigCatalogScript.CONFIG_OUTER_WALL:
			return [NODE_NORMAL]
		BattleConfigCatalogScript.CONFIG_IRON_GATE:
			return [NODE_ELITE]
		BattleConfigCatalogScript.CONFIG_OUTER_BELL:
			return [NODE_BOSS]
	return [NODE_NORMAL]

static func _default_map_layer_range(config_id: String) -> Vector2i:
	match config_id:
		BattleConfigCatalogScript.CONFIG_OUTER_WALL:
			return Vector2i(1, 1)
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD:
			return Vector2i(2, 4)
		BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD:
			return Vector2i(3, 4)
		BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE:
			return Vector2i(3, 4)
		BattleConfigCatalogScript.CONFIG_IRON_GATE:
			return Vector2i(4, 4)
		BattleConfigCatalogScript.CONFIG_OUTER_BELL:
			return Vector2i(6, 6)
	return Vector2i(1, 99)

static func _default_enemy_family_hint(config_id: String) -> String:
	match config_id:
		BattleConfigCatalogScript.CONFIG_OUTER_WALL:
			return "rot_beast_archer"
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD:
			return "rift_archer"
		BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD:
			return "pillar_push"
		BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE:
			return "bridge_execution"
		BattleConfigCatalogScript.CONFIG_IRON_GATE:
			return "ironhorn_elite"
		BattleConfigCatalogScript.CONFIG_OUTER_BELL:
			return "bell_boss"
	return "mixed"
