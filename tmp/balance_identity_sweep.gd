extends SceneTree
## Temporary role-identity sweep for low-move balance review.
##
## The goal is not to find the strongest numbers. It checks whether keeping
## wardens at Move 2 can still create distinct role value through HP / Range /
## Force growth, using the real BattleEngine and generated encounter variants.

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

const WARDEN_DEF_PATHS := [
	"res://scripts/data/defs/warden_bountyhunter.tres",
	"res://scripts/data/defs/warden_graverobber.tres",
	"res://scripts/data/defs/warden_mage.tres",
]

const ROLE_IDS := [
	"warden_bountyhunter",
	"warden_graverobber",
	"warden_mage",
]

const BASE_SEED := 240620
const SEED_COUNT := 4
const VARIANT_COUNT := 2

const SCENARIOS := [
	{"id": "baseline", "label": "Move2基线"},
	{"id": "bounty_move3", "label": "赏金Move3对照"},
	{"id": "bounty_hp3", "label": "赏金HP+1"},
	{"id": "bounty_force2", "label": "赏金推力+1"},
	{"id": "grave_range4", "label": "盗墓射程+1"},
	{"id": "grave_pull2", "label": "盗墓拉力+1"},
	{"id": "mage_force2", "label": "法师推力+1"},
	{"id": "identity_light", "label": "低Move职业轻成长"},
	{"id": "identity_control", "label": "低Move控制成长"},
]

func _init() -> void:
	print("=== low-move role identity sweep ===")
	print("sample=configs:%d seeds:%d variants:%d total_per_scenario:%d" % [
		CONFIG_IDS.size(),
		SEED_COUNT,
		VARIANT_COUNT,
		CONFIG_IDS.size() * SEED_COUNT * VARIANT_COUNT,
	])
	var records_by_scenario := {}
	for scenario in SCENARIOS:
		var records: Array[Dictionary] = []
		for config_id in CONFIG_IDS:
			var config := BattleConfigCatalogScript.get_config(config_id)
			for seed_offset in range(SEED_COUNT):
				var seed := BASE_SEED + seed_offset
				for variant_index in range(VARIANT_COUNT):
					var candidate := BattlePoolCandidateGeneratorScript.generate_candidate(config, seed, variant_index)
					records.append(_evaluate_candidate(config, candidate, scenario))
		records_by_scenario[String(scenario.get("id", ""))] = records
		_print_scenario_summary(scenario, records)
	_print_per_map_summary(records_by_scenario)
	quit(0)

func _evaluate_candidate(config: Dictionary, candidate: Dictionary, scenario: Dictionary) -> Dictionary:
	var runtime: Dictionary = BattleConfigCatalogScript.build_runtime_config(config)
	var deployment_candidates: Array = BattleCandidatePlaytesterScript._deployment_candidates(config, runtime, candidate)
	var best: Dictionary = {}
	var best_score := 1 << 30
	for deploy_index in range(deployment_candidates.size()):
		var deploy_spawns: Array = deployment_candidates[deploy_index]
		var engine := _start_battle(config, candidate, deploy_spawns, scenario)
		var simulation := _simulate(engine)
		var score := _simulation_score(simulation)
		if best.is_empty() or score < best_score:
			best = simulation
			best_score = score
		if _is_clean_win(simulation):
			break
	return _record(config, candidate, scenario, best)

func _start_battle(config: Dictionary, candidate: Dictionary, deploy_spawns: Array, scenario: Dictionary) -> BattleEngine:
	var runtime: Dictionary = BattleConfigCatalogScript.build_runtime_config(config)
	var engine := BattleEngine.new()
	engine.start_battle(
		runtime.get("grid"),
		_load_warden_defs(scenario),
		_candidate_initial_enemies(candidate.get("initial_enemies", []), scenario),
		runtime.get("deploy_zone", []),
		runtime.get("rift_positions", []),
		_candidate_schedule(candidate.get("rift_schedule", []), true, scenario),
		int(runtime.get("max_rounds", 5)),
		runtime.get("protected_targets", []),
		runtime.get("reward_tasks", []),
		[],
		BattleCandidatePlaytesterScript._boss_config(config),
		_candidate_schedule(candidate.get("scripted_spawns", []), false, scenario),
		runtime.get("cracked_ground_schedule", []),
		runtime.get("abyss_edges", {}),
		runtime.get("bell_wave_schedule", [])
	)
	for p in BattleCandidatePlaytesterScript._deployment_spawns(runtime, candidate, deploy_spawns):
		engine.apply_action(BattleAction.deploy(p))
	engine.apply_action(BattleAction.confirm_deploy())
	return engine

func _simulate(engine: BattleEngine) -> Dictionary:
	var result := {
		"rounds": [],
		"outcome": "running",
		"total_protected_damage": 0,
		"destroyed": 0,
		"warden_deaths": 0,
		"enemies_left": 0,
		"max_threat": 0,
		"heart_hits": 0,
		"actions_total": 0,
		"move_actions": 0,
		"attack_actions": 0,
		"turns": 0,
		"start_attackers": 0,
		"start_attack_options": 0,
		"role_attacks": {},
		"role_moves": {},
		"role_ready_turns": {},
	}
	var guard := 0
	while engine.state.phase == BattleState.Phase.PLAYER_ACTION and engine.state.outcome == BattleState.Outcome.UNDECIDED:
		guard += 1
		if guard > engine.state.max_rounds + 2:
			break
		var round := engine.state.current_round
		var before_damage := engine.state.protected_damage_taken
		_count_start_attack_options(engine, result)
		var choice: Dictionary = BattleCandidatePlaytesterScript._choose_turn_control(engine)
		result["max_threat"] = maxi(int(result.get("max_threat", 0)), int(choice.get("threat", 0)))
		for action in choice.get("actions_raw", []):
			if engine.state.phase != BattleState.Phase.PLAYER_ACTION or engine.state.current_round != round:
				break
			_count_action(engine, result, action)
			engine.apply_action(action)
			if engine.state.current_round != round:
				break
		if engine.state.phase == BattleState.Phase.PLAYER_ACTION and engine.state.current_round == round:
			engine.apply_action(BattleAction.end_turn())
		result["rounds"].append({
			"round": round,
			"protected_damage": engine.state.protected_damage_taken - before_damage,
			"enemies_left": engine.state.enemies().size(),
		})
	result["outcome"] = _outcome_text(engine.state.outcome)
	result["total_protected_damage"] = engine.state.protected_damage_taken
	result["destroyed"] = engine.state.destroyed_protected_count
	result["warden_deaths"] = engine.state.warden_deaths
	result["enemies_left"] = engine.state.enemies().size()
	result["heart_hits"] = engine.state.heart_hits
	return result

func _record(config: Dictionary, candidate: Dictionary, scenario: Dictionary, simulation: Dictionary) -> Dictionary:
	return {
		"scenario": String(scenario.get("id", "")),
		"config_id": String(config.get("config_id", "")),
		"seed": int(candidate.get("seed", 0)),
		"variant": int(candidate.get("variant_index", 0)),
		"outcome": String(simulation.get("outcome", "")),
		"clean": _is_clean_win(simulation),
		"damage": int(simulation.get("total_protected_damage", 0)),
		"destroyed": int(simulation.get("destroyed", 0)),
		"deaths": int(simulation.get("warden_deaths", 0)),
		"left": int(simulation.get("enemies_left", 0)),
		"max_threat": int(simulation.get("max_threat", 0)),
		"heart_hits": int(simulation.get("heart_hits", 0)),
		"actions_total": int(simulation.get("actions_total", 0)),
		"move_actions": int(simulation.get("move_actions", 0)),
		"attack_actions": int(simulation.get("attack_actions", 0)),
		"turns": int(simulation.get("turns", 0)),
		"start_attackers": int(simulation.get("start_attackers", 0)),
		"start_attack_options": int(simulation.get("start_attack_options", 0)),
		"role_attacks": simulation.get("role_attacks", {}).duplicate(),
		"role_moves": simulation.get("role_moves", {}).duplicate(),
		"role_ready_turns": simulation.get("role_ready_turns", {}).duplicate(),
	}

func _load_warden_defs(scenario: Dictionary) -> Array:
	var defs: Array = []
	for path in WARDEN_DEF_PATHS:
		var def: UnitDef = load(path).duplicate(true)
		_apply_warden_scenario(def, String(scenario.get("id", "")))
		defs.append(def)
	return defs

func _enemy_def_for(enemy_id: String, scenario: Dictionary) -> UnitDef:
	var path := String(BattleConfigCatalogScript.ENEMY_RUNTIME_DEF_PATHS.get(enemy_id, ""))
	if path.is_empty():
		return null
	var def: UnitDef = load(path).duplicate(true)
	# This sweep intentionally keeps enemy numbers fixed.
	return def

func _apply_warden_scenario(def: UnitDef, scenario_id: String) -> void:
	match scenario_id:
		"bounty_move3":
			if def.def_id == &"warden_bountyhunter":
				def.move += 1
		"bounty_hp3":
			if def.def_id == &"warden_bountyhunter":
				def.max_hp += 1
		"bounty_force2":
			if def.def_id == &"warden_bountyhunter":
				def.attack_force += 1
		"grave_range4":
			if def.def_id == &"warden_graverobber":
				def.attack_range += 1
		"grave_pull2":
			if def.def_id == &"warden_graverobber":
				def.attack_force += 1
		"mage_force2":
			if def.def_id == &"warden_mage":
				def.attack_force += 1
		"identity_light":
			if def.def_id == &"warden_bountyhunter":
				def.max_hp += 1
			elif def.def_id == &"warden_graverobber":
				def.attack_range += 1
			elif def.def_id == &"warden_mage":
				def.attack_force += 1
		"identity_control":
			if def.def_id == &"warden_bountyhunter":
				def.attack_force += 1
			elif def.def_id == &"warden_graverobber":
				def.attack_range += 1
				def.attack_force += 1
			elif def.def_id == &"warden_mage":
				def.attack_force += 1

func _candidate_initial_enemies(entries: Array, scenario: Dictionary) -> Array:
	var result: Array = []
	for entry in entries:
		var enemy_id := String(entry.get("enemy_id", ""))
		var def := _enemy_def_for(enemy_id, scenario)
		if def == null:
			continue
		result.append({"def": def, "pos": entry.get("pos", Vector2i(-1, -1)), "enemy_id": enemy_id})
	return result

func _candidate_schedule(entries: Array, include_rift_id: bool, scenario: Dictionary) -> Array:
	var result: Array = []
	for entry in entries:
		var enemy_id := String(entry.get("enemy_id", ""))
		var def := _enemy_def_for(enemy_id, scenario)
		if def == null:
			continue
		var normalized := {
			"round": int(entry.get("round", 0)),
			"pos": entry.get("pos", Vector2i(-1, -1)),
			"def": def,
			"enemy_id": enemy_id,
		}
		if include_rift_id:
			normalized["rift_id"] = String(entry.get("rift_id", ""))
		else:
			normalized["source"] = String(entry.get("source_pool", "candidate_pool"))
		result.append(normalized)
	return result

func _count_start_attack_options(engine: BattleEngine, result: Dictionary) -> void:
	result["turns"] = int(result.get("turns", 0)) + 1
	for w in engine.state.wardens():
		if w.has_acted:
			continue
		var targets := engine.get_legal_attack_targets(w.id)
		result["start_attack_options"] = int(result.get("start_attack_options", 0)) + targets.size()
		if not targets.is_empty():
			result["start_attackers"] = int(result.get("start_attackers", 0)) + 1
			_inc_dict(result.get("role_ready_turns", {}), String(w.def.def_id))

func _count_action(engine: BattleEngine, result: Dictionary, action: BattleAction) -> void:
	result["actions_total"] = int(result.get("actions_total", 0)) + 1
	var actor := engine.state.find_unit(action.actor_id)
	var role_id := String(actor.def.def_id) if actor != null and actor.def != null else "unknown"
	match action.kind:
		BattleAction.Kind.MOVE:
			result["move_actions"] = int(result.get("move_actions", 0)) + 1
			_inc_dict(result.get("role_moves", {}), role_id)
		BattleAction.Kind.ATTACK:
			result["attack_actions"] = int(result.get("attack_actions", 0)) + 1
			_inc_dict(result.get("role_attacks", {}), role_id)

func _inc_dict(dict: Dictionary, key: String, amount: int = 1) -> void:
	dict[key] = int(dict.get(key, 0)) + amount

func _is_clean_win(simulation: Dictionary) -> bool:
	return String(simulation.get("outcome", "")) == "victory" \
		and int(simulation.get("total_protected_damage", 0)) == 0 \
		and int(simulation.get("destroyed", 0)) == 0 \
		and int(simulation.get("warden_deaths", 0)) == 0

func _simulation_score(simulation: Dictionary) -> int:
	var outcome_penalty := 0 if String(simulation.get("outcome", "")) == "victory" else 900000
	return outcome_penalty \
		+ int(simulation.get("destroyed", 0)) * 180000 \
		+ int(simulation.get("total_protected_damage", 0)) * 110000 \
		+ int(simulation.get("warden_deaths", 0)) * 70000 \
		+ int(simulation.get("max_threat", 0)) * 2500 \
		+ int(simulation.get("enemies_left", 0)) * 900

func _print_scenario_summary(scenario: Dictionary, records: Array[Dictionary]) -> void:
	var total := records.size()
	var clean := 0
	var damage := 0
	var left := 0
	var actions := 0
	var moves := 0
	var attacks := 0
	var turns := 0
	var start_attackers := 0
	var start_attack_options := 0
	var boss_count := 0
	var heart_hits := 0
	var role_attacks := {}
	var role_moves := {}
	var role_ready := {}
	for rec in records:
		if bool(rec.get("clean", false)):
			clean += 1
		damage += int(rec.get("damage", 0))
		left += int(rec.get("left", 0))
		actions += int(rec.get("actions_total", 0))
		moves += int(rec.get("move_actions", 0))
		attacks += int(rec.get("attack_actions", 0))
		turns += int(rec.get("turns", 0))
		start_attackers += int(rec.get("start_attackers", 0))
		start_attack_options += int(rec.get("start_attack_options", 0))
		_merge_counts(role_attacks, rec.get("role_attacks", {}))
		_merge_counts(role_moves, rec.get("role_moves", {}))
		_merge_counts(role_ready, rec.get("role_ready_turns", {}))
		if String(rec.get("config_id", "")) == BattleConfigCatalogScript.CONFIG_OUTER_BELL:
			boss_count += 1
			heart_hits += int(rec.get("heart_hits", 0))
	print("scenario=%s label=%s clean=%.1f%% avg_dmg=%.2f avg_left=%.2f avg_actions=%.2f move_share=%.1f%% attack_share=%.1f%% start_attackers_per_turn=%.2f start_options_per_turn=%.2f boss_heart_avg=%.2f role_attacks=%s role_ready=%s" % [
		String(scenario.get("id", "")),
		String(scenario.get("label", "")),
		_pct(clean, total),
		_avg(damage, total),
		_avg(left, total),
		_avg(actions, total),
		_pct(moves, maxi(1, actions)),
		_pct(attacks, maxi(1, actions)),
		float(start_attackers) / float(maxi(1, turns)),
		float(start_attack_options) / float(maxi(1, turns)),
		float(heart_hits) / float(maxi(1, boss_count)),
		_role_share_text(role_attacks, attacks),
		_role_rate_text(role_ready, turns),
	])

func _print_per_map_summary(records_by_scenario: Dictionary) -> void:
	print("")
	print("per_map:")
	for scenario in SCENARIOS:
		var scenario_id := String(scenario.get("id", ""))
		var records: Array = records_by_scenario.get(scenario_id, [])
		var parts: Array[String] = []
		for config_id in CONFIG_IDS:
			var rows: Array[Dictionary] = []
			for rec in records:
				if String(rec.get("config_id", "")) == config_id:
					rows.append(rec)
			var clean := 0
			var damage := 0
			var left := 0
			for row in rows:
				if bool(row.get("clean", false)):
					clean += 1
				damage += int(row.get("damage", 0))
				left += int(row.get("left", 0))
			parts.append("%s clean=%.0f%% dmg=%.2f left=%.2f" % [
				config_id.replace("battle_", ""),
				_pct(clean, rows.size()),
				_avg(damage, rows.size()),
				_avg(left, rows.size()),
			])
		print("scenario=%s | %s" % [scenario_id, " | ".join(parts)])

func _merge_counts(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[String(key)] = int(target.get(String(key), 0)) + int(source.get(key, 0))

func _role_share_text(counts: Dictionary, total: int) -> String:
	var parts: Array[String] = []
	for role in ROLE_IDS:
		parts.append("%s=%.0f%%" % [_role_short(role), _pct(int(counts.get(role, 0)), total)])
	return ",".join(parts)

func _role_rate_text(counts: Dictionary, total_turns: int) -> String:
	var parts: Array[String] = []
	for role in ROLE_IDS:
		parts.append("%s=%.2f" % [_role_short(role), float(int(counts.get(role, 0))) / float(maxi(1, total_turns))])
	return ",".join(parts)

func _role_short(role: String) -> String:
	match role:
		"warden_bountyhunter":
			return "bounty"
		"warden_graverobber":
			return "grave"
		"warden_mage":
			return "mage"
	return role

func _pct(value: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return float(value) / float(total) * 100.0

func _avg(value: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return float(value) / float(total)

func _outcome_text(outcome: int) -> String:
	match outcome:
		BattleState.Outcome.VICTORY:
			return "victory"
		BattleState.Outcome.DEFEAT:
			return "defeat"
	return "undecided"
