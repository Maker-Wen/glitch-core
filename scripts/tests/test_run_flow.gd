extends RefCounted
## Regression coverage for the fixed demo Run state and Run-to-battle HP handoff.

const RunStateScript := preload("res://scripts/run/run_state.gd")

static func _make_bh() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"warden_bountyhunter"
	d.display_name = "BH"
	d.faction = UnitDef.Faction.WARDEN
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.MELEE_PUSH
	d.attack_range = 1
	d.attack_damage = 1
	d.attack_force = 1
	return d

static func _summary(victory: bool, destroyed: int, completed: int, warden_hp: int = 2, protected_damage: int = -1) -> Dictionary:
	var damage := destroyed if protected_damage < 0 else protected_damage
	return {
		"outcome": BattleState.Outcome.VICTORY if victory else BattleState.Outcome.DEFEAT,
		"victory": victory,
		"line_breached": not victory,
		"destroyed_protected_count": destroyed,
		"protected_damage_taken": damage,
		"completed_reward_count": completed,
		"reward_tasks": [],
		"reward_completed": {},
		"reward_failed": {},
		"wardens": [
			{"def_id": "warden_bountyhunter", "name": "BH", "hp": warden_hp, "hp_max": 2, "alive": warden_hp > 0},
			{"def_id": "warden_graverobber", "name": "GR", "hp": 2, "hp_max": 2, "alive": true},
			{"def_id": "warden_mage", "name": "MG", "hp": 2, "hp_max": 2, "alive": true},
		],
		"round": 4,
		"max_rounds": 4,
	}

static func _boss_summary(heart_hits: int, completed: int = 3) -> Dictionary:
	var summary := _summary(true, 0, completed, 2)
	summary["boss_config_id"] = "knell_lord_demo_01"
	summary["boss_doom_count"] = 1
	summary["boss_doom_count_max"] = 3
	summary["boss_breached"] = false
	summary["boss_anchor_destroyed_count"] = 2
	summary["boss_anchor_count"] = 2
	summary["boss_heart_hits"] = heart_hits
	summary["round"] = 6
	summary["max_rounds"] = 6
	return summary

static func run(tr) -> void:
	_test_demo_route_shape(tr)
	_test_initial_warden_stats_follow_unit_defs(tr)
	_test_event_node_marks_visited_and_updates_resources(tr)
	_test_camp_node_marks_visited_and_heals_or_repairs(tr)
	_test_shop_requires_enough_embers_and_marks_visited(tr)
	_test_battle_victory_builds_pending_reward(tr)
	_test_reward_claim_marks_node_and_persists_warden_hp(tr)
	_test_pending_reward_claims_only_once(tr)
	_test_invalid_reward_choice_does_not_claim(tr)
	_test_elite_reward_uses_demo_relic_options(tr)
	_test_three_tasks_offer_guardian_recovery(tr)
	_test_full_sanctuary_recovery_conversion_uses_chapter_slot(tr)
	_test_dead_warden_has_no_upgrade_option(tr)
	_test_protected_damage_spends_sanctuary_without_immediate_defeat(tr)
	_test_boss_reward_can_finish_route(tr)
	_test_boss_heart_hits_add_visible_reward_bonus(tr)
	_test_boss_heart_hits_clamp_at_cap(tr)
	_test_boss_heart_bonus_is_not_repaid_after_claim(tr)
	_test_non_boss_ignores_boss_heart_hits(tr)
	_test_battle_engine_accepts_run_level_warden_hp(tr)
	_test_battle_scene_builds_runtime_warden_max_hp_def(tr)

static func _test_demo_route_shape(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	tr.assert_eq("demo route has twelve graph nodes", run.route_nodes.size(), 12)
	var expected_types := [
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
	]
	var expected_ids := [
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
	]
	for i in range(expected_types.size()):
		tr.assert_eq("demo route type %d" % (i + 1), run.route_nodes[i].node_type, expected_types[i])
		tr.assert_eq("demo route id %d" % (i + 1), run.route_nodes[i].node_id, expected_ids[i])
	tr.assert_eq("initial commission board", _node_ids(run.available_route_nodes()), ["outer_wall_01", "extinguished_beacon_02", "quartermaster_cache_02"])
	tr.assert_eq("initial sanctuary", run.sanctuary_integrity, 12)
	tr.assert_eq("initial alive wardens", run.alive_warden_count(), 3)

static func _test_initial_warden_stats_follow_unit_defs(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	tr.assert_eq("initial bountyhunter hp follows unit def", run.wardens[0].hp, 3)
	tr.assert_eq("initial bountyhunter max hp follows unit def", run.wardens[0].hp_max, 3)
	tr.assert_eq("initial bountyhunter move follows unit def", run.wardens[0].move, 2)
	tr.assert_eq("initial graverobber hp follows unit def", run.wardens[1].hp, 2)
	tr.assert_eq("initial graverobber move follows unit def", run.wardens[1].move, 3)
	tr.assert_eq("initial mage hp follows unit def", run.wardens[2].hp, 2)
	tr.assert_eq("initial mage move follows unit def", run.wardens[2].move, 2)
	var random_run = RunStateScript.new()
	random_run.setup_new_random_route(777)
	tr.assert_eq("random run bountyhunter max hp follows unit def", random_run.wardens[0].hp_max, 3)
	tr.assert_eq("random run graverobber move follows unit def", random_run.wardens[1].move, 3)

static func _test_event_node_marks_visited_and_updates_resources(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.sanctuary_integrity = 5
	run.current_node_id = "extinguished_beacon_02"
	run.resolve_event_node("rekindle_beacon")
	tr.assert_eq("event repairs sanctuary", run.sanctuary_integrity, 6)
	tr.assert_eq("event grants fixed embers", run.embers, 2)
	tr.assert_eq("event node visited", run.visited_nodes[0], "extinguished_beacon_02")
	tr.assert_eq("event clears current node", run.current_node_id, "")
	tr.assert_true("event leaves no pending reward", run.pending_reward.is_empty())
	tr.assert_eq("event records node resolution", run.last_resolution.outcome, "event_resolved")

static func _test_camp_node_marks_visited_and_heals_or_repairs(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.sanctuary_integrity = 4
	run.wardens[0].hp = 1
	run.wardens[1].hp = 1
	run.wardens[2].alive = false
	run.wardens[2].hp = 0
	run.current_node_id = "ember_camp_05"
	run.resolve_camp_node("heal_squad")
	tr.assert_eq("camp heals first living warden", run.wardens[0].hp, 2)
	tr.assert_eq("camp heals second living warden", run.wardens[1].hp, 2)
	tr.assert_eq("camp does not revive dead warden", run.wardens[2].hp, 0)
	tr.assert_eq("camp node visited", run.visited_nodes[0], "ember_camp_05")
	tr.assert_true("camp leaves no pending reward", run.pending_reward.is_empty())
	tr.assert_eq("camp records node resolution", run.last_resolution.outcome, "camp_resolved")

static func _test_shop_requires_enough_embers_and_marks_visited(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.wardens[0].hp = 1
	run.current_node_id = "quartermaster_cache_02"
	run.resolve_shop_node("buy_small_treatment")
	tr.assert_eq("unaffordable shop does not spend embers", run.embers, 0)
	tr.assert_eq("unaffordable shop does not heal", run.wardens[0].hp, 1)
	tr.assert_eq("unaffordable shop does not visit node", run.visited_nodes.size(), 0)
	tr.assert_eq("unaffordable shop keeps current node", run.current_node_id, "quartermaster_cache_02")
	run.embers = 3
	run.resolve_shop_node("buy_small_treatment")
	tr.assert_eq("affordable shop spends exact embers", run.embers, 0)
	tr.assert_eq("affordable shop heals", run.wardens[0].hp, 2)
	tr.assert_eq("affordable shop marks node visited", run.visited_nodes[0], "quartermaster_cache_02")
	tr.assert_eq("affordable shop clears current node", run.current_node_id, "")
	tr.assert_eq("shop records node resolution", run.last_resolution.outcome, "shop_resolved")

static func _test_battle_victory_builds_pending_reward(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var node: Dictionary = run.route_nodes[0]
	run.current_node_id = node.node_id
	run.apply_battle_resolution(_summary(true, 0, 3, 2))
	run.pending_reward = run.build_pending_reward(node, run.last_resolution)
	tr.assert_true("battle success creates pending reward", not run.pending_reward.is_empty())
	tr.assert_eq("pending reward source node", run.pending_reward.source_node_id, "outer_wall_01")
	tr.assert_eq("pending reward source type", run.pending_reward.source_type, "battle")
	tr.assert_true("pending reward has choices", not run.pending_reward.choice_groups.is_empty())

static func _test_reward_claim_marks_node_and_persists_warden_hp(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var node: Dictionary = run.next_unvisited_node()
	run.current_node_id = node.node_id
	run.apply_battle_resolution(_summary(true, 1, 2, 1))
	tr.assert_eq("sanctuary lost one from protected damage", run.sanctuary_integrity, 11)
	tr.assert_eq("warden hp persisted from battle", run.wardens[0].hp, 1)
	run.pending_reward = run.build_pending_reward(node, run.last_resolution)
	run.claim_pending_reward("upgrade_bountyhunter_vanguard")
	run.mark_current_node_visited()
	tr.assert_eq("fixed embers plus two-task bonus", run.embers, 11)
	tr.assert_eq("upgrade increases max hp", run.wardens[0].hp_max, 4)
	tr.assert_eq("upgrade heals one hp", run.wardens[0].hp, 2)
	tr.assert_eq("node marked visited", run.visited_nodes.size(), 1)
	tr.assert_eq("next node advanced", run.next_unvisited_node().node_id, "extinguished_beacon_02")
	tr.assert_eq("commission board refills after first battle", _node_ids(run.available_route_nodes()), ["extinguished_beacon_02", "quartermaster_cache_02", "crack_courtyard_03"])

static func _test_pending_reward_claims_only_once(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var node: Dictionary = run.next_unvisited_node()
	run.current_node_id = node.node_id
	run.apply_battle_resolution(_summary(true, 0, 1, 2))
	run.pending_reward = run.build_pending_reward(node, run.last_resolution)
	run.claim_pending_reward("upgrade_bountyhunter_vanguard")
	var embers_after_first: int = run.embers
	run.claim_pending_reward("upgrade_bountyhunter_vanguard")
	tr.assert_eq("second claim on cleared reward pays nothing", run.embers, embers_after_first)
	run.pending_reward = run.build_pending_reward(node, run.last_resolution)
	tr.assert_true("claimed reward cannot be rebuilt for same node", run.pending_reward.is_empty())
	run.claim_pending_reward("skip")
	tr.assert_eq("rebuilt duplicate claim pays nothing", run.embers, embers_after_first)

static func _test_invalid_reward_choice_does_not_claim(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var node: Dictionary = run.next_unvisited_node()
	run.current_node_id = node.node_id
	run.apply_battle_resolution(_summary(true, 0, 1, 2))
	run.pending_reward = run.build_pending_reward(node, run.last_resolution)
	run.claim_pending_reward("not_a_real_option")
	tr.assert_true("invalid choice keeps pending reward", not run.pending_reward.is_empty())
	tr.assert_eq("invalid choice does not pay fixed embers", run.embers, 0)
	tr.assert_eq("invalid choice does not mark claimed", run.claimed_reward_ids.size(), 0)

static func _test_elite_reward_uses_demo_relic_options(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var node: Dictionary = run.node_by_id("iron_gate_04")
	run.current_node_id = node.node_id
	run.apply_battle_resolution(_summary(true, 0, 2, 2))
	var reward := run.build_pending_reward(node, run.last_resolution)
	var group: Dictionary = reward.choice_groups[0]
	tr.assert_eq("elite reward group is relic", group.group_type, "relic")
	tr.assert_eq("elite two-task reward shows four relics", group.options.size(), 4)
	tr.assert_eq("elite relic option uses formal demo id", group.options[0].option_id, "relic_chain_weight")
	tr.assert_eq("elite relic has rarity", group.options[0].rarity, "普通")
	tr.assert_eq("elite relic has type", group.options[0].relic_type, "角色 / 位移")

static func _test_three_tasks_offer_guardian_recovery(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var node: Dictionary = run.next_unvisited_node()
	run.current_node_id = node.node_id
	run.apply_battle_resolution(_summary(true, 1, 3, 2))
	run.pending_reward = run.build_pending_reward(node, run.last_resolution)
	tr.assert_true("three tasks creates recovery option", _has_option(run.pending_reward, "repair_sanctuary"))
	run.claim_pending_reward("repair_sanctuary")
	tr.assert_eq("recovery option restores sanctuary", run.sanctuary_integrity, 12)
	tr.assert_true("chapter recovery marked used", run.chapter_guardian_reward_used)

static func _test_full_sanctuary_recovery_conversion_uses_chapter_slot(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var node: Dictionary = run.next_unvisited_node()
	run.current_node_id = node.node_id
	run.apply_battle_resolution(_summary(true, 0, 3, 2))
	run.pending_reward = run.build_pending_reward(node, run.last_resolution)
	tr.assert_true("full sanctuary converts recovery to embers", _has_modifier(run.pending_reward, "guardian_recovery_converted"))
	tr.assert_true("converted recovery does not mark slot before claim", not run.chapter_guardian_reward_used)
	run.claim_pending_reward("upgrade_bountyhunter_vanguard")
	tr.assert_true("converted recovery marks chapter slot used", run.chapter_guardian_reward_used)
	tr.assert_eq("converted recovery pays extra embers", run.embers, 16)

static func _test_dead_warden_has_no_upgrade_option(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var node: Dictionary = run.next_unvisited_node()
	run.current_node_id = node.node_id
	run.apply_battle_resolution(_summary(true, 0, 2, 0))
	var reward := run.build_pending_reward(node, run.last_resolution)
	tr.assert_true("dead bountyhunter upgrade is not offered", not _has_option(reward, "upgrade_bountyhunter_vanguard"))
	tr.assert_true("living graverobber upgrade remains available", _has_option(reward, "upgrade_graverobber_field_pack"))

static func _test_protected_damage_spends_sanctuary_without_immediate_defeat(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	run.current_node_id = run.next_unvisited_node().node_id
	run.apply_battle_resolution(_summary(false, 3, 0, 2, 3))
	tr.assert_eq("protected damage costs sanctuary", run.sanctuary_integrity, 9)
	tr.assert_eq("protected damage can continue run", run.result_outcome, "")

static func _test_boss_reward_can_finish_route(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	for node_id in ["outer_wall_01", "extinguished_beacon_02", "ember_camp_03", "iron_gate_04", "ember_camp_05"]:
		run.current_node_id = node_id
		run.mark_current_node_visited()
	var boss: Dictionary = run.next_unvisited_node()
	tr.assert_eq("boss is final unvisited node", boss.node_type, RunStateScript.NODE_BOSS)
	run.current_node_id = boss.node_id
	run.apply_battle_resolution(_summary(true, 0, 3, 2))
	run.pending_reward = run.build_pending_reward(boss, run.last_resolution)
	run.claim_pending_reward("relic_broken_bell_echo")
	run.mark_current_node_visited()
	tr.assert_true("route complete after boss", run.is_route_complete())
	tr.assert_eq("boss base plus three-task bonus", run.embers, 22)
	tr.assert_eq("chapter relic claimed", run.relics.size(), 1)

static func _test_boss_heart_hits_add_visible_reward_bonus(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var boss: Dictionary = run.node_by_id("boss_outer_bell_01")
	run.current_node_id = boss.node_id
	run.apply_battle_resolution(_boss_summary(2, 3))
	var reward := run.build_pending_reward(boss, run.last_resolution)
	tr.assert_true("boss heart bonus modifier exists", _has_modifier(reward, "boss_heart_bell_bonus"))
	tr.assert_eq("boss heart bonus fixed reward amount", _fixed_reward_amount_for_reason(reward, "心脏钟命中 2 次"), 4)
	tr.assert_eq("boss heart bonus keeps chapter reward phase", reward.get("reward_phase", ""), "chapter_choice")

static func _test_boss_heart_hits_clamp_at_cap(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var boss: Dictionary = run.node_by_id("boss_outer_bell_01")
	run.current_node_id = boss.node_id
	run.apply_battle_resolution(_boss_summary(9, 3))
	var reward := run.build_pending_reward(boss, run.last_resolution)
	tr.assert_eq("boss heart hits clamp reward amount", _fixed_reward_amount_for_reason(reward, "心脏钟命中 3 次"), 6)

static func _test_boss_heart_bonus_is_not_repaid_after_claim(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var boss: Dictionary = run.node_by_id("boss_outer_bell_01")
	run.current_node_id = boss.node_id
	run.apply_battle_resolution(_boss_summary(3, 3))
	run.pending_reward = run.build_pending_reward(boss, run.last_resolution)
	run.claim_pending_reward("relic_broken_bell_echo")
	var embers_after_first: int = run.embers
	tr.assert_eq("boss heart bonus pays through pending reward", embers_after_first, 28)
	run.claim_pending_reward("relic_broken_bell_echo")
	tr.assert_eq("boss heart bonus second claim pays nothing", run.embers, embers_after_first)
	run.pending_reward = run.build_pending_reward(boss, run.last_resolution)
	tr.assert_true("boss heart claimed reward cannot rebuild", run.pending_reward.is_empty())

static func _test_non_boss_ignores_boss_heart_hits(tr) -> void:
	var run = RunStateScript.new()
	run.setup_new_demo()
	var node: Dictionary = run.route_nodes[0]
	var resolution := _summary(true, 0, 2, 2)
	resolution["boss_heart_hits"] = 3
	var reward := run.build_pending_reward(node, resolution)
	tr.assert_true("normal reward ignores boss heart modifier", not _has_modifier(reward, "boss_heart_bell_bonus"))
	tr.assert_eq("normal reward has no heart fixed reward", _fixed_reward_amount_for_reason(reward, "心脏钟命中"), 0)

static func _test_battle_engine_accepts_run_level_warden_hp(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(7, 7)
	grid.set_tile(building, Grid.TileType.BUILDING, 2)
	engine.start_battle(
		grid,
		[_make_bh()],
		[],
		[Vector2i(3, 4)],
		[],
		[],
		1,
		[building],
		[],
		[1]
	)
	engine.apply_action(BattleAction.deploy(Vector2i(3, 4)))
	tr.assert_eq("deployed warden uses run hp", engine.state.wardens()[0].hp, 1)

static func _test_battle_scene_builds_runtime_warden_max_hp_def(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var base_def := _make_bh()
	var runtime_def := scene._runtime_warden_def(base_def, 3)
	tr.assert_eq("runtime warden def uses run max hp", runtime_def.max_hp, 3)
	tr.assert_eq("base warden def keeps static max hp", base_def.max_hp, 2)
	tr.assert_true("runtime warden def is isolated from base def", runtime_def != base_def)
	scene.free()

static func _has_option(reward: Dictionary, option_id: String) -> bool:
	for group in reward.get("choice_groups", []):
		for option in group.get("options", []):
			if String(option.get("option_id", "")) == option_id:
				return true
	return false

static func _has_modifier(reward: Dictionary, modifier_id: String) -> bool:
	for modifier in reward.get("modifiers", []):
		if String(modifier.get("modifier_id", "")) == modifier_id:
			return true
	return false

static func _fixed_reward_amount_for_reason(reward: Dictionary, reason_prefix: String) -> int:
	for fixed_reward in reward.get("fixed_rewards", []):
		if String(fixed_reward.get("reason", "")).begins_with(reason_prefix):
			return int(fixed_reward.get("amount", 0))
	return 0

static func _node_ids(nodes: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for node in nodes:
		ids.append(String(node.get("node_id", "")))
	return ids
