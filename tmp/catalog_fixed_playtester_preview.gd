extends SceneTree
## Runs fixed catalog tables through the candidate playtester controller.

const Catalog := preload("res://scripts/data/battle_config_catalog.gd")
const Playtester := preload("res://scripts/data/battle_candidate_playtester.gd")

const CONFIG_IDS := [
	Catalog.CONFIG_OUTER_WALL,
	Catalog.CONFIG_RIFT_COURTYARD,
	Catalog.CONFIG_PILLAR_GRAVEYARD,
	Catalog.CONFIG_IRON_GATE,
	Catalog.CONFIG_OUTER_BELL,
]

func _init() -> void:
	print("=== fixed catalog playtester preview ===")
	for config_id in CONFIG_IDS:
		var config := Catalog.get_config(config_id)
		var runtime := Catalog.build_runtime_config(config)
		var result := Playtester.evaluate_candidate(config, _fixed_candidate(runtime))
		print("[%s] %s result=%s outcome=%s dmg=%d destroyed=%d deaths=%d left=%d deploy=%s rounds=%s%s" % [
			config_id,
			String(config.get("display_name", "")),
			String(result.get("result", "")),
			String(result.get("outcome", "")),
			int(result.get("total_protected_damage", 0)),
			int(result.get("destroyed", 0)),
			int(result.get("warden_deaths", 0)),
			int(result.get("enemies_left", 0)),
			_spawns_text(result.get("deployment", [])),
			_rounds_text(result.get("rounds", [])),
			" boss=%s" % String(result.get("boss", "")) if not String(result.get("boss", "")).is_empty() else "",
		])
	quit(0)

func _fixed_candidate(runtime: Dictionary) -> Dictionary:
	return {
		"initial_enemies": _runtime_entries(runtime.get("initial_enemies", []), "initial"),
		"scripted_spawns": _runtime_entries(runtime.get("scripted_spawn_schedule", []), "scripted"),
		"rift_schedule": _runtime_entries(runtime.get("rift_schedule", []), "rift"),
	}

func _runtime_entries(entries: Array, source: String) -> Array:
	var result: Array = []
	for entry in entries:
		result.append({
			"enemy_id": String(entry.get("enemy_id", "")),
			"pos": entry.get("pos", Vector2i(-1, -1)),
			"round": int(entry.get("round", 1)),
			"source_pool": source,
			"rift_id": String(entry.get("rift_id", "")),
		})
	return result

func _spawns_text(spawns: Array) -> String:
	var parts: Array[String] = []
	for p in spawns:
		parts.append("(%d,%d)" % [p.x, p.y])
	return " ; ".join(parts)

func _rounds_text(rounds: Array) -> String:
	var parts: Array[String] = []
	for raw in rounds:
		var entry: Dictionary = raw
		parts.append("R%d:t%d:d%d:left%d" % [
			int(entry.get("round", 0)),
			int(entry.get("threat", 0)),
			int(entry.get("protected_damage", 0)),
			int(entry.get("enemies_left", 0)),
		])
	return " | ".join(parts)
