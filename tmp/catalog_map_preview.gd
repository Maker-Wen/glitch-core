extends SceneTree

const CONTROL_SEARCH_DEPTH := 6
const CONTROL_BEAM_WIDTH := 80
const CONTROL_BRANCH_WIDTH := 18
const CONFIG_IDS := [
	BattleConfigCatalog.CONFIG_OUTER_WALL,
	BattleConfigCatalog.CONFIG_RIFT_COURTYARD,
	BattleConfigCatalog.CONFIG_PILLAR_GRAVEYARD,
	BattleConfigCatalog.CONFIG_IRON_GATE,
	BattleConfigCatalog.CONFIG_OUTER_BELL,
]

func _init() -> void:
	print("=== catalog map preview ===")
	for config_id in CONFIG_IDS:
		_preview_config(config_id)
	quit(0)

func _preview_config(config_id: String) -> void:
	var config := BattleConfigCatalog.get_config(config_id)
	var engine := _start(config)
	var result := _simulate(engine)
	print("[%s] %s total_dmg=%d destroyed=%d warden_deaths=%d enemies_left=%d outcome=%s deploy=%s rounds=%s%s" % [
		config_id,
		String(config.get("display_name", "")),
		int(result.get("total_protected_damage", 0)),
		int(result.get("destroyed", 0)),
		int(result.get("warden_deaths", 0)),
		int(result.get("enemies_left", 0)),
		String(result.get("outcome", "")),
		" ; ".join(_deploy_text(config.get("warden_spawns", []))),
		" | ".join(result.get("rounds", [])),
		String(result.get("boss", "")),
	])

func _start(config: Dictionary) -> BattleEngine:
	var runtime := BattleConfigCatalog.build_runtime_config(config)
	var engine := BattleEngine.new()
	engine.start_battle(
		runtime.get("grid"),
		[load("res://scripts/data/defs/warden_bountyhunter.tres"), load("res://scripts/data/defs/warden_graverobber.tres"), load("res://scripts/data/defs/warden_mage.tres")],
		runtime.get("initial_enemies", []),
		runtime.get("deploy_zone", []),
		runtime.get("rift_positions", []),
		runtime.get("rift_schedule", []),
		int(runtime.get("max_rounds", 5)),
		runtime.get("protected_targets", []),
		runtime.get("reward_tasks", []),
		[],
		_boss_config(config),
		runtime.get("scripted_spawn_schedule", []),
		runtime.get("cracked_ground_schedule", []),
		runtime.get("abyss_edges", {}),
		runtime.get("bell_wave_schedule", [])
	)
	for p in config.get("warden_spawns", []):
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
		"boss": "",
	}
	while engine.state.phase == BattleState.Phase.PLAYER_ACTION and engine.state.outcome == BattleState.Outcome.UNDECIDED:
		var round := engine.state.current_round
		var before_damage := engine.state.protected_damage_taken
		var choice := _choose_turn_control(engine)
		for action in choice.get("actions_raw", []):
			if engine.state.phase != BattleState.Phase.PLAYER_ACTION or engine.state.current_round != round:
				break
			engine.apply_action(action)
			if engine.state.current_round != round:
				break
		if engine.state.phase == BattleState.Phase.PLAYER_ACTION and engine.state.current_round == round:
			engine.apply_action(BattleAction.end_turn())
		result["rounds"].append("R%d threat=%d dmg=%d left=%d actions=%d" % [
			round,
			int(choice.get("threat", 0)),
			engine.state.protected_damage_taken - before_damage,
			engine.state.enemies().size(),
			choice.get("actions", []).size(),
		])
	result["outcome"] = _outcome_text(engine.state.outcome)
	result["total_protected_damage"] = engine.state.protected_damage_taken
	result["destroyed"] = engine.state.destroyed_protected_count
	result["warden_deaths"] = engine.state.warden_deaths
	result["enemies_left"] = engine.state.enemies().size()
	result["boss"] = _boss_summary(engine)
	return result

func _choose_turn_control(engine: BattleEngine) -> Dictionary:
	var root := BattleEngine.new()
	root.state = engine.state.clone()
	var start_score := _turn_score(root)
	var best := {
		"score": start_score,
		"actions": [],
		"actions_raw": [],
		"threat": _sum_damage(_protected_damage_from_rows(engine.get_enemy_intent_ui_state())),
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
				best["score"] = int(node.score)
				best["actions"] = node.actions.duplicate()
				best["actions_raw"] = node.actions_raw.duplicate()
			for entry in _candidate_actions_ranked(cur_engine):
				var next := BattleEngine.new()
				next.state = cur_engine.state.clone()
				next._dispatch_action(next.state, entry.action)
				var score := _turn_score(next)
				candidates.append({
					"engine": next,
					"actions": node.actions + [String(entry.text)],
					"actions_raw": node.actions_raw + [entry.action],
					"score": score,
				})
				if score < int(best.score):
					best["score"] = score
					best["actions"] = node.actions + [String(entry.text)]
					best["actions_raw"] = node.actions_raw + [entry.action]
		if candidates.is_empty():
			break
		candidates.sort_custom(func(a, b): return int(a.score) < int(b.score))
		frontier = candidates.slice(0, mini(CONTROL_BEAM_WIDTH, candidates.size()))
	return best

func _candidate_actions_ranked(engine: BattleEngine) -> Array:
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
	for entry in actions:
		var next := BattleEngine.new()
		next.state = engine.state.clone()
		next._dispatch_action(next.state, entry.action)
		entry["score"] = _turn_score(next)
	actions.sort_custom(func(a, b): return int(a.score) < int(b.score))
	return actions.slice(0, mini(CONTROL_BRANCH_WIDTH, actions.size()))

func _turn_score(engine: BattleEngine) -> int:
	var pending_damage := _sum_damage(_protected_damage_from_rows(engine.get_enemy_intent_ui_state()))
	return engine.state.protected_damage_taken * 100000 \
		+ engine.state.destroyed_protected_count * 70000 \
		+ _boss_breach_risk(engine) * 60000 \
		+ pending_damage * 12000 \
		+ _warden_damage_from_rows(engine.get_enemy_intent_ui_state()) * 1400 \
		+ _warden_hp_lost(engine) * 800 \
		+ _active_threat_count(engine.get_enemy_intent_ui_state()) * 300 \
		+ engine.state.enemies().size() * 160 \
		+ _enemy_hp_total(engine) * 35 \
		+ _boss_anchor_hp_total(engine) * 320 \
		- engine.state.heart_hits * 520 \
		- _weak_enemy_count(engine) * 25 \
		+ _acted_warden_count(engine) * 5 \
		+ _warden_distance_to_live_threats(engine)

func _state_signature(engine: BattleEngine) -> String:
	var unit_parts: Array[String] = []
	for u in engine.state.units:
		unit_parts.append("%d:%s:%s:%d:%s:%s" % [u.id, String(u.def.def_id if u.def != null else &""), _v(u.position), u.hp, str(u.has_moved), str(u.has_acted)])
	unit_parts.sort()
	return ";".join(unit_parts)

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

func _warden_damage_from_rows(rows: Array) -> int:
	var total := 0
	for row in rows:
		if String(row.get("target_kind", "")) == BattleEngine.TARGET_KIND_UNIT:
			total += int(row.get("target_damage", 0))
	return total

func _active_threat_count(rows: Array) -> int:
	var total := 0
	for row in rows:
		if bool(row.get("has_attack", false)) and String(row.get("status", "")) == BattleEngine.INTENT_STATUS_HIT:
			total += 1
	return total

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

func _boss_config(config: Dictionary) -> Dictionary:
	if String(config.get("boss_config_id", "")).is_empty():
		return {}
	var anchors: Array[Vector2i] = []
	var anchor_hp := -1
	var heart := Vector2i(-1, -1)
	for raw in config.get("boss_objects", []):
		var entry: Dictionary = raw
		var pos: Vector2i = entry.get("pos", Vector2i(-1, -1))
		match String(entry.get("kind", "")):
			"anchor":
				anchors.append(pos)
				anchor_hp = maxi(anchor_hp, int(entry.get("hp", -1)))
			"heart_bell":
				heart = pos
	return {
		"boss_config_id": String(config.get("boss_config_id", "knell_lord_demo_01")),
		"boss_script_id": String(config.get("boss_script_id", "knell_lord_demo_six_round")),
		"doom_count_initial": int(config.get("doom_count_initial", 0)),
		"doom_count_max": int(config.get("doom_count_max", 3)),
		"anchor_positions": anchors,
		"anchor_hp": anchor_hp if anchor_hp > 0 else 2,
		"heart_position": heart,
		"heart_hit_cap": int(config.get("heart_hit_cap", 3)),
	}

func _boss_anchor_hp_total(engine: BattleEngine) -> int:
	if not engine.state.has_boss():
		return 0
	var total := 0
	for hp in engine.state.boss_anchor_hp.values():
		total += maxi(0, int(hp))
	return total

func _boss_breach_risk(engine: BattleEngine) -> int:
	if not engine.state.has_boss():
		return 0
	var remaining: int = max(0, engine.state.doom_count_max - engine.state.doom_count)
	return engine.state.doom_count * 2 + maxi(0, _boss_anchor_hp_total(engine) - remaining)

func _boss_summary(engine: BattleEngine) -> String:
	if not engine.state.has_boss():
		return ""
	return " boss=anchors:%d/%d heart:%d doom:%d/%d" % [
		engine.state.boss_destroyed_anchor_count(),
		engine.state.boss_anchor_positions.size(),
		engine.state.heart_hits,
		engine.state.doom_count,
		engine.state.doom_count_max,
	]

func _deploy_text(spawns: Array) -> Array:
	var result: Array[String] = []
	for p in spawns:
		result.append(_v(p))
	return result

func _outcome_text(outcome: int) -> String:
	match outcome:
		BattleState.Outcome.VICTORY:
			return "victory"
		BattleState.Outcome.DEFEAT:
			return "defeat"
	return "undecided"

func _v(p: Vector2i) -> String:
	return "(%d,%d)" % [p.x, p.y]
