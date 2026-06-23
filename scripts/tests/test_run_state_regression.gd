extends RefCounted
## Focused RunState regressions for Demo Run shell integration.

const RunStateScript := preload("res://scripts/run/run_state.gd")
const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const RunExpeditionCatalogScript := preload("res://scripts/data/run_expedition_catalog.gd")

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
	_test_boss_replaces_board_after_unlock_count_from_any_non_boss_nodes(tr)
	_test_commission_refresh_replaces_single_card_from_draw_pile(tr)
	_test_commission_refresh_is_disabled_after_boss_unlock(tr)
	_test_boss_completion_leaves_no_commissions(tr)
	_test_guard_loss_from_protected_damage_is_uncapped(tr)
	_test_run_fails_when_sanctuary_reaches_zero(tr)
	_test_run_fails_when_all_wardens_are_dead(tr)
	_test_pending_reward_basic_structure(tr)
	_test_expedition_map_pools_are_explicit(tr)
	_test_commission_decks_follow_map_generation_rules(tr)
	_test_random_route_is_seeded_and_valid(tr)
	_test_random_route_map_pool_contracts(tr)
	_test_map_pool_candidate_filtering_prefers_valid_entries(tr)
	_test_battle_map_assignment_debug_report(tr)

static func _test_fixed_demo_route_order_and_battle_limits(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var normal_deck := _non_boss_nodes(run.route_nodes)
	var battle_max_rounds: Array[int] = []
	var battle_config_ids: Array[String] = []
	for node in run.route_nodes:
		if run.is_battle_node(node):
			var battle: Dictionary = node.get("battle", {})
			battle_max_rounds.append(int(battle.get("max_rounds", 0)))
			battle_config_ids.append(String(battle.get("config_id", "")))
	tr.assert_eq("demo commission deck has configured normal card count", normal_deck.size(), 16)
	tr.assert_eq("demo route includes boss outside normal deck", run.route_nodes.size(), 17)
	tr.assert_eq("demo commission deck ids mirror normal card count", run.commission_deck_ids.size(), 16)
	tr.assert_eq("demo hand size is map configured", run.commission_hand_size, 3)
	tr.assert_eq("demo boss unlock count is map configured", run.boss_unlock_count, 8)
	tr.assert_eq("demo refresh charges are map configured", run.refresh_charges, 2)
	tr.assert_eq("demo type counts follow map config", _node_type_counts(normal_deck), {
		RunStateScript.NODE_NORMAL: 7,
		RunStateScript.NODE_EVENT: 3,
		RunStateScript.NODE_SHOP: 2,
		RunStateScript.NODE_ELITE: 3,
		RunStateScript.NODE_CAMP: 1,
	})
	tr.assert_true("configured route battle max rounds are valid", battle_max_rounds.size() >= 5 and battle_max_rounds.max() <= 6)
	tr.assert_true("configured route battle includes intro config", BattleConfigCatalogScript.CONFIG_OUTER_WALL in battle_config_ids)
	tr.assert_true("configured route battle includes boss config", BattleConfigCatalogScript.CONFIG_OUTER_BELL in battle_config_ids)
	tr.assert_eq("beacon event has options", run.node_by_id("extinguished_beacon_02").get("event", {}).get("options", []).size(), 3)
	tr.assert_true("deck has at least one event with options", _deck_has_interaction_options(run.route_nodes, RunStateScript.NODE_EVENT, "event"))
	tr.assert_true("deck has at least one camp with options", _deck_has_interaction_options(run.route_nodes, RunStateScript.NODE_CAMP, "camp"))
	tr.assert_eq("early shop has options", run.node_by_id("quartermaster_cache_02").get("shop", {}).get("options", []).size(), 3)
	tr.assert_true("deck has at least one shop with options", _deck_has_interaction_options(run.route_nodes, RunStateScript.NODE_SHOP, "shop"))
	tr.assert_eq("initial commission board offers three tasks", _node_ids(run.available_commissions()), ["outer_wall_01", "extinguished_beacon_02", "quartermaster_cache_02"])
	tr.assert_eq("legacy route availability mirrors commission board", _node_ids(run.available_route_nodes()), _node_ids(run.available_commissions()))
	tr.assert_eq("current commission mirrors legacy next node", run.current_commission().get("node_id", ""), run.next_unvisited_node().get("node_id", ""))
	tr.assert_eq("commission availability replaces route-node availability", run.is_commission_available("outer_wall_01"), run.is_route_node_available("outer_wall_01"))

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
	run.claim_pending_reward("")
	tr.assert_eq("fixed reward claim keeps synced bountyhunter max hp", run.wardens[0].hp_max, 3)
	tr.assert_eq("fixed reward claim keeps current battle hp", run.wardens[0].hp, 2)

static func _test_mark_current_node_visited_is_idempotent(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.mark_current_node_visited()
	tr.assert_eq("empty current node visit is no-op", run.visited_nodes.size(), 0)
	run.current_node_id = "outer_wall_01"
	run.mark_current_node_visited()
	tr.assert_eq("visited node recorded once", run.visited_nodes, ["outer_wall_01"])
	tr.assert_eq("commission candidate visited flag set", run.route_nodes[0].get("visited", false), true)
	tr.assert_eq("chapter node index follows visited count", run.chapter_node_index, 1)
	tr.assert_eq("current node cleared after visit", run.current_node_id, "")
	tr.assert_eq("current commission advances after visit", run.current_commission().get("node_id", ""), "extinguished_beacon_02")
	tr.assert_eq("commission board refills after first visit", _node_ids(run.available_commissions()), ["extinguished_beacon_02", "quartermaster_cache_02", "crack_courtyard_03"])
	run.current_node_id = "outer_wall_01"
	run.mark_current_node_visited()
	tr.assert_eq("duplicate visit does not duplicate id", run.visited_nodes.size(), 1)

static func _test_commission_board_refills_after_each_completed_task(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	tr.assert_eq("initial board has three visible commissions", _node_ids(run.available_commissions()), ["outer_wall_01", "extinguished_beacon_02", "quartermaster_cache_02"])
	run.current_node_id = "outer_wall_01"
	run.mark_current_node_visited()
	tr.assert_eq("first completion replaces one commission", _node_ids(run.available_commissions()), ["extinguished_beacon_02", "quartermaster_cache_02", "crack_courtyard_03"])
	run.current_node_id = "extinguished_beacon_02"
	run.mark_current_node_visited()
	tr.assert_eq("second completion refills from draw pile", _node_ids(run.available_commissions()), ["quartermaster_cache_02", "crack_courtyard_03", "pillar_graveyard_03"])
	_complete_until_boss_unlock(run)
	tr.assert_eq("after configured non-boss commissions boss unlocks alone", _node_ids(run.available_commissions()), ["boss_outer_bell_01"])

	var out_of_order_run = RunStateScript.new()
	out_of_order_run.setup_new_demo()
	out_of_order_run.current_node_id = "outer_wall_01"
	out_of_order_run.mark_current_node_visited()
	out_of_order_run.current_node_id = "crack_courtyard_03"
	out_of_order_run.mark_current_node_visited()
	tr.assert_eq("out-of-order completion keeps three commission cards", out_of_order_run.available_commissions().size(), 3)

static func _test_boss_replaces_board_after_unlock_count_from_any_non_boss_nodes(tr) -> void:
	var event_run = _run_one_short_of_boss_unlock()
	var event_id := _first_unvisited_id_of_type(event_run, RunStateScript.NODE_EVENT)
	event_run.current_node_id = event_id
	event_run.resolve_event_node(String(event_run.node_by_id(event_id).get("event", {}).get("options", [])[0].get("option_id", "")))
	tr.assert_eq("event as unlock-count commission unlocks boss only", _node_ids(event_run.available_commissions()), ["boss_outer_bell_01"])

	var camp_run = _run_one_short_of_boss_unlock()
	var camp_id := _first_unvisited_id_of_type(camp_run, RunStateScript.NODE_CAMP)
	camp_run.current_node_id = camp_id
	camp_run.resolve_camp_node(String(camp_run.node_by_id(camp_id).get("camp", {}).get("options", [])[0].get("option_id", "")))
	tr.assert_eq("camp as unlock-count commission unlocks boss only", _node_ids(camp_run.available_commissions()), ["boss_outer_bell_01"])

	var shop_run = _run_one_short_of_boss_unlock()
	shop_run.embers = 10
	var shop_id := _first_unvisited_id_of_type(shop_run, RunStateScript.NODE_SHOP)
	shop_run.current_node_id = shop_id
	shop_run.resolve_shop_node(String(shop_run.node_by_id(shop_id).get("shop", {}).get("options", [])[0].get("option_id", "")))
	tr.assert_eq("shop as unlock-count commission unlocks boss only", _node_ids(shop_run.available_commissions()), ["boss_outer_bell_01"])

static func _test_commission_refresh_replaces_single_card_from_draw_pile(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_random_route(777, RunStateScript.EXPEDITION_BROKEN_WALL)
	var before := _node_ids(run.available_commissions())
	var old_draw: Array[String] = run.commission_draw_pile_ids.duplicate()
	tr.assert_true("first slot can refresh with configured charges", run.can_refresh_commission(0))
	tr.assert_true("refresh succeeds", run.refresh_commission(0))
	var after := _node_ids(run.available_commissions())
	tr.assert_eq("refresh keeps three visible cards", after.size(), 3)
	tr.assert_eq("refresh preserves other slots", after.slice(1), before.slice(1))
	tr.assert_eq("refresh consumes one charge", run.refresh_charges, run.refresh_charges_max - 1)
	tr.assert_eq("refreshed card goes to discard", run.discarded_commission_ids, [before[0]])
	tr.assert_eq("replacement comes from previous draw pile head", after[0], old_draw[0])
	run.refresh_commission(0)
	tr.assert_eq("second refresh consumes final charge", run.refresh_charges, 0)
	tr.assert_true("refresh disabled at zero charges", not run.can_refresh_commission(0))

static func _test_commission_refresh_is_disabled_after_boss_unlock(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	_complete_until_boss_unlock(run)
	tr.assert_eq("boss unlock replaces normal board", _node_ids(run.available_commissions()), ["boss_outer_bell_01"])
	tr.assert_true("refresh disabled once boss is visible", not run.can_refresh_commission(0))
	var charges_before: int = run.refresh_charges
	tr.assert_true("boss card refresh fails", not run.refresh_commission(0))
	tr.assert_eq("failed boss refresh does not spend charges", run.refresh_charges, charges_before)

static func _test_boss_completion_leaves_no_commissions(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	for node_id in ["outer_wall_01", "extinguished_beacon_02", "quartermaster_cache_02", "crack_courtyard_03", "pillar_graveyard_03"]:
		run.current_node_id = node_id
		run.mark_current_node_visited()
	_complete_until_boss_unlock(run)
	tr.assert_eq("boss is only available after unlock", _node_ids(run.available_commissions()), ["boss_outer_bell_01"])
	run.current_node_id = "boss_outer_bell_01"
	run.mark_current_node_visited()
	tr.assert_eq("boss completion leaves board empty", _node_ids(run.available_commissions()), [])

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
	tr.assert_eq("pending reward phase", reward.get("reward_phase", ""), "fixed")
	tr.assert_eq("pending reward fixed reward count", reward.get("fixed_rewards", []).size(), 2)
	tr.assert_eq("pending reward base embers", reward.get("fixed_rewards", [])[0].get("amount", 0), 7)
	tr.assert_eq("pending reward bonus embers", reward.get("fixed_rewards", [])[1].get("amount", 0), 4)
	tr.assert_eq("pending reward claim state generated", reward.get("claim_state", {}).get("generated", false), true)
	tr.assert_eq("pending reward has no choice groups", reward.get("choice_groups", []).size(), 0)


static func _test_expedition_map_pools_are_explicit(tr) -> void:
	var run = RunStateScript.new()
	var broken_normal := run.expedition_map_pool_config_ids(RunStateScript.EXPEDITION_BROKEN_WALL, RunStateScript.MAP_POOL_NORMAL)
	var rift_normal := run.expedition_map_pool_config_ids(RunStateScript.EXPEDITION_RIFT_CORRIDOR, RunStateScript.MAP_POOL_NORMAL)
	var supply_normal := run.expedition_map_pool_config_ids(RunStateScript.EXPEDITION_SUPPLY_LINE, RunStateScript.MAP_POOL_NORMAL)
	tr.assert_true("broken wall normal pool includes rift courtyard", BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD in broken_normal)
	tr.assert_true("broken wall normal pool includes bridge candidate", BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE in broken_normal)
	tr.assert_true("rift corridor normal pool includes bridge candidate", BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE in rift_normal)
	tr.assert_true("supply line normal pool excludes bridge candidate", not (BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE in supply_normal))
	tr.assert_eq("broken wall start pool is fixed intro", run.expedition_map_pool_config_ids(RunStateScript.EXPEDITION_BROKEN_WALL, RunStateScript.MAP_POOL_START), [BattleConfigCatalogScript.CONFIG_OUTER_WALL])
	tr.assert_eq("broken wall elite pool is fixed elite", run.expedition_map_pool_config_ids(RunStateScript.EXPEDITION_BROKEN_WALL, RunStateScript.MAP_POOL_ELITE), [BattleConfigCatalogScript.CONFIG_IRON_GATE])
	tr.assert_eq("broken wall boss pool is fixed boss", run.expedition_map_pool_config_ids(RunStateScript.EXPEDITION_BROKEN_WALL, RunStateScript.MAP_POOL_BOSS), [BattleConfigCatalogScript.CONFIG_OUTER_BELL])

static func _test_commission_decks_follow_map_generation_rules(tr) -> void:
	for expedition_id in RunExpeditionCatalogScript.expedition_ids():
		var config := RunExpeditionCatalogScript.commission_deck_config(expedition_id)
		var seen_signatures := {}
		for seed in [1, 7, 19, 777]:
			var run = RunStateScript.new()
			run.setup_new_random_route(seed, expedition_id)
			var normal_deck := _non_boss_nodes(run.route_nodes)
			var type_sequence := _node_types(normal_deck)
			var deck_size := int(config.get("deck_size", 0))
			var hand_size := int(config.get("hand_size", 0))
			var boss_unlock_count := int(config.get("boss_unlock_count", 0))
			var refresh_count := int(config.get("initial_refresh_charges", 0))
			tr.assert_eq("%s seed %d deck size" % [expedition_id, seed], normal_deck.size(), deck_size)
			tr.assert_eq("%s seed %d boss outside deck" % [expedition_id, seed], run.route_nodes.size(), deck_size + 1)
			tr.assert_eq("%s seed %d hand size" % [expedition_id, seed], run.commission_hand_size, hand_size)
			tr.assert_eq("%s seed %d initial board size" % [expedition_id, seed], run.available_commissions().size(), hand_size)
			tr.assert_eq("%s seed %d boss unlock" % [expedition_id, seed], run.commission_goal_count(), boss_unlock_count)
			tr.assert_eq("%s seed %d refresh max" % [expedition_id, seed], run.refresh_charges_max, refresh_count)
			tr.assert_eq("%s seed %d type counts" % [expedition_id, seed], _node_type_counts(normal_deck), config.get("type_counts", {}))
			tr.assert_eq("%s seed %d opening types" % [expedition_id, seed], type_sequence.slice(0, 3), [RunStateScript.NODE_NORMAL, RunStateScript.NODE_EVENT, RunStateScript.NODE_SHOP])
			tr.assert_eq("%s seed %d fourth card is normal" % [expedition_id, seed], type_sequence[3], RunStateScript.NODE_NORMAL)
			tr.assert_true("%s seed %d no early elite" % [expedition_id, seed], not (RunStateScript.NODE_ELITE in type_sequence.slice(0, 5)))
			tr.assert_true("%s seed %d max two non-combat in a row: %s" % [expedition_id, seed, " > ".join(type_sequence)], _max_consecutive_non_combat(type_sequence) <= int(config.get("max_consecutive_non_combat", 2)))
			tr.assert_eq("%s seed %d boss not in deck ids" % [expedition_id, seed], RunStateScript.NODE_BOSS in type_sequence, false)
			seen_signatures["|".join(_node_ids(normal_deck))] = true
		tr.assert_true("%s deck generation changes across seeds" % expedition_id, seen_signatures.size() > 1)


static func _test_random_route_is_seeded_and_valid(tr) -> void:
	var first = RunStateScript.new()
	first.setup_new_random_route(777)
	var second = RunStateScript.new()
	second.setup_new_random_route(777)
	tr.assert_eq("random route seed keeps node ids stable", _node_ids(first.route_nodes), _node_ids(second.route_nodes))
	tr.assert_eq("random route chapter name", first.chapter_name, "断墙外环")
	var broken_deck_config := RunExpeditionCatalogScript.commission_deck_config(first.expedition_id)
	tr.assert_eq("random route follows expedition deck size plus boss", first.route_nodes.size(), int(broken_deck_config.get("deck_size", 0)) + 1)
	tr.assert_eq("random route initial commission board size", first.available_commissions().size(), 3)
	tr.assert_eq("random route starts with normal battle", first.available_commissions()[0].get("node_type", ""), RunStateScript.NODE_NORMAL)
	tr.assert_eq("random route boss layer availability after path", _complete_first_available_path(first), RunStateScript.NODE_BOSS)
	var layer_counts := _route_layer_counts(second.route_nodes)
	tr.assert_eq("random route layer 1 count", layer_counts.get(1, 0), 1)
	tr.assert_true("random route has early layer", int(layer_counts.get(2, 0)) > 0)
	tr.assert_true("random route has middle layer", int(layer_counts.get(3, 0)) > 0)
	tr.assert_true("random route has combat pressure layer", int(layer_counts.get(4, 0)) > 0)
	tr.assert_true("random route has boss prep layer", int(layer_counts.get(5, 0)) > 0)
	tr.assert_eq("random route layer 6 count", layer_counts.get(6, 0), 1)
	tr.assert_eq("random route commission goal follows expedition config", second.commission_goal_count(), int(broken_deck_config.get("boss_unlock_count", 0)))
	tr.assert_eq("random route refresh charges follow expedition config", second.refresh_charges_max, int(broken_deck_config.get("initial_refresh_charges", 0)))
	tr.assert_true("random route boss-prep layer has recovery or shop", _layer_has_type(second.route_nodes, 5, RunStateScript.NODE_CAMP) or _layer_has_type(second.route_nodes, 5, RunStateScript.NODE_SHOP))
	tr.assert_true("random route has at least one elite", _route_has_type(second.route_nodes, RunStateScript.NODE_ELITE))
	for node in second.route_nodes:
		if not second.is_battle_node(node):
			continue
		var battle: Dictionary = node.get("battle", {})
		var pool_key := String(battle.get("map_pool_key", ""))
		var allowed_config_ids := second.expedition_map_pool_config_ids(second.expedition_id, pool_key)
		tr.assert_true("random battle node has map pool key %s" % String(node.get("node_id", "")), not pool_key.is_empty())
		tr.assert_true("random battle node uses map from pool %s" % String(node.get("node_id", "")), String(battle.get("config_id", "")) in allowed_config_ids)
		var config := BattleConfigCatalogScript.resolve_battle_config(String(node.get("node_id", "")), node.get("battle", {}))
		tr.assert_true("random battle node resolves config %s" % String(node.get("node_id", "")), not config.is_empty())
		tr.assert_eq("random battle map id mirrors catalog %s" % String(node.get("node_id", "")), battle.get("map_id", ""), config.get("map_id", ""))
		tr.assert_eq("random battle rounds mirror catalog %s" % String(node.get("node_id", "")), int(battle.get("max_rounds", 0)), int(config.get("max_rounds", 0)))
	var supply = RunStateScript.new()
	supply.setup_new_random_route(777, RunStateScript.EXPEDITION_SUPPLY_LINE)
	tr.assert_eq("supply random route chapter name", supply.chapter_name, "废弃军需线")
	for node in supply.route_nodes:
		if not supply.is_battle_node(node):
			continue
		var battle: Dictionary = node.get("battle", {})
		var pool_key := String(battle.get("map_pool_key", ""))
		var allowed_config_ids := supply.expedition_map_pool_config_ids(supply.expedition_id, pool_key)
		tr.assert_true("supply battle node uses supply map pool %s" % String(node.get("node_id", "")), String(battle.get("config_id", "")) in allowed_config_ids)

static func _test_random_route_map_pool_contracts(tr) -> void:
	for expedition_id in [
		RunStateScript.EXPEDITION_BROKEN_WALL,
		RunStateScript.EXPEDITION_RIFT_CORRIDOR,
		RunStateScript.EXPEDITION_SUPPLY_LINE,
	]:
		for seed in [1, 7, 19]:
			var run = RunStateScript.new()
			run.setup_new_random_route(seed, expedition_id)
			var used_normal_groups := {}
			var contract_errors: Array[String] = []
			for node in run.route_nodes:
				if not run.is_battle_node(node):
					continue
				var battle: Dictionary = node.get("battle", {})
				var node_id := String(node.get("node_id", ""))
				var pool_key := String(battle.get("map_pool_key", ""))
				var config_id := String(battle.get("config_id", ""))
				var layer := int(node.get("layer", 0))
				var range := _expected_map_layer_range(config_id)
				if pool_key != _expected_map_pool_key(node):
					contract_errors.append("%s pool key %s" % [node_id, pool_key])
				if layer < range.x or layer > range.y:
					contract_errors.append("%s layer %d outside %s-%s" % [node_id, layer, range.x, range.y])
				if int(battle.get("map_pressure_cost", 99)) > _map_pressure_budget(pool_key):
					contract_errors.append("%s pressure %d" % [node_id, int(battle.get("map_pressure_cost", 99))])
				if String(battle.get("map_archetype", "")).is_empty():
					contract_errors.append("%s missing archetype" % node_id)
				if String(battle.get("map_enemy_family_hint", "")).is_empty():
					contract_errors.append("%s missing enemy hint" % node_id)
				if int(battle.get("map_pressure_cost", -1)) != node.get("pressure_tags", []).size():
					contract_errors.append("%s pressure does not mirror tags" % node_id)
				if pool_key != RunStateScript.MAP_POOL_NORMAL:
					continue
				var repeat_group := String(battle.get("map_no_repeat_group", ""))
				if not used_normal_groups.has(repeat_group):
					used_normal_groups[repeat_group] = true
				elif String(battle.get("map_assignment_relaxed", "")) == "repeat":
					contract_errors.append("%s normal pool repeat used relaxed fallback" % node_id)
				used_normal_groups[repeat_group] = true
			tr.assert_true("random route map pool contracts %s seed %d: %s" % [expedition_id, seed, ", ".join(contract_errors)], contract_errors.is_empty())

static func _test_map_pool_candidate_filtering_prefers_valid_entries(tr) -> void:
	var run = RunStateScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var node := {"node_type": RunStateScript.NODE_NORMAL, "layer": 3}
	var used_repeat_groups := {"used": true}
	var candidates := [
		{
			"config_id": BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
			"weight": 100,
			"allowed_node_types": [RunStateScript.NODE_NORMAL],
			"min_layer": 3,
			"max_layer": 3,
			"pressure_cost": 3,
			"no_repeat_group": "used",
		},
		{
			"config_id": BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD,
			"weight": 1,
			"allowed_node_types": [RunStateScript.NODE_NORMAL],
			"min_layer": 3,
			"max_layer": 3,
			"pressure_cost": 3,
			"no_repeat_group": "fresh",
		},
	]
	var strict_pick: Dictionary = run._pick_map_pool_entry_for_node(candidates, node, RunStateScript.MAP_POOL_NORMAL, {"pressure_budget": {RunStateScript.MAP_POOL_NORMAL: 3}}, used_repeat_groups, rng)
	tr.assert_eq("map pool prefers unused repeat group", strict_pick.get("config_id", ""), BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD)
	tr.assert_eq("unused repeat group pick is strict", strict_pick.get("map_assignment_relaxed", ""), "")
	used_repeat_groups["fresh"] = true
	var repeat_pick: Dictionary = run._pick_map_pool_entry_for_node(candidates, node, RunStateScript.MAP_POOL_NORMAL, {"pressure_budget": {RunStateScript.MAP_POOL_NORMAL: 3}}, used_repeat_groups, rng)
	tr.assert_eq("exhausted repeat groups start a new strict cycle", repeat_pick.get("map_assignment_relaxed", ""), "")
	tr.assert_true("repeat cycle reset clears previous groups", used_repeat_groups.size() == 0)
	var pressure_pick: Dictionary = run._pick_map_pool_entry_for_node([
		{
			"config_id": BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD,
			"weight": 1,
			"allowed_node_types": [RunStateScript.NODE_NORMAL],
			"min_layer": 3,
			"max_layer": 3,
			"pressure_cost": 4,
			"no_repeat_group": "over_budget",
		},
	], node, RunStateScript.MAP_POOL_NORMAL, {"pressure_budget": {RunStateScript.MAP_POOL_NORMAL: 3}}, {}, rng)
	tr.assert_eq("over-budget fallback is marked", pressure_pick.get("map_assignment_relaxed", ""), "pressure")

static func _test_battle_map_assignment_debug_report(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_random_route(7, RunStateScript.EXPEDITION_RIFT_CORRIDOR)
	var rows := run.battle_map_assignment_debug_rows()
	tr.assert_true("debug report has battle map rows", rows.size() > 0)
	tr.assert_eq("debug report row count mirrors battle nodes", rows.size(), _battle_node_count(run.route_nodes, run))
	var row_errors: Array[String] = []
	for row in rows:
		if int(row.get("run_seed", 0)) != 7:
			row_errors.append("seed")
		if String(row.get("expedition_id", "")) != RunStateScript.EXPEDITION_RIFT_CORRIDOR:
			row_errors.append("expedition")
		for field in ["node_id", "pool_key", "config_id", "archetype", "repeat_group"]:
			if String(row.get(field, "")).is_empty():
				row_errors.append("%s missing %s" % [String(row.get("node_id", "<missing>")), field])
	tr.assert_true("debug rows carry required fields: %s" % ", ".join(row_errors), row_errors.is_empty())
	var text := run.battle_map_assignment_debug_text()
	tr.assert_true("debug text carries seed", text.contains("seed=7"))
	tr.assert_true("debug text carries expedition", text.contains("expedition=rift_corridor"))
	tr.assert_true("debug text carries pool", text.contains("pool="))
	tr.assert_true("debug text carries config", text.contains("config="))

static func _node_ids(nodes: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for node in nodes:
		ids.append(String(node.get("node_id", "")))
	return ids

static func _node_types(nodes: Array[Dictionary]) -> Array[String]:
	var types: Array[String] = []
	for node in nodes:
		types.append(String(node.get("node_type", "")))
	return types

static func _non_boss_nodes(nodes: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in nodes:
		if String(node.get("node_type", "")) != RunStateScript.NODE_BOSS:
			result.append(node)
	return result

static func _node_type_counts(nodes: Array[Dictionary]) -> Dictionary:
	var result := {}
	for node in nodes:
		var node_type := String(node.get("node_type", ""))
		result[node_type] = int(result.get(node_type, 0)) + 1
	return result

static func _deck_has_interaction_options(nodes: Array[Dictionary], node_type: String, group_key: String) -> bool:
	for node in nodes:
		if String(node.get("node_type", "")) != node_type:
			continue
		if not node.get(group_key, {}).get("options", []).is_empty():
			return true
	return false

static func _complete_until_boss_unlock(run: RunStateScript) -> void:
	_complete_until_count(run, run.commission_goal_count())

static func _run_one_short_of_boss_unlock() -> RunStateScript:
	var run = RunStateScript.new()
	run.setup_new_demo()
	_complete_until_count(run, run.commission_goal_count() - 1, {
		RunStateScript.NODE_EVENT: true,
		RunStateScript.NODE_CAMP: true,
		RunStateScript.NODE_SHOP: true,
	})
	return run

static func _complete_until_count(run: RunStateScript, target_count: int, excluded_types: Dictionary = {}) -> void:
	var guard := 0
	while run.completed_commission_count() < target_count and guard < 64:
		guard += 1
		var selected := _first_unvisited_id_excluding_types(run, excluded_types)
		if selected.is_empty():
			selected = _first_unvisited_non_boss_id(run)
		if selected.is_empty():
			return
		run.current_node_id = selected
		run.mark_current_node_visited()

static func _first_unvisited_id_excluding_types(run: RunStateScript, excluded_types: Dictionary) -> String:
	for node in run.route_nodes:
		var node_id := String(node.get("node_id", ""))
		var node_type := String(node.get("node_type", ""))
		if node_id.is_empty() or bool(node.get("visited", false)) or node_type == RunStateScript.NODE_BOSS:
			continue
		if excluded_types.has(node_type):
			continue
		return node_id
	return ""

static func _first_unvisited_non_boss_id(run: RunStateScript) -> String:
	for node in run.route_nodes:
		var node_id := String(node.get("node_id", ""))
		if node_id.is_empty() or bool(node.get("visited", false)) or String(node.get("node_type", "")) == RunStateScript.NODE_BOSS:
			continue
		return node_id
	return ""

static func _first_unvisited_id_of_type(run: RunStateScript, node_type: String) -> String:
	for node in run.route_nodes:
		if bool(node.get("visited", false)):
			continue
		if String(node.get("node_type", "")) == node_type:
			return String(node.get("node_id", ""))
	return ""

static func _battle_node_count(nodes: Array[Dictionary], run: RunStateScript) -> int:
	var result := 0
	for node in nodes:
		if run.is_battle_node(node):
			result += 1
	return result

static func _expected_map_pool_key(node: Dictionary) -> String:
	var node_type := String(node.get("node_type", ""))
	match node_type:
		RunStateScript.NODE_BOSS:
			return RunStateScript.MAP_POOL_BOSS
		RunStateScript.NODE_ELITE:
			return RunStateScript.MAP_POOL_ELITE
	if int(node.get("layer", 0)) <= 1:
		return RunStateScript.MAP_POOL_START
	return RunStateScript.MAP_POOL_NORMAL

static func _expected_map_layer_range(config_id: String) -> Vector2i:
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

static func _map_pressure_budget(pool_key: String) -> int:
	match pool_key:
		RunStateScript.MAP_POOL_START:
			return 2
		RunStateScript.MAP_POOL_NORMAL:
			return 3
		RunStateScript.MAP_POOL_ELITE:
			return 3
		RunStateScript.MAP_POOL_BOSS:
			return 3
	return 99

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

static func _max_consecutive_non_combat(type_sequence: Array[String]) -> int:
	var best := 0
	var current := 0
	for node_type in type_sequence:
		if node_type == RunStateScript.NODE_NORMAL or node_type == RunStateScript.NODE_ELITE:
			current = 0
		else:
			current += 1
			best = maxi(best, current)
	return best

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
