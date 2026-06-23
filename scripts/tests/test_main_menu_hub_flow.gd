extends RefCounted
## Focused coverage for the formal main menu -> hub -> mission flow wrapper.

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const RunStateScript := preload("res://scripts/run/run_state.gd")

static func run(tr) -> void:
	_test_start_mission_from_board_sets_current_node_and_enters_target(tr)
	_test_after_reward_returns_to_mission_board_route_phase(tr)
	_test_run_continue_failure_returns_to_mission_board(tr)
	_test_battle_victory_routes_directly_to_reward(tr)
	_test_boss_failure_uses_retry_page(tr)
	_test_formal_menu_copy_has_no_demo_language(tr)
	_test_main_menu_action_hierarchy_and_continue_state(tr)
	_test_main_menu_has_no_decorative_reference_rects(tr)
	_test_new_run_enters_hub_before_expedition_table(tr)
	_test_hub_renders_only_current_main_nodes(tr)
	_test_future_development_hub_nodes_show_simple_placeholder(tr)
	_test_hub_separates_expedition_gate_from_continue_run(tr)
	_test_mission_board_uses_commission_task_language(tr)
	_test_mission_board_refresh_replaces_single_card(tr)
	_test_mission_board_card_click_directly_enters_mission(tr)
	_test_non_battle_mission_cards_directly_enter_node_pages(tr)
	_test_shop_node_uses_formal_stall_layout(tr)
	_test_removed_mission_detail_does_not_render_from_continue(tr)
	_test_active_run_navigation_stays_on_mission_board(tr)
	_test_buttons_keep_practical_safe_size_and_focus(tr)
	_test_continue_from_stale_resolution_routes_to_reward(tr)
	_test_continue_from_reward_restores_reward(tr)
	_test_new_run_requires_overwrite_confirmation(tr)
	_test_event_camp_shop_back_returns_to_mission_board(tr)
	_test_hub_return_opens_menu_panel(tr)

static func _make_manager_with_run() -> Node2D:
	var manager: Node2D = GameManagerScript.new()
	manager._run = RunStateScript.new()
	manager._run.setup_new_demo()
	return manager

static func _test_start_mission_from_board_sets_current_node_and_enters_target(tr) -> void:
	var manager := _make_manager_with_run()
	var node_id := String(manager._run.available_route_nodes()[0].get("node_id", ""))
	manager._start_mission_from_board(node_id)
	tr.assert_eq("start from board sets current node", manager._run.current_node_id, node_id)
	tr.assert_eq("start from board enters battle phase", manager._run.phase, RunStateScript.Phase.BATTLE)
	manager.queue_free()

static func _test_after_reward_returns_to_mission_board_route_phase(tr) -> void:
	var manager := _make_manager_with_run()
	manager._run.current_node_id = "outer_wall_01"
	manager._after_reward_claimed()
	tr.assert_eq("reward return marks visited node", manager._run.visited_nodes, ["outer_wall_01"])
	tr.assert_eq("reward return clears current node", manager._run.current_node_id, "")
	tr.assert_eq("reward return uses hub route phase", manager._run.phase, RunStateScript.Phase.ROUTE)
	tr.assert_true("reward return opens commission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	manager.queue_free()

static func _test_run_continue_failure_returns_to_mission_board(tr) -> void:
	var manager := _make_manager_with_run()
	manager._run.current_node_id = "outer_wall_01"
	manager._on_battle_finished(_battle_summary(false, 2, 0))
	tr.assert_eq("nonfatal battle failure opens debrief phase", manager._run.phase, RunStateScript.Phase.NODE_RESOLUTION)
	tr.assert_eq("nonfatal battle failure keeps run active", manager._run.result_outcome, "")
	tr.assert_true("nonfatal battle failure shows short debrief", _collect_label_text(manager._ui).find("战果短报") >= 0)
	tr.assert_true("nonfatal battle failure debrief names loss", _collect_label_text(manager._ui).find("委托失利") >= 0)
	var continue_button := _find_button(manager._ui, "返回任务布告")
	tr.assert_true("nonfatal battle failure has board continue", continue_button != null)
	continue_button.pressed.emit()
	tr.assert_eq("nonfatal battle failure marks task resolved", manager._run.visited_nodes, ["outer_wall_01"])
	tr.assert_true("nonfatal battle failure opens commission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	tr.assert_true("nonfatal battle failure shows route notice", _collect_label_text(manager._ui).find("委托失利") >= 0)
	tr.assert_true("nonfatal battle failure does not render old resolution", _collect_label_text(manager._ui).find("战后结算") == -1)
	manager.queue_free()

static func _test_battle_victory_routes_directly_to_reward(tr) -> void:
	var manager := _make_manager_with_run()
	manager._run.current_node_id = "outer_wall_01"
	manager._on_battle_finished(_battle_summary(true, 0, 1))
	tr.assert_eq("victory enters reward phase directly", manager._run.phase, RunStateScript.Phase.REWARD)
	tr.assert_true("victory builds pending reward", not manager._run.pending_reward.is_empty())
	var text := _collect_label_text(manager._ui)
	tr.assert_true("victory opens reward list page", text.find("获得奖励") >= 0)
	tr.assert_true("victory reward page names completed commission", text.find("委托完成") >= 0)
	tr.assert_true("reward page renders reward item component", _collect_nodes_named(manager._ui, "RewardListItem").size() >= 1)
	tr.assert_true("reward page has return button", _find_button(manager._ui, "返回任务委托") != null)
	tr.assert_true("reward page skips short debrief", text.find("战果短报") == -1)
	tr.assert_true("reward page skips old choice title", text.find("奖励选择") == -1)
	tr.assert_true("reward page skips task stat", text.find("奖励任务") == -1)
	tr.assert_true("reward page skips battle loss stat", text.find("守护值 -") == -1 and text.find("保护目标") == -1)
	tr.assert_true("reward page removes old resolution return", text.find("返回结算") == -1)
	tr.assert_true("victory does not render old resolution", text.find("战后结算") == -1)
	_find_button(manager._ui, "返回任务委托").pressed.emit()
	tr.assert_true("reward claim returns commission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	tr.assert_eq("reward claim marks task visited", manager._run.visited_nodes, ["outer_wall_01"])
	manager.queue_free()

static func _test_boss_failure_uses_retry_page(tr) -> void:
	var manager := _make_manager_with_run()
	manager._run.current_node_id = "boss_outer_bell_01"
	manager._on_battle_finished(_battle_summary(false, 0, 0))
	tr.assert_eq("boss retry opens debrief phase", manager._run.phase, RunStateScript.Phase.NODE_RESOLUTION)
	tr.assert_eq("boss retry keeps current node", manager._run.current_node_id, "boss_outer_bell_01")
	tr.assert_true("boss retry flag stored", bool(manager._run.last_resolution.get("boss_retry", false)))
	var text := _collect_label_text(manager._ui)
	tr.assert_true("boss retry debrief visible", text.find("战果短报") >= 0)
	tr.assert_true("boss retry page visible", text.find("Boss 未压制") >= 0)
	tr.assert_true("boss retry has retry button", _find_button(manager._ui, "重试 Boss") != null)
	tr.assert_true("boss retry has mission board return", _find_button(manager._ui, "返回任务布告") != null)
	tr.assert_true("boss retry avoids old resolution screen", text.find("战后结算") == -1)
	manager._show_main_menu()
	manager._continue_run_pressed()
	tr.assert_true("continue restores boss retry debrief", _collect_label_text(manager._ui).find("Boss 未压制") >= 0)
	manager.queue_free()

static func _test_formal_menu_copy_has_no_demo_language(tr) -> void:
	var manager := _make_manager_with_run()
	manager._show_main_menu()
	var text := _collect_label_text(manager._ui)
	tr.assert_true("formal menu uses title", text.find("裂隙守夜") >= 0)
	tr.assert_true("formal menu removes demo and explanatory side copy", text.find("Demo") == -1 and text.find("本次实现流程") == -1 and text.find("当前验证") == -1 and text.find("断墙外的据点") == -1 and text.find("任务选择已转入据点场景") == -1)
	manager.queue_free()

static func _test_main_menu_action_hierarchy_and_continue_state(tr) -> void:
	var empty_manager: Node2D = GameManagerScript.new()
	empty_manager._show_main_menu()
	var empty_text := _collect_label_text(empty_manager._ui)
	for label in ["继续守夜", "开始新局", "图鉴", "设置", "退出"]:
		tr.assert_true("main menu includes %s" % label, empty_text.find(label) >= 0)
	for old_label in ["进入据点", "继续远征", "开始新远征"]:
		tr.assert_true("main menu removes %s" % old_label, empty_text.find(old_label) == -1)
	var empty_continue := _find_button(empty_manager._ui, "继续守夜")
	tr.assert_true("continue button exists without run", empty_continue != null)
	tr.assert_true("continue button disabled without run", empty_continue.disabled)
	empty_manager.queue_free()

	var manager := _make_manager_with_run()
	manager._show_main_menu()
	var continue_button := _find_button(manager._ui, "继续守夜")
	tr.assert_true("continue button exists with run", continue_button != null)
	tr.assert_true("continue button enabled with run", not continue_button.disabled)
	continue_button.pressed.emit()
	tr.assert_true("main menu continue opens mission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	tr.assert_true("main menu continue does not open hub", _collect_label_text(manager._ui).find("断墙据点") == -1)
	manager.queue_free()

static func _test_main_menu_has_no_decorative_reference_rects(tr) -> void:
	var manager := _make_manager_with_run()
	manager._show_main_menu()
	tr.assert_eq("main menu root has no decorative ReferenceRect frames", _collect_reference_rects(manager._ui).size(), 0)
	manager.queue_free()

static func _test_new_run_enters_hub_before_expedition_table(tr) -> void:
	var manager: Node2D = GameManagerScript.new()
	manager._show_main_menu()
	manager._on_new_run_pressed()
	var text := _collect_label_text(manager._ui)
	tr.assert_eq("new run does not create run before map choice", manager._run, null)
	tr.assert_true("new run enters hub first", text.find("断墙据点") >= 0)
	tr.assert_true("new run hub shows expedition gate", text.find("断墙远征门") >= 0)
	tr.assert_true("new run hub shows report table", text.find("篝火 / 战报台") >= 0)
	tr.assert_true("new run hub does not immediately show expedition table", text.find("断墙外远征地图") == -1)
	var gate := _find_button(manager._ui, "断墙远征门\n选择远征")
	tr.assert_true("expedition gate opens map choice before run exists", gate != null)
	gate.pressed.emit()
	text = _collect_label_text(manager._ui)
	tr.assert_true("gate opens expedition map table", text.find("断墙外远征地图") >= 0)
	tr.assert_true("expedition table offers broken wall", text.find("断墙外环") >= 0)
	tr.assert_true("expedition table offers rift corridor", text.find("裂隙回廊") >= 0)
	var button := _find_button(manager._ui, "断墙外环\n标准 / 均衡")
	tr.assert_true("expedition region button exists", button != null)
	button.pressed.emit()
	tr.assert_true("selecting expedition creates run", manager._run != null)
	tr.assert_eq("selected expedition id stored", manager._run.expedition_id, RunStateScript.EXPEDITION_BROKEN_WALL)
	tr.assert_true("selecting expedition opens commission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	manager.queue_free()

static func _test_hub_renders_only_current_main_nodes(tr) -> void:
	var manager := _make_manager_with_run()
	manager._show_hub()
	var text := _collect_label_text(manager._ui)
	for label in ["断墙远征门", "守卫者营帐", "篝火 / 战报台", "工坊", "档案馆", "设置"]:
		tr.assert_true("hub includes %s" % label, text.find(label) >= 0)
	for removed in ["守卫者召集处", "营地", "图鉴", "补给", "远征进度", "进度 ", "腐化", "守护值", "主菜单", "布告板 / 任务选择"]:
		tr.assert_true("hub excludes %s" % removed, text.find(removed) == -1)
	tr.assert_true("hub has return entry", _find_button(manager._ui, "返回") != null)
	manager.queue_free()

static func _test_future_development_hub_nodes_show_simple_placeholder(tr) -> void:
	var manager: Node2D = GameManagerScript.new()
	manager._show_main_menu()
	var new_run := _find_button(manager._ui, "开始新局")
	tr.assert_true("new run button exists for future placeholder path", new_run != null)
	if new_run == null:
		manager.queue_free()
		return
	new_run.pressed.emit()
	for case_data in [
		{"button": "守卫者营帐\n队伍名册", "title": "守卫者营帐"},
		{"button": "篝火 / 战报台\n最近战报", "title": "篝火 / 战报台"},
		{"button": "工坊\n图纸与遗物", "title": "工坊"},
		{"button": "档案馆\n敌人与规则", "title": "档案馆"},
	]:
		manager._show_hub()
		var entry := _find_button(manager._ui, String(case_data.button))
		tr.assert_true("%s entry exists" % String(case_data.title), entry != null)
		if entry == null:
			continue
		var root_before: Control = manager._ui
		entry.pressed.emit()
		var text := _collect_label_text(manager._ui)
		var dialog := _find_node_named(manager._ui, "FutureDevelopmentDialog")
		tr.assert_eq("%s dialog keeps current hub root" % String(case_data.title), manager._ui, root_before)
		tr.assert_true("%s dialog exists" % String(case_data.title), dialog != null)
		tr.assert_true("%s dialog keeps hub entry visible" % String(case_data.title), _find_button(manager._ui, String(case_data.button)) != null)
		tr.assert_true("%s dialog keeps title" % String(case_data.title), text.find(String(case_data.title)) >= 0)
		tr.assert_true("%s dialog says future development" % String(case_data.title), text.find("未来开发中") >= 0)
		var close_button := _find_button_named(manager._ui, "FutureDevelopmentClose")
		tr.assert_true("%s dialog has close button" % String(case_data.title), close_button != null)
		tr.assert_true("%s dialog does not use hub return as action" % String(case_data.title), _find_button(dialog, "返回据点") == null)
		tr.assert_true("%s dialog omits temporary roster" % String(case_data.title), text.find("赏金猎人  HP") == -1)
		tr.assert_true("%s dialog omits detailed copy" % String(case_data.title), text.find("第一版") == -1 and text.find("最近战报和失败记录") == -1)
		if close_button != null:
			close_button.pressed.emit()
		tr.assert_true("%s dialog closes in place" % String(case_data.title), _find_node_named(manager._ui, "FutureDevelopmentDialog") == null)
		tr.assert_eq("%s close keeps current hub root" % String(case_data.title), manager._ui, root_before)
	manager.queue_free()

static func _test_hub_separates_expedition_gate_from_continue_run(tr) -> void:
	var manager := _make_manager_with_run()
	manager._show_hub()
	var gate := _find_button(manager._ui, "断墙远征门\n选择远征")
	tr.assert_true("expedition gate exists as new run entry", gate != null)
	gate.pressed.emit()
	tr.assert_true("expedition gate opens expedition table even with run", _collect_label_text(manager._ui).find("断墙外远征地图") >= 0)
	manager._show_hub()
	var report := _find_button(manager._ui, "篝火 / 战报台\n继续远征")
	tr.assert_true("report table exposes continue run entry", report != null)
	report.pressed.emit()
	tr.assert_true("report table opens run status panel", _collect_label_text(manager._ui).find("继续远征") >= 0)
	var continue_button := _find_button(manager._ui, "继续远征")
	tr.assert_true("run status panel has continue button", continue_button != null)
	continue_button.pressed.emit()
	tr.assert_true("continue opens mission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	manager.queue_free()

static func _test_mission_board_uses_commission_task_language(tr) -> void:
	var manager := _make_manager_with_run()
	manager._show_mission_board()
	var text := _collect_label_text(manager._ui)
	tr.assert_true("mission board uses commission title", text.find("任务委托") >= 0)
	tr.assert_true("mission board uses short action subtitle", text.find("断墙外环 · 选择下一次行动") >= 0)
	tr.assert_true("mission board shows boss unlock progress", text.find("完成 0 / 8 后进入 Boss") >= 0)
	tr.assert_true("mission board shows icon refresh status", _find_node_named(manager._ui, "MissionRefreshStatus") != null)
	tr.assert_true("mission board shows refresh charge count", text.find("2 / 2") >= 0)
	tr.assert_true("mission board exposes generated refresh icon", _find_node_named(manager._ui, "MissionRefreshIcon") != null)
	tr.assert_true("mission board always shows corruption", text.find("腐化 0") >= 0)
	tr.assert_true("mission board shows sanctuary status", text.find("守护值 12 / 12") >= 0)
	tr.assert_true("mission card shows task-first type", text.find("防守委托") >= 0)
	tr.assert_true("normal mission previews direct reward", text.find("报酬 7 余烬") >= 0)
	tr.assert_true("mission card shows precise risk", text.find("低危 1/5") >= 0)
	tr.assert_true("mission card uses in-world intel", text.find("外墙有远程火线压近。") >= 0)
	tr.assert_true("mission board removes detail button", _find_button(manager._ui, "查看详情") == null)
	tr.assert_true("mission board keeps return inside mission panel", _find_button_parent_named(manager._ui, "返回据点", "RunUI") == null)
	tr.assert_true("mission board has no hub return inside active run", _find_button(manager._ui, "返回据点") == null)
	tr.assert_true("mission board no longer explains refill", text.find("完成一个委托后") == -1)
	tr.assert_true("mission board hides designer summary", text.find("教学式普通战") == -1 and text.find("奖励玩家") == -1 and text.find("Demo") == -1)
	tr.assert_true("mission board no longer says base reward", text.find("基础奖励") == -1)
	tr.assert_true("mission board no longer uses expedition map title", text.find("断墙远征图") == -1)
	manager._run.current_node_id = "boss_outer_bell_01"
	manager._run.mark_current_node_visited()
	manager._show_mission_board()
	text = _collect_label_text(manager._ui)
	tr.assert_true("empty mission board uses map wording", text.find("本次地图委托已完成") >= 0)
	tr.assert_true("empty mission board removes chapter route wording", text.find("本章路线") == -1)
	manager._run.phase = RunStateScript.Phase.RUN_RESULT
	manager._run.result_outcome = "victory"
	manager._show_run_result()
	var result_text := _collect_label_text(manager._ui)
	tr.assert_true("run result uses commission progress copy", result_text.find("完成委托") >= 0)
	tr.assert_true("run result avoids node progress copy", result_text.find("完成节点") == -1)
	manager.queue_free()

static func _test_mission_board_refresh_replaces_single_card(tr) -> void:
	var manager := _make_manager_with_run()
	manager._show_mission_board()
	var before := _node_ids(manager._run.available_commissions())
	var refresh_button := _find_button_named(manager._ui, "MissionCardRefresh_outer_wall_01")
	tr.assert_true("mission card refresh button exists", refresh_button != null)
	if refresh_button == null:
		manager.queue_free()
		return
	tr.assert_eq("mission card refresh button uses icon instead of text", refresh_button.text, "")
	tr.assert_true("mission card refresh icon exists", _find_node_named(refresh_button, "MissionRefreshIcon") != null)
	tr.assert_true("mission card refresh button enabled", not refresh_button.disabled)
	refresh_button.pressed.emit()
	var after := _node_ids(manager._run.available_commissions())
	tr.assert_eq("refresh does not start mission", manager._run.current_node_id, "")
	tr.assert_eq("refresh keeps route phase", manager._run.phase, RunStateScript.Phase.ROUTE)
	tr.assert_eq("refresh consumes one charge", manager._run.refresh_charges, 1)
	tr.assert_eq("refresh preserves other card slots", after.slice(1), before.slice(1))
	tr.assert_true("refresh replaces selected slot", after[0] != before[0])
	tr.assert_true("mission board rerenders refresh count", _collect_label_text(manager._ui).find("1 / 2") >= 0)
	manager.queue_free()

static func _test_mission_board_card_click_directly_enters_mission(tr) -> void:
	var manager := _make_manager_with_run()
	manager._show_mission_board()
	var card := _find_button_named(manager._ui, "MissionCard_outer_wall_01")
	tr.assert_true("mission card is a full-card button", card != null)
	if card == null:
		manager.queue_free()
		return
	tr.assert_eq("mission card supports keyboard focus", card.focus_mode, Control.FOCUS_ALL)
	tr.assert_true("mission card has selected hover style", card.get_theme_stylebox("hover") != null)
	var glow := _find_node_named(card, "MissionCardSelectionGlow") as Control
	tr.assert_true("mission card has selection glow overlay", glow != null)
	tr.assert_eq("mission card selection glow ignores mouse", glow.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	card.pressed.emit()
	tr.assert_eq("mission card click sets current node", manager._run.current_node_id, "outer_wall_01")
	tr.assert_eq("mission card click enters battle directly", manager._run.phase, RunStateScript.Phase.BATTLE)
	tr.assert_true("mission card click bypasses detail page", manager._ui == null)
	manager.queue_free()

static func _test_non_battle_mission_cards_directly_enter_node_pages(tr) -> void:
	var manager := _make_manager_with_run()
	manager._run.current_node_id = "outer_wall_01"
	manager._run.mark_current_node_visited()
	manager._show_mission_board()
	var event_card := _find_button_named(manager._ui, "MissionCard_extinguished_beacon_02")
	tr.assert_true("event mission card exists", event_card != null)
	if event_card == null:
		manager.queue_free()
		return
	event_card.pressed.emit()
	tr.assert_eq("event card sets current node", manager._run.current_node_id, "extinguished_beacon_02")
	tr.assert_true("event card opens event page directly", _collect_label_text(manager._ui).find("事件") >= 0)
	tr.assert_true("event card bypasses detail page", _collect_label_text(manager._ui).find("委托确认") == -1)
	manager._show_mission_board()
	var shop_card := _find_button_named(manager._ui, "MissionCard_quartermaster_cache_02")
	tr.assert_true("shop mission card exists", shop_card != null)
	if shop_card == null:
		manager.queue_free()
		return
	shop_card.pressed.emit()
	tr.assert_eq("shop card sets current node", manager._run.current_node_id, "quartermaster_cache_02")
	tr.assert_true("shop card opens shop page directly", _find_node_named(manager._ui, "ShopStallPanel") != null)
	tr.assert_true("shop card opens formal stall panel", _find_node_named(manager._ui, "ShopStallPanel") != null)
	tr.assert_true("shop card bypasses detail page", _collect_label_text(manager._ui).find("委托确认") == -1)
	manager.queue_free()

static func _test_shop_node_uses_formal_stall_layout(tr) -> void:
	var manager := _make_manager_with_run()
	manager._run.current_node_id = "quartermaster_cache_02"
	manager._show_shop_node()
	var text := _collect_label_text(manager._ui)
	tr.assert_true("shop keeps node title", text.find("前线军需点") >= 0)
	tr.assert_true("shop removes redundant action title", text.find("商店行动") == -1)
	tr.assert_true("shop removes nonessential flavor copy", text.find("封存的军需箱仍带着余温。") == -1)
	tr.assert_true("shop removes redundant purchase count copy", text.find("购买 1 项") == -1)
	tr.assert_true("shop does not use a baked full-screen stall image", _find_node_named(manager._ui, "ShopStallArt") == null)
	tr.assert_true("shop uses atlas main panel", _find_node_named(manager._ui, "ShopAtlasMainPanel") != null)
	tr.assert_true("shop uses atlas back button plate", _find_node_named(manager._ui, "ShopAtlasBackButtonPlate") != null)
	tr.assert_true("shop shows resource strip", _find_node_named(manager._ui, "ShopResourceStrip") != null)
	tr.assert_true("shop resource strip uses formal backplate", _find_node_named(manager._ui, "ShopResourceStripBackplate") != null)
	for resource_name in ["ShopResource_余烬", "ShopResource_守护值", "ShopResource_守卫者", "ShopResource_腐化"]:
		tr.assert_true("shop has %s" % resource_name, _find_node_named(manager._ui, resource_name) != null)
	tr.assert_true("shop uses shelf frame", _find_node_named(manager._ui, "ShopShelfFrame") != null)
	for stall_name in ["ShopStall_buy_small_treatment", "ShopStall_buy_barricade_kit", "ShopStall_buy_cracked_charm"]:
		tr.assert_true("shop has %s" % stall_name, _find_node_named(manager._ui, stall_name) != null)
	for mark_name in ["ShopItemMark_healing", "ShopItemMark_repair", "ShopItemMark_relic"]:
		tr.assert_true("shop has item mark %s" % mark_name, _find_node_named(manager._ui, mark_name) != null)
	for icon_name in ["ShopAtlasItemIcon_healing", "ShopAtlasItemIcon_repair", "ShopAtlasItemIcon_relic"]:
		tr.assert_true("shop has atlas item icon %s" % icon_name, _find_node_named(manager._ui, icon_name) != null)
	var repair_icon := _find_node_named(manager._ui, "ShopAtlasItemIcon_repair")
	if repair_icon is TextureRect:
		var repair_texture := (repair_icon as TextureRect).texture
		tr.assert_true("shop repair icon uses full atlas region", repair_texture is AtlasTexture)
		if repair_texture is AtlasTexture:
			tr.assert_eq("shop repair icon keeps bottom padding", (repair_texture as AtlasTexture).region, Rect2(783, 596, 224, 176))
	tr.assert_true("shop strips buy prefix from item title", text.find("简易急救包") >= 0 and text.find("路障材料") >= 0 and text.find("裂纹护符") >= 0)
	tr.assert_true("shop presents price lines", text.find("余烬 -3") >= 0 and text.find("余烬 -4") >= 0 and text.find("余烬 -5") >= 0)
	tr.assert_true("shop removes crowded effect copy", text.find("存活守卫者 HP +1") == -1 and text.find("守护值 +1") == -1 and text.find("获得遗物") == -1)
	tr.assert_true("shop removes debug tick copy", text.find("战略 tick") == -1 and text.find("不会压制") == -1)
	tr.assert_true("shop removes designer summaries", text.find("第一战后的早期商店") == -1 and text.find("Boss 前补给节点") == -1)
	tr.assert_true("shop removes long item descriptions", text.find("花 3 余烬") == -1 and text.find("花 4 余烬") == -1 and text.find("花 5 余烬") == -1)
	manager.queue_free()

static func _test_removed_mission_detail_does_not_render_from_continue(tr) -> void:
	var manager := _make_manager_with_run()
	manager._run.current_node_id = "outer_wall_01"
	manager._run.phase = RunStateScript.Phase.NODE_PREVIEW
	manager._show_main_menu()
	manager._continue_run_pressed()
	var text := _collect_label_text(manager._ui)
	tr.assert_eq("stale preview continue clears current node", manager._run.current_node_id, "")
	tr.assert_eq("stale preview continue returns route phase", manager._run.phase, RunStateScript.Phase.ROUTE)
	tr.assert_true("stale preview continue opens mission board", text.find("任务委托") >= 0)
	tr.assert_true("stale preview continue does not render detail", text.find("委托确认") == -1)
	tr.assert_true("stale preview continue does not render old task detail copy", text.find("任务目标：") == -1 and text.find("奖励预览：") == -1)
	manager.queue_free()

static func _test_active_run_navigation_stays_on_mission_board(tr) -> void:
	var manager := _make_manager_with_run()
	manager._run.current_node_id = "outer_wall_01"
	manager._run.phase = RunStateScript.Phase.NODE_PREVIEW
	manager._continue_run_from_hub_status()
	tr.assert_eq("hub status stale preview clears current node", manager._run.current_node_id, "")
	tr.assert_eq("hub status stale preview returns route phase", manager._run.phase, RunStateScript.Phase.ROUTE)
	tr.assert_true("hub status stale preview opens mission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	tr.assert_true("hub status stale preview does not open hub", _collect_label_text(manager._ui).find("断墙据点") == -1)
	tr.assert_true("hub status stale preview does not render detail", _collect_label_text(manager._ui).find("委托确认") == -1)

	_reset_run_visits(manager._run)
	manager._run.current_node_id = "extinguished_beacon_02"
	manager._show_event_node()
	var event_confirm := _find_button(manager._ui, "确认")
	tr.assert_true("event node has confirm", event_confirm != null)
	event_confirm.pressed.emit()
	tr.assert_eq("event confirm returns to route phase", manager._run.phase, RunStateScript.Phase.ROUTE)
	tr.assert_true("event confirm returns mission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	tr.assert_true("event confirm does not return hub", _collect_label_text(manager._ui).find("断墙据点") == -1)

	_reset_run_visits(manager._run)
	manager._run.current_node_id = _first_node_id_of_type(manager._run, RunStateScript.NODE_CAMP)
	manager._show_camp_node()
	var camp_confirm := _find_button(manager._ui, "确认")
	tr.assert_true("camp node has confirm", camp_confirm != null)
	camp_confirm.pressed.emit()
	tr.assert_eq("camp confirm returns to route phase", manager._run.phase, RunStateScript.Phase.ROUTE)
	tr.assert_true("camp confirm returns mission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	tr.assert_true("camp confirm does not return hub", _collect_label_text(manager._ui).find("断墙据点") == -1)

	_reset_run_visits(manager._run)
	manager._run.current_node_id = "quartermaster_cache_02"
	manager._show_shop_node()
	var shop_buy := _find_button(manager._ui, "购买")
	tr.assert_true("shop node has buy", shop_buy != null)
	shop_buy.pressed.emit()
	tr.assert_eq("shop buy returns to route phase", manager._run.phase, RunStateScript.Phase.ROUTE)
	tr.assert_true("shop buy returns mission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	tr.assert_true("shop buy does not return hub", _collect_label_text(manager._ui).find("断墙据点") == -1)

	manager._run.current_node_id = "missing_node"
	manager._execute_current_node()
	tr.assert_true("missing current node fallback returns mission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	tr.assert_true("missing current node fallback does not return hub", _collect_label_text(manager._ui).find("断墙据点") == -1)
	manager.queue_free()

static func _test_buttons_keep_practical_safe_size_and_focus(tr) -> void:
	var manager := _make_manager_with_run()
	manager._show_hub()
	var buttons := _collect_buttons(manager._ui)
	tr.assert_true("hub exposes mission board and navigation controls", buttons.size() >= 2)
	for button in buttons:
		tr.assert_true("button target height safe for %s" % button.text, button.size.y >= 48.0)
		tr.assert_eq("button focus visible for %s" % button.text, button.focus_mode, Control.FOCUS_ALL)
		tr.assert_true("button has hover style for %s" % button.text, button.get_theme_stylebox("hover") != null)
	manager.queue_free()

static func _test_continue_from_stale_resolution_routes_to_reward(tr) -> void:
	var manager := _make_manager_with_run()
	var node: Dictionary = manager._run.next_unvisited_node()
	manager._run.current_node_id = String(node.get("node_id", ""))
	manager._run.last_resolution = _battle_summary(true, 0, 1)
	manager._run.pending_reward = manager._run.build_pending_reward(node, manager._run.last_resolution)
	manager._run.phase = RunStateScript.Phase.NODE_RESOLUTION
	var reward_id := String(manager._run.pending_reward.get("reward_id", ""))
	manager._show_main_menu()
	manager._continue_run_pressed()
	tr.assert_eq("continue stale resolution routes to reward phase", manager._run.phase, RunStateScript.Phase.REWARD)
	tr.assert_eq("continue resolution keeps current node", manager._run.current_node_id, String(node.get("node_id", "")))
	tr.assert_eq("continue resolution keeps pending reward", String(manager._run.pending_reward.get("reward_id", "")), reward_id)
	tr.assert_true("continue stale resolution renders reward list", _collect_label_text(manager._ui).find("获得奖励") >= 0)
	tr.assert_true("continue stale resolution keeps reward item component", _collect_nodes_named(manager._ui, "RewardListItem").size() >= 1)
	tr.assert_true("continue stale resolution skips debrief", _collect_label_text(manager._ui).find("战果短报") == -1)
	tr.assert_true("continue stale resolution avoids old resolution screen", _collect_label_text(manager._ui).find("战后结算") == -1)
	manager.queue_free()

static func _test_continue_from_reward_restores_reward(tr) -> void:
	var manager := _make_manager_with_run()
	var node: Dictionary = manager._run.next_unvisited_node()
	manager._run.current_node_id = String(node.get("node_id", ""))
	manager._run.last_resolution = _battle_summary(true, 0, 2)
	manager._run.pending_reward = manager._run.build_pending_reward(node, manager._run.last_resolution)
	manager._run.phase = RunStateScript.Phase.REWARD
	var reward_id := String(manager._run.pending_reward.get("reward_id", ""))
	manager._show_main_menu()
	manager._continue_run_pressed()
	tr.assert_eq("continue reward keeps phase", manager._run.phase, RunStateScript.Phase.REWARD)
	tr.assert_eq("continue reward keeps pending reward", String(manager._run.pending_reward.get("reward_id", "")), reward_id)
	tr.assert_true("continue reward renders reward screen", _collect_label_text(manager._ui).find("获得奖励") >= 0)
	tr.assert_true("continue reward renders reward item component", _collect_nodes_named(manager._ui, "RewardListItem").size() >= 1)
	manager.queue_free()

static func _test_new_run_requires_overwrite_confirmation(tr) -> void:
	var manager := _make_manager_with_run()
	var old_run = manager._run
	manager._run.current_node_id = "outer_wall_01"
	manager._run.phase = RunStateScript.Phase.NODE_PREVIEW
	manager._on_new_run_pressed()
	tr.assert_true("new run first click keeps active run", manager._run == old_run)
	tr.assert_eq("new run confirmation keeps current node", manager._run.current_node_id, "outer_wall_01")
	tr.assert_true("new run first click shows overwrite copy", _collect_label_text(manager._ui).find("覆盖当前存档") >= 0)
	manager._confirm_new_run_overwrite()
	tr.assert_eq("overwrite confirmation clears visible run until expedition selected", manager._run, null)
	tr.assert_true("overwrite confirmation enters hub before expedition table", _collect_label_text(manager._ui).find("断墙据点") >= 0)
	tr.assert_true("overwrite confirmation hides expedition table first", _collect_label_text(manager._ui).find("断墙外远征地图") == -1)
	var gate := _find_button(manager._ui, "断墙远征门\n选择远征")
	tr.assert_true("overwrite hub exposes map gate", gate != null)
	gate.pressed.emit()
	tr.assert_true("map gate opens expedition table", _collect_label_text(manager._ui).find("断墙外远征地图") >= 0)
	var button := _find_button(manager._ui, "裂隙回廊\n高压 / 成长")
	tr.assert_true("can choose new expedition after overwrite", button != null)
	button.pressed.emit()
	tr.assert_true("overwrite expedition creates new run", manager._run != old_run)
	tr.assert_eq("new run starts without selected node", manager._run.current_node_id, "")
	tr.assert_eq("new run uses selected expedition", manager._run.expedition_id, RunStateScript.EXPEDITION_RIFT_CORRIDOR)
	tr.assert_true("overwrite expedition opens commission board", _collect_label_text(manager._ui).find("任务委托") >= 0)
	manager.queue_free()

static func _test_event_camp_shop_back_returns_to_mission_board(tr) -> void:
	var manager := _make_manager_with_run()
	var camp_id := _first_node_id_of_type(manager._run, RunStateScript.NODE_CAMP)
	for case_data in [
		{"node_id": "extinguished_beacon_02", "show": "_show_event_node", "visited": ["outer_wall_01"]},
		{"node_id": camp_id, "show": "_show_camp_node", "visited": ["outer_wall_01", "extinguished_beacon_02", "quartermaster_cache_02"]},
		{"node_id": "quartermaster_cache_02", "show": "_show_shop_node", "visited": ["outer_wall_01"]},
	]:
		_reset_run_visits(manager._run)
		for visited_id in case_data.visited:
			manager._run.current_node_id = String(visited_id)
			manager._run.mark_current_node_visited()
		manager._run.current_node_id = String(case_data.node_id)
		manager.call(String(case_data.show))
		var back_button := _find_button(manager._ui, "返回任务布告")
		tr.assert_true("%s back button returns to board" % String(case_data.show), back_button != null)
		tr.assert_true("%s has no detail return" % String(case_data.show), _find_button(manager._ui, "返回任务详情") == null)
		back_button.pressed.emit()
		tr.assert_eq("%s clears selected node" % String(case_data.show), manager._run.current_node_id, "")
		tr.assert_eq("%s returns to route phase" % String(case_data.show), manager._run.phase, RunStateScript.Phase.ROUTE)
		tr.assert_true("%s opens mission board" % String(case_data.show), _collect_label_text(manager._ui).find("任务委托") >= 0)
		tr.assert_true("%s does not render detail" % String(case_data.show), _collect_label_text(manager._ui).find("委托确认") == -1)
	manager.queue_free()

static func _test_hub_return_opens_menu_panel(tr) -> void:
	var manager := _make_manager_with_run()
	manager._show_hub()
	var return_button := _find_button(manager._ui, "返回")
	tr.assert_true("hub return button exists", return_button != null)
	return_button.pressed.emit()
	var panel_text := _collect_label_text(manager._ui)
	tr.assert_true("return opens panel", panel_text.find("离开据点并返回标题菜单") >= 0)
	tr.assert_true("return panel can go title", _find_button(manager._ui, "返回标题") != null)
	var stay_button := _find_button(manager._ui, "留在据点")
	tr.assert_true("return panel can stay", stay_button != null)
	stay_button.pressed.emit()
	tr.assert_true("stay returns hub", _collect_label_text(manager._ui).find("断墙远征门") >= 0)
	manager.queue_free()

static func _battle_summary(victory: bool, destroyed: int, completed: int) -> Dictionary:
	return {
		"outcome": BattleState.Outcome.VICTORY if victory else BattleState.Outcome.DEFEAT,
		"victory": victory,
		"line_breached": not victory,
		"destroyed_protected_count": destroyed,
		"protected_damage_taken": destroyed,
		"completed_reward_count": completed,
		"reward_tasks": [],
		"reward_completed": {},
		"reward_failed": {},
		"wardens": [
			{"def_id": "warden_bountyhunter", "name": "BH", "hp": 2, "hp_max": 2, "alive": true},
			{"def_id": "warden_graverobber", "name": "GR", "hp": 2, "hp_max": 2, "alive": true},
			{"def_id": "warden_mage", "name": "MG", "hp": 2, "hp_max": 2, "alive": true},
		],
		"round": 5,
		"max_rounds": 5,
	}

static func _reset_run_visits(run: RunStateScript) -> void:
	run.current_node_id = ""
	run.visited_nodes.clear()
	run.active_commission_ids.clear()
	for i in range(run.route_nodes.size()):
		run.route_nodes[i]["visited"] = false
	run.available_route_nodes()

static func _collect_label_text(node: Node) -> String:
	var parts: Array[String] = []
	_collect_label_text_into(node, parts)
	return "\n".join(parts)

static func _collect_label_text_into(node: Node, parts: Array[String]) -> void:
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		_collect_label_text_into(child, parts)

static func _collect_buttons(node: Node) -> Array[Button]:
	var buttons: Array[Button] = []
	_collect_buttons_into(node, buttons)
	return buttons

static func _collect_buttons_into(node: Node, buttons: Array[Button]) -> void:
	if node is Button:
		buttons.append(node as Button)
	for child in node.get_children():
		_collect_buttons_into(child, buttons)

static func _collect_reference_rects(node: Node) -> Array[ReferenceRect]:
	var frames: Array[ReferenceRect] = []
	_collect_reference_rects_into(node, frames)
	return frames

static func _collect_reference_rects_into(node: Node, frames: Array[ReferenceRect]) -> void:
	if node is ReferenceRect:
		frames.append(node as ReferenceRect)
	for child in node.get_children():
		_collect_reference_rects_into(child, frames)

static func _collect_nodes_named(node: Node, node_name: String) -> Array[Node]:
	var nodes: Array[Node] = []
	_collect_nodes_named_into(node, node_name, nodes)
	return nodes

static func _collect_nodes_named_into(node: Node, node_name: String, nodes: Array[Node]) -> void:
	if String(node.name) == node_name:
		nodes.append(node)
	for child in node.get_children():
		_collect_nodes_named_into(child, node_name, nodes)

static func _find_node_named(node: Node, node_name: String) -> Node:
	if String(node.name) == node_name:
		return node
	for child in node.get_children():
		var found := _find_node_named(child, node_name)
		if found != null:
			return found
	return null

static func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

static func _find_button_named(node: Node, node_name: String) -> Button:
	if node is Button and String(node.name) == node_name:
		return node as Button
	for child in node.get_children():
		var found := _find_button_named(child, node_name)
		if found != null:
			return found
	return null

static func _find_button_parent_named(node: Node, text: String, parent_name: String) -> Button:
	if node is Button and (node as Button).text == text and node.get_parent() != null and String(node.get_parent().name) == parent_name:
		return node as Button
	for child in node.get_children():
		var found := _find_button_parent_named(child, text, parent_name)
		if found != null:
			return found
	return null

static func _node_ids(nodes: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for node in nodes:
		ids.append(String(node.get("node_id", "")))
	return ids

static func _first_node_id_of_type(run: RunStateScript, node_type: String) -> String:
	for node in run.route_nodes:
		if String(node.get("node_type", "")) == node_type:
			return String(node.get("node_id", ""))
	return ""
