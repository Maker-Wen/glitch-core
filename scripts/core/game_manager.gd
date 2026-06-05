extends Node2D
## Game entry point and fixed demo Run controller.

const BATTLE_SCENE := preload("res://Scenes/battle/BattleScene.tscn")
const RunStateScript := preload("res://scripts/run/run_state.gd")

const COLOR_BG := Color(0.035, 0.032, 0.040, 1.0)
const COLOR_PANEL := Color(0.070, 0.060, 0.066, 0.96)
const COLOR_PANEL_SOFT := Color(0.095, 0.080, 0.070, 0.94)
const COLOR_LINE := Color(0.62, 0.48, 0.30, 0.74)
const COLOR_TEXT := Color(0.92, 0.89, 0.82, 1.0)
const COLOR_MUTED := Color(0.62, 0.66, 0.70, 1.0)
const COLOR_DANGER := Color(0.96, 0.34, 0.30, 1.0)
const COLOR_AMBER := Color(1.00, 0.72, 0.34, 1.0)
const COLOR_GOOD := Color(0.48, 0.82, 0.56, 1.0)

var _run = null
var _ui: Control = null
var _battle: BattleScene = null
var _selected_reward_option_id: String = ""

func _ready() -> void:
	_show_main_menu()

func _clear_screen() -> void:
	if _battle != null:
		_battle.queue_free()
		_battle = null
	if _ui != null:
		_ui.queue_free()
		_ui = null

func _make_root() -> Control:
	_clear_screen()
	var root := Control.new()
	root.name = "RunUI"
	root.position = Vector2.ZERO
	root.size = get_viewport_rect().size
	add_child(root)
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = COLOR_BG
	root.add_child(bg)
	_ui = root
	return root

func _show_main_menu() -> void:
	var root := _make_root()
	_run = null if _run != null and _run.result_outcome != "" else _run
	var panel := _panel(root, Rect2(72, 72, 420, 410), COLOR_PANEL)
	_label(panel, "裂隙守夜", Rect2(32, 30, 370, 58), 42, COLOR_AMBER)
	_label(panel, "Demo Run · 固定路线肉鸽闭环", Rect2(34, 88, 350, 30), 17, COLOR_MUTED)
	_label(panel, "主菜单", Rect2(34, 142, 320, 32), 23, COLOR_TEXT)
	var summary := "暂无可继续 Run"
	if _run != null:
		var node: Dictionary = _run.next_unvisited_node()
		summary = "%s · 节点 %d / %d\n守护值 %d / %d   余烬 %d\n下一节点：%s" % [
			_run.chapter_name,
			_run.visited_nodes.size() + 1,
			_run.route_nodes.size(),
			_run.sanctuary_integrity,
			_run.sanctuary_integrity_max,
			_run.embers,
			node.get("title", "已完成"),
		]
	_label(panel, summary, Rect2(34, 180, 350, 76), 16, COLOR_MUTED)
	_button(panel, "新 Run", Rect2(34, 270, 178, 40), _on_new_run_pressed)
	var continue_btn := _button(panel, "继续 Run", Rect2(226, 270, 128, 40), _show_route)
	continue_btn.disabled = _run == null
	_button(panel, "图鉴", Rect2(34, 326, 94, 36), func(): _show_codex_placeholder())
	_button(panel, "设置", Rect2(142, 326, 94, 36), func(): _show_settings_placeholder())
	_button(panel, "退出", Rect2(250, 326, 94, 36), func(): get_tree().quit())

	var right := _panel(root, Rect2(528, 72, 580, 410), COLOR_PANEL_SOFT)
	_label(right, "本次实现流程", Rect2(28, 24, 460, 30), 24, COLOR_TEXT)
	_label(
		right,
		"主菜单 -> 新 Run -> 固定路线 -> 节点预览 -> 战斗 -> 结算 -> 奖励选择 -> 下一节点 -> Boss -> Run 结算",
		Rect2(28, 62, 512, 76),
		16,
		COLOR_MUTED,
	)
	_label(right, "Demo 固定为 1 章 6 节点，所有战斗都沿用当前棋盘战斗系统：布防、公开意图、撑到最大回合、防守建筑、奖励任务。", Rect2(28, 150, 512, 70), 16, COLOR_TEXT)
	var flow := _panel(right, Rect2(28, 248, 246, 82), COLOR_PANEL)
	_label(flow, "当前验证", Rect2(18, 12, 180, 22), 17, COLOR_AMBER)
	_label(flow, "完整 Run 闭环\n固定路线 + 战斗结算", Rect2(18, 38, 200, 36), 14, COLOR_MUTED)
	var rules := _panel(right, Rect2(294, 248, 246, 82), COLOR_PANEL)
	_label(rules, "战斗规则", Rect2(18, 12, 180, 22), 17, COLOR_AMBER)
	_label(rules, "公开意图\n守住建筑到最大回合", Rect2(18, 38, 200, 36), 14, COLOR_MUTED)

func _on_new_run_pressed() -> void:
	_run = RunStateScript.new()
	_run.setup_new_demo()
	_show_prep()

func _show_prep() -> void:
	if _run == null:
		_on_new_run_pressed()
		return
	_run.phase = RunStateScript.Phase.PREP
	var root := _make_root()
	_add_top_bar(root)
	_label(root, "新 Run · 固定队伍确认", Rect2(72, 96, 720, 40), 29, COLOR_AMBER)
	_label(root, "第一轮 Demo 使用固定三人队和固定路线，验证完整肉鸽 Run 闭环。", Rect2(72, 136, 760, 26), 17, COLOR_MUTED)
	var x := 72.0
	for w in _run.wardens:
		var card := _panel(root, Rect2(x, 190, 286, 176), COLOR_PANEL)
		_label(card, String(w.get("name", "")), Rect2(22, 20, 236, 30), 23, COLOR_TEXT)
		_label(card, String(w.get("role", "")), Rect2(22, 54, 236, 22), 16, COLOR_AMBER)
		_label(card, "HP %d / %d" % [int(w.get("hp", 0)), int(w.get("hp_max", 0))], Rect2(22, 92, 236, 24), 17, COLOR_TEXT)
		_label(card, _warden_rule_hint(String(w.get("warden_id", ""))), Rect2(22, 124, 236, 40), 14, COLOR_MUTED)
		x += 318.0
	_button(root, "出发", Rect2(72, 404, 160, 44), _show_route)
	_button(root, "返回主菜单", Rect2(252, 404, 150, 44), _show_main_menu)

func _show_route() -> void:
	if _run == null:
		_show_main_menu()
		return
	_run.phase = RunStateScript.Phase.ROUTE
	var root := _make_root()
	_add_top_bar(root)
	_label(root, "章节路线图 · %s" % _run.chapter_name, Rect2(60, 92, 560, 38), 29, COLOR_AMBER)
	_label(root, "固定路线 Demo：每次只开放下一节点，节点风险和压力在进战前公开。", Rect2(60, 130, 760, 24), 16, COLOR_MUTED)
	var next_node: Dictionary = _run.next_unvisited_node()
	var start_x := 54.0
	for i in range(_run.route_nodes.size()):
		var node: Dictionary = _run.route_nodes[i]
		var rect := Rect2(start_x + i * 184.0, 178, 160, 132)
		var color := COLOR_PANEL
		if bool(node.get("visited", false)):
			color = Color(0.045, 0.052, 0.048, 0.96)
		elif String(node.get("node_id", "")) == String(next_node.get("node_id", "")):
			color = Color(0.12, 0.085, 0.045, 0.97)
		var card := _panel(root, rect, color)
		_label(card, "%02d" % (i + 1), Rect2(14, 10, 48, 22), 17, COLOR_AMBER)
		_label(card, _node_type_text(String(node.get("node_type", ""))), Rect2(62, 10, 84, 22), 14, _node_type_color(String(node.get("node_type", ""))))
		_label(card, String(node.get("title", "")), Rect2(14, 38, 130, 28), 19, COLOR_TEXT)
		_label(card, "风险 %d / 5" % int(node.get("risk_level", 1)), Rect2(14, 72, 130, 20), 14, COLOR_MUTED)
		var status := "已完成" if bool(node.get("visited", false)) else ("可进入" if String(node.get("node_id", "")) == String(next_node.get("node_id", "")) else "锁定")
		_label(card, status, Rect2(14, 100, 130, 22), 14, COLOR_GOOD if status == "已完成" else COLOR_AMBER if status == "可进入" else COLOR_MUTED)
		if i < _run.route_nodes.size() - 1:
			_label(root, "->", Rect2(rect.position.x + 162, rect.position.y + 52, 34, 28), 22, COLOR_LINE)
	if next_node.is_empty():
		_button(root, "查看 Run 结算", Rect2(60, 342, 190, 42), _show_run_result)
	else:
		_button(root, "预览下一节点", Rect2(60, 342, 190, 42), func(): _select_node(String(next_node.get("node_id", ""))))
	_button(root, "主菜单", Rect2(270, 342, 132, 42), _show_main_menu)

func _select_node(node_id: String) -> void:
	_run.current_node_id = node_id
	_show_node_preview()

func _show_node_preview() -> void:
	if _run == null:
		_show_main_menu()
		return
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_route()
		return
	_run.phase = RunStateScript.Phase.NODE_PREVIEW
	var root := _make_root()
	_add_top_bar(root)
	_label(root, "节点预览", Rect2(72, 92, 420, 36), 28, COLOR_AMBER)
	var panel := _panel(root, Rect2(72, 138, 520, 392), COLOR_PANEL)
	_label(panel, String(node.get("title", "")), Rect2(26, 22, 440, 38), 29, COLOR_TEXT)
	_label(panel, _node_type_text(String(node.get("node_type", ""))), Rect2(28, 66, 220, 24), 17, _node_type_color(String(node.get("node_type", ""))))
	_label(panel, String(node.get("summary", "")), Rect2(28, 102, 450, 58), 16, COLOR_MUTED)
	_label(panel, "风险等级：%d / 5" % int(node.get("risk_level", 1)), Rect2(28, 184, 260, 24), 17, COLOR_TEXT)
	if _run.is_battle_node(node):
		_label(panel, "裂隙强度：%d" % int(node.get("rift_strength", 0)), Rect2(28, 214, 260, 24), 17, COLOR_TEXT)
		_label(panel, "基础奖励：%d 余烬" % int(node.get("base_embers", 0)), Rect2(28, 244, 260, 24), 17, COLOR_TEXT)
		var battle_config: Dictionary = node.get("battle", {})
		_label(panel, "回合数：%d" % int(battle_config.get("max_rounds", 5)), Rect2(28, 274, 260, 24), 17, COLOR_TEXT)
		_label(panel, "压力标签：%s" % ", ".join(node.get("pressure_tags", [])), Rect2(28, 306, 450, 52), 16, COLOR_AMBER)
	else:
		_label(panel, "影响类型：%s" % ", ".join(node.get("pressure_tags", [])), Rect2(28, 214, 430, 24), 17, COLOR_TEXT)
		_label(panel, _non_battle_preview_text(node), Rect2(28, 252, 450, 82), 16, COLOR_AMBER)
	var side := _panel(root, Rect2(620, 138, 420, 392), COLOR_PANEL_SOFT)
	_label(side, "出战状态", Rect2(26, 22, 320, 28), 23, COLOR_TEXT)
	var y := 64.0
	for w in _run.wardens:
		var alive := bool(w.get("alive", false))
		var line := "%s  HP %d/%d" % [String(w.get("name", "")), int(w.get("hp", 0)), int(w.get("hp_max", 0))]
		if not alive:
			line += "  已死亡"
		_label(side, line, Rect2(26, y, 350, 24), 16, COLOR_TEXT if alive else COLOR_DANGER)
		y += 30.0
	_label(side, "守护值损失、守卫者受伤和死亡会跨节点保留。奖励任务只改变奖励，不改变主胜负。", Rect2(26, 210, 350, 76), 15, COLOR_MUTED)
	_button(root, _node_action_text(String(node.get("node_type", ""))), Rect2(72, 560, 170, 44), _execute_current_node)
	_button(root, "返回路线", Rect2(262, 560, 150, 44), _show_route)

func _execute_current_node() -> void:
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_route()
		return
	if _run.is_battle_node(node):
		_start_battle_for_current_node()
		return
	match String(node.get("node_type", "")):
		RunStateScript.NODE_EVENT:
			_show_event_node()
		RunStateScript.NODE_CAMP:
			_show_camp_node()
		_:
			_run.mark_current_node_visited()
			_show_route()

func _start_battle_for_current_node() -> void:
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_route()
		return
	if not _run.is_battle_node(node):
		_execute_current_node()
		return
	_run.phase = RunStateScript.Phase.BATTLE
	_clear_screen()
	_battle = BATTLE_SCENE.instantiate()
	_battle.configure_battle(node, _run.wardens, _run.sanctuary_integrity, _run.sanctuary_integrity_max)
	_battle.battle_finished.connect(_on_battle_finished)
	add_child(_battle)

func _show_event_node() -> void:
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_route()
		return
	var root := _make_root()
	_add_top_bar(root)
	_label(root, "事件", Rect2(72, 92, 420, 38), 28, COLOR_AMBER)
	var panel := _panel(root, Rect2(72, 150, 470, 430), COLOR_PANEL)
	_label(panel, String(node.get("title", "")), Rect2(28, 26, 390, 36), 28, COLOR_TEXT)
	_label(panel, String(node.get("summary", "")), Rect2(30, 80, 390, 84), 17, COLOR_MUTED)
	_label(panel, "当前资源\n守护值 %d/%d\n余烬 %d\n腐化 %d" % [
		_run.sanctuary_integrity,
		_run.sanctuary_integrity_max,
		_run.embers,
		_run.corruption,
	], Rect2(30, 206, 390, 120), 18, COLOR_TEXT)
	var options_panel := _panel(root, Rect2(596, 150, 610, 430), COLOR_PANEL_SOFT)
	_label(options_panel, "选择 1 项", Rect2(26, 24, 320, 30), 24, COLOR_TEXT)
	var y := 74.0
	var event_data: Dictionary = node.get("event", {})
	for option in event_data.get("options", []):
		var card := _panel(options_panel, Rect2(26, y, 554, 96), COLOR_PANEL)
		_label(card, String(option.get("title", "")), Rect2(18, 12, 330, 26), 20, COLOR_AMBER)
		_label(card, String(option.get("description", "")), Rect2(18, 42, 360, 42), 15, COLOR_TEXT)
		_label(card, _effects_text(option.get("effects", [])), Rect2(386, 18, 132, 58), 14, COLOR_MUTED)
		var option_id := String(option.get("option_id", ""))
		_button(card, "确认", Rect2(468, 56, 78, 30), func(id := option_id): _resolve_event_choice(id))
		y += 112.0
	_button(root, "返回预览", Rect2(72, 610, 150, 48), _show_node_preview)

func _resolve_event_choice(option_id: String) -> void:
	_run.resolve_event_node(option_id)
	_show_route()

func _show_camp_node() -> void:
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_route()
		return
	var root := _make_root()
	_add_top_bar(root)
	_label(root, "营地", Rect2(72, 92, 420, 38), 28, COLOR_AMBER)
	var panel := _panel(root, Rect2(72, 150, 470, 430), COLOR_PANEL)
	_label(panel, String(node.get("title", "")), Rect2(28, 26, 390, 36), 28, COLOR_TEXT)
	_label(panel, String(node.get("summary", "")), Rect2(30, 80, 390, 84), 17, COLOR_MUTED)
	_label(panel, "守护值 %d / %d" % [_run.sanctuary_integrity, _run.sanctuary_integrity_max], Rect2(30, 184, 390, 28), 18, COLOR_AMBER)
	var y := 232.0
	for w in _run.wardens:
		_label(panel, "%s  HP %d/%d%s" % [
			String(w.get("name", "")),
			int(w.get("hp", 0)),
			int(w.get("hp_max", 0)),
			"" if bool(w.get("alive", false)) else "  已死亡",
		], Rect2(30, y, 390, 26), 17, COLOR_TEXT if bool(w.get("alive", false)) else COLOR_DANGER)
		y += 34.0
	var options_panel := _panel(root, Rect2(596, 150, 610, 430), COLOR_PANEL_SOFT)
	_label(options_panel, "选择 1 项", Rect2(26, 24, 320, 30), 24, COLOR_TEXT)
	var camp_data: Dictionary = node.get("camp", {})
	y = 86.0
	for option in camp_data.get("options", []):
		var card := _panel(options_panel, Rect2(26, y, 554, 112), COLOR_PANEL)
		_label(card, String(option.get("title", "")), Rect2(18, 14, 360, 28), 22, COLOR_AMBER)
		_label(card, String(option.get("description", "")), Rect2(18, 50, 360, 44), 16, COLOR_TEXT)
		_label(card, _effects_text(option.get("effects", [])), Rect2(390, 22, 132, 56), 14, COLOR_MUTED)
		var option_id := String(option.get("option_id", ""))
		_button(card, "确认", Rect2(468, 72, 78, 30), func(id := option_id): _resolve_camp_choice(id))
		y += 132.0
	_button(root, "返回预览", Rect2(72, 610, 150, 48), _show_node_preview)

func _resolve_camp_choice(option_id: String) -> void:
	_run.resolve_camp_node(option_id)
	_show_route()

func _on_battle_finished(summary: Dictionary) -> void:
	var node: Dictionary = _run.current_node()
	_run.apply_battle_resolution(summary)
	if _run.result_outcome == "defeat":
		_show_run_result()
		return
	var victory := bool(summary.get("victory", false))
	if not victory:
		if String(node.get("node_type", "")) == RunStateScript.NODE_BOSS and _run.sanctuary_integrity > 0 and _run.alive_warden_count() > 0:
			_run.last_resolution["boss_retry"] = true
			_show_resolution()
			return
		if _run.sanctuary_integrity > 0 and _run.alive_warden_count() > 0:
			_run.pending_reward.clear()
			_run.last_resolution["run_continue"] = true
			_show_resolution()
			return
		_run.result_outcome = "defeat"
		_show_run_result()
		return
	_run.pending_reward = _run.build_pending_reward(node, _run.last_resolution)
	_show_resolution()

func _show_resolution() -> void:
	_run.phase = RunStateScript.Phase.NODE_RESOLUTION
	var node: Dictionary = _run.current_node()
	var res: Dictionary = _run.last_resolution
	var root := _make_root()
	_add_top_bar(root)
	_label(root, "战后结算", Rect2(72, 92, 420, 38), 28, COLOR_AMBER)
	var panel := _panel(root, Rect2(72, 150, 560, 430), COLOR_PANEL)
	var victory := bool(res.get("victory", false))
	var title := "胜利" if victory else "Boss 溃败，可重试" if bool(res.get("boss_retry", false)) else "防线溃败，Run 继续" if bool(res.get("run_continue", false)) else "失败"
	_label(panel, "%s · %s" % [String(node.get("title", "")), title], Rect2(28, 26, 500, 38), 28, COLOR_GOOD if victory else COLOR_DANGER)
	_label(panel, "主目标：撑到最大回合并至少 1 名守卫者存活", Rect2(30, 80, 500, 24), 17, COLOR_TEXT)
	_label(panel, "保护目标被毁：%d   建筑总受伤：%d" % [int(res.get("destroyed_protected_count", 0)), int(res.get("protected_damage_taken", 0))], Rect2(30, 118, 500, 24), 17, COLOR_TEXT)
	_label(panel, "守护值变化：-%d   当前 %d / %d" % [int(res.get("sanctuary_loss", 0)), _run.sanctuary_integrity, _run.sanctuary_integrity_max], Rect2(30, 154, 500, 24), 17, COLOR_AMBER if int(res.get("sanctuary_loss", 0)) == 0 else COLOR_DANGER)
	_label(panel, "奖励任务完成：%d / 3" % int(res.get("completed_reward_count", 0)), Rect2(30, 190, 500, 24), 17, COLOR_TEXT)
	var y := 236.0
	for w in _run.wardens:
		var color := COLOR_TEXT if bool(w.get("alive", false)) else COLOR_DANGER
		_label(panel, "%s  HP %d/%d%s" % [
			String(w.get("name", "")),
			int(w.get("hp", 0)),
			int(w.get("hp_max", 0)),
			"" if bool(w.get("alive", false)) else "  已死亡",
		], Rect2(30, y, 500, 24), 16, color)
		y += 30.0
	if bool(res.get("boss_retry", false)):
		_button(root, "重试 Boss", Rect2(72, 610, 160, 48), _show_node_preview)
	else:
		var next_text := "领取奖励" if not _run.pending_reward.is_empty() else "继续路线"
		_button(root, next_text, Rect2(72, 610, 160, 48), _show_reward)
	_button(root, "返回主菜单", Rect2(252, 610, 150, 48), _show_main_menu)

func _show_reward() -> void:
	if _run.pending_reward.is_empty():
		_after_reward_claimed()
		return
	_run.phase = RunStateScript.Phase.REWARD
	_selected_reward_option_id = ""
	var root := _make_root()
	_add_top_bar(root)
	_label(root, "奖励选择", Rect2(72, 92, 420, 38), 28, COLOR_AMBER)
	var reward: Dictionary = _run.pending_reward
	var fixed_panel := _panel(root, Rect2(72, 148, 370, 420), COLOR_PANEL)
	_label(fixed_panel, "固定奖励", Rect2(26, 24, 280, 30), 24, COLOR_TEXT)
	var fy := 78.0
	for fr in reward.get("fixed_rewards", []):
		_label(fixed_panel, "+%d %s · %s" % [
			int(fr.get("amount", 0)),
			"余烬" if String(fr.get("reward_type", "")) == "embers" else String(fr.get("reward_type", "")),
			String(fr.get("reason", "")),
		], Rect2(28, fy, 318, 28), 17, COLOR_AMBER)
		fy += 34.0
	_label(fixed_panel, "当前余烬：%d\n当前守护值：%d / %d\n遗物数量：%d" % [
		_run.embers,
		_run.sanctuary_integrity,
		_run.sanctuary_integrity_max,
		_run.relics.size(),
	], Rect2(28, 250, 318, 96), 17, COLOR_MUTED)

	var choice_panel := _panel(root, Rect2(486, 148, 740, 420), COLOR_PANEL_SOFT)
	_label(choice_panel, "选择 1 项", Rect2(26, 24, 320, 30), 24, COLOR_TEXT)
	var options: Array = []
	for group in reward.get("choice_groups", []):
		options.append_array(group.get("options", []))
	var x := 28.0
	for option in options:
		var card := _panel(choice_panel, Rect2(x, 76, 220, 260), COLOR_PANEL)
		_label(card, String(option.get("title", "")), Rect2(18, 18, 184, 48), 20, COLOR_AMBER)
		_label(card, String(option.get("description", "")), Rect2(18, 78, 184, 104), 15, COLOR_TEXT)
		_label(card, ", ".join(option.get("tags", [])), Rect2(18, 190, 184, 26), 14, COLOR_MUTED)
		var option_id := String(option.get("option_id", ""))
		_button(card, "选择", Rect2(18, 222, 90, 34), func(id := option_id): _select_reward_option(id))
		x += 238.0
	if options.is_empty():
		_label(choice_panel, "本节点只有固定奖励。", Rect2(28, 92, 500, 30), 18, COLOR_MUTED)
	else:
		_button(choice_panel, "跳过换 3 余烬", Rect2(28, 352, 148, 36), func(): _select_reward_option("skip"))
	_button(root, "确认领取", Rect2(72, 610, 160, 48), _confirm_reward)
	_button(root, "返回结算", Rect2(252, 610, 150, 48), _show_resolution)

func _select_reward_option(option_id: String) -> void:
	_selected_reward_option_id = option_id
	_confirm_reward()

func _confirm_reward() -> void:
	if _run.pending_reward.is_empty():
		_after_reward_claimed()
		return
	var has_choices := false
	for group in _run.pending_reward.get("choice_groups", []):
		if not group.get("options", []).is_empty():
			has_choices = true
			break
	if has_choices and _selected_reward_option_id.is_empty():
		_selected_reward_option_id = String(_run.pending_reward.get("choice_groups", [])[0].get("options", [])[0].get("option_id", ""))
	_run.claim_pending_reward(_selected_reward_option_id)
	_after_reward_claimed()

func _after_reward_claimed() -> void:
	var node: Dictionary = _run.current_node()
	_run.mark_current_node_visited()
	if String(node.get("node_type", "")) == RunStateScript.NODE_BOSS or _run.is_route_complete():
		_run.result_outcome = "victory"
		_show_run_result()
	else:
		_show_route()

func _show_run_result() -> void:
	if _run == null:
		_show_main_menu()
		return
	_run.phase = RunStateScript.Phase.RUN_RESULT
	var root := _make_root()
	_add_top_bar(root)
	var victory: bool = _run.result_outcome == "victory"
	_label(root, "Run 结算", Rect2(82, 92, 420, 38), 30, COLOR_AMBER)
	var panel := _panel(root, Rect2(82, 156, 620, 420), COLOR_PANEL)
	_label(panel, "防线守住" if victory else "Run 失败", Rect2(30, 28, 500, 48), 36, COLOR_GOOD if victory else COLOR_DANGER)
	_label(panel, "%s · 完成节点 %d / %d" % [_run.chapter_name, _run.visited_nodes.size(), _run.route_nodes.size()], Rect2(32, 94, 520, 28), 18, COLOR_TEXT)
	_label(panel, "守护值 %d / %d   余烬 %d   腐化 %d" % [_run.sanctuary_integrity, _run.sanctuary_integrity_max, _run.embers, _run.corruption], Rect2(32, 136, 520, 28), 18, COLOR_AMBER)
	_label(panel, "遗物：%s" % _relic_summary(), Rect2(32, 178, 540, 52), 17, COLOR_MUTED)
	var y := 252.0
	for w in _run.wardens:
		_label(panel, "%s  HP %d/%d%s" % [
			String(w.get("name", "")),
			int(w.get("hp", 0)),
			int(w.get("hp_max", 0)),
			"" if bool(w.get("alive", false)) else "  已死亡",
		], Rect2(32, y, 540, 26), 17, COLOR_TEXT if bool(w.get("alive", false)) else COLOR_DANGER)
		y += 34.0
	_button(root, "再开一局", Rect2(82, 614, 150, 48), _on_new_run_pressed)
	_button(root, "主菜单", Rect2(252, 614, 130, 48), _show_main_menu)

func _show_codex_placeholder() -> void:
	var root := _make_root()
	_label(root, "图鉴", Rect2(86, 96, 420, 42), 30, COLOR_AMBER)
	_label(root, "Demo 版图鉴占位。当前重点是完整 Run 闭环。", Rect2(86, 164, 640, 32), 18, COLOR_TEXT)
	_button(root, "返回", Rect2(86, 240, 120, 44), _show_main_menu)

func _show_settings_placeholder() -> void:
	var root := _make_root()
	_label(root, "设置", Rect2(86, 96, 420, 42), 30, COLOR_AMBER)
	_label(root, "Demo 版设置占位。战斗快捷键沿用现有输入配置。", Rect2(86, 164, 640, 32), 18, COLOR_TEXT)
	_button(root, "返回", Rect2(86, 240, 120, 44), _show_main_menu)

func _add_top_bar(root: Control) -> void:
	var bar := _panel(root, Rect2(0, 0, 1280, 72), Color(0.045, 0.040, 0.050, 0.96), false)
	if _run == null:
		return
	_label(bar, "第 %d 章 · %s" % [_run.chapter_index, _run.chapter_name], Rect2(24, 18, 240, 26), 18, COLOR_AMBER)
	_label(bar, "守护值 %d/%d" % [_run.sanctuary_integrity, _run.sanctuary_integrity_max], Rect2(286, 18, 130, 26), 17, COLOR_TEXT)
	_label(bar, "余烬 %d" % _run.embers, Rect2(436, 18, 110, 26), 17, COLOR_TEXT)
	_label(bar, "腐化 %d" % _run.corruption, Rect2(556, 18, 110, 26), 17, COLOR_TEXT)
	_label(bar, "存活守卫者 %d / 3" % _run.alive_warden_count(), Rect2(676, 18, 180, 26), 17, COLOR_TEXT)
	_label(bar, "遗物 %d" % _run.relics.size(), Rect2(862, 18, 100, 26), 17, COLOR_TEXT)

func _panel(parent: Node, rect: Rect2, color: Color = COLOR_PANEL, border: bool = true) -> ColorRect:
	var p := ColorRect.new()
	p.position = rect.position
	p.size = rect.size
	p.color = color
	parent.add_child(p)
	if border:
		var b := ReferenceRect.new()
		b.anchor_right = 1.0
		b.anchor_bottom = 1.0
		b.offset_right = 0.0
		b.offset_bottom = 0.0
		b.border_width = 2.0
		b.border_color = COLOR_LINE
		b.editor_only = false
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(b)
	return p

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color = COLOR_TEXT) -> Label:
	var l := Label.new()
	l.position = rect.position
	l.size = rect.size
	l.text = text
	l.modulate = color
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = rect.size
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _node_type_text(node_type: String) -> String:
	match node_type:
		RunStateScript.NODE_ELITE:
			return "精英战"
		RunStateScript.NODE_BOSS:
			return "Boss"
		RunStateScript.NODE_EVENT:
			return "事件"
		RunStateScript.NODE_CAMP:
			return "营地"
	return "普通战"

func _node_type_color(node_type: String) -> Color:
	match node_type:
		RunStateScript.NODE_ELITE:
			return COLOR_DANGER
		RunStateScript.NODE_BOSS:
			return Color(1.0, 0.48, 0.26, 1.0)
		RunStateScript.NODE_EVENT:
			return COLOR_AMBER
		RunStateScript.NODE_CAMP:
			return COLOR_GOOD
	return COLOR_GOOD

func _node_action_text(node_type: String) -> String:
	match node_type:
		RunStateScript.NODE_EVENT:
			return "处理事件"
		RunStateScript.NODE_CAMP:
			return "进入营地"
	return "进入战斗"

func _non_battle_preview_text(node: Dictionary) -> String:
	match String(node.get("node_type", "")):
		RunStateScript.NODE_EVENT:
			var event_data: Dictionary = node.get("event", {})
			return "事件选项：%d 个。确认前会展示收益和代价。" % event_data.get("options", []).size()
		RunStateScript.NODE_CAMP:
			var camp_data: Dictionary = node.get("camp", {})
			return "营地选项：%d 个。每次营地只能选择 1 项，选择后不可返回本节点。" % camp_data.get("options", []).size()
	return "占位节点：确认后标记完成并回到路线图。"

func _effects_text(effects: Array) -> String:
	if effects.is_empty():
		return "无变化"
	var parts: Array[String] = []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var reward_type := String(effect.get("reward_type", ""))
		var amount := int(effect.get("amount", 0))
		var sign := "+" if amount >= 0 else ""
		match reward_type:
			"embers":
				parts.append("余烬 %s%d" % [sign, amount])
			"sanctuary_integrity":
				parts.append("守护值 %s%d" % [sign, amount])
			"corruption":
				parts.append("腐化 %s%d" % [sign, amount])
			"warden_hp":
				parts.append("存活守卫者 HP %s%d" % [sign, amount])
			_:
				parts.append("%s %s%d" % [reward_type, sign, amount])
	return "\n".join(parts)

func _warden_rule_hint(warden_id: String) -> String:
	match warden_id:
		"warden_bountyhunter":
			return "近战推击，负责把敌人撞离建筑。"
		"warden_graverobber":
			return "远程牵引，能把威胁拉出攻击线。"
		"warden_mage":
			return "远程推击，适合处理长线威胁。"
	return ""

func _relic_summary() -> String:
	if _run.relics.is_empty():
		return "无"
	var names: Array[String] = []
	for relic in _run.relics:
		names.append(String(relic.get("title", "遗物")))
	return ", ".join(names)
