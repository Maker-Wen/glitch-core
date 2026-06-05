extends RefCounted
## Focused RunState regressions for Demo Run shell integration.

const RunStateScript := preload("res://scripts/run/run_state.gd")
const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")

static func _resolution(line_breached: bool, destroyed: int, completed: int = 0, hps: Array = [2, 2, 2]) -> Dictionary:
	return {
		"outcome": BattleState.Outcome.DEFEAT if line_breached else BattleState.Outcome.VICTORY,
		"victory": not line_breached,
		"line_breached": line_breached,
		"destroyed_protected_count": destroyed,
		"protected_damage_taken": destroyed,
		"completed_reward_count": completed,
		"reward_tasks": [],
		"reward_completed": {},
		"reward_failed": {},
		"wardens": [
			{"def_id": "warden_bountyhunter", "name": "BH", "hp": int(hps[0]), "hp_max": 2, "alive": int(hps[0]) > 0},
			{"def_id": "warden_graverobber", "name": "GR", "hp": int(hps[1]), "hp_max": 2, "alive": int(hps[1]) > 0},
			{"def_id": "warden_mage", "name": "MG", "hp": int(hps[2]), "hp_max": 2, "alive": int(hps[2]) > 0},
		],
		"round": 5,
		"max_rounds": 5,
	}

static func run(tr) -> void:
	_test_fixed_demo_route_order_and_battle_limits(tr)
	_test_mark_current_node_visited_is_idempotent(tr)
	_test_guard_loss_from_destroyed_targets_is_capped(tr)
	_test_run_fails_when_sanctuary_reaches_zero(tr)
	_test_run_fails_when_all_wardens_are_dead(tr)
	_test_pending_reward_basic_structure(tr)

static func _test_fixed_demo_route_order_and_battle_limits(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var ids: Array[String] = []
	var types: Array[String] = []
	var battle_max_rounds: Array[int] = []
	var battle_config_ids: Array[String] = []
	for node in run.route_nodes:
		ids.append(String(node.get("node_id", "")))
		types.append(String(node.get("node_type", "")))
		if run.is_battle_node(node):
			var battle: Dictionary = node.get("battle", {})
			battle_max_rounds.append(int(battle.get("max_rounds", 0)))
			battle_config_ids.append(String(battle.get("config_id", "")))
	tr.assert_eq("fixed route node ids", ids, [
		"outer_wall_01",
		"extinguished_beacon_02",
		"crack_courtyard_03",
		"iron_gate_04",
		"ember_camp_05",
		"boss_outer_bell_01",
	])
	tr.assert_eq("fixed route node types", types, [
		RunStateScript.NODE_NORMAL,
		RunStateScript.NODE_EVENT,
		RunStateScript.NODE_NORMAL,
		RunStateScript.NODE_ELITE,
		RunStateScript.NODE_CAMP,
		RunStateScript.NODE_BOSS,
	])
	tr.assert_eq("fixed route battle max rounds", battle_max_rounds, [5, 5, 5, 6])
	tr.assert_eq("fixed route battle config ids", battle_config_ids, [
		BattleConfigCatalogScript.CONFIG_OUTER_WALL,
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
		BattleConfigCatalogScript.CONFIG_IRON_GATE,
		BattleConfigCatalogScript.CONFIG_OUTER_BELL,
	])
	tr.assert_eq("event has placeholder options", run.route_nodes[1].get("event", {}).get("options", []).size(), 3)
	tr.assert_eq("camp has placeholder options", run.route_nodes[4].get("camp", {}).get("options", []).size(), 2)

static func _test_mark_current_node_visited_is_idempotent(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.mark_current_node_visited()
	tr.assert_eq("empty current node visit is no-op", run.visited_nodes.size(), 0)
	run.current_node_id = "outer_wall_01"
	run.mark_current_node_visited()
	tr.assert_eq("visited node recorded once", run.visited_nodes, ["outer_wall_01"])
	tr.assert_eq("route node visited flag set", run.route_nodes[0].get("visited", false), true)
	tr.assert_eq("chapter node index follows visited count", run.chapter_node_index, 1)
	tr.assert_eq("current node cleared after visit", run.current_node_id, "")
	tr.assert_eq("next unvisited advanced after visit", run.next_unvisited_node().get("node_id", ""), "extinguished_beacon_02")
	run.current_node_id = "outer_wall_01"
	run.mark_current_node_visited()
	tr.assert_eq("duplicate visit does not duplicate id", run.visited_nodes.size(), 1)

static func _test_guard_loss_from_destroyed_targets_is_capped(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.current_node_id = run.next_unvisited_node().get("node_id", "")
	run.apply_battle_resolution(_resolution(false, 5, 0))
	tr.assert_eq("destroyed protected targets cap sanctuary loss", run.sanctuary_integrity, 4)
	tr.assert_eq("resolution records capped sanctuary loss", run.last_resolution.get("sanctuary_loss", -1), 3)
	tr.assert_eq("resolution records sanctuary after", run.last_resolution.get("sanctuary_after", -1), 4)
	tr.assert_eq("capped loss does not fail healthy run", run.result_outcome, "")

static func _test_run_fails_when_sanctuary_reaches_zero(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.current_node_id = run.next_unvisited_node().get("node_id", "")
	run.sanctuary_integrity = 2
	run.pending_reward = {"reward_id": "stale"}
	run.apply_battle_resolution(_resolution(true, 0, 0))
	tr.assert_eq("line breach clamps sanctuary at zero", run.sanctuary_integrity, 0)
	tr.assert_eq("zero sanctuary sets defeat outcome", run.result_outcome, "defeat")
	tr.assert_eq("zero sanctuary enters run result phase", run.phase, RunStateScript.Phase.RUN_RESULT)
	tr.assert_eq("defeat clears stale pending reward", run.pending_reward.is_empty(), true)

static func _test_run_fails_when_all_wardens_are_dead(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.current_node_id = run.next_unvisited_node().get("node_id", "")
	run.pending_reward = {"reward_id": "stale"}
	run.apply_battle_resolution(_resolution(false, 0, 0, [0, 0, 0]))
	tr.assert_eq("all wardens dead count", run.alive_warden_count(), 0)
	tr.assert_eq("all wardens dead sets defeat outcome", run.result_outcome, "defeat")
	tr.assert_eq("all wardens dead enters result phase", run.phase, RunStateScript.Phase.RUN_RESULT)
	tr.assert_eq("all wardens dead clears pending reward", run.pending_reward.is_empty(), true)

static func _test_pending_reward_basic_structure(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var node := run.next_unvisited_node()
	var resolution := _resolution(false, 1, 2)
	var reward := run.build_pending_reward(node, resolution)
	tr.assert_eq("pending reward id uses source node", reward.get("reward_id", ""), "outer_wall_01-reward")
	tr.assert_eq("pending reward source node", reward.get("source_node_id", ""), "outer_wall_01")
	tr.assert_eq("pending reward source type", reward.get("source_type", ""), "battle")
	tr.assert_eq("pending reward phase", reward.get("reward_phase", ""), "choice")
	tr.assert_eq("pending reward fixed reward count", reward.get("fixed_rewards", []).size(), 2)
	tr.assert_eq("pending reward base embers", reward.get("fixed_rewards", [])[0].get("amount", 0), 7)
	tr.assert_eq("pending reward bonus embers", reward.get("fixed_rewards", [])[1].get("amount", 0), 4)
	tr.assert_eq("pending reward claim state generated", reward.get("claim_state", {}).get("generated", false), true)
	tr.assert_eq("pending reward has one choice group", reward.get("choice_groups", []).size(), 1)
	var group = reward.get("choice_groups", [])[0]
	tr.assert_eq("pending reward choose count", group.get("choose_count", 0), 1)
	tr.assert_eq("pending reward can skip", group.get("can_skip", false), true)
	tr.assert_eq("pending reward skip embers", group.get("skip_reward", {}).get("amount", 0), 3)
