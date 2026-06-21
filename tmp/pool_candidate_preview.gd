extends SceneTree
## Prints preview-only pool candidates for map design review.
##
## Usage:
##   godot --headless -s tmp/pool_candidate_preview.gd

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const BattlePoolCandidateGeneratorScript := preload("res://scripts/data/battle_pool_candidate_generator.gd")
const BattleCandidatePlaytesterScript := preload("res://scripts/data/battle_candidate_playtester.gd")

const CONFIG_IDS := [
	BattleConfigCatalogScript.CONFIG_OUTER_WALL,
	BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
	BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD,
	BattleConfigCatalogScript.CONFIG_IRON_GATE,
	BattleConfigCatalogScript.CONFIG_OUTER_BELL,
]

const BASE_SEED := 240620
const VARIANT_COUNT := 3

func _init() -> void:
	print("=== map pool candidate preview ===")
	print("preview_only=true runtime_catalog_unchanged=true")
	for config_id in CONFIG_IDS:
		_preview_config(config_id)
	quit(0)

func _preview_config(config_id: String) -> void:
	var config := BattleConfigCatalogScript.get_config(config_id)
	print("")
	print("[%s] %s" % [config_id, String(config.get("display_name", ""))])
	for variant_index in range(VARIANT_COUNT):
		var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, BASE_SEED, variant_index)
		var validation: Dictionary = candidate.get("validation", {})
		var solvability := BattleCandidatePlaytesterScript.evaluate_candidate(config, candidate)
		print("  variant=%d seed=%d result=%s" % [
			variant_index,
			int(candidate.get("seed", 0)),
			String(validation.get("result", "")),
		])
		print("    elements: %s" % _selected_element_text(candidate.get("selected_elements", {})))
		print("    initial: %s" % _entry_list_text(candidate.get("initial_enemies", [])))
		print("    scripted: %s" % _entry_list_text(candidate.get("scripted_spawns", [])))
		print("    rifts: %s" % _entry_list_text(candidate.get("rift_schedule", [])))
		print("    solvability: %s outcome=%s dmg=%d destroyed=%d deaths=%d left=%d max_threat=%d%s" % [
			String(solvability.get("result", "")),
			String(solvability.get("outcome", "")),
			int(solvability.get("total_protected_damage", 0)),
			int(solvability.get("destroyed", 0)),
			int(solvability.get("warden_deaths", 0)),
			int(solvability.get("enemies_left", 0)),
			int(solvability.get("max_threat", 0)),
			_boss_text(String(solvability.get("boss", ""))),
		])
		print("    sim_rounds: %s" % _round_list_text(solvability.get("rounds", [])))
		if not validation.get("issues", []).is_empty():
			print("    issues: %s" % " | ".join(_string_array(validation.get("issues", []))))
		if not validation.get("warnings", []).is_empty():
			print("    warnings: %s" % " | ".join(_string_array(validation.get("warnings", []))))
		if not solvability.get("issues", []).is_empty():
			print("    sim_issues: %s" % " | ".join(_string_array(solvability.get("issues", []))))
		if not solvability.get("warnings", []).is_empty():
			print("    sim_warnings: %s" % " | ".join(_string_array(solvability.get("warnings", []))))

func _selected_element_text(elements: Dictionary) -> String:
	if elements.is_empty():
		return "-"
	var parts: Array[String] = []
	var keys := elements.keys()
	keys.sort()
	for key in keys:
		var entry: Dictionary = elements.get(key, {})
		parts.append("%s=%s" % [String(key), String(entry.get("id", ""))])
	return "; ".join(parts)

func _entry_list_text(entries: Array) -> String:
	if entries.is_empty():
		return "-"
	var parts: Array[String] = []
	for entry in entries:
		var round := int(entry.get("round", 1))
		var enemy_id := String(entry.get("enemy_id", ""))
		var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
		var source_pool := String(entry.get("source_pool", ""))
		parts.append("R%d %s@%s/%s" % [round, enemy_id, _v(pos), source_pool])
	return "; ".join(parts)

func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result

func _round_list_text(rounds: Array) -> String:
	if rounds.is_empty():
		return "-"
	var parts: Array[String] = []
	for entry in rounds:
		var round: Dictionary = entry
		parts.append("R%d threat=%d dmg=%d left=%d actions=%d" % [
			int(round.get("round", 0)),
			int(round.get("threat", 0)),
			int(round.get("protected_damage", 0)),
			int(round.get("enemies_left", 0)),
			round.get("actions", []).size(),
		])
	return " | ".join(parts)

func _boss_text(summary: String) -> String:
	if summary.is_empty():
		return ""
	return " boss=%s" % summary

func _v(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]
