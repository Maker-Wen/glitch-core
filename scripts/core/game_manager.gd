extends Node2D
## Game entry point and roguelite Run controller.

const BATTLE_SCENE := preload("res://Scenes/battle/BattleScene.tscn")
const RunStateScript := preload("res://scripts/run/run_state.gd")
const RewardListItemScript := preload("res://scripts/view/reward_list_item.gd")
const AudioManagerScript := preload("res://scripts/core/audio_manager.gd")
const MAIN_MENU_BACKGROUND_PATH := "res://art/ui/main_menu/main_menu_background_final_v2.jpg"
const MAIN_MENU_BACKGROUND_REGION := Rect2(1210, 0, 1542, 1536)
const BATTLE_DEBRIEF_PANEL_PATH := "res://art/ui/battle_result/battle_result_debrief_panel_gpt-image-2.png"
const HUB_BACKGROUND_PATH := "res://art/ui/hub/main_hub_multi_node_gpt_v1.png"
const EXPEDITION_MAP_BACKGROUND_PATH := "res://art/ui/expedition/expedition_tactical_map_gpt.png"

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
const HUB_NODE_WARDEN_CAMP := "warden_camp"
const HUB_NODE_WORKSHOP := "workshop"
const HUB_NODE_ARCHIVE := "archive"
const HUB_NODE_WAR_REPORT := "war_report"
const HUB_TITLE := "断墙据点"
const HUB_TITLE_RECT := Rect2(UI_SAFE_MARGIN + 6.0, 96, 360, 42)
const HUB_SUBTITLE_RECT := Rect2(UI_SAFE_MARGIN + 8.0, 140, 520, 28)
const HUB_SUMMARY_RECT := Rect2(UI_SAFE_MARGIN, 24, 1168, 56)
const HUB_RETURN_BUTTON_RECT := Rect2(UI_SAFE_MARGIN, 612, 144, UI_BUTTON_MIN_HEIGHT)
const HUB_RESULT_BUTTON_RECT := Rect2(220, 612, 156, UI_BUTTON_MIN_HEIGHT)
const HUB_GATE_HOTSPOT_RECT := Rect2(944, 358, 224, 86)
const HUB_CAMP_HOTSPOT_RECT := Rect2(74, 342, 196, 78)
const HUB_REPORT_HOTSPOT_RECT := Rect2(480, 436, 230, 82)
const HUB_WORKSHOP_HOTSPOT_RECT := Rect2(338, 268, 178, 70)
const HUB_ARCHIVE_HOTSPOT_RECT := Rect2(694, 248, 178, 70)
const HUB_SETTINGS_BUTTON_RECT := Rect2(1036, 612, 96, UI_BUTTON_MIN_HEIGHT)
const HUB_VIEWPORT_RECT := Rect2(0, 0, 1280, 720)
const HUB_SILHOUETTE_RECT := Rect2(110, 210, 1040, 310)
const HUB_GROUND_RECT := Rect2(0, 520, 1280, 200)
const HUB_SKY_COLOR := Color(0.040, 0.032, 0.030, 1.0)
const HUB_WALL_COLOR := Color(0.075, 0.060, 0.052, 0.70)
const HUB_GROUND_COLOR := Color(0.025, 0.020, 0.018, 0.92)
const HUB_GATE_BUTTON_FILL := Color(0.070, 0.046, 0.030, 0.72)
const HUB_ART_GRADE_COLOR := Color(0.020, 0.016, 0.014, 0.30)

var _run = null
var _pending_overwrite_run = null
var _ui: Control = null
var _battle: BattleScene = null
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
	_play_menu_bgm()
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
			_cancel_current_node_and_show_mission_board()
		RunStateScript.Phase.BATTLE:
			if not _run.current_node_id.is_empty():
				_execute_current_node()
			else:
				_show_mission_board()
		_:
			_show_mission_board()

func _continue_run_from_hub_status() -> void:
	if _run == null:
		_show_hub()
		return
	match _run.phase:
		RunStateScript.Phase.NODE_RESOLUTION:
			_show_battle_debrief_or_recover()
		RunStateScript.Phase.REWARD:
			_show_reward()
		RunStateScript.Phase.BATTLE:
			if not _run.current_node_id.is_empty():
				_execute_current_node()
			else:
				_show_mission_board()
		RunStateScript.Phase.NODE_PREVIEW:
			_cancel_current_node_and_show_mission_board()
		_:
			_show_mission_board()

func _show_new_run_confirm() -> void:
	_play_menu_bgm()
	var root := _make_root()
	_add_main_menu_background(root)
	var panel := _panel(root, Rect2(360, 188, 560, 310), COLOR_PANEL)
	_label(panel, "覆盖当前存档？", Rect2(32, 30, 420, 42), 31, COLOR_DANGER)
	_label(panel, _run_summary_line(), Rect2(34, 94, 460, 86), 17, COLOR_TEXT)
	_label(panel, "当前进度尚未结算完成。覆盖后无法恢复。", Rect2(34, 190, 460, 28), 17, COLOR_MUTED)
	_button(panel, "覆盖并选远征", Rect2(34, 238, 174, UI_BUTTON_MIN_HEIGHT), _confirm_new_run_overwrite)
	_button(panel, "返回主菜单", Rect2(220, 238, 150, UI_BUTTON_MIN_HEIGHT), _show_main_menu)

func _show_expedition_table() -> void:
	_play_menu_bgm()
	var root := _make_root()
	_add_hub_backdrop(root)
	_decor_rect(root, HUB_VIEWPORT_RECT, Color(0.010, 0.008, 0.007, 0.44))
	var map_panel := _panel(root, Rect2(38, 58, 1204, 552), Color(0.040, 0.034, 0.030, 0.97))
	_add_expedition_title_plate(map_panel, Rect2(34, 22, 390, 46))
	var sand_table := _add_expedition_map_backdrop(map_panel, Rect2(28, 74, 1148, 438))
	_add_expedition_route_path(sand_table, [Vector2(92, 316), Vector2(146, 300)])
	_add_expedition_route_path(sand_table, [Vector2(438, 236), Vector2(486, 158)])
	_add_expedition_route_path(sand_table, [Vector2(734, 328), Vector2(808, 328)])
	_add_expedition_map_region(sand_table, "断墙外环", "标准 / 均衡", Rect2(146, 252, 208, 92), Color(0.18, 0.27, 0.15, 0.97), "balanced", func(): _start_new_run_with_expedition(RunStateScript.EXPEDITION_BROKEN_WALL))
	_add_expedition_map_region(sand_table, "裂隙回廊", "高压 / 成长", Rect2(486, 78, 214, 94), Color(0.34, 0.13, 0.11, 0.97), "rift", func(): _start_new_run_with_expedition(RunStateScript.EXPEDITION_RIFT_CORRIDOR))
	_add_expedition_map_region(sand_table, "废弃军需线", "资源 / 补给", Rect2(808, 286, 236, 94), Color(0.13, 0.24, 0.34, 0.97), "supply", func(): _start_new_run_with_expedition(RunStateScript.EXPEDITION_SUPPLY_LINE))
	_label(sand_table, "断墙", Rect2(134, 162, 96, 22), 14, Color(0.84, 0.60, 0.34, 0.50))
	_label(sand_table, "裂谷", Rect2(564, 250, 96, 22), 14, Color(0.52, 0.78, 0.88, 0.48))
	_label(sand_table, "旧道", Rect2(934, 190, 96, 22), 14, Color(0.84, 0.60, 0.34, 0.46))
	_button(root, "返回据点", Rect2(72, 622, 160, UI_BUTTON_MIN_HEIGHT), _show_hub)

func _show_hub() -> void:
	if not _can_show_hub():
		_show_main_menu()
		return
	_play_menu_bgm()
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
	_add_hub_header(root)
	_add_hub_hotspots(root)
	_add_hub_footer_actions(root)

func _add_hub_header(root: Control) -> void:
	_label(root, HUB_TITLE, HUB_TITLE_RECT, 34, COLOR_AMBER)
	_label(root, _hub_subtitle(), HUB_SUBTITLE_RECT, 18, COLOR_TEXT)

func _hub_subtitle() -> String:
	if _run == null:
		return "选择远征区域，确认下一次远征。"
	return "整队，确认下一次远征。"

func _add_hub_hotspots(root: Control) -> void:
	for node in _hub_nodes():
		_add_hub_hotspot(root, node)

func _add_hub_footer_actions(root: Control) -> void:
	_button(root, "返回", HUB_RETURN_BUTTON_RECT, _show_hub_return_panel)
	_button(root, "设置", HUB_SETTINGS_BUTTON_RECT, func(): _show_settings_placeholder(true))
	if _hub_should_show_result_button():
		_button(root, "查看结算", HUB_RESULT_BUTTON_RECT, _show_run_result)

func _hub_should_show_result_button() -> bool:
	return _run != null and _run.available_commissions().is_empty()

func _hub_nodes() -> Array[Dictionary]:
	return [
		_hub_node(HUB_NODE_WARDEN_CAMP, "守卫者营帐", "队伍名册", HUB_CAMP_HOTSPOT_RECT, _show_warden_camp),
		_hub_node(HUB_NODE_WAR_REPORT, "篝火 / 战报台", _hub_report_subtitle(), HUB_REPORT_HOTSPOT_RECT, _show_hub_status_panel),
		_hub_node(HUB_NODE_BROKEN_WALL_GATE, "断墙远征门", "选择远征", HUB_GATE_HOTSPOT_RECT, _show_expedition_table),
		_hub_node(HUB_NODE_WORKSHOP, "工坊", "图纸与遗物", HUB_WORKSHOP_HOTSPOT_RECT, _show_workshop_placeholder),
		_hub_node(HUB_NODE_ARCHIVE, "档案馆", "敌人与规则", HUB_ARCHIVE_HOTSPOT_RECT, _show_archive_placeholder),
	]

func _hub_node(id: String, title: String, subtitle: String, rect: Rect2, action: Callable) -> Dictionary:
	return {
		"id": id,
		"title": title,
		"subtitle": subtitle,
		"rect": rect,
		"action": action,
	}

func _hub_report_subtitle() -> String:
	if _run == null:
		return "最近战报"
	return "继续远征"

func _show_hub_return_panel() -> void:
	_play_menu_bgm()
	var root := _make_root()
	_add_hub_backdrop(root)
	_add_hub_summary(root)
	var panel := _panel(root, Rect2(420, 220, 440, 230), COLOR_PANEL)
	_label(panel, "返回", Rect2(30, 28, 240, 34), 29, COLOR_AMBER)
	_label(panel, "离开据点并返回标题菜单？当前远征进度会保留。", Rect2(32, 82, 330, 58), 18, COLOR_TEXT)
	_button(panel, "返回标题", Rect2(32, 158, 140, UI_BUTTON_MIN_HEIGHT), _show_main_menu)
	_button(panel, "留在据点", Rect2(196, 158, 140, UI_BUTTON_MIN_HEIGHT), _show_hub)

func _show_hub_status_panel() -> void:
	_play_menu_bgm()
	if _run == null:
		_show_future_development_dialog("篝火 / 战报台")
		return
	var root := _make_root()
	_add_hub_backdrop(root)
	_add_hub_summary(root)
	var panel := _panel(root, Rect2(392, 180, 496, 318), COLOR_PANEL)
	_label(panel, "篝火 / 战报台", Rect2(30, 28, 300, 34), 29, COLOR_AMBER)
	_label(panel, _run_summary_line(), Rect2(32, 84, 420, 100), 18, COLOR_TEXT)
	_button(panel, "继续远征", Rect2(32, 226, 150, UI_BUTTON_MIN_HEIGHT), _continue_run_from_hub_status)
	_button(panel, "返回据点", Rect2(206, 226, 144, UI_BUTTON_MIN_HEIGHT), _show_hub)

func _show_warden_camp() -> void:
	_show_future_development_dialog("守卫者营帐")

func _show_workshop_placeholder() -> void:
	_show_future_development_dialog("工坊")

func _show_archive_placeholder() -> void:
	_show_future_development_dialog("档案馆")

func _show_future_development_dialog(title: String) -> void:
	_play_menu_bgm()
	if _ui == null:
		return
	_close_future_development_dialog()
	var dialog := Control.new()
	dialog.name = "FutureDevelopmentDialog"
	dialog.anchor_right = 1.0
	dialog.anchor_bottom = 1.0
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(dialog)
	var scrim := ColorRect.new()
	scrim.name = "FutureDevelopmentScrim"
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.color = Color(0.0, 0.0, 0.0, 0.42)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.add_child(scrim)
	var window := _panel(dialog, Rect2(454, 246, 372, 194), Color(0.040, 0.034, 0.032, 0.96))
	window.name = "FutureDevelopmentWindow"
	_label(window, title, Rect2(30, 26, 230, 30), 25, COLOR_AMBER)
	_label(window, "未来开发中", Rect2(32, 78, 240, 30), 20, COLOR_TEXT)
	var close_button := _button(window, "确定", Rect2(32, 124, 132, UI_BUTTON_MIN_HEIGHT), _close_future_development_dialog)
	close_button.name = "FutureDevelopmentClose"

func _close_future_development_dialog() -> void:
	if _ui == null:
		return
	var dialog := _ui.get_node_or_null("FutureDevelopmentDialog")
	if dialog == null:
		return
	_ui.remove_child(dialog)
	dialog.queue_free()

func _show_mission_board() -> void:
	_play_menu_bgm()
	if _run == null:
		_show_expedition_table()
		return
	_sync_run_warden_base_stats()
	_run.phase = RunStateScript.Phase.ROUTE
	var root := _make_root()
	_add_hub_backdrop(root)
	_add_mission_board_summary(root)
	var panel := _panel(root, Rect2(96, 112, 1040, 500), Color(0.070, 0.056, 0.048, 0.97))
	_label(panel, "任务委托", Rect2(28, 24, 260, 34), 29, COLOR_AMBER)
	_label(panel, "%s · 选择下一次行动" % _run.expedition_name, Rect2(30, 64, 520, 26), 17, COLOR_MUTED)
	var cards_y := 134.0
	if not _run.last_route_notice.is_empty():
		_add_route_notice(panel, Rect2(30, 98, 980, 58), _run.last_route_notice)
		cards_y = 172.0
	var available: Array[Dictionary] = _run.available_commissions()
	if available.is_empty():
		_label(panel, "本章路线已完成。", Rect2(360, 214, 260, 30), 22, COLOR_TEXT)
		_button(panel, "查看 Run 结算", Rect2(392, 270, 180, UI_BUTTON_MIN_HEIGHT), _show_run_result)
	else:
		var card_w := 306.0
		var card_h := 250.0
		for i in range(available.size()):
			var node: Dictionary = available[i]
			var col := i % 3
			var row := int(i / 3)
			_add_mission_card(panel, node, Rect2(30 + col * 326, cards_y + row * 268, card_w, card_h))

func _cancel_current_node_and_show_mission_board() -> void:
	if _run != null:
		_run.current_node_id = ""
	_show_mission_board()

func _start_mission_from_board(node_id: String) -> void:
	if _run == null:
		_show_main_menu()
		return
	if not _run.is_commission_available(node_id):
		_show_mission_board()
		return
	_run.current_node_id = node_id
	_execute_current_node()

func _execute_current_node() -> void:
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_mission_board()
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
			_show_mission_board()

func _start_battle_for_current_node() -> void:
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_mission_board()
		return
	if not _run.is_battle_node(node):
		_execute_current_node()
		return
	_sync_run_warden_base_stats()
	_run.phase = RunStateScript.Phase.BATTLE
	_play_battle_bgm()
	_clear_screen()
	_battle = BATTLE_SCENE.instantiate()
	_battle.configure_battle(node, _run.wardens, _run.sanctuary_integrity, _run.sanctuary_integrity_max)
	_battle.battle_finished.connect(_on_battle_finished)
	add_child(_battle)

func _show_event_node() -> void:
	_play_menu_bgm()
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_mission_board()
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
	_button(root, "返回任务布告", Rect2(72, 610, 150, 48), _cancel_current_node_and_show_mission_board)

func _resolve_event_choice(option_id: String) -> void:
	_run.resolve_event_node(option_id)
	_show_mission_board()

func _show_camp_node() -> void:
	_play_menu_bgm()
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_mission_board()
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
	_button(root, "返回任务布告", Rect2(72, 610, 150, 48), _cancel_current_node_and_show_mission_board)

func _resolve_camp_choice(option_id: String) -> void:
	_run.resolve_camp_node(option_id)
	_show_mission_board()

func _show_shop_node() -> void:
	_play_menu_bgm()
	var node: Dictionary = _run.current_node()
	if node.is_empty():
		_show_mission_board()
		return
	var root := _make_root()
	_add_hub_backdrop(root)
	_decor_rect(root, HUB_VIEWPORT_RECT, Color(0.010, 0.007, 0.005, 0.48))
	_add_top_bar(root)
	_label(root, "商店行动", Rect2(72, 92, 420, 38), 28, COLOR_AMBER)
	var shop_panel := _panel(root, Rect2(72, 142, 1136, 448), Color(0.052, 0.041, 0.035, 0.985))
	shop_panel.name = "ShopStallPanel"
	_add_shop_panel_decoration(shop_panel, Vector2(1136, 448))
	_label(shop_panel, String(node.get("title", "")), Rect2(36, 26, 360, 40), 31, COLOR_TEXT)
	_label(shop_panel, "封存的军需箱仍带着余温。", Rect2(404, 36, 360, 26), 17, COLOR_MUTED)
	_label(shop_panel, "购买 1 项", Rect2(940, 34, 150, 28), 20, COLOR_AMBER)
	_add_shop_resource_strip(shop_panel, Rect2(34, 84, 1068, 58))
	_add_shop_shelf_frame(shop_panel, Rect2(30, 160, 1076, 246))
	var shop_data: Dictionary = node.get("shop", {})
	var options: Array = shop_data.get("options", [])
	var card_w := 328.0
	var gap := 30.0
	for option in shop_data.get("options", []):
		var index := options.find(option)
		var option_id := String(option.get("option_id", ""))
		var effects: Array = option.get("effects", [])
		var can_afford: bool = _run.can_afford_effects(effects)
		var card_rect := Rect2(54 + index * (card_w + gap), 178, card_w, 206)
		_add_shop_stall_card(shop_panel, card_rect, option, can_afford, func(id := option_id): _resolve_shop_choice(id))
	_button(root, "返回任务布告", Rect2(72, 610, 150, 48), _cancel_current_node_and_show_mission_board)

func _resolve_shop_choice(option_id: String) -> void:
	_run.resolve_shop_node(option_id)
	_show_mission_board()

func _add_shop_panel_decoration(parent: Control, size: Vector2) -> void:
	_decor_rect(parent, Rect2(0, 0, size.x, 6), Color(1.0, 0.55, 0.18, 0.30)).name = "ShopPanelTopGlow"
	_decor_rect(parent, Rect2(0, size.y - 10, size.x, 10), Color(0.0, 0.0, 0.0, 0.32)).name = "ShopPanelBottomShade"
	_decor_rect(parent, Rect2(20, 72, size.x - 40, 1), Color(1.0, 0.67, 0.30, 0.28)).name = "ShopTitleHairline"
	_decor_rect(parent, Rect2(22, 22, 5, 28), COLOR_AMBER).name = "ShopTitleAccent"
	_decor_rect(parent, Rect2(size.x - 176, 24, 126, 2), Color(1.0, 0.68, 0.26, 0.24)).name = "ShopLedgerRule"

func _add_shop_resource_strip(parent: Control, rect: Rect2) -> void:
	var strip := _panel(parent, rect, Color(0.036, 0.030, 0.028, 0.96))
	strip.name = "ShopResourceStrip"
	_decor_rect(strip, Rect2(0, 0, rect.size.x, 2), Color(1.0, 0.70, 0.30, 0.28)).name = "ShopResourceTopLine"
	_decor_rect(strip, Rect2(0, rect.size.y - 2, rect.size.x, 2), Color(0.0, 0.0, 0.0, 0.24)).name = "ShopResourceBottomLine"
	var chip_w := 246.0
	var gap := 22.0
	_add_shop_resource_chip(strip, Rect2(18, 10, chip_w, 38), "余烬", "%d" % _run.embers, COLOR_AMBER)
	_add_shop_resource_chip(strip, Rect2(18 + (chip_w + gap), 10, chip_w, 38), "守护值", "%d / %d" % [_run.sanctuary_integrity, _run.sanctuary_integrity_max], COLOR_GOOD)
	_add_shop_resource_chip(strip, Rect2(18 + (chip_w + gap) * 2, 10, chip_w, 38), "守卫者", "%d / 3" % _run.alive_warden_count(), COLOR_TEXT)
	_add_shop_resource_chip(strip, Rect2(18 + (chip_w + gap) * 3, 10, chip_w, 38), "腐化", "%d" % _run.corruption, COLOR_DANGER if _run.corruption > 0 else COLOR_PARCHMENT)

func _add_shop_resource_chip(parent: Control, rect: Rect2, title: String, value: String, accent: Color) -> void:
	var chip := _panel(parent, rect, Color(0.075, 0.058, 0.045, 0.92))
	chip.name = "ShopResource_%s" % title
	_decor_rect(chip, Rect2(0, 0, 4, rect.size.y), accent).name = "ShopResourceAccent"
	_label(chip, title, Rect2(14, 9, 78, 20), 15, COLOR_MUTED)
	_label(chip, value, Rect2(104, 7, rect.size.x - 118, 24), 19, accent)

func _add_shop_shelf_frame(parent: Control, rect: Rect2) -> void:
	var shelf := _panel(parent, rect, Color(0.030, 0.024, 0.022, 0.76))
	shelf.name = "ShopShelfFrame"
	_decor_rect(shelf, Rect2(0, 0, rect.size.x, 10), Color(0.23, 0.13, 0.060, 0.92)).name = "ShopShelfTopBeam"
	_decor_rect(shelf, Rect2(14, 14, rect.size.x - 28, 24), Color(0.090, 0.048, 0.024, 0.92)).name = "ShopShelfCanopy"
	var stripe_w := (rect.size.x - 52.0) / 12.0
	for i in range(12):
		var stripe_color := Color(0.24, 0.13, 0.055, 0.70) if i % 2 == 0 else Color(0.12, 0.065, 0.032, 0.82)
		_decor_rect(shelf, Rect2(26 + i * stripe_w, 15, stripe_w - 3, 22), stripe_color).name = "ShopShelfCanopyStripe"
	_decor_rect(shelf, Rect2(22, 42, rect.size.x - 44, 4), Color(1.0, 0.62, 0.22, 0.18)).name = "ShopShelfLampLine"
	_decor_rect(shelf, Rect2(22, 132, rect.size.x - 44, 34), Color(0.0, 0.0, 0.0, 0.24)).name = "ShopShelfRearShadow"
	_decor_rect(shelf, Rect2(0, rect.size.y - 14, rect.size.x, 14), Color(0.16, 0.085, 0.040, 0.94)).name = "ShopShelfCounterLip"
	_decor_rect(shelf, Rect2(0, rect.size.y - 3, rect.size.x, 3), Color(1.0, 0.62, 0.22, 0.20)).name = "ShopShelfCounterGlow"
	for x in [352.0, 710.0]:
		_decor_rect(shelf, Rect2(x, 18, 2, rect.size.y - 38), Color(1.0, 0.56, 0.20, 0.18)).name = "ShopShelfDivider"

func _add_shop_stall_card(parent: Control, rect: Rect2, option: Dictionary, can_afford: bool, callback: Callable) -> Control:
	var effects: Array = option.get("effects", [])
	var kind := _shop_item_kind(effects)
	var accent := _shop_item_accent(kind)
	var card_fill := Color(0.079, 0.061, 0.049, 0.98) if can_afford else Color(0.044, 0.038, 0.036, 0.94)
	var card := _panel(parent, rect, card_fill)
	card.name = "ShopStall_%s" % String(option.get("option_id", "unknown"))
	_decor_rect(card, Rect2(0, 0, rect.size.x, 5), accent).name = "ShopStallAccent"
	_decor_rect(card, Rect2(10, 14, rect.size.x - 20, 118), Color(0.018, 0.016, 0.015, 0.50)).name = "ShopStallBackcloth"
	_decor_rect(card, Rect2(15, 17, 4, 106), Color(0.18, 0.10, 0.047, 0.80)).name = "ShopStallPostLeft"
	_decor_rect(card, Rect2(rect.size.x - 19, 17, 4, 106), Color(0.18, 0.10, 0.047, 0.80)).name = "ShopStallPostRight"
	_decor_rect(card, Rect2(22, 118, rect.size.x - 44, 9), Color(0.25, 0.13, 0.055, 0.90)).name = "ShopStallDisplayShelf"
	_decor_rect(card, Rect2(32, 128, rect.size.x - 64, 3), Color(1.0, 0.63, 0.24, 0.18)).name = "ShopStallShelfGlow"
	_decor_rect(card, Rect2(26, 143, 116, 30), Color(0.030, 0.026, 0.023, 0.92)).name = "ShopStallPriceTag"
	_decor_rect(card, Rect2(0, rect.size.y - 6, rect.size.x, 6), Color(0.0, 0.0, 0.0, 0.26)).name = "ShopStallBaseShade"
	_add_shop_item_mark(card, Rect2(22, 26, 86, 86), kind, can_afford)
	_label(card, _shop_item_title(option), Rect2(124, 24, 180, 30), 23, accent if can_afford else COLOR_MUTED)
	_label(card, _shop_price_text(effects), Rect2(126, 60, 150, 24), 18, COLOR_AMBER if can_afford else COLOR_MUTED)
	_label(card, _shop_effect_text(effects), Rect2(126, 92, 176, 46), 16, COLOR_TEXT if can_afford else COLOR_MUTED)
	if not can_afford:
		_label(card, "余烬不足", Rect2(24, 148, 100, 24), 15, COLOR_MUTED)
	var buy_button := _button(card, "购买", Rect2(204, 144, 94, 42), callback)
	buy_button.name = "ShopBuy_%s" % String(option.get("option_id", "unknown"))
	buy_button.disabled = not can_afford
	if can_afford:
		_apply_button_style(buy_button, Color(0.18, 0.105, 0.045, 0.98), Color(0.86, 0.52, 0.20, 0.92), 2)
	return card

func _add_shop_item_mark(parent: Control, rect: Rect2, kind: String, can_afford: bool) -> void:
	var accent := _shop_item_accent(kind)
	var alpha := 1.0 if can_afford else 0.46
	var holder := _panel(parent, rect, Color(0.020, 0.018, 0.017, 0.96))
	holder.name = "ShopItemMark_%s" % kind
	_decor_rect(holder, Rect2(8, 8, rect.size.x - 16, rect.size.y - 16), Color(accent.r, accent.g, accent.b, 0.13 * alpha)).name = "ShopItemInnerGlow"
	_decor_rect(holder, Rect2(15, rect.size.y - 20, rect.size.x - 30, 6), Color(0.0, 0.0, 0.0, 0.34 * alpha)).name = "ShopItemCastShadow"
	match kind:
		"healing":
			_decor_rect(holder, Rect2(26, 58, 34, 8), Color(0.18, 0.13, 0.09, 0.86 * alpha)).name = "ShopHealBottleBase"
			_decor_rect(holder, Rect2(28, 18, 30, 50), Color(0.72, 0.84, 0.66, 0.86 * alpha)).name = "ShopHealBottle"
			_decor_rect(holder, Rect2(34, 10, 18, 12), Color(0.44, 0.60, 0.42, 0.86 * alpha)).name = "ShopHealCap"
			_decor_rect(holder, Rect2(49, 24, 5, 30), Color(0.94, 1.0, 0.78, 0.24 * alpha)).name = "ShopHealBottleHighlight"
			_decor_rect(holder, Rect2(39, 29, 8, 28), Color(0.08, 0.18, 0.12, 0.88 * alpha)).name = "ShopHealCrossV"
			_decor_rect(holder, Rect2(29, 39, 28, 8), Color(0.08, 0.18, 0.12, 0.88 * alpha)).name = "ShopHealCrossH"
		"repair":
			_decor_rect(holder, Rect2(16, 58, 54, 7), Color(0.18, 0.10, 0.055, 0.84 * alpha)).name = "ShopRepairStackShadow"
			_decor_rect(holder, Rect2(18, 42, 50, 14), Color(0.74, 0.45, 0.20, 0.90 * alpha)).name = "ShopRepairPlankA"
			_decor_rect(holder, Rect2(22, 24, 42, 12), Color(0.60, 0.34, 0.15, 0.90 * alpha)).name = "ShopRepairPlankB"
			_decor_rect(holder, Rect2(15, 33, 54, 7), Color(0.86, 0.56, 0.25, 0.78 * alpha)).name = "ShopRepairPlankC"
			_decor_rect(holder, Rect2(24, 20, 8, 42), Color(0.24, 0.19, 0.16, 0.88 * alpha)).name = "ShopRepairStrapA"
			_decor_rect(holder, Rect2(56, 22, 8, 38), Color(0.24, 0.19, 0.16, 0.88 * alpha)).name = "ShopRepairStrapB"
		"relic":
			var gem := _decor_rect(holder, Rect2(32, 22, 24, 24), Color(0.42, 0.62, 0.74, 0.88 * alpha))
			gem.name = "ShopRelicGem"
			gem.pivot_offset = Vector2(12, 12)
			gem.rotation = 0.785
			_decor_rect(holder, Rect2(29, 47, 28, 10), Color(0.10, 0.16, 0.18, 0.82 * alpha)).name = "ShopRelicSocket"
			_decor_rect(holder, Rect2(26, 55, 34, 6), Color(0.88, 0.58, 0.24, 0.82 * alpha)).name = "ShopRelicBase"
			_decor_rect(holder, Rect2(39, 14, 7, 54), Color(0.66, 0.84, 0.94, 0.34 * alpha)).name = "ShopRelicLight"
		_:
			_decor_rect(holder, Rect2(20, 28, 46, 34), Color(0.70, 0.48, 0.24, 0.84 * alpha)).name = "ShopSupplyBox"
			_decor_rect(holder, Rect2(20, 40, 46, 6), Color(0.24, 0.18, 0.13, 0.86 * alpha)).name = "ShopSupplyBand"
	_decor_rect(holder, Rect2(10, rect.size.y - 12, rect.size.x - 20, 2), Color(1.0, 0.80, 0.44, 0.20 * alpha)).name = "ShopItemFootGlow"

func _shop_item_kind(effects: Array) -> String:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		match String(effect.get("reward_type", "")):
			"warden_hp":
				return "healing"
			"sanctuary_integrity":
				return "repair"
			"relic":
				return "relic"
	return "supply"

func _shop_item_accent(kind: String) -> Color:
	match kind:
		"healing":
			return Color(0.54, 0.80, 0.56, 1.0)
		"repair":
			return Color(0.95, 0.58, 0.24, 1.0)
		"relic":
			return Color(0.50, 0.72, 0.86, 1.0)
	return COLOR_AMBER

func _shop_item_title(option: Dictionary) -> String:
	var title := String(option.get("title", ""))
	if title.begins_with("购买"):
		title = title.substr(2)
	return title

func _shop_price_text(effects: Array) -> String:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if String(effect.get("reward_type", "")) == "embers":
			return "余烬 %d" % int(effect.get("amount", 0))
	return "无余烬消耗"

func _shop_effect_text(effects: Array) -> String:
	var lines: Array[String] = []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var reward_type := String(effect.get("reward_type", ""))
		if reward_type == "embers":
			continue
		var amount := int(effect.get("amount", 0))
		var sign := "+" if amount >= 0 else ""
		match reward_type:
			"warden_hp":
				lines.append("存活守卫者 HP %s%d" % [sign, amount])
			"sanctuary_integrity":
				lines.append("守护值 %s%d" % [sign, amount])
			"relic":
				lines.append("获得遗物")
			"corruption":
				lines.append("腐化 %s%d" % [sign, amount])
			_:
				lines.append("%s %s%d" % [reward_type, sign, amount])
	if lines.is_empty():
		return "无即时收益"
	return "\n".join(lines)

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
	button.add_theme_font_size_override("font_size", 16)
	_apply_button_style(button, HUB_GATE_BUTTON_FILL, COLOR_AMBER, 3)
	return button

func _add_expedition_title_plate(parent: Control, rect: Rect2) -> void:
	var shadow := _decor_rect(parent, Rect2(rect.position + Vector2(4, 5), rect.size), Color(0.0, 0.0, 0.0, 0.34))
	shadow.name = "ExpeditionTitleShadow"
	var plate := _panel(parent, rect, Color(0.070, 0.046, 0.030, 0.92))
	plate.name = "ExpeditionTitlePlate"
	_decor_rect(plate, Rect2(12, 12, 4, 22), COLOR_AMBER).name = "ExpeditionTitleAccent"
	_decor_rect(plate, Rect2(22, 34, rect.size.x - 44, 1), Color(1.0, 0.70, 0.30, 0.32)).name = "ExpeditionTitleHairline"
	_label(plate, "断墙外远征地图", Rect2(30, 7, rect.size.x - 50, 36), 29, COLOR_AMBER)

func _add_expedition_map_backdrop(parent: Control, rect: Rect2) -> Control:
	var holder := Control.new()
	holder.name = "ExpeditionTacticalMap"
	holder.position = rect.position
	holder.size = rect.size
	parent.add_child(holder)
	var texture := _load_texture_from_path(EXPEDITION_MAP_BACKGROUND_PATH)
	if texture != null:
		var image := TextureRect.new()
		image.name = "ExpeditionMapArt"
		image.anchor_right = 1.0
		image.anchor_bottom = 1.0
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(image)
	else:
		_panel(holder, Rect2(Vector2.ZERO, rect.size), Color(0.026, 0.022, 0.020, 0.98))
	_decor_rect(holder, Rect2(Vector2.ZERO, rect.size), Color(0.0, 0.0, 0.0, 0.16)).name = "ExpeditionMapGrade"
	_decor_rect(holder, Rect2(0, 0, rect.size.x, 18), Color(0.0, 0.0, 0.0, 0.30)).name = "ExpeditionMapTopShade"
	_decor_rect(holder, Rect2(0, rect.size.y - 22, rect.size.x, 22), Color(0.0, 0.0, 0.0, 0.32)).name = "ExpeditionMapBottomShade"
	_add_expedition_map_frame(holder, rect.size)
	return holder

func _add_expedition_map_frame(parent: Control, size: Vector2) -> void:
	var outer := ReferenceRect.new()
	outer.name = "ExpeditionMapOuterFrame"
	outer.anchor_right = 1.0
	outer.anchor_bottom = 1.0
	outer.border_width = 2.0
	outer.border_color = Color(0.95, 0.58, 0.24, 0.64)
	outer.editor_only = false
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(outer)
	var inner := ReferenceRect.new()
	inner.name = "ExpeditionMapInnerFrame"
	inner.position = Vector2(14, 14)
	inner.size = size - Vector2(28, 28)
	inner.border_width = 1.0
	inner.border_color = Color(0.95, 0.67, 0.30, 0.26)
	inner.editor_only = false
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(inner)
	_decor_rect(parent, Rect2(0, 0, 2, size.y), Color(1.0, 0.60, 0.24, 0.28)).name = "ExpeditionMapLeftRail"
	_decor_rect(parent, Rect2(size.x - 2, 0, 2, size.y), Color(1.0, 0.60, 0.24, 0.28)).name = "ExpeditionMapRightRail"

func _add_expedition_route_path(parent: Control, points: Array) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		_add_expedition_route_line(parent, points[i], points[i + 1])
	for point in points:
		_add_expedition_route_pin(parent, point, 3.0, Color(1.0, 0.64, 0.26, 0.58))

func _add_expedition_route_line(parent: Control, from: Vector2, to: Vector2) -> void:
	var delta := to - from
	var length := delta.length()
	if length <= 0.0:
		return
	var shadow := _decor_rect(parent, Rect2(from + Vector2(0, 2), Vector2(length, 3)), Color(0.0, 0.0, 0.0, 0.28))
	shadow.rotation = delta.angle()
	var line := _decor_rect(parent, Rect2(from, Vector2(length, 2)), Color(1.0, 0.60, 0.22, 0.42))
	line.rotation = delta.angle()
	var core := _decor_rect(parent, Rect2(from + Vector2(0, 1), Vector2(length, 1)), Color(1.0, 0.84, 0.46, 0.54))
	core.rotation = delta.angle()

func _add_expedition_route_pin(parent: Control, position: Vector2, radius: float, color: Color) -> void:
	var glow := ColorRect.new()
	glow.position = position - Vector2(radius + 3.0, radius + 3.0)
	glow.size = Vector2((radius + 3.0) * 2.0, (radius + 3.0) * 2.0)
	glow.color = Color(color.r, color.g, color.b, 0.16)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glow)
	var pin := ColorRect.new()
	pin.position = position - Vector2(radius, radius)
	pin.size = Vector2(radius * 2.0, radius * 2.0)
	pin.color = color
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pin)

func _add_expedition_map_region(parent: Control, title: String, subtitle: String, rect: Rect2, color: Color, marker_kind: String, callback: Callable) -> Button:
	var shadow := ColorRect.new()
	shadow.position = rect.position + Vector2(7, 9)
	shadow.size = rect.size
	shadow.color = Color(0.0, 0.0, 0.0, 0.44)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shadow)
	var button := _button(parent, "%s\n%s" % [title, subtitle], rect, callback)
	button.name = "ExpeditionRegion_%s" % title
	button.add_theme_font_size_override("font_size", 18)
	_apply_expedition_region_style(button, color)
	_add_expedition_region_marker(parent, rect, color, marker_kind)
	return button

func _add_expedition_region_marker(parent: Control, rect: Rect2, color: Color, marker_kind: String) -> void:
	var marker_rect := Rect2(rect.position + Vector2(16, 17), Vector2(32, 32))
	var base := _decor_rect(parent, marker_rect, Color(0.020, 0.017, 0.015, 0.80))
	base.name = "ExpeditionRegionMarker_%s" % marker_kind
	var accent := Color(color.r, color.g, color.b, 1.0).lightened(0.46)
	match marker_kind:
		"rift":
			_decor_rect(parent, Rect2(marker_rect.position + Vector2(14, 5), Vector2(4, 22)), accent).rotation = 0.46
			_decor_rect(parent, Rect2(marker_rect.position + Vector2(9, 16), Vector2(14, 3)), Color(0.52, 0.82, 0.94, 0.88)).rotation = 0.18
		"supply":
			_decor_rect(parent, Rect2(marker_rect.position + Vector2(8, 9), Vector2(16, 14)), accent)
			_decor_rect(parent, Rect2(marker_rect.position + Vector2(12, 5), Vector2(8, 5)), Color(1.0, 0.78, 0.40, 0.78))
		_:
			_decor_rect(parent, Rect2(marker_rect.position + Vector2(8, 8), Vector2(16, 4)), accent)
			_decor_rect(parent, Rect2(marker_rect.position + Vector2(8, 14), Vector2(16, 4)), accent.darkened(0.12))
			_decor_rect(parent, Rect2(marker_rect.position + Vector2(8, 20), Vector2(16, 4)), accent.darkened(0.24))

func _add_hub_summary(root: Control) -> void:
	var bar := _panel(root, HUB_SUMMARY_RECT, Color(0.045, 0.038, 0.036, 0.96))
	bar.name = "HubSummary"
	if _run == null:
		_label(bar, "尚未选择远征区域", Rect2(20, 15, 220, 26), 17, COLOR_TEXT)
		_label(bar, "断墙远征门等待确认目的地", Rect2(266, 15, 260, 26), 17, COLOR_MUTED)
		return
	_sync_run_warden_base_stats()
	_label(bar, "余烬 %d" % _run.embers, Rect2(20, 15, 112, 26), 17, COLOR_TEXT)
	_label(bar, "守卫者 %d / 3" % _run.alive_warden_count(), Rect2(166, 15, 154, 26), 17, COLOR_TEXT)

func _add_mission_board_summary(root: Control) -> void:
	var bar := _panel(root, HUB_SUMMARY_RECT, Color(0.045, 0.038, 0.036, 0.96))
	bar.name = "MissionBoardSummary"
	if _run == null:
		return
	_sync_run_warden_base_stats()
	_label(bar, "余烬 %d" % _run.embers, Rect2(20, 15, 112, 26), 17, COLOR_TEXT)
	_label(bar, "守护值 %d / %d" % [_run.sanctuary_integrity, _run.sanctuary_integrity_max], Rect2(152, 15, 170, 26), 17, COLOR_TEXT)
	_label(bar, "守卫者 %d / 3" % _run.alive_warden_count(), Rect2(350, 15, 154, 26), 17, COLOR_TEXT)
	_label(bar, "腐化 %d" % _run.corruption, Rect2(532, 15, 112, 26), 17, COLOR_TEXT)

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
	var next: Dictionary = _run.current_commission()
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
	var node_id := String(node.get("node_id", ""))
	var accent := _mission_accent(node_type)
	var card := Button.new()
	card.name = "MissionCard_%s" % node_id
	card.position = rect.position
	card.size = rect.size
	card.text = ""
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(func(id := node_id): _start_mission_from_board(id))
	_apply_mission_card_style(card, node_type)
	parent.add_child(card)
	var accent_rule := ColorRect.new()
	accent_rule.position = Vector2(0, 0)
	accent_rule.size = Vector2(rect.size.x, 5)
	accent_rule.color = accent
	accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(accent_rule)
	var selection_glow := ColorRect.new()
	selection_glow.name = "MissionCardSelectionGlow"
	selection_glow.anchor_right = 1.0
	selection_glow.anchor_bottom = 1.0
	selection_glow.offset_right = 0.0
	selection_glow.offset_bottom = 0.0
	selection_glow.color = Color(accent.r, accent.g, accent.b, 0.09)
	selection_glow.visible = false
	selection_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(selection_glow)
	var inner := ReferenceRect.new()
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.offset_left = 8
	inner.offset_top = 8
	inner.offset_right = -8
	inner.offset_bottom = -8
	inner.border_width = 1.0
	inner.border_color = Color(accent.r, accent.g, accent.b, 0.28)
	inner.editor_only = false
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	_bind_mission_card_selection_state(card, selection_glow, inner, accent)
	_card_label(card, String(node.get("title", "")), Rect2(20, 20, rect.size.x - 40, 34), 24, COLOR_TEXT)
	_card_label(card, _mission_type_title(node), Rect2(20, 62, 142, 24), 17, accent)
	_card_label(card, _mission_risk_label(node), Rect2(166, 62, 120, 24), 17, _mission_risk_color(node))
	_card_label(card, _mission_card_intel(node), Rect2(20, 106, rect.size.x - 40, 54), 18, COLOR_TEXT)
	_card_label(card, _mission_card_reward_line(node), Rect2(20, rect.size.y - 52, rect.size.x - 40, 28), 18, COLOR_PARCHMENT)

func _bind_mission_card_selection_state(card: Button, glow: Control, inner: ReferenceRect, accent: Color) -> void:
	var update_state := func() -> void:
		var selected := card.is_hovered() or card.has_focus()
		glow.visible = selected
		inner.border_width = 2.0 if selected else 1.0
		inner.border_color = Color(accent.r, accent.g, accent.b, 0.64 if selected else 0.28)
	card.mouse_entered.connect(update_state)
	card.mouse_exited.connect(update_state)
	card.focus_entered.connect(update_state)
	card.focus_exited.connect(update_state)
	update_state.call()

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

func _mission_risk_label(node: Dictionary) -> String:
	var risk := clampi(int(node.get("risk_level", 1)), 1, 5)
	if String(node.get("node_type", "")) == RunStateScript.NODE_BOSS:
		return "Boss %d/5" % risk
	var label := "低危"
	match risk:
		2:
			label = "中危"
		3:
			label = "高危"
		4:
			label = "危急"
		5:
			label = "死线"
	return "%s %d/5" % [label, risk]

func _mission_risk_color(node: Dictionary) -> Color:
	var risk := clampi(int(node.get("risk_level", 1)), 1, 5)
	if risk >= 4 or String(node.get("node_type", "")) == RunStateScript.NODE_BOSS:
		return COLOR_DANGER
	if risk >= 3:
		return COLOR_AMBER
	return COLOR_PARCHMENT

func _mission_card_intel(node: Dictionary) -> String:
	match String(node.get("node_id", "")):
		"outer_wall_01":
			return "外墙有远程火线压近。"
		"extinguished_beacon_02":
			return "灯塔内仍有余火。"
		"quartermaster_cache_02":
			return "军需箱仍可开封。"
		"crack_courtyard_03":
			return "浅裂隙正在扩张。"
		"pillar_graveyard_03":
			return "石柱间回声越来越密。"
		"ember_camp_03":
			return "守夜人留下补给。"
		"scout_ritual_03":
			return "坑底还在冒黑火。"
		"iron_gate_04":
			return "铁角闸门后有重影。"
		"ember_camp_05":
			return "残火还够整队一次。"
		"quartermaster_cache_05":
			return "仓库深处仍有封箱。"
		"last_watch_event_05":
			return "最后一圈路障未倒。"
		"boss_outer_bell_01":
			return "心脏钟正在倒数。"
	var node_type := String(node.get("node_type", ""))
	if node_type == RunStateScript.NODE_EVENT:
		return "前线传来一项取舍。"
	if node_type == RunStateScript.NODE_CAMP:
		return "这里还能短暂喘息。"
	if node_type == RunStateScript.NODE_SHOP:
		return "旧补给线尚未断绝。"
	if node_type == RunStateScript.NODE_ELITE:
		return "更重的脚步压近防线。"
	if node_type == RunStateScript.NODE_BOSS:
		return "终局威胁已经显形。"
	return "断墙外仍有火线。"

func _mission_card_reward_line(node: Dictionary) -> String:
	var node_type := String(node.get("node_type", ""))
	match node_type:
		RunStateScript.NODE_ELITE:
			return "报酬 %d 余烬 · 遗物" % int(node.get("base_embers", 0))
		RunStateScript.NODE_BOSS:
			return "终局报酬 %d 余烬" % int(node.get("base_embers", 0))
		RunStateScript.NODE_EVENT:
			return _option_preview(node, "event")
		RunStateScript.NODE_CAMP:
			return "治疗 / 修复"
		RunStateScript.NODE_SHOP:
			return "消耗余烬 · 补给"
	return "报酬 %d 余烬" % int(node.get("base_embers", 0))

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

func _mission_accent(node_type: String) -> Color:
	if node_type == RunStateScript.NODE_ELITE or node_type == RunStateScript.NODE_BOSS:
		return COLOR_DANGER
	if node_type == RunStateScript.NODE_EVENT:
		return COLOR_PARCHMENT
	if node_type == RunStateScript.NODE_CAMP:
		return COLOR_GOOD
	return COLOR_AMBER

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
	_show_reward()

func _show_battle_debrief_or_recover() -> void:
	if _run == null:
		_show_main_menu()
		return
	if not _run.pending_reward.is_empty():
		_show_reward()
		return
	if not _run.last_resolution.is_empty():
		_show_battle_debrief()
		return
	if _run.result_outcome != "":
		_show_run_result()
		return
	if _run.current_node_id.is_empty():
		_show_mission_board()
		return
	_complete_current_node_and_show_mission_board()

func _show_battle_debrief() -> void:
	if _run == null:
		_show_main_menu()
		return
	_play_menu_bgm()
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
	return _load_texture_from_path(BATTLE_DEBRIEF_PANEL_PATH)

func _load_texture_from_path(path: String) -> Texture2D:
	var source := Image.new()
	var err := source.load(ProjectSettings.globalize_path(path))
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
	_play_menu_bgm()
	_run.phase = RunStateScript.Phase.REWARD
	var root := _make_root()
	_add_hub_backdrop(root)
	var reward: Dictionary = _run.pending_reward
	var node: Dictionary = _run.current_node()
	var panel := _panel(root, Rect2(320, 104, 640, 496), Color(0.066, 0.056, 0.052, 0.98))
	_label(panel, "获得奖励", Rect2(42, 36, 320, 44), 32, COLOR_AMBER)
	_label(panel, "%s · 委托完成" % String(node.get("title", "当前委托")), Rect2(44, 84, 440, 28), 18, COLOR_TEXT)
	var rewards: Array = reward.get("fixed_rewards", []).duplicate(true)
	rewards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("visible_order", 0)) < int(b.get("visible_order", 0))
	)
	var y := 140.0
	for item in rewards:
		_add_reward_list_item(panel, Rect2(42, y, 556, 78), item)
		y += 92.0
	if rewards.is_empty():
		_label(panel, "没有可领取奖励。", Rect2(44, 154, 360, 28), 19, COLOR_MUTED)
	_button(root, "返回任务委托", Rect2(540, 620, 200, UI_BUTTON_MIN_HEIGHT), _confirm_reward)

func _add_reward_list_item(parent: Control, rect: Rect2, reward_item: Dictionary) -> Control:
	var item: Control = RewardListItemScript.new()
	item.position = rect.position
	item.size = rect.size
	var display := _reward_item_display(reward_item)
	item.setup(display)
	parent.add_child(item)
	return item

func _reward_item_display(reward_item: Dictionary) -> Dictionary:
	var reward_type := String(reward_item.get("reward_type", ""))
	var amount := int(reward_item.get("amount", 0))
	var sign := "+" if amount >= 0 else ""
	var reason := _reward_item_reason_text(String(reward_item.get("reason", "")))
	match reward_type:
		"embers":
			return {
				"title": "余烬",
				"amount_text": "%s%d" % [sign, amount],
				"description": reason,
				"icon_text": "烬",
				"amount_color": COLOR_AMBER,
			}
		"sanctuary_integrity":
			return {
				"title": "防线修复",
				"amount_text": "%s%d" % [sign, amount],
				"description": reason,
				"icon_text": "墙",
				"amount_color": COLOR_GOOD,
			}
		"warden_hp":
			return {
				"title": "守卫者治疗",
				"amount_text": "%s%d" % [sign, amount],
				"description": reason,
				"icon_text": "疗",
				"amount_color": COLOR_GOOD,
			}
		"relic":
			return {
				"title": String(reward_item.get("title", "获得遗物")),
				"amount_text": "",
				"description": reason,
				"icon_text": "遗",
				"amount_color": COLOR_AMBER,
			}
		"upgrade":
			return {
				"title": String(reward_item.get("title", "获得升级")),
				"amount_text": "",
				"description": reason,
				"icon_text": "升",
				"amount_color": COLOR_AMBER,
			}
		"chapter_reward":
			return {
				"title": String(reward_item.get("title", "章节奖励")),
				"amount_text": "",
				"description": reason,
				"icon_text": "章",
				"amount_color": COLOR_AMBER,
			}
	return {
		"title": reward_type if not reward_type.is_empty() else "奖励",
		"amount_text": "%s%d" % [sign, amount] if amount != 0 else "",
		"description": reason,
		"icon_text": "奖",
		"amount_color": COLOR_AMBER,
	}

func _reward_item_reason_text(reason: String) -> String:
	if reason.begins_with("完成 ") and reason.find("个奖励任务") >= 0:
		return "额外目标奖励"
	match reason:
		"普通战基础奖励":
			return "完成普通委托"
		"精英战基础奖励":
			return "完成精英委托"
		"Boss 战基础奖励":
			return "完成 Boss 委托"
		"守护值已满，恢复机会转化":
			return "防线已满，修复转化"
		_:
			return reason if not reason.is_empty() else "委托奖励"

func _confirm_reward() -> void:
	if _run.pending_reward.is_empty():
		_after_reward_claimed()
		return
	_run.claim_pending_reward("")
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
	_play_menu_bgm()
	_sync_run_warden_base_stats()
	_run.phase = RunStateScript.Phase.RUN_RESULT
	var root := _make_root()
	_add_top_bar(root)
	var victory: bool = _run.result_outcome == "victory"
	_label(root, "Run 结算", Rect2(82, 92, 420, 38), 30, COLOR_AMBER)
	var panel := _panel(root, Rect2(82, 156, 620, 420), COLOR_PANEL)
	_label(panel, "防线守住" if victory else "Run 失败", Rect2(30, 28, 500, 48), 36, COLOR_GOOD if victory else COLOR_DANGER)
	_label(panel, "%s · 完成委托 %d / %d" % [_run.chapter_name, _run.visited_nodes.size(), _run.route_nodes.size()], Rect2(32, 94, 520, 28), 18, COLOR_TEXT)
	_label(panel, "守护值 %d / %d   余烬 %d   腐化 %d" % [_run.sanctuary_integrity, _run.sanctuary_integrity_max, _run.embers, _run.corruption], Rect2(32, 136, 520, 28), 18, COLOR_AMBER)
	_label(panel, "遗物：%s" % _relic_summary(), Rect2(32, 178, 540, 52), 17, COLOR_MUTED)
	var y := 252.0
	for w in _run.wardens:
		_label(panel, _warden_status_text(w), Rect2(32, y, 540, 26), 17, COLOR_TEXT if bool(w.get("alive", false)) else COLOR_DANGER)
		y += 34.0
	_button(root, "再开一局", Rect2(82, 614, 150, 48), _on_new_run_pressed)
	_button(root, "主菜单", Rect2(252, 614, 130, 48), _show_main_menu)

func _show_codex_placeholder(return_to_hub: bool = false) -> void:
	_play_menu_bgm()
	var root := _make_root()
	_label(root, "图鉴", Rect2(86, 96, 420, 42), 30, COLOR_AMBER)
	_label(root, "图鉴入口已保留，第一版暂未开放完整资料库。", Rect2(86, 164, 640, 32), 18, COLOR_TEXT)
	_button(root, "返回据点" if return_to_hub else "返回", Rect2(86, 240, 120, 44), _show_hub if return_to_hub else _show_main_menu)

func _show_settings_placeholder(return_to_hub: bool = false) -> void:
	_play_menu_bgm()
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

func _card_label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color = COLOR_TEXT) -> Label:
	var label := _label(parent, text, rect, font_size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var b := Button.new()
	b.position = rect.position
	b.size = Vector2(maxf(rect.size.x, 48.0), maxf(rect.size.y, UI_BUTTON_MIN_HEIGHT))
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(func() -> void:
		_play_button_sfx(text)
		callback.call()
	)
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
	button.pressed.connect(func() -> void:
		_play_button_sfx(text)
		callback.call()
	)
	parent.add_child(button)
	return button

func _play_button_sfx(text: String) -> void:
	var manager = _audio_manager()
	if manager == null or not manager.has_method(&"play_sfx"):
		return
	manager.play_sfx(_button_sfx_id(text))

func _button_sfx_id(text: String) -> StringName:
	var label := text.strip_edges()
	if label.contains("返回") or label.contains("取消") or label.contains("退出") or label.contains("留在"):
		return AudioManagerScript.SFX_UI_CANCEL
	return AudioManagerScript.SFX_UI_CONFIRM

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

func _apply_expedition_region_style(button: Button, fill: Color) -> void:
	button.custom_minimum_size = Vector2(132, 76)
	button.focus_mode = Control.FOCUS_ALL
	var border := Color(1.0, 0.72, 0.34, 0.94)
	button.add_theme_stylebox_override("normal", _expedition_region_stylebox(fill, border, 3, 0))
	button.add_theme_stylebox_override("hover", _expedition_region_stylebox(fill.lightened(0.08), COLOR_AMBER, 4, 1))
	button.add_theme_stylebox_override("pressed", _expedition_region_stylebox(fill.darkened(0.10), border.darkened(0.10), 3, -1))
	button.add_theme_stylebox_override("focus", _expedition_region_stylebox(fill.lightened(0.06), COLOR_AMBER, 4, 1))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.62, 1.0))
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.88, 0.62, 1.0))

func _apply_mission_card_style(button: Button, node_type: String) -> void:
	button.custom_minimum_size = Vector2(240, 188)
	button.focus_mode = Control.FOCUS_ALL
	var fill := Color(0.115, 0.086, 0.060, 0.98)
	var accent := _mission_accent(node_type)
	var border := Color(0.48, 0.32, 0.17, 0.82)
	button.add_theme_stylebox_override("normal", _mission_card_stylebox(fill, border, 2, 0, false))
	button.add_theme_stylebox_override("hover", _mission_card_stylebox(fill.lightened(0.07), Color(1.0, 0.68, 0.25, 0.98), 3, -3, true))
	button.add_theme_stylebox_override("focus", _mission_card_stylebox(fill.lightened(0.07), Color(1.0, 0.68, 0.25, 0.98), 3, -3, true))
	button.add_theme_stylebox_override("pressed", _mission_card_stylebox(fill.darkened(0.08), accent.darkened(0.12), 3, 1, false))
	button.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0))

func _mission_card_stylebox(fill: Color, border: Color, border_width: int, state_offset: int, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width + 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.shadow_color = Color(1.0, 0.42, 0.12, 0.30) if selected else Color(0.0, 0.0, 0.0, 0.46)
	style.shadow_size = 12 if selected else 7
	style.shadow_offset = Vector2(0, 5 + state_offset)
	return style

func _expedition_region_stylebox(fill: Color, border: Color, border_width: int, state_offset: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width + 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 54
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 11
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 9
	style.shadow_offset = Vector2(1, 2 + state_offset)
	return style

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

func _play_menu_bgm() -> void:
	var audio = _audio_manager()
	if audio != null and audio.has_method(&"play_menu_bgm"):
		audio.play_menu_bgm()

func _play_battle_bgm() -> void:
	var audio = _audio_manager()
	if audio != null and audio.has_method(&"play_battle_bgm"):
		audio.play_battle_bgm()

func _audio_manager():
	if is_inside_tree() and get_tree().root != null:
		return get_tree().root.get_node_or_null("AudioManager")
	return null
