extends SceneTree
## Debug trace for the current iron gate generated candidate.

const Catalog := preload("res://scripts/data/battle_config_catalog.gd")
const Generator := preload("res://scripts/data/battle_pool_candidate_generator.gd")
const Playtester := preload("res://scripts/data/battle_candidate_playtester.gd")

func _init() -> void:
	var config := Catalog.get_config(Catalog.CONFIG_IRON_GATE)
	var candidate := Generator.generate_candidate(config, 240620, 0)
	var sim := Playtester.evaluate_candidate(config, candidate)
	print("=== iron gate trace seed=240620 variant=0 ===")
	print("initial=%s" % _entries(candidate.get("initial_enemies", [])))
	print("scripted=%s" % _entries(candidate.get("scripted_spawns", [])))
	print("rifts=%s" % _entries(candidate.get("rift_schedule", [])))
	print("result=%s outcome=%s dmg=%d destroyed=%d deaths=%d left=%d max_threat=%d" % [
		String(sim.get("result", "")),
		String(sim.get("outcome", "")),
		int(sim.get("total_protected_damage", 0)),
		int(sim.get("destroyed", 0)),
		int(sim.get("warden_deaths", 0)),
		int(sim.get("enemies_left", 0)),
		int(sim.get("max_threat", 0)),
	])
	print("deployment=%s index=%d" % [_cells(sim.get("deployment", [])), int(sim.get("deployment_index", -1))])
	for round in sim.get("rounds", []):
		print("R%d threat=%d dmg=%d left=%d" % [
			int(round.get("round", 0)),
			int(round.get("threat", 0)),
			int(round.get("protected_damage", 0)),
			int(round.get("enemies_left", 0)),
		])
		for action in round.get("actions", []):
			print("  %s" % String(action))
	quit(0)

func _entries(entries: Array) -> String:
	if entries.is_empty():
		return "-"
	var parts: Array[String] = []
	for entry in entries:
		var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
		parts.append("R%d %s@%d,%d/%s" % [
			int(entry.get("round", 1)),
			String(entry.get("enemy_id", "")),
			pos.x,
			pos.y,
			String(entry.get("source_pool", "")),
		])
	return "; ".join(parts)

func _cells(cells: Array) -> String:
	var parts: Array[String] = []
	for cell in cells:
		var p: Vector2i = cell
		parts.append("%d,%d" % [p.x, p.y])
	return "; ".join(parts)
