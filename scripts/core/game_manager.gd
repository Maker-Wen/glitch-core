extends Node2D
## Game entry point and roguelite Run controller.

const BATTLE_SCENE := preload("res://Scenes/battle/BattleScene.tscn")
const RunStateScript := preload("res://scripts/run/run_state.gd")
const MAIN_MENU_BACKGROUND_PATH := "res://art/ui/main_menu/main_menu_background_final_v2.jpg"
const MAIN_MENU_BACKGROUND_REGION := Rect2(1210, 0, 1542, 1536)
const BATTLE_DEBRIEF_PANEL_PATH := "res://art/ui/battle_result/battle_result_debrief_panel_gpt-image-2.png"
const HUB_BACKGROUND_PATH := "res://art/ui/hub/hub_broken_wall_gate_gpt_v1_16x9.png"

const COLOR_BG := Color(0.035, 0.032, 0.040, 1.0)
const COLOR_PANEL := Color(0.070, 0.060, 0.066, 0.96)
const COLOR_PANEL_SOFT := Color(0.095, 0.080, 0.070, 0.94)
const COLOR_LINE := Color(0.37, 0.25, 0.15, 0.62)
const COLOR_TEXT := Color(0.92, 0.89, 0.82, 1.0)
const COLOR_MUTED := Color(0.62, 0.66, 0.70, 1.0)
const COLOR_DANGER := Color(0.96, 0.34, 0.30, 1.0)
const COLOR_AMBER := Color(1.00, 0.72, 0.34, 1.0)
const COLOR_GOOD := Color(0.48, 0.82, 0.56, 1.0)
const COLOR_PARCHMENT := Color(0.78, 0.67, 0.48, 1.0)
const UI_SAFE_MARGIN := 56.0
const UI_BUTTON_MIN_HEIGHT := 48.0
const HUB_NODE_BROKEN_WALL_GATE := "broken_wall_gate"
const HUB_TITLE := "断墙据点"
const HUB_TITLE_RECT := Rect2(UI_SAFE_MARGIN + 6.0, 96, 360, 42)
const HUB_SUBTITLE_RECT := Rect2(UI_SAFE_MARGIN + 8.0, 140, 520, 28)
const HUB_SUMMARY_RECT := Rect2(UI_SAFE_MARGIN, 24, 1168, 56)
const HUB_RETURN_BUTTON_RECT := Rect2(UI_SAFE_MARGIN, 612, 144, UI_BUTTON_MIN_HEIGHT)
const HUB_RESULT_BUTTON_RECT := Rect2(220, 612, 156, UI_BUTTON_MIN_HEIGHT)
const HUB_GATE_HOTSPOT_RECT := Rect2(786, 340, 350, 116)
const HUB_VIEWPORT_RECT := Rect2(0, 0, 1280, 720)
const HUB_SILHOUETTE_RECT := Rect2(110, 210, 1040, 310)
const HUB_GROUND_RECT := Rect2(0, 520, 1280, 200)
const HUB_SKY_COLOR := Color(0.040, 0.032, 0.030, 1.0)
const HUB_WALL_COLOR := Color(0.075, 0.060, 0.052, 0.70)
const HUB_GROUND_COLOR := Color(0.025, 0.020, 0.018, 0.92)
const HUB_GATE_BUTTON_FILL := Color(0.105, 0.076, 0.052, 0.94)
const HUB_ART_GRADE_COLOR := Color(0.020, 0.016, 0.014, 0.30)

var _run = null
var _pending_overwrite_run = null
var _ui: Control = null
var _battle: BattleScene = null
var _selected_reward_option_id: String = ""
var _selecting_new_run_map: bool = false

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
	root.size = _ui_viewport_size()
	add_child(root)
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = COLOR_BG
	root.add_child(bg)
	_ui = root
	return root

func _ui_viewport_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	)

func _show_main_menu() -> void:
	var root := _make_root()
	_run = null if _run != null and _run.result_outcome != "" else _run
	if _pending_overwrite_run != null:
		_run = _pending_overwrite_run
		_pending_overwrite_run = null
	_sync_run_warden_base_stats()
	_selecting_new_run_map = false
	_add_main_menu_background(root)
	_add_main_menu_atmosphere_overlay(root)
	var panel := Control.new()
	panel.position = Vector2(70, 92)
	panel.size = Vector2(440, 500)
	root.add_child(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(panel, "裂隙守夜", Rect2(34, 34, 372, 62), 44, COLOR_AMBER)
	_label(panel, "RIFT NIGHT WATCH", Rect2(38, 112, 300, 22), 14, COLOR_MUTED)
	if _run != null:
		_label(panel, _run_summary_line(), Rect2(36, 164, 360, 86), 17, COLOR_MUTED)
	var continue_btn := _main_menu_button(panel, "继续守夜", Rect2(36, 286, 364, 58), _continue_run_pressed, true, _run == null)
	continue_btn.add_theme_font_size_override("font_size", 20)
	_main_menu_button(panel, "开始新局", Rect2(36, 358, 364, 58), _on_new_run_pressed, true).add_theme_font_size_override("font_size", 20)
	_main_menu_button(panel, "图鉴", Rect2(36, 468, 112, UI_BUTTON_MIN_HEIGHT), func(): _show_codex_placeholder(false), false)
	_main_menu_button(panel, "设置", Rect2(164, 468, 112, UI_BUTTON_MIN_HEIGHT), func(): _show_settings_placeholder(false), false)
	_main_menu_button(panel, "退出", Rect2(292, 468, 108, UI_BUTTON_MIN_HEIGHT), func(): get_tree().quit(), false)

func _on_new_run_pressed() -> void:
	if _run != null and _run.result_outcome == "":
		_show_new_run_confirm()
		return
	_pending_overwrite_run = null
	_selecting_new_run_map = true
	_show_hub()

func _confirm_new_run_overwrite() -> void:
	_pending_overwrite_run = _run
	_run = null
	_selecting_new_run_map = true
	_show_hub()

func _start_new_run_with_expedition(expedition_id: String) -> void:
	_selecting_new_run_map = false
	_pending_overwrite_run = null
	_run = RunStateScript.new()
	_run.setup_new_random_route(0, expedition_id)
	_sync_run_warden_base_stats()
	_show_mission_board()

func _continue_run_pressed() -> void:
	if _run == null:
		_show_main_menu()
		return
	match _run.phase:
		RunStateScript.Phase.NODE_RESOLUTION:
			_show_battle_debrief_or_recover()
		RunStateScript.Phase.REWARD:
			_show_reward()
		RunStateScript.Phase.NODE_PREVIEW:
			if not _run.current_node_id.is_empty():
				_show_mission_detail(_run.current_node_id)
			else:
				_show_hub()
		RunStateScript.Phase.BATTLE:
			if not _run.current_node_id.is_empty():
				_execute_current_node()
			else:
				_show_hub()
		_:
			_show_hub()

func _show_new_run_confirm() -> void:
	var root := _make_root()
	_add_main_menu_background(root)
	var panel := _panel(root, Rect2(360, 188, 560, 310), COLOR_PANEL)
	_label(panel, "覆盖当前存档？", Rect2(32, 30, 420, 42), 31, COLOR_DANGER)
	_label(panel, _run_summary_line(), Rect2(34, 94, 460, 86), 17, COLOR_TEXT)
	_label(panel, "当前进度尚未结算完成。覆盖后无法恢复。", Rect2(34, 190, 460, 28), 17, COLOR_MUTED)
	_button(panel, "覆盖并选远征", Rect2(34, 238, 174, UI_BUTTON_MIN_HEIGHT), _confirm_new_run_overwrite)
	_button(panel, "返回主菜单", Rect2(220, 238, 150, UI_BUTTON_MIN_HEIGHT), _show_main_menu)

func _show_expedition_table() -> void:
	var root := _make_root()
	_add_hub_backdrop(root)
	var map_panel := _panel(root, Rect2(72, 96, 760, 500), Color(0.108, 0.082, 0.058, 0.98))
	_label(map_panel, "断墙外远征地图", Rect2(28, 24, 360, 38), 31, COLOR_AMBER)
	_label(map_panel, "选择这一局 Run 的目的地。确认后会生成本局委托榜。", Rect2(30, 68, 620, 28), 17, COLOR_MUTED)
	_add_expedition_map_region(map_panel, "断墙外环", "标准 / 均衡", Rect2(110, 238, 170, 92), Color(0.33, 0.43, 0.22, 0.96), func(): _start_new_run_with_expedition(RunStateScript.EXPEDITION_BROKEN_WALL))
	_add_expedition_map_region(map_panel, "裂隙回廊", "高压 / 成长", Rect2(384, 156, 180, 96), Color(0.50, 0.22, 0.19, 0.96), func(): _start_new_run_with_expedition(RunStateScript.EXPEDITION_RIFT_CORRIDOR))
	_add_expedition_map_region(map_panel, "废弃军需线", "资源 / 补给", Rect2(420, 358, 200, 96), Color(0.23, 0.34, 0.48, 0.96), func(): _start_new_run_with_expedition(RunStateScript.EXPEDITION_SUPPLY_LINE))
	_label(map_panel, "裂谷", Rect2(248, 334, 120, 22), 15, Color(0.20, 0.12, 0.08, 0.80))
	_label(map_panel, "断墙", Rect2(118, 176, 120, 22), 15, Color(0.20, 0.12, 0.08, 0.80))
	_label(map_panel, "旧道", Rect2(584, 294, 120, 22), 15, Color(0.20, 0.12, 0.08, 0.80))

	var detail := _panel(root, Rect2(864, 126, 332, 410), COLOR_PANEL)
	_label(detail, "地图说明", Rect2(26, 28, 240, 32), 27, COLOR_AMBER)
	_label(detail, "断墙外环：默认路线，战斗、事件和整备均衡。", Rect2(28, 82, 270, 58), 17, COLOR_TEXT)
	_label(detail, "裂隙回廊：战斗密度更高，裂隙压力更明显，成长机会更多。", Rect2(28, 158, 270, 66), 17, COLOR_TEXT)
	_label(detail, "废弃军需线：商店和事件更多，更考验余烬规划。", Rect2(28, 242, 270, 58), 17, COLOR_TEXT)
	_label(detail, "选中地图后会直接打开本局委托榜。", Rect2(28, 330, 270, 42), 16, COLOR_MUTED)
	_button(root, "返回据点", Rect2(72, 622, 160, UI_BUTTON_MIN_HEIGHT), _show_hub)

func _show_hub() -> void:
	if not _can_show_hub():
		_show_main_menu()
		return
	_prepare_hub_state()
	var root := _make_root()
	_build_hub_scene(root)

func _can_show_hub() -> bool:
	return _run != null or _selecting_new_run_map

func _prepare_hub_state() -> void:
	if _run == null:
		return
	_sync_run_warden_base_stats()
	_run.phase = RunStateScript.Phase.ROUTE

func _build_hub_scene(root: Control) -> void:
	_add_hub_backdrop(root)
	_add_hub_summary(root)
	_add_hub_header(root)
	_add_hub_hotspots(root)
	_add_hub_footer_actions(root)

func _add_hub_header(root: Control) -> void:
	_label(root, HUB_TITLE, HUB_TITLE_RECT, 34, COLOR_AMBER)
	_label(root, _hub_subtitle(), HUB_SUBTITLE_RECT, 18, COLOR_TEXT)

func _hub_subtitle() -> String:
	if _run == null:
		return "选择关卡地图，确认下一次远征。"
	return "整队，确认下一次远征。"

func _add_hub_hotspots(root: Control) -> void:
	for node in _hub_nodes():
		_add_hub_hotspot(root, node)

func _add_hub_footer_actions(root: Control) -> void:
	_button(root, "返回", HUB_RETURN_BUTTON_RECT, _show_hub_return_panel)
	if _hub_should_show_result_button():
		_button(root, "查看结算", HUB_RESULT_BUTTON_RECT, _show_run_result)

func _hub_should_show_result_button() -> bool:
	return _run != null and _run.available_route_nodes().is_empty()

func _hub_nodes() -> Array[Dictionary]:
	if _run == null:
		return [_hub_gate_node("选择关卡地图", _show_expedition_table)]
	return [_hub_gate_node("布告板 / 任务选择", _show_mission_board)]

func _hub_gate_node(subtitle: String, action: Callable) -> Dictionary:
	return {
		"id": HUB_NODE_BROKEN_WALL_GATE,
		"title": "断墙远征门",
		"subtitle": subtitle,
		"rect": HUB_GATE_HOTSPOT_RECT,
		"action": action,
	}

func _show_hub_return_panel() -> void:
	var root := _make_root()
	_add_hub_backdrop(root)
	_add_hub_summary(root)
	var panel := _panel(root, Rect2(420, 220, 440, 230), COLOR_PANEL)
	_label(panel, "返回", Rect2(30, 28, 240, 34), 29, COLOR_AMBER)
	_label(panel, "离开据点并返回标题菜单？当前远征进度会保留。", Rect2(32, 82, 330, 58), 18, COLOR_TEXT)
	_button(panel, "返回标题", Rect2(32, 158, 140, UI_BUTTON_MIN_HEIGHT), _show_main_menu)
	_button(panel, "留在据点", Rect2(196, 158, 140, UI_BUTTON_MIN_HEIGHT), _show_hub)

func _show_mission_board() -> void:
	if _run == null:
		_show_expedition_table()
		return
	_sync_run_warden_base_stats()
	_run.phase = RunStateScript.Phase.ROUTE
	var root := _make_root()
	_add_hub_backdrop(root)
	_add_hub_summary(root)
	var panel := _panel(root, Rect2(96, 118, 1040, 470), Color(0.070, 0.056, 0.048, 0.97))
	_label(panel, "任务委托", Rect2(28, 24, 260, 34), 29, COLOR_AMBER)
	_label(panel, "%s 正在等待不同委托。完成一个委托后，榜单会补入新的可接任务。" % _run.expedition_name, Rect2(30, 64, 820, 26), 17, COLOR_MUTED)
	var cards_y := 118.0
	if not _run.last_route_notice.is_empty():
		_add_route_notice(panel, Rect2(30, 102, 980, 58), _run.last_route_notice)
		cards_y = 178.0
	var available: Array[Dictionary] = _run.available_route_nodes()
	if available.is_empty():
		_label(panel, "本章路线已完成。", Rect2(360, 214, 260, 30), 22, COLOR_TEXT)
		_button(panel, "查看 Run 结算", Rect2(392, 270, 180, UI_BUTTON_MIN_HEIGHT), _show_run_result)
	else:
		var card_w := 300.0
		var card_h := 136.0 if not _run.last_route_notice.is_empty() else 156.0
		for i in range(available.size()):
			var node: Dictionary = available[i]
			var col := i % 3
			var row := int(i / 3)
			_add_mission_card(panel, node, Rect2(30 + col * 326, cards_y + row * 154, card_w, card_h))
	_button(root, "返回据点", Rect2(96, 612, 150, UI_BUTTON_MIN_HEIGHT), _show_hub)

func _show_mission_detail(node_id: String) -> void:
	if _run == null:
		_show_main_menu()
		return
	_sync_run_warden_base_stats()
	var node: Dictionary = _run.node_by_id(node_id)
	if node.is_empty() or not _run.is_route_node_available(node_id):
		_show_mission_board()
		return
	_run.phase = RunStateScript.Phase.NODE_PREVIEW
	var root := _make_root()
	_add_hub_backdrop(root)
	_add_hub_summary(root)
	var panel := _panel(root, Rect2(120, 112, 1000, 500), Color(0.075, 0.057, 0.045, 0.98))
	_label(panel, "委托确认", Rect2(34, 26, 300, 36), 30, COLOR_AMBER)
	_label(panel, String(node.get("title", "")), Rect2(36, 78, 430, 44), 34, COLOR_TEXT)
	_label(panel, _mission_type_title(node), Rect2(488, 86, 220, 28), 20, _mission_accent(String(node.get("node_type", ""))))
	_label(panel, _mission_summary_text(node), Rect2(38, 146, 560, 142), 18, COLOR_TEXT)
	var risk_panel := _panel(panel, Rect2(644, 76, 306, 240), Color(0.048, 0.040, 0.038, 0.98))
	_label(risk_panel, "风险刻度  %s" % _risk_marks(int(node.get("risk_level", 1))), Rect2(22, 22, 260, 28), 20, COLOR_AMBER)
	_label(risk_panel, "队伍状态  %d / 3\n守护值  %d / %d\n余烬  %d\n腐化  %d" % [
		_run.alive_warden_count(),
		_run.sanctuary_integrity,
		_run.sanctuary_integrity_max,
		_run.embers,
		_run.corruption,
	], Rect2(22, 68, 250, 128), 18, COLOR_TEXT)
	if _mission_is_high_risk(node):
		_label(risk_panel, "警告：当前战力进入高风险任务。", Rect2(22, 194, 254, 30), 16, COLOR_DANGER)
	_label(panel, "守卫者", Rect2(38, 314, 240, 28), 22, COLOR_AMBER)
	var y := 354.0
	for w in _run.wardens:
		_label(panel, _warden_status_text(w), Rect2(42, y, 500, 28), 17, COLOR_TEXT if bool(w.get("alive", false)) else COLOR_DANGER)
		y += 34.0
	_button(panel, "开始任务", Rect2(646, 386, 164, UI_BUTTON_MIN_HEIGHT), func(id := node_id): _confirm_mission(id))
	_button(panel, "返回据点", Rect2(832, 386, 140, UI_BUTTON_MIN_HEIGHT), func(id := node_id): _cancel_mission_and_show_hub(id))
	_button(root, "返回任务布告", Rect2(120, 628, 174, UI_BUTTON_MIN_HEIGHT), _show_mission_board)

func _cancel_mission_and_show_hub(node_id: String) -> void:
	if _run != null and _run.current_node_id == node_id:
		_run.current_node_id = ""
	_show_hub()

func _confirm_mission(node_id: String) -> void:
	if _run == null:
		_show_main_menu()
		return
	if not _run.is_route_node_available(node_id):
		_show_mission_board()
		return
	_run.current_node_id = node_id
	_execute_current_node()

func _execute_current_node() -> void:
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_hub()
		return
	if _run.is_battle_node(node):
		_start_battle_for_current_node()
		return
	match String(node.get("node_type", "")):
		RunStateScript.NODE_EVENT:
			_show_event_node()
		RunStateScript.NODE_CAMP:
			_show_camp_node()
		RunStateScript.NODE_SHOP:
			_show_shop_node()
		_:
			_run.mark_current_node_visited()
			_show_hub()

func _start_battle_for_current_node() -> void:
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_hub()
		return
	if not _run.is_battle_node(node):
		_execute_current_node()
		return
	_sync_run_warden_base_stats()
	_run.phase = RunStateScript.Phase.BATTLE
	_clear_screen()
	_battle = BATTLE_SCENE.instantiate()
	_battle.configure_battle(node, _run.wardens, _run.sanctuary_integrity, _run.sanctuary_integrity_max)
	_battle.battle_finished.connect(_on_battle_finished)
	add_child(_battle)

func _show_event_node() -> void:
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_hub()
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
	_button(root, "返回任务详情", Rect2(72, 610, 150, 48), _return_to_current_mission_detail)

func _resolve_event_choice(option_id: String) -> void:
	_run.resolve_event_node(option_id)
	_show_hub()

func _show_camp_node() -> void:
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_hub()
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
		_label(panel, _warden_status_text(w), Rect2(30, y, 410, 26), 17, COLOR_TEXT if bool(w.get("alive", false)) else COLOR_DANGER)
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
	_button(root, "返回任务详情", Rect2(72, 610, 150, 48), _return_to_current_mission_detail)

func _resolve_camp_choice(option_id: String) -> void:
	_run.resolve_camp_node(option_id)
	_show_hub()

func _show_shop_node() -> void:
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_hub()
		return
	var root := _make_root()
	_add_top_bar(root)
	_label(root, "商店行动", Rect2(72, 92, 420, 38), 28, COLOR_AMBER)
	var panel := _panel(root, Rect2(72, 150, 470, 430), COLOR_PANEL)
	_label(panel, String(node.get("title", "")), Rect2(28, 26, 390, 36), 28, COLOR_TEXT)
	_label(panel, String(node.get("summary", "")), Rect2(30, 80, 390, 86), 17, COLOR_MUTED)
	_label(panel, "商店会消耗 1 个战略 tick，且不会压制任何前线。", Rect2(30, 188, 390, 52), 17, COLOR_DANGER)
	_label(panel, "当前余烬：%d\n守护值：%d / %d" % [
		_run.embers,
		_run.sanctuary_integrity,
		_run.sanctuary_integrity_max,
	], Rect2(30, 270, 390, 72), 18, COLOR_TEXT)
	var options_panel := _panel(root, Rect2(596, 150, 610, 430), COLOR_PANEL_SOFT)
	_label(options_panel, "购买 1 项", Rect2(26, 24, 320, 30), 24, COLOR_TEXT)
	var y := 74.0
	var shop_data: Dictionary = node.get("shop", {})
	for option in shop_data.get("options", []):
		var card := _panel(options_panel, Rect2(26, y, 554, 96), COLOR_PANEL)
		_label(card, String(option.get("title", "")), Rect2(18, 12, 330, 26), 20, COLOR_AMBER)
		_label(card, String(option.get("description", "")), Rect2(18, 42, 360, 42), 15, COLOR_TEXT)
		_label(card, _effects_text(option.get("effects", [])), Rect2(386, 18, 132, 58), 14, COLOR_MUTED)
		var option_id := String(option.get("option_id", ""))
		var buy_button := _button(card, "购买", Rect2(468, 56, 78, 30), func(id := option_id): _resolve_shop_choice(id))
		buy_button.disabled = not _run.can_afford_effects(option.get("effects", []))
		y += 112.0
	_button(root, "返回任务详情", Rect2(72, 610, 150, 48), _return_to_current_mission_detail)

func _return_to_current_mission_detail() -> void:
	if _run == null or _run.current_node_id.is_empty():
		_show_hub()
		return
	_show_mission_detail(_run.current_node_id)

func _resolve_shop_choice(option_id: String) -> void:
	_run.resolve_shop_node(option_id)
	_show_hub()

func _add_main_menu_background(root: Control) -> void:
	var background := TextureRect.new()
	background.name = "MainMenuBackground"
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.texture = _load_main_menu_background_texture()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

func _add_main_menu_atmosphere_overlay(root: Control) -> void:
	_decor_rect(root, Rect2(0, 0, 1280, 720), Color(0.025, 0.018, 0.014, 0.12))

func _load_main_menu_background_texture() -> Texture2D:
	var source := ResourceLoader.load(MAIN_MENU_BACKGROUND_PATH) as Texture2D
	if source == null:
		return null
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = MAIN_MENU_BACKGROUND_REGION
	return cropped

func _decor_rect(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var decoration := ColorRect.new()
	decoration.position = rect.position
	decoration.size = rect.size
	decoration.color = color
	decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(decoration)
	return decoration

func _add_hub_backdrop(root: Control) -> void:
	if _add_hub_art_backdrop(root):
		return
	var sky := _panel(root, HUB_VIEWPORT_RECT, HUB_SKY_COLOR, false)
	sky.name = "HubBackdrop"
	_add_hub_wall_blocks(sky)
	_add_hub_silhouette(root, HUB_SILHOUETTE_RECT)
	_decor_rect(root, HUB_GROUND_RECT, HUB_GROUND_COLOR).name = "HubGround"

func _add_hub_art_backdrop(root: Control) -> bool:
	var texture := _load_texture_from_path(HUB_BACKGROUND_PATH)
	if texture == null:
		return false
	var background := TextureRect.new()
	background.name = "HubArtBackdrop"
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	_decor_rect(root, HUB_VIEWPORT_RECT, HUB_ART_GRADE_COLOR).name = "HubArtGrade"
	return true

func _add_hub_wall_blocks(parent: Control) -> void:
	for i in range(6):
		var wall := _decor_rect(parent, _hub_wall_rect(i), HUB_WALL_COLOR)
		wall.name = "HubWallBlock%d" % i

func _hub_wall_rect(index: int) -> Rect2:
	return Rect2(
		74 + index * 178,
		236 - (index % 3) * 24,
		132,
		236 + (index % 2) * 52
	)

func _add_hub_silhouette(parent: Control, rect: Rect2) -> void:
	var fire := _decor_rect(parent, _hub_fire_rect(rect), Color(0.92, 0.42, 0.15, 0.32))
	fire.name = "HubFireGlow"
	var gate := ReferenceRect.new()
	var gate_rect := _hub_gate_frame_rect(rect)
	gate.name = "HubGateFrame"
	gate.position = gate_rect.position
	gate.size = gate_rect.size
	gate.border_width = 4.0
	gate.border_color = Color(0.55, 0.33, 0.16, 0.55)
	gate.editor_only = false
	gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gate)
	var floor := _decor_rect(parent, _hub_floor_rect(rect), Color(0.12, 0.075, 0.045, 0.42))
	floor.name = "HubWalkway"

func _hub_fire_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position + Vector2(rect.size.x * 0.46, rect.size.y * 0.54), Vector2(76, 118))

func _hub_gate_frame_rect(rect: Rect2) -> Rect2:
	return Rect2(
		rect.position + Vector2(rect.size.x * 0.70, rect.size.y * 0.18),
		Vector2(rect.size.x * 0.22, rect.size.y * 0.64)
	)

func _hub_floor_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position + Vector2(0, rect.size.y * 0.82), Vector2(rect.size.x, rect.size.y * 0.12))

func _add_hub_hotspot(root: Control, node: Dictionary) -> Button:
	var title := String(node.get("title", ""))
	var subtitle := String(node.get("subtitle", ""))
	var rect: Rect2 = node.get("rect", Rect2())
	var callback: Callable = node.get("action", Callable())
	var button := _button(root, "%s\n%s" % [title, subtitle], rect, callback)
	button.name = "HubHotspot_%s" % String(node.get("id", "unknown"))
	button.add_theme_font_size_override("font_size", 18)
	_apply_button_style(button, HUB_GATE_BUTTON_FILL, COLOR_AMBER, 3)
	return button

func _add_expedition_map_region(parent: Control, title: String, subtitle: String, rect: Rect2, color: Color, callback: Callable) -> Button:
	var button := _button(parent, "%s\n%s" % [title, subtitle], rect, callback)
	button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(button, color, COLOR_AMBER, 3)
	return button

func _add_hub_summary(root: Control) -> void:
	var bar := _panel(root, HUB_SUMMARY_RECT, Color(0.045, 0.038, 0.036, 0.96))
	bar.name = "HubSummary"
	if _run == null:
		_label(bar, "尚未选择关卡地图", Rect2(20, 15, 220, 26), 17, COLOR_TEXT)
		_label(bar, "断墙远征门等待确认目的地", Rect2(266, 15, 260, 26), 17, COLOR_MUTED)
		return
	_sync_run_warden_base_stats()
	_label(bar, "余烬 %d" % _run.embers, Rect2(20, 15, 112, 26), 17, COLOR_TEXT)
	_label(bar, "守卫者 %d / 3" % _run.alive_warden_count(), Rect2(166, 15, 154, 26), 17, COLOR_TEXT)

func _show_unavailable_hub_feature(feature_name: String) -> void:
	var root := _make_root()
	_add_hub_backdrop(root)
	var panel := _panel(root, Rect2(370, 210, 540, 220), COLOR_PANEL)
	_label(panel, feature_name, Rect2(32, 28, 320, 34), 29, COLOR_AMBER)
	_label(panel, "该据点入口已作为热点保留，第一版暂未开放完整系统。", Rect2(34, 88, 440, 60), 18, COLOR_TEXT)
	_button(panel, "返回据点", Rect2(34, 152, 144, UI_BUTTON_MIN_HEIGHT), _show_hub)

func _run_summary_line() -> String:
	if _run == null:
		return "暂无远征。"
	_sync_run_warden_base_stats()
	var next: Dictionary = _run.next_unvisited_node()
	var next_title := String(next.get("title", "已完成"))
	return "%s · 进度 %d/%d\n守护值 %d/%d   余烬 %d   腐化 %d\n下一任务：%s" % [
		_run.chapter_name,
		_run.visited_nodes.size(),
		_run.route_nodes.size(),
		_run.sanctuary_integrity,
		_run.sanctuary_integrity_max,
		_run.embers,
		_run.corruption,
		next_title,
	]

func _mission_card_tags(node: Dictionary) -> String:
	var tags: Array = node.get("pressure_tags", [])
	var text := " · ".join(tags.slice(0, 2))
	if text.is_empty():
		text = String(node.get("summary", ""))
	return text

func _add_mission_card(parent: Control, node: Dictionary, rect: Rect2) -> void:
	var node_type := String(node.get("node_type", ""))
	var card := _panel(parent, rect, Color(0.095, 0.072, 0.052, 0.98))
	var accent := _mission_accent(node_type)
	_label(card, String(node.get("title", "")), Rect2(18, 16, rect.size.x - 36, 30), 22, COLOR_TEXT)
	_label(card, _mission_type_title(node), Rect2(18, 50, 132, 24), 17, accent)
	_label(card, "风险 %s" % _risk_marks(int(node.get("risk_level", 1))), Rect2(156, 50, 120, 24), 16, COLOR_AMBER)
	_label(card, _mission_card_tags(node), Rect2(18, 80, rect.size.x - 36, 32), 15, COLOR_MUTED)
	_label(card, _mission_reward_preview(node), Rect2(18, rect.size.y - 34, 170, 24), 15, COLOR_PARCHMENT)
	var node_id := String(node.get("node_id", ""))
	_button(card, "查看详情", Rect2(rect.size.x - 118, rect.size.y - 48, 100, 40), func(id := node_id): _show_mission_detail(id))

func _add_route_notice(parent: Control, rect: Rect2, notice: Dictionary) -> void:
	var tone := String(notice.get("tone", "good"))
	var accent := COLOR_DANGER if tone == "danger" else COLOR_AMBER if tone == "warning" else COLOR_GOOD
	var bg := Color(0.090, 0.060, 0.048, 0.98) if tone == "danger" else Color(0.068, 0.058, 0.048, 0.98)
	var panel := _panel(parent, rect, bg)
	_label(panel, String(notice.get("title", "战果")), Rect2(18, 9, 150, 24), 20, accent)
	_label(panel, String(notice.get("summary", "")), Rect2(176, 10, 430, 22), 16, COLOR_TEXT)
	_label(panel, String(notice.get("details", "")), Rect2(176, 32, 560, 20), 14, COLOR_MUTED)
	_label(panel, String(notice.get("resource", "")), Rect2(758, 17, 190, 24), 16, accent)

func _add_reward_battle_strip(parent: Control, rect: Rect2) -> void:
	var node: Dictionary = _run.current_node()
	var res: Dictionary = _run.last_resolution
	var panel := _panel(parent, rect, Color(0.052, 0.046, 0.042, 0.98))
	_label(panel, "委托完成", Rect2(20, 13, 150, 30), 22, COLOR_GOOD)
	_label(panel, String(node.get("title", "")), Rect2(178, 12, 360, 24), 18, COLOR_TEXT)
	_label(panel, _battle_summary_line(res).replace("\n", "   "), Rect2(178, 40, 690, 20), 15, COLOR_MUTED)
	_label(panel, _pending_reward_fixed_summary(_run.pending_reward), Rect2(910, 22, 200, 24), 17, COLOR_AMBER)

func _route_notice_from_resolution(node: Dictionary, res: Dictionary) -> Dictionary:
	var victory := bool(res.get("victory", false))
	var run_continue := bool(res.get("run_continue", false))
	var boss_retry := bool(res.get("boss_retry", false))
	var title := "委托完成" if victory else "Boss 未压制" if boss_retry else "委托失利"
	var tone := "good" if victory else "warning" if boss_retry or run_continue else "danger"
	var outcome := "已领取战利品" if victory else "防线仍可继续推进" if run_continue else "可重试" if boss_retry else "任务结束"
	return {
		"title": title,
		"tone": tone,
		"summary": "%s · %s" % [String(node.get("title", "")), outcome],
		"details": "保护目标被毁 %d · 建筑受伤 %d · 奖励任务 %d/3" % [
			int(res.get("destroyed_protected_count", 0)),
			int(res.get("protected_damage_taken", 0)),
			int(res.get("completed_reward_count", 0)),
		],
		"resource": "守护值 -%d  %d/%d" % [
			int(res.get("sanctuary_loss", 0)),
			_run.sanctuary_integrity,
			_run.sanctuary_integrity_max,
		],
	}

func _battle_summary_line(res: Dictionary) -> String:
	return "保护目标被毁 %d · 建筑受伤 %d\n守护值 -%d · 奖励任务 %d/3" % [
		int(res.get("destroyed_protected_count", 0)),
		int(res.get("protected_damage_taken", 0)),
		int(res.get("sanctuary_loss", 0)),
		int(res.get("completed_reward_count", 0)),
	]

func _pending_reward_fixed_summary(reward: Dictionary) -> String:
	var embers := 0
	for fixed_reward in reward.get("fixed_rewards", []):
		if String(fixed_reward.get("reward_type", "")) == "embers":
			embers += int(fixed_reward.get("amount", 0))
	if embers <= 0:
		return "待领取奖励"
	return "待领取 余烬 +%d" % embers

func _mission_summary_text(node: Dictionary) -> String:
	var battle: Dictionary = node.get("battle", {})
	var rounds := int(battle.get("max_rounds", 0))
	var lines: Array[String] = []
	lines.append("任务目标：%s" % _mission_objective_text(node))
	lines.append(String(node.get("summary", "")))
	if rounds > 0:
		lines.append("回合数：撑到第 %d 回合，保护目标。" % rounds)
	else:
		lines.append("行动：处理据点外事务并返回据点。")
	lines.append("压力提示：%s" % _mission_card_tags(node))
	lines.append("奖励预览：%s" % _mission_reward_detail(node))
	return "\n".join(lines)

func _mission_type_title(node: Dictionary) -> String:
	var node_type := String(node.get("node_type", ""))
	var tags: Array = node.get("pressure_tags", [])
	match node_type:
		RunStateScript.NODE_ELITE:
			return "精英讨伐"
		RunStateScript.NODE_BOSS:
			return "Boss 压制"
		RunStateScript.NODE_EVENT:
			return "事件委托"
		RunStateScript.NODE_CAMP:
			return "整备委托"
		RunStateScript.NODE_SHOP:
			return "补给委托"
	if "裂隙压力" in tags:
		return "裂隙压制"
	if "堵路拥挤" in tags or "推撞连锁" in tags or "深渊边缘" in tags:
		return "清剿委托"
	return "防守委托"

func _mission_objective_text(node: Dictionary) -> String:
	var node_type := String(node.get("node_type", ""))
	match node_type:
		RunStateScript.NODE_ELITE:
			return "击退精英威胁，守住关键建筑并争取遗物。"
		RunStateScript.NODE_BOSS:
			return "压制锚石与心脏钟，撑过 Boss 毁灭脚本。"
		RunStateScript.NODE_EVENT:
			return "在公开收益和代价之间选择一项。"
		RunStateScript.NODE_CAMP:
			return "选择治疗小队或修复防线。"
		RunStateScript.NODE_SHOP:
			return "花费余烬购买治疗、修复或遗物。"
	if _mission_type_title(node) == "裂隙压制":
		return "处理地裂出怪压力，保护建筑到终局。"
	if _mission_type_title(node) == "清剿委托":
		return "利用推撞、挡线和地形化解密集威胁。"
	return "完成标准防守，撑到最大回合。"

func _mission_reward_preview(node: Dictionary) -> String:
	var node_type := String(node.get("node_type", ""))
	match node_type:
		RunStateScript.NODE_ELITE:
			return "余烬 +%d · 遗物" % int(node.get("base_embers", 0))
		RunStateScript.NODE_BOSS:
			return "余烬 +%d · 终局奖励" % int(node.get("base_embers", 0))
		RunStateScript.NODE_EVENT:
			return _option_preview(node, "event")
		RunStateScript.NODE_CAMP:
			return "治疗 / 修复二选一"
		RunStateScript.NODE_SHOP:
			return "消耗余烬 · 补给"
	return "余烬 +%d · 成长机会" % int(node.get("base_embers", 0))

func _mission_reward_detail(node: Dictionary) -> String:
	var node_type := String(node.get("node_type", ""))
	match node_type:
		RunStateScript.NODE_ELITE:
			return "基础余烬 +%d，胜利后出现遗物选择；奖励任务越多，选项和稀有权重越高。" % int(node.get("base_embers", 0))
		RunStateScript.NODE_BOSS:
			return "基础余烬 +%d，Boss 奖励任务和心脏钟命中会追加终局收益。" % int(node.get("base_embers", 0))
		RunStateScript.NODE_EVENT:
			return "事件选项会改变余烬、守护值、腐化或下一战状态。"
		RunStateScript.NODE_CAMP:
			return "免费整备，只能在治疗小队和修复防线中选择 1 项。"
		RunStateScript.NODE_SHOP:
			return "用当前余烬购买治疗、守护值修复或原型遗物。"
	return "基础余烬 +%d；奖励任务可追加余烬，并可能提供成长或防线修复机会。" % int(node.get("base_embers", 0))

func _option_preview(node: Dictionary, group_key: String) -> String:
	var group: Dictionary = node.get(group_key, {})
	var labels: Array[String] = []
	for option in group.get("options", []):
		if typeof(option) != TYPE_DICTIONARY:
			continue
		labels.append(String(option.get("title", "")))
		if labels.size() >= 2:
			break
	if labels.is_empty():
		return "公开取舍"
	return " / ".join(labels)

func _risk_marks(risk: int) -> String:
	var filled := clampi(risk, 1, 5)
	var marks := ""
	for i in range(5):
		marks += "■" if i < filled else "□"
	return "%s %d/5" % [marks, filled]

func _mission_accent(node_type: String) -> Color:
	if node_type == RunStateScript.NODE_ELITE or node_type == RunStateScript.NODE_BOSS:
		return COLOR_DANGER
	if node_type == RunStateScript.NODE_EVENT:
		return COLOR_PARCHMENT
	if node_type == RunStateScript.NODE_CAMP:
		return COLOR_GOOD
	return COLOR_AMBER

func _mission_is_high_risk(node: Dictionary) -> bool:
	return int(node.get("risk_level", 1)) >= 3 and (_run.alive_warden_count() < 3 or _run.sanctuary_integrity <= 3)

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
			_run.pending_reward.clear()
			_show_battle_debrief()
			return
		if _run.sanctuary_integrity > 0 and _run.alive_warden_count() > 0:
			_run.pending_reward.clear()
			_run.last_resolution["run_continue"] = true
			_show_battle_debrief()
			return
		_run.result_outcome = "defeat"
		_show_run_result()
		return
	_run.pending_reward = _run.build_pending_reward(node, _run.last_resolution)
	_show_battle_debrief()

func _show_battle_debrief_or_recover() -> void:
	if _run == null:
		_show_main_menu()
		return
	if not _run.last_resolution.is_empty():
		_show_battle_debrief()
		return
	if _run.result_outcome != "":
		_show_run_result()
		return
	if not _run.pending_reward.is_empty():
		_show_reward()
		return
	if _run.current_node_id.is_empty():
		_show_mission_board()
		return
	_complete_current_node_and_show_mission_board()

func _show_battle_debrief() -> void:
	if _run == null:
		_show_main_menu()
		return
	_run.phase = RunStateScript.Phase.NODE_RESOLUTION
	var node: Dictionary = _run.current_node()
	var res: Dictionary = _run.last_resolution
	var root := _make_root()
	_add_hub_backdrop(root)
	_add_top_bar(root)
	var rect := Rect2(164, 104, 952, 536)
	var panel := _debrief_art_panel(root, rect)
	var title := _debrief_title(res)
	var title_color := COLOR_GOOD if bool(res.get("victory", false)) else COLOR_DANGER if bool(res.get("boss_retry", false)) else COLOR_AMBER
	_label(panel, "战果短报", Rect2(70, 42, 220, 28), 20, COLOR_MUTED)
	_label(panel, title, Rect2(70, 72, 342, 42), 31, title_color)
	_label(panel, String(node.get("title", "当前委托")), Rect2(424, 60, 310, 30), 23, COLOR_TEXT)
	_label(panel, _debrief_subtitle(res), Rect2(424, 96, 360, 24), 16, COLOR_MUTED)
	_add_debrief_stat(panel, Rect2(120, 250, 200, 86), "守护值", _debrief_loss_value(int(res.get("sanctuary_loss", 0))), "%d / %d" % [_run.sanctuary_integrity, _run.sanctuary_integrity_max], COLOR_AMBER if int(res.get("sanctuary_loss", 0)) == 0 else COLOR_DANGER)
	_add_debrief_stat(panel, Rect2(376, 250, 200, 86), "目标损伤", "%d 被毁" % int(res.get("destroyed_protected_count", 0)), "建筑受伤 %d" % int(res.get("protected_damage_taken", 0)), COLOR_TEXT)
	_add_debrief_stat(panel, Rect2(632, 250, 200, 86), "奖励任务", "%d / 3" % int(res.get("completed_reward_count", 0)), _debrief_reward_line(), COLOR_GOOD if bool(res.get("victory", false)) else COLOR_MUTED)
	_button(panel, _debrief_primary_button_text(), Rect2(348, 426, 160, UI_BUTTON_MIN_HEIGHT), _continue_from_debrief)
	if bool(res.get("boss_retry", false)):
		_button(panel, "返回任务布告", Rect2(530, 426, 174, UI_BUTTON_MIN_HEIGHT), _return_boss_retry_to_mission_board)

func _debrief_art_panel(parent: Control, rect: Rect2) -> Control:
	var holder := Control.new()
	holder.position = rect.position
	holder.size = rect.size
	parent.add_child(holder)
	var texture := _load_debrief_panel_texture()
	if texture == null:
		_panel(holder, Rect2(Vector2.ZERO, rect.size), Color(0.075, 0.052, 0.045, 0.98))
		return holder
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.anchor_right = 1.0
	image.anchor_bottom = 1.0
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(image)
	return holder

func _load_debrief_panel_texture() -> Texture2D:
	var source := Image.new()
	var err := source.load(ProjectSettings.globalize_path(BATTLE_DEBRIEF_PANEL_PATH))
	if err != OK:
		return null
	return ImageTexture.create_from_image(source)

func _add_debrief_stat(parent: Control, rect: Rect2, title: String, value: String, detail: String, value_color: Color) -> void:
	_label(parent, title, Rect2(rect.position.x, rect.position.y, rect.size.x, 22), 17, COLOR_MUTED)
	_label(parent, value, Rect2(rect.position.x, rect.position.y + 28.0, rect.size.x, 32), 25, value_color)
	_label(parent, detail, Rect2(rect.position.x, rect.position.y + 62.0, rect.size.x, 22), 15, COLOR_TEXT)

func _debrief_title(res: Dictionary) -> String:
	if bool(res.get("victory", false)):
		return "委托完成"
	if bool(res.get("boss_retry", false)):
		return "Boss 未压制"
	return "委托失利"

func _debrief_loss_value(loss: int) -> String:
	if loss <= 0:
		return "0"
	return "-%d" % loss

func _debrief_subtitle(res: Dictionary) -> String:
	if bool(res.get("victory", false)):
		return "清点战利品，确认下一步。"
	if bool(res.get("boss_retry", false)):
		return "防线尚未崩溃，可以立即重试。"
	return "防线仍可运转，此委托将从榜单移除。"

func _debrief_reward_line() -> String:
	if _run.pending_reward.is_empty():
		return "无待领取奖励"
	return _pending_reward_fixed_summary(_run.pending_reward)

func _debrief_primary_button_text() -> String:
	if bool(_run.last_resolution.get("boss_retry", false)):
		return "重试 Boss"
	if not _run.pending_reward.is_empty():
		return "领取奖励"
	if _run.is_route_complete():
		return "查看 Run 结算"
	return "返回任务布告"

func _continue_from_debrief() -> void:
	if _run == null:
		_show_main_menu()
		return
	if bool(_run.last_resolution.get("boss_retry", false)):
		_start_battle_for_current_node()
		return
	if not _run.pending_reward.is_empty():
		_show_reward()
		return
	_run.last_route_notice = _route_notice_from_resolution(_run.current_node(), _run.last_resolution)
	_complete_current_node_and_show_mission_board()

func _return_boss_retry_to_mission_board() -> void:
	if _run != null:
		_run.last_resolution.erase("boss_retry")
		_run.current_node_id = ""
	_show_mission_board()

func _show_reward() -> void:
	if _run.pending_reward.is_empty():
		_after_reward_claimed()
		return
	_run.phase = RunStateScript.Phase.REWARD
	_selected_reward_option_id = ""
	var root := _make_root()
	_add_hub_backdrop(root)
	_add_top_bar(root)
	_label(root, "奖励选择", Rect2(72, 92, 420, 38), 28, COLOR_AMBER)
	var reward: Dictionary = _run.pending_reward
	_add_reward_battle_strip(root, Rect2(72, 136, 1154, 72))
	var fixed_panel := _panel(root, Rect2(72, 224, 370, 374), COLOR_PANEL)
	_label(fixed_panel, "固定奖励", Rect2(26, 24, 280, 30), 24, COLOR_TEXT)
	var fy := 78.0
	for fr in reward.get("fixed_rewards", []):
		_label(fixed_panel, "+%d %s · %s" % [
			int(fr.get("amount", 0)),
			"余烬" if String(fr.get("reward_type", "")) == "embers" else String(fr.get("reward_type", "")),
			String(fr.get("reason", "")),
		], Rect2(28, fy, 318, 24), 16, COLOR_AMBER)
		fy += 28.0
	if not reward.get("modifiers", []).is_empty():
		_label(fixed_panel, "奖励修正", Rect2(28, fy + 10.0, 318, 22), 17, COLOR_TEXT)
		fy += 38.0
		for modifier in reward.get("modifiers", []):
			_label(
				fixed_panel,
				"· %s" % String(modifier.get("description", "")),
				Rect2(28, fy, 318, 30),
				14,
				COLOR_MUTED
			)
			fy += 32.0
	_label(fixed_panel, "当前余烬：%d\n当前守护值：%d / %d\n遗物数量：%d" % [
		_run.embers,
		_run.sanctuary_integrity,
		_run.sanctuary_integrity_max,
		_run.relics.size(),
	], Rect2(28, minf(274.0, maxf(224.0, fy + 8.0)), 318, 96), 17, COLOR_MUTED)

	var choice_panel := _panel(root, Rect2(486, 224, 740, 374), COLOR_PANEL_SOFT)
	_label(choice_panel, "选择 1 项", Rect2(26, 24, 320, 30), 24, COLOR_TEXT)
	var options: Array = []
	for group in reward.get("choice_groups", []):
		options.append_array(group.get("options", []))
	var x := 28.0
	for option in options:
		var card := _panel(choice_panel, Rect2(x, 76, 220, 218), COLOR_PANEL)
		_label(card, String(option.get("title", "")), Rect2(18, 16, 184, 42), 19, COLOR_AMBER)
		_label(card, String(option.get("description", "")), Rect2(18, 70, 184, 86), 15, COLOR_TEXT)
		_label(card, ", ".join(option.get("tags", [])), Rect2(18, 164, 184, 24), 14, COLOR_MUTED)
		var option_id := String(option.get("option_id", ""))
		_button(card, "选择", Rect2(18, 184, 90, 34), func(id := option_id): _select_reward_option(id))
		x += 238.0
	if options.is_empty():
		_label(choice_panel, "本节点只有固定奖励。", Rect2(28, 92, 500, 30), 18, COLOR_MUTED)
	else:
		_button(choice_panel, "跳过换 3 余烬", Rect2(28, 312, 148, 36), func(): _select_reward_option("skip"))
	_button(root, "确认领取", Rect2(72, 610, 160, 48), _confirm_reward)

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
	_run.last_route_notice = _route_notice_from_resolution(node, _run.last_resolution)
	_run.mark_current_node_visited()
	if String(node.get("node_type", "")) == RunStateScript.NODE_BOSS or _run.is_route_complete():
		_run.result_outcome = "victory"
		_show_run_result()
	else:
		_show_mission_board()

func _complete_current_node_and_show_mission_board() -> void:
	if _run == null:
		_show_main_menu()
		return
	if not _run.current_node_id.is_empty():
		_run.mark_current_node_visited()
	if _run.is_route_complete():
		_show_run_result()
	else:
		_show_mission_board()

func _show_run_result() -> void:
	if _run == null:
		_show_main_menu()
		return
	_sync_run_warden_base_stats()
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
		_label(panel, _warden_status_text(w), Rect2(32, y, 540, 26), 17, COLOR_TEXT if bool(w.get("alive", false)) else COLOR_DANGER)
		y += 34.0
	_button(root, "再开一局", Rect2(82, 614, 150, 48), _on_new_run_pressed)
	_button(root, "主菜单", Rect2(252, 614, 130, 48), _show_main_menu)

func _show_codex_placeholder(return_to_hub: bool = false) -> void:
	var root := _make_root()
	_label(root, "图鉴", Rect2(86, 96, 420, 42), 30, COLOR_AMBER)
	_label(root, "图鉴入口已保留，第一版暂未开放完整资料库。", Rect2(86, 164, 640, 32), 18, COLOR_TEXT)
	_button(root, "返回据点" if return_to_hub else "返回", Rect2(86, 240, 120, 44), _show_hub if return_to_hub else _show_main_menu)

func _show_settings_placeholder(return_to_hub: bool = false) -> void:
	var root := _make_root()
	_label(root, "设置", Rect2(86, 96, 420, 42), 30, COLOR_AMBER)
	_label(root, "设置入口已保留，第一版沿用现有输入配置。", Rect2(86, 164, 640, 32), 18, COLOR_TEXT)
	_button(root, "返回据点" if return_to_hub else "返回", Rect2(86, 240, 120, 44), _show_hub if return_to_hub else _show_main_menu)

func _add_top_bar(root: Control) -> void:
	var bar := _panel(root, Rect2(0, 0, 1280, 72), Color(0.045, 0.040, 0.050, 0.96), false)
	if _run == null:
		return
	_sync_run_warden_base_stats()
	_label(bar, "第 %d 章 · %s" % [_run.chapter_index, _run.chapter_name], Rect2(24, 18, 240, 26), 18, COLOR_AMBER)
	_label(bar, "守护值 %d/%d" % [_run.sanctuary_integrity, _run.sanctuary_integrity_max], Rect2(286, 18, 130, 26), 17, COLOR_TEXT)
	_label(bar, "余烬 %d" % _run.embers, Rect2(436, 18, 110, 26), 17, COLOR_TEXT)
	_label(bar, "腐化 %d" % _run.corruption, Rect2(556, 18, 110, 26), 17, COLOR_TEXT)
	_label(bar, "存活守卫者 %d / 3" % _run.alive_warden_count(), Rect2(676, 18, 180, 26), 17, COLOR_TEXT)
	_label(bar, "遗物 %d" % _run.relics.size(), Rect2(862, 18, 100, 26), 17, COLOR_TEXT)

func _sync_run_warden_base_stats() -> void:
	if _run != null and _run.has_method("sync_warden_base_stats"):
		_run.sync_warden_base_stats()

func _warden_status_text(warden: Dictionary) -> String:
	var text := "%s  HP %d/%d  移动 %d" % [
		String(warden.get("name", "")),
		int(warden.get("hp", 0)),
		int(warden.get("hp_max", 0)),
		int(warden.get("move", 0)),
	]
	if not bool(warden.get("alive", false)):
		text += "  已死亡"
	return text

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
	b.size = Vector2(maxf(rect.size.x, 48.0), maxf(rect.size.y, UI_BUTTON_MIN_HEIGHT))
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(callback)
	_apply_button_style(b)
	parent.add_child(b)
	return b

func _main_menu_button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool, disabled: bool = false) -> Button:
	var shadow := ColorRect.new()
	shadow.position = rect.position + Vector2(5, 6)
	shadow.size = Vector2(maxf(rect.size.x, 48.0), maxf(rect.size.y, UI_BUTTON_MIN_HEIGHT))
	shadow.color = Color(0.0, 0.0, 0.0, 0.28 if primary else 0.20)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shadow)
	var button := Button.new()
	button.position = rect.position
	button.size = Vector2(maxf(rect.size.x, 48.0), maxf(rect.size.y, UI_BUTTON_MIN_HEIGHT))
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(96, UI_BUTTON_MIN_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18 if primary else 16)
	_apply_main_menu_button_style(button, primary)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_AMBER)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.50, 0.78))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _apply_main_menu_button_style(button: Button, primary: bool) -> void:
	var fill := Color(0.060, 0.052, 0.046, 0.96) if primary else Color(0.048, 0.043, 0.040, 0.90)
	var border := Color(0.84, 0.54, 0.24, 0.92) if primary else Color(0.50, 0.35, 0.21, 0.82)
	var hover_border := Color(1.00, 0.66, 0.28, 0.98)
	button.add_theme_stylebox_override("normal", _main_menu_button_stylebox(fill, border, primary, 0))
	button.add_theme_stylebox_override("hover", _main_menu_button_stylebox(fill.lightened(0.08), hover_border, primary, 1))
	button.add_theme_stylebox_override("pressed", _main_menu_button_stylebox(fill.darkened(0.10), border, primary, -1))
	button.add_theme_stylebox_override("disabled", _main_menu_button_stylebox(Color(0.040, 0.037, 0.035, 0.70), Color(0.24, 0.20, 0.16, 0.70), primary, 0))
	button.add_theme_stylebox_override("focus", _main_menu_button_stylebox(Color(0.076, 0.062, 0.050, 0.96), hover_border, primary, 1))

func _main_menu_button_stylebox(fill: Color, border: Color, primary: bool, state_offset: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	var base_border := 3 if primary else 2
	style.border_width_left = base_border
	style.border_width_top = base_border + 1
	style.border_width_right = base_border
	style.border_width_bottom = base_border + 3
	var radius := 12 if primary else 9
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 24 if primary else 16
	style.content_margin_right = 22 if primary else 15
	style.content_margin_top = 12 if primary else 10
	style.content_margin_bottom = 12 if primary else 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	style.shadow_size = 6 if primary else 4
	style.shadow_offset = Vector2(2, 3 + state_offset)
	return style

func _apply_button_style(button: Button, fill: Color = Color(0.12, 0.085, 0.055, 0.98), border: Color = COLOR_LINE, border_width: int = 2) -> void:
	button.custom_minimum_size = Vector2(96, UI_BUTTON_MIN_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	var normal := _button_stylebox(fill, border, border_width)
	var hover := _button_stylebox(fill.lightened(0.08), COLOR_AMBER, border_width + 1)
	var pressed := _button_stylebox(fill.darkened(0.08), border, border_width)
	var disabled := _button_stylebox(fill.darkened(0.16), Color(0.20, 0.16, 0.13, 0.70), border_width)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_AMBER)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.38, 0.80))

func _button_stylebox(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

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
			"relic":
				parts.append("获得遗物")
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
