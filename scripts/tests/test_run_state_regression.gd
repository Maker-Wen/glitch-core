extends RefCounted
## Focused RunState regressions for Demo Run shell integration.

const RunStateScript := preload("res://scripts/run/run_state.gd")
const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")

static func _resolution(line_breached: bool, destroyed: int, completed: int = 0, hps: Array = [2, 2, 2], protected_damage: int = -1) -> Dictionary:
	var damage := destroyed if protected_damage < 0 else protected_damage
	return {
		"outcome": BattleState.Outcome.DEFEAT if line_breached else BattleState.Outcome.VICTORY,
		"victory": not line_breached,
		"line_breached": line_breached,
		"destroyed_protected_count": destroyed,
		"protected_damage_taken": damage,
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
	_test_legacy_warden_snapshot_syncs_to_current_base_stats(tr)
	_test_run_state_public_methods_sync_legacy_stats(tr)
	_test_mark_current_node_visited_is_idempotent(tr)
	_test_commission_board_refills_after_each_completed_task(tr)
	_test_guard_loss_from_protected_damage_is_uncapped(tr)
	_test_run_fails_when_sanctuary_reaches_zero(tr)
	_test_run_fails_when_all_wardens_are_dead(tr)
	_test_pending_reward_basic_structure(tr)
	_test_random_route_is_seeded_and_valid(tr)

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
		"quartermaster_cache_02",
		"crack_courtyard_03",
		"pillar_graveyard_03",
		"ember_camp_03",
		"scout_ritual_03",
		"iron_gate_04",
		"ember_camp_05",
		"quartermaster_cache_05",
		"last_watch_event_05",
		"boss_outer_bell_01",
	])
	tr.assert_eq("fixed route node types", types, [
		RunStateScript.NODE_NORMAL,
		RunStateScript.NODE_EVENT,
		RunStateScript.NODE_SHOP,
		RunStateScript.NODE_NORMAL,
		RunStateScript.NODE_NORMAL,
		RunStateScript.NODE_CAMP,
		RunStateScript.NODE_EVENT,
		RunStateScript.NODE_ELITE,
		RunStateScript.NODE_CAMP,
		RunStateScript.NODE_SHOP,
		RunStateScript.NODE_EVENT,
		RunStateScript.NODE_BOSS,
	])
	tr.assert_eq("fixed route battle max rounds", battle_max_rounds, [5, 5, 5, 5, 6])
	tr.assert_eq("fixed route battle config ids", battle_config_ids, [
		BattleConfigCatalogScript.CONFIG_OUTER_WALL,
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
		BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD,
		BattleConfigCatalogScript.CONFIG_IRON_GATE,
		BattleConfigCatalogScript.CONFIG_OUTER_BELL,
	])
	tr.assert_eq("beacon event has options", run.node_by_id("extinguished_beacon_02").get("event", {}).get("options", []).size(), 3)
	tr.assert_eq("scout event has options", run.node_by_id("scout_ritual_03").get("event", {}).get("options", []).size(), 3)
	tr.assert_eq("last watch event has options", run.node_by_id("last_watch_event_05").get("event", {}).get("options", []).size(), 3)
	tr.assert_eq("early camp has options", run.node_by_id("ember_camp_03").get("camp", {}).get("options", []).size(), 2)
	tr.assert_eq("boss camp has options", run.node_by_id("ember_camp_05").get("camp", {}).get("options", []).size(), 2)
	tr.assert_eq("early shop has options", run.node_by_id("quartermaster_cache_02").get("shop", {}).get("options", []).size(), 3)
	tr.assert_eq("boss shop has options", run.node_by_id("quartermaster_cache_05").get("shop", {}).get("options", []).size(), 3)
	tr.assert_eq("initial commission board offers three tasks", _node_ids(run.available_route_nodes()), ["outer_wall_01", "extinguished_beacon_02", "quartermaster_cache_02"])

static func _test_legacy_warden_snapshot_syncs_to_current_base_stats(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.wardens[0]["hp"] = 2
	run.wardens[0]["hp_max"] = 2
	run.wardens[0]["move"] = 2
	run.wardens[1]["hp"] = 1
	run.wardens[1]["hp_max"] = 2
	run.wardens[1]["move"] = 2
	run.wardens[1]["upgrades"] = ["upgrade_graverobber_field_pack"]
	run.sync_warden_base_stats()
	tr.assert_eq("legacy full bountyhunter syncs to new max hp", run.wardens[0].hp_max, 3)
	tr.assert_eq("legacy full bountyhunter is topped to new max", run.wardens[0].hp, 3)
	tr.assert_eq("legacy bountyhunter keeps current move", run.wardens[0].move, 2)
	tr.assert_eq("legacy wounded graverobber keeps current hp", run.wardens[1].hp, 1)
	tr.assert_eq("legacy upgraded graverobber max hp follows base plus upgrade", run.wardens[1].hp_max, 3)
	tr.assert_eq("legacy graverobber syncs new move", run.wardens[1].move, 3)

static func _test_run_state_public_methods_sync_legacy_stats(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.wardens[0]["hp"] = 2
	run.wardens[0]["hp_max"] = 2
	run.wardens[1]["move"] = 2
	var node := run.next_unvisited_node()
	run.current_node_id = String(node.get("node_id", ""))
	run.apply_battle_resolution(_resolution(false, 0, 2, [2, 2, 2]))
	tr.assert_eq("battle resolution syncs legacy bountyhunter max hp", run.wardens[0].hp_max, 3)
	tr.assert_eq("battle resolution syncs legacy graverobber move", run.wardens[1].move, 3)
	run.pending_reward = run.build_pending_reward(node, run.last_resolution)
	run.claim_pending_reward("upgrade_bountyhunter_vanguard")
	tr.assert_eq("claim upgrade stacks on synced bountyhunter base hp", run.wardens[0].hp_max, 4)
	tr.assert_eq("claim upgrade heals from current battle hp", run.wardens[0].hp, 3)

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
	tr.assert_eq("commission board refills after first visit", _node_ids(run.available_route_nodes()), ["extinguished_beacon_02", "quartermaster_cache_02", "crack_courtyard_03"])
	run.current_node_id = "outer_wall_01"
	run.mark_current_node_visited()
	tr.assert_eq("duplicate visit does not duplicate id", run.visited_nodes.size(), 1)

static func _test_commission_board_refills_after_each_completed_task(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	tr.assert_eq("initial board has three visible commissions", _node_ids(run.available_route_nodes()), ["outer_wall_01", "extinguished_beacon_02", "quartermaster_cache_02"])
	run.current_node_id = "outer_wall_01"
	run.mark_current_node_visited()
	tr.assert_eq("first completion replaces one commission", _node_ids(run.available_route_nodes()), ["extinguished_beacon_02", "quartermaster_cache_02", "crack_courtyard_03"])
	run.current_node_id = "extinguished_beacon_02"
	run.mark_current_node_visited()
	tr.assert_eq("second completion refills from deeper pool", _node_ids(run.available_route_nodes()), ["quartermaster_cache_02", "crack_courtyard_03", "pillar_graveyard_03"])
	run.current_node_id = "quartermaster_cache_02"
	run.mark_current_node_visited()
	run.current_node_id = "crack_courtyard_03"
	run.mark_current_node_visited()
	run.current_node_id = "pillar_graveyard_03"
	run.mark_current_node_visited()
	tr.assert_eq("after five non-boss commissions boss unlocks alone", _node_ids(run.available_route_nodes()), ["boss_outer_bell_01"])

static func _test_guard_loss_from_protected_damage_is_uncapped(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.current_node_id = run.next_unvisited_node().get("node_id", "")
	run.apply_battle_resolution(_resolution(false, 2, 0, [2, 2, 2], 5))
	tr.assert_eq("protected damage spends sanctuary without cap", run.sanctuary_integrity, 7)
	tr.assert_eq("resolution records full sanctuary loss", run.last_resolution.get("sanctuary_loss", -1), 5)
	tr.assert_eq("resolution records sanctuary after", run.last_resolution.get("sanctuary_after", -1), 7)
	tr.assert_eq("full damage loss does not fail healthy run", run.result_outcome, "")

static func _test_run_fails_when_sanctuary_reaches_zero(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.current_node_id = run.next_unvisited_node().get("node_id", "")
	run.sanctuary_integrity = 2
	run.pending_reward = {"reward_id": "stale"}
	run.apply_battle_resolution(_resolution(true, 0, 0, [2, 2, 2], 2))
	tr.assert_eq("protected damage clamps sanctuary at zero", run.sanctuary_integrity, 0)
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


static func _test_random_route_is_seeded_and_valid(tr) -> void:
	var first = RunStateScript.new()
	first.setup_new_random_route(777)
	var second = RunStateScript.new()
	second.setup_new_random_route(777)
	tr.assert_eq("random route seed keeps node ids stable", _node_ids(first.route_nodes), _node_ids(second.route_nodes))
	tr.assert_eq("random route chapter name", first.chapter_name, "断墙外环")
	tr.assert_eq("random route has thirteen graph nodes", first.route_nodes.size(), 13)
	tr.assert_eq("random route initial commission board size", first.available_route_nodes().size(), 3)
	tr.assert_eq("random route starts with normal battle", first.available_route_nodes()[0].get("node_type", ""), RunStateScript.NODE_NORMAL)
	tr.assert_eq("random route boss layer availability after path", _complete_first_available_path(first), RunStateScript.NODE_BOSS)
	var layer_counts := _route_layer_counts(second.route_nodes)
	tr.assert_eq("random route layer 1 count", layer_counts.get(1, 0), 1)
	tr.assert_eq("random route layer 2 count", layer_counts.get(2, 0), 3)
	tr.assert_eq("random route layer 3 count", layer_counts.get(3, 0), 3)
	tr.assert_eq("random route layer 4 count", layer_counts.get(4, 0), 2)
	tr.assert_eq("random route layer 5 count", layer_counts.get(5, 0), 3)
	tr.assert_eq("random route layer 6 count", layer_counts.get(6, 0), 1)
	tr.assert_true("random route boss-prep layer has recovery or shop", _layer_has_type(second.route_nodes, 5, RunStateScript.NODE_CAMP) or _layer_has_type(second.route_nodes, 5, RunStateScript.NODE_SHOP))
	tr.assert_true("random route has at least one elite", _route_has_type(second.route_nodes, RunStateScript.NODE_ELITE))
	for node in second.route_nodes:
		if not second.is_battle_node(node):
			continue
		var config := BattleConfigCatalogScript.resolve_battle_config(String(node.get("node_id", "")), node.get("battle", {}))
		tr.assert_true("random battle node resolves config %s" % String(node.get("node_id", "")), not config.is_empty())

static func _node_ids(nodes: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for node in nodes:
		ids.append(String(node.get("node_id", "")))
	return ids

static func _route_layer_counts(nodes: Array[Dictionary]) -> Dictionary:
	var result := {}
	for node in nodes:
		var layer := int(node.get("layer", 0))
		result[layer] = int(result.get(layer, 0)) + 1
	return result

static func _route_has_type(nodes: Array[Dictionary], node_type: String) -> bool:
	for node in nodes:
		if String(node.get("node_type", "")) == node_type:
			return true
	return false

static func _layer_has_type(nodes: Array[Dictionary], layer: int, node_type: String) -> bool:
	for node in nodes:
		if int(node.get("layer", 0)) == layer and String(node.get("node_type", "")) == node_type:
			return true
	return false

static func _complete_first_available_path(run: RunStateScript) -> String:
	var last_type := ""
	var guard := 0
	while guard < 10:
		guard += 1
		var available: Array[Dictionary] = run.available_route_nodes()
		if available.is_empty():
			return last_type
		var node: Dictionary = available[0]
		last_type = String(node.get("node_type", ""))
		run.current_node_id = String(node.get("node_id", ""))
		run.mark_current_node_visited()
		if last_type == RunStateScript.NODE_BOSS:
			return last_type
	return last_type
