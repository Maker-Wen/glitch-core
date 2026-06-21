extends RefCounted
## Focused coverage for the formal main menu -> hub -> mission flow wrapper.

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const RunStateScript := preload("res://scripts/run/run_state.gd")

static func run(tr) -> void:
	_test_mission_detail_does_not_mutate_current_node(tr)
	_test_confirm_mission_sets_current_node_and_enters_preview_target(tr)
	_test_after_reward_returns_to_mission_board_route_phase(tr)
	_test_run_continue_failure_returns_to_mission_board(tr)
	_test_battle_victory_routes_directly_to_reward(tr)
	_test_boss_failure_uses_retry_page(tr)
	_test_formal_menu_copy_has_no_demo_language(tr)
	_test_main_menu_action_hierarchy_and_continue_state(tr)
	_test_main_menu_has_no_decorative_reference_rects(tr)
	_test_new_run_enters_hub_before_expedition_table(tr)
	_test_hub_renders_only_current_main_nodes(tr)
	_test_mission_board_uses_commission_task_language(tr)
	_test_mission_detail_shows_task_goal_and_reward_preview(tr)
	_test_buttons_keep_practical_safe_size_and_focus(tr)
	_test_continue_from_stale_resolution_routes_to_reward(tr)
	_test_continue_from_reward_restores_reward(tr)
	_test_new_run_requires_overwrite_confirmation(tr)
	_test_event_camp_shop_back_returns_to_mission_detail(tr)
	_test_hub_return_opens_menu_panel(tr)

static func _make_manager_with_run() -> Node2D:
	var manager: Node2D = GameManagerScript.new()
	manager._run = RunStateScript.new()
	manager._run.setup_new_demo()
	return manager

static func _test_mission_detail_does_not_mutate_current_node(tr) -> void:
	var manager := _make_manager_with_run()
	var node_id := String(manager._run.available_route_nodes()[0].get("node_id", ""))
	manager._show_mission_detail(node_id)
	tr.assert_eq("mission detail leaves current node empty before confirm", manager._run.current_node_id, "")
	tr.assert_eq("mission detail enters node preview phase", manager._run.phase, RunStateScript.Phase.NODE_PREVIEW)
	manager.queue_free()

static func _test_confirm_mission_sets_current_node_and_enters_preview_target(tr) -> void:
	var manager := _make_manager_with_run()
	var node_id := String(manager._run.available_route_nodes()[0].get("node_id", ""))
	manager._confirm_mission(node_id)
	tr.assert_eq("confirm mission sets current node", manager._run.current_node_id, node_id)
	tr.assert_eq("confirm battle mission enters battle phase", manager._run.phase, RunStateScript.Phase.BATTLE)
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
	tr.assert_eq("victory enters debrief phase first", manager._run.phase, RunStateScript.Phase.NODE_RESOLUTION)
	tr.assert_true("victory builds pending reward", not manager._run.pending_reward.is_empty())
	var text := _collect_label_text(manager._ui)
	tr.assert_true("victory opens short debrief", text.find("战果短报") >= 0)
	tr.assert_true("victory debrief names completed commission", text.find("委托完成") >= 0)
	tr.assert_true("victory debrief has reward button", _find_button(manager._ui, "领取奖励") != null)
	_find_button(manager._ui, "领取奖励").pressed.emit()
	text = _collect_label_text(manager._ui)
	tr.assert_eq("victory continues to reward phase", manager._run.phase, RunStateScript.Phase.REWARD)
	tr.assert_true("victory opens reward page after debrief", text.find("奖励选择") >= 0)
	tr.assert_true("reward page carries compact battle result", text.find("委托完成") >= 0)
	tr.assert_true("reward page removes old resolution return", text.find("返回结算") == -1)
	tr.assert_true("victory does not render old resolution", text.find("战后结算") == -1)
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
	tr.assert_true("new run hub does not immediately show expedition table", text.find("断墙外远征地图") == -1)
	var gate := _find_button(manager._ui, "断墙远征门\n选择关卡地图")
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
	for label in ["断墙远征门", "布告板 / 任务选择"]:
		tr.assert_true("hub includes %s" % label, text.find(label) >= 0)
	for removed in ["守卫者召集处", "营地", "工坊", "图鉴", "补给", "远征进度", "进度 ", "腐化", "守护值", "设置", "主菜单"]:
		tr.assert_true("hub excludes %s" % removed, text.find(removed) == -1)
	tr.assert_true("hub has return entry", _find_button(manager._ui, "返回") != null)
	manager.queue_free()

static func _test_mission_board_uses_commission_task_language(tr) -> void:
	var manager := _make_manager_with_run()
	manager._show_mission_board()
	var text := _collect_label_text(manager._ui)
	tr.assert_true("mission board uses commission title", text.find("任务委托") >= 0)
	tr.assert_true("mission board explains refill", text.find("完成一个委托后") >= 0)
	tr.assert_true("mission card shows task-first type", text.find("防守委托") >= 0)
	tr.assert_true("normal mission previews differentiated reward", text.find("余烬 +7 · 成长机会") >= 0)
	tr.assert_true("mission board no longer says base reward", text.find("基础奖励") == -1)
	tr.assert_true("mission board no longer uses expedition map title", text.find("断墙远征图") == -1)
	manager.queue_free()

static func _test_mission_detail_shows_task_goal_and_reward_preview(tr) -> void:
	var manager := _make_manager_with_run()
	manager._show_mission_detail("outer_wall_01")
	var text := _collect_label_text(manager._ui)
	tr.assert_true("mission detail uses commission confirmation", text.find("委托确认") >= 0)
	tr.assert_true("mission detail shows task goal", text.find("任务目标：完成标准防守") >= 0)
	tr.assert_true("mission detail shows reward preview", text.find("奖励预览：基础余烬 +7") >= 0)
	tr.assert_true("mission detail shows bountyhunter current base hp", text.find("赏金猎人  HP 3/3  移动 2") >= 0)
	tr.assert_true("mission detail shows graverobber current base move", text.find("盗墓人  HP 2/2  移动 3") >= 0)
	tr.assert_true("mission detail says return hub not route", text.find("返回据点") >= 0)
	tr.assert_true("mission detail returns to commission board", text.find("返回任务布告") >= 0)
	tr.assert_true("mission detail no longer returns to expedition map", text.find("返回远征图") == -1)
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
	tr.assert_eq("continue stale resolution restores debrief phase", manager._run.phase, RunStateScript.Phase.NODE_RESOLUTION)
	tr.assert_eq("continue resolution keeps current node", manager._run.current_node_id, String(node.get("node_id", "")))
	tr.assert_eq("continue resolution keeps pending reward", String(manager._run.pending_reward.get("reward_id", "")), reward_id)
	tr.assert_true("continue stale resolution renders short debrief", _collect_label_text(manager._ui).find("战果短报") >= 0)
	_find_button(manager._ui, "领取奖励").pressed.emit()
	tr.assert_eq("continue stale resolution can enter reward phase", manager._run.phase, RunStateScript.Phase.REWARD)
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
	tr.assert_true("continue reward renders reward screen", _collect_label_text(manager._ui).find("奖励选择") >= 0)
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
	var gate := _find_button(manager._ui, "断墙远征门\n选择关卡地图")
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

static func _test_event_camp_shop_back_returns_to_mission_detail(tr) -> void:
	var manager := _make_manager_with_run()
	for case_data in [
		{"node_id": "extinguished_beacon_02", "show": "_show_event_node", "title": "熄灭的灯塔", "visited": ["outer_wall_01"]},
		{"node_id": "ember_camp_03", "show": "_show_camp_node", "title": "巡火营地", "visited": ["outer_wall_01", "extinguished_beacon_02", "quartermaster_cache_02"]},
		{"node_id": "quartermaster_cache_02", "show": "_show_shop_node", "title": "前线军需点", "visited": ["outer_wall_01"]},
	]:
		_reset_run_visits(manager._run)
		for visited_id in case_data.visited:
			manager._run.current_node_id = String(visited_id)
			manager._run.mark_current_node_visited()
		manager._run.current_node_id = String(case_data.node_id)
		manager.call(String(case_data.show))
		var back_button := _find_button(manager._ui, "返回任务详情")
		tr.assert_true("%s back button returns to detail" % String(case_data.show), back_button != null)
		back_button.pressed.emit()
		tr.assert_eq("%s keeps selected node for detail" % String(case_data.show), manager._run.current_node_id, String(case_data.node_id))
		tr.assert_eq("%s returns to node preview phase" % String(case_data.show), manager._run.phase, RunStateScript.Phase.NODE_PREVIEW)
		tr.assert_true("%s detail text visible" % String(case_data.show), _collect_label_text(manager._ui).find(String(case_data.title)) >= 0)
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

static func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null
