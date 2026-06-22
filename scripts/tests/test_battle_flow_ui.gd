extends RefCounted
## Regression coverage for enemy intent rows consumed by battle-flow UI.

const BattleEventAnimatorScript := preload("res://scripts/view/battle_event_animator.gd")
const AttackFxPresenterScript := preload("res://scripts/view/attack_fx_presenter.gd")
const BattleSfxPresenterScript := preload("res://scripts/view/battle_sfx_presenter.gd")
const AudioManagerScript := preload("res://scripts/core/audio_manager.gd")
const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const WardenSkillCatalogScript := preload("res://scripts/battle/warden_skill_catalog.gd")
const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_bh() -> UnitDef:
	return TestUnitDefs.bountyhunter()

static func _make_bh_with_stats(overrides: Dictionary) -> UnitDef:
	return TestUnitDefs.bountyhunter(overrides)

static func _make_gr() -> UnitDef:
	return TestUnitDefs.graverobber()

static func _make_mage() -> UnitDef:
	return TestUnitDefs.mage()

static func _make_carrion() -> UnitDef:
	return TestUnitDefs.carrion_spawn()

static func _make_basic_melee_enemy(overrides: Dictionary = {}) -> UnitDef:
	var base := {
		"def_id": &"enemy_test",
		"display_name": "腐食兽",
		"max_hp": 2,
		"move": 2,
		"attack_kind": UnitDef.AttackKind.MELEE_BUMP,
		"attack_range": 1,
		"attack_damage": 1,
		"attack_force": 0,
	}
	base.merge(overrides, true)
	return TestUnitDefs.generic_enemy(base)

static func _add(s: BattleState, def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	s.units.append(u)
	return u

static func _make_engine_with_locked_melee(enemy_overrides: Dictionary = {}) -> Dictionary:
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(engine.state, _make_bh(), Vector2i(3, 5))
	var decoy := _add(engine.state, _make_bh(), Vector2i(0, 0))
	var carrion := _add(engine.state, _make_basic_melee_enemy(enemy_overrides), Vector2i(3, 4))
	var plan := AIDecider.EnemyPlan.new()
	plan.origin_pos = carrion.position
	plan.move_to = carrion.position
	plan.attack_pos = bh.position
	engine.state.enemy_warnings[carrion.id] = plan
	return {"engine": engine, "bh": bh, "decoy": decoy, "carrion": carrion}

static func run(tr) -> void:
	_test_current_intent_row_has_hit_state(tr)
	_test_intent_preview_push_slides_attack_line_without_mutating_state(tr)
	_test_intent_preview_kill_marks_removed_row(tr)
	_test_pushed_enemy_attack_slot_still_resolves(tr)
	_test_pushed_enemy_attack_can_hit_shifted_target(tr)
	_test_hud_stack_focus_does_not_rebuild_rows(tr)
	_test_hud_stack_rows_use_low_text_status_marks(tr)
	_test_hud_enemy_rows_show_segmented_hp_bars(tr)
	_test_hud_enemy_stack_scrolls_many_rows(tr)
	_test_hud_side_panels_use_approved_visual_balance(tr)
	_test_hud_omits_persistent_map_feature_tags(tr)
	_test_hud_sanctuary_preview_uses_bar_segments(tr)
	_test_hud_squad_cards_use_segmented_hp_bars(tr)
	_test_hud_ability_buttons_do_not_overlap_portrait(tr)
	_test_hud_all_warden_skills_have_short_and_detail_copy(tr)
	_test_hud_upgraded_skill_copy_uses_upgrade_values(tr)
	_test_hud_ability_detail_panel_shows_skill_context(tr)
	_test_hud_disabled_ability_reports_reason(tr)
	_test_hud_ability_cooldown_uses_visual_state(tr)
	_test_hud_selected_unit_uses_segmented_hp_bar(tr)
	_test_enemy_board_hover_does_not_show_enemy_info(tr)
	_test_enemy_push_events_defer_intent_refresh(tr)
	_test_outcome_banner_waits_for_event_playback(tr)
	_test_unit_action_visual_resets_without_selection(tr)
	_test_garrison_click_uses_event_position_for_deploy(tr)
	_test_f1_debug_shortcut_forces_player_turn_win(tr)
	_test_enemy_stack_shows_no_attack_rows(tr)
	_test_battle_scene_updates_building_damage_preview_from_intents(tr)
	_test_battle_scene_updates_bell_wave_preview(tr)
	_test_battle_scene_armed_skill_shows_range_and_targets(tr)
	_test_battle_scene_sanctuary_bar_spends_real_protected_damage(tr)
	_test_battle_scene_sanctuary_spends_damage_during_tile_events(tr)
	_test_battle_scene_unit_hp_spends_damage_during_unit_events(tr)
	_test_selecting_warden_refreshes_hover_push_preview(tr)
	_test_hover_push_preview_marks_fall_on_edge_cell(tr)
	_test_hud_objective_summary_shows_protected_targets(tr)
	_test_hud_objective_summary_shows_boss_state(tr)
	_test_hud_boss_status_panel_shows_script_and_window(tr)
	_test_hud_hides_boss_status_panel_for_normal_battle(tr)
	_test_battle_scene_boss_event_feedback_updates_help(tr)
	_test_attack_fx_layers_replace_legacy_flash_state(tr)
	_test_battle_animation_timing_is_readable(tr)
	_test_battle_sfx_presenter_uses_resource_paths_without_generation(tr)
	_test_battle_scene_command_sfx_uses_audio_manager(tr)
	_test_battle_scene_outcome_and_death_sfx_uses_audio_manager(tr)
	_test_attack_fx_presenter_builds_staged_layers(tr)
	_test_player_attack_fx_context_and_trigger(tr)
	_test_non_attack_skill_does_not_capture_player_attack_fx(tr)
	_test_empty_event_batch_clears_unplayed_player_attack_fx(tr)
	_test_move_event_playback_refreshes_ability_bar(tr)
	_test_attack_fx_layers_remain_attack_presentation_only(tr)
	_test_attack_fx_presenter_clear_restores_intents(tr)
	_test_enemy_attack_fx_request_uses_event_positions(tr)
	_test_animator_primes_displacement_before_results(tr)
	_test_battle_event_animator_clears_board_visual_positions(tr)
	_test_outcome_banner_shows_reason(tr)
	_test_battle_scene_outcome_reason_names_sources(tr)

static func _test_current_intent_row_has_hit_state(tr) -> void:
	var ctx := _make_engine_with_locked_melee()
	var engine: BattleEngine = ctx.engine
	var carrion: Unit = ctx.carrion
	var rows := engine.get_enemy_intent_ui_state()
	tr.assert_eq("one intent row", rows.size(), 1)
	tr.assert_eq("row enemy id", rows[0].enemy_id, carrion.id)
	tr.assert_eq("row status hit", rows[0].status, BattleEngine.INTENT_STATUS_HIT)
	tr.assert_eq("row target kind unit", rows[0].target_kind, BattleEngine.TARGET_KIND_UNIT)

static func _test_intent_preview_push_slides_attack_line_without_mutating_state(tr) -> void:
	var ctx := _make_engine_with_locked_melee()
	var engine: BattleEngine = ctx.engine
	var bh: Unit = ctx.bh
	var carrion: Unit = ctx.carrion
	var rows := engine.preview_enemy_intent_ui_state(BattleAction.attack(bh.id, carrion.position))
	tr.assert_eq("intent preview keeps one row", rows.size(), 1)
	tr.assert_eq("pushed intent preview keeps attack slot active", rows[0].attack_fires, true)
	tr.assert_eq("pushed intent preview attack line slides forward", rows[0].attack_pos, Vector2i(3, 4))
	tr.assert_eq("pushed intent preview has no damage when line hits empty cell", rows[0].target_damage, 0)
	tr.assert_eq("real enemy did not move", carrion.position, Vector2i(3, 4))
	tr.assert_eq("real enemy hp did not change", carrion.hp, 2)

static func _test_intent_preview_kill_marks_removed_row(tr) -> void:
	var ctx := _make_engine_with_locked_melee({"max_hp": 1})
	var engine: BattleEngine = ctx.engine
	var bh: Unit = ctx.bh
	var carrion: Unit = ctx.carrion
	carrion.hp = 1
	var rows := engine.preview_enemy_intent_ui_state(BattleAction.attack(bh.id, carrion.position))
	tr.assert_eq("removed intent preview keeps row", rows.size(), 1)
	tr.assert_eq("intent preview row removed", rows[0].status, BattleEngine.INTENT_STATUS_REMOVED)
	tr.assert_true("real enemy still exists after intent preview", engine.state.find_unit(carrion.id) != null)

static func _test_pushed_enemy_attack_slot_still_resolves(tr) -> void:
	var ctx := _make_engine_with_locked_melee()
	var engine: BattleEngine = ctx.engine
	var bh: Unit = ctx.bh
	var carrion: Unit = ctx.carrion
	engine.apply_action(BattleAction.attack(bh.id, carrion.position))
	var events := engine.apply_action(BattleAction.end_turn())
	var started := false
	var missed := false
	var miss_pos := Vector2i(-1, -1)
	for raw in events:
		var e: BattleEvent = raw
		if e.type == BattleEvent.Type.ENEMY_ATTACK_STARTED and e.unit_id == carrion.id:
			started = true
		if e.type == BattleEvent.Type.ENEMY_ATTACK_MISSED and e.unit_id == carrion.id:
			missed = true
			miss_pos = e.to_pos
	tr.assert_true("pushed attack slot starts visibly", started)
	tr.assert_true("pushed attack slot emits miss only after firing", missed)
	tr.assert_eq("pushed attack misses at shifted cell", miss_pos, Vector2i(3, 4))

static func _test_pushed_enemy_attack_can_hit_shifted_target(tr) -> void:
	var ctx := _make_engine_with_locked_melee()
	var engine: BattleEngine = ctx.engine
	var bh: Unit = ctx.bh
	var decoy: Unit = ctx.decoy
	var carrion: Unit = ctx.carrion
	decoy.position = Vector2i(3, 4)
	carrion.position = Vector2i(3, 3)
	engine.state.enemy_warnings[carrion.id].origin_pos = Vector2i(3, 4)
	engine.state.enemy_warnings[carrion.id].move_to = Vector2i(3, 4)
	engine.state.enemy_warnings[carrion.id].attack_pos = bh.position
	var rows := engine.get_enemy_intent_ui_state()
	tr.assert_eq("shifted attack row remains hit", rows[0].status, BattleEngine.INTENT_STATUS_HIT)
	tr.assert_eq("shifted attack targets decoy cell", rows[0].attack_pos, decoy.position)
	tr.assert_eq("shifted attack target is decoy", rows[0].target_id, decoy.id)
	var events := engine.apply_action(BattleAction.end_turn())
	var damaged_decoy := false
	for raw in events:
		var e: BattleEvent = raw
		if e.type == BattleEvent.Type.UNIT_DAMAGED and e.unit_id == decoy.id:
			damaged_decoy = true
	tr.assert_true("shifted attack damages new target", damaged_decoy)

static func _test_hud_stack_focus_does_not_rebuild_rows(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.enemy_stack_bg = hud.get_node("Root/EnemyStackBg")
	hud.enemy_stack_mode = hud.get_node("Root/EnemyStackBg/EnemyStackMode")
	hud.enemy_stack_row = hud.get_node("Root/EnemyStackBg/EnemyStackRow")
	tr.assert_true("battle scene hud exists", hud != null)
	var rows: Array = [{
		"enemy_id": 101,
		"enemy_name": "腐食兽",
		"order": 1,
		"enemy_pos": Vector2i(3, 4),
		"attack_pos": Vector2i(3, 5),
		"status": BattleEngine.INTENT_STATUS_HIT,
		"target_kind": BattleEngine.TARGET_KIND_UNIT,
		"target_id": 1,
		"target_name": "赏金猎人",
		"target_hp": 2,
		"target_damage": 1,
		"has_attack": true,
	}]
	hud.set_enemy_action_stack(rows)
	tr.assert_eq("hud stack has one row", hud.enemy_stack_row.get_child_count(), 1)
	var row_node := hud.enemy_stack_row.get_child(0)
	hud.set_enemy_stack_focus(101)
	tr.assert_eq("focus keeps one row", hud.enemy_stack_row.get_child_count(), 1)
	tr.assert_true("focus does not rebuild row node", hud.enemy_stack_row.get_child(0) == row_node)
	hud.set_enemy_stack_focus(-1)
	tr.assert_true("focus exit still keeps row node", hud.enemy_stack_row.get_child(0) == row_node)
	scene.free()

static func _test_hud_stack_rows_use_low_text_status_marks(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.enemy_stack_bg = hud.get_node("Root/EnemyStackBg")
	hud.enemy_stack_mode = hud.get_node("Root/EnemyStackBg/EnemyStackMode")
	hud.enemy_stack_row = hud.get_node("Root/EnemyStackBg/EnemyStackRow")
	var rows: Array = [{
		"enemy_id": 201,
		"enemy_name": "腐食兽",
		"order": 1,
		"enemy_pos": Vector2i(3, 4),
		"attack_pos": Vector2i(3, 5),
		"status": BattleEngine.INTENT_STATUS_HIT,
		"target_kind": BattleEngine.TARGET_KIND_BUILDING,
		"target_id": -1,
		"target_name": "建筑",
		"target_hp": 2,
		"target_damage": 1,
		"has_attack": true,
	}]
	hud.set_enemy_action_stack(rows)
	var row_node := hud.enemy_stack_row.get_child(0)
	var labels: Array = []
	_collect_label_texts(row_node, labels)
	tr.assert_eq("enemy row keeps only order and name labels", labels.size(), 2)
	tr.assert_true("enemy row has graphic status mark", row_node.get_node("StatusMark") is Panel)
	var joined := " ".join(labels)
	tr.assert_true("enemy row omits damage summary text", not joined.contains("预计") and not joined.contains("伤"))
	tr.assert_true("enemy row omits status wording", not joined.contains("命中") and not joined.contains("落空") and not joined.contains("无攻击") and not joined.contains("已移除"))
	scene.free()

static func _test_hud_enemy_rows_show_segmented_hp_bars(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.enemy_stack_bg = hud.get_node("Root/EnemyStackBg")
	hud.enemy_stack_mode = hud.get_node("Root/EnemyStackBg/EnemyStackMode")
	hud.enemy_stack_row = hud.get_node("Root/EnemyStackBg/EnemyStackRow")
	var rows: Array = [{
		"enemy_id": 205,
		"enemy_name": "腐食兽",
		"enemy_hp": 3,
		"enemy_max_hp": 5,
		"order": 1,
		"enemy_pos": Vector2i(3, 4),
		"attack_pos": Vector2i(3, 5),
		"status": BattleEngine.INTENT_STATUS_HIT,
		"target_kind": BattleEngine.TARGET_KIND_BUILDING,
		"target_id": -1,
		"target_name": "建筑",
		"target_hp": 2,
		"target_damage": 1,
		"has_attack": true,
	}]
	hud.set_enemy_action_stack(rows)
	var hp_bar: Control = hud.enemy_stack_row.get_child(0).get_node("EnemyHpBar")
	tr.assert_eq("enemy hp bar segment count", hp_bar.get_child_count(), 5)
	tr.assert_true("enemy hp bar fits row", hp_bar.offset_right <= 166.0)
	tr.assert_eq("enemy filled segment uses enemy fill", (hp_bar.get_child(0) as ColorRect).color, HUD.UI_ENEMY_HP_FILL)
	tr.assert_eq("enemy empty segment uses dark fill", (hp_bar.get_child(4) as ColorRect).color, HUD.UI_HP_EMPTY)
	scene.free()

static func _test_hud_enemy_stack_scrolls_many_rows(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.enemy_stack_bg = hud.get_node("Root/EnemyStackBg")
	hud.enemy_stack_mode = hud.get_node("Root/EnemyStackBg/EnemyStackMode")
	hud.enemy_stack_row = hud.get_node("Root/EnemyStackBg/EnemyStackRow")
	hud._ensure_enemy_stack_scroll()
	hud._apply_layout_metrics()
	var rows: Array = []
	for i in range(10):
		rows.append({
			"enemy_id": 500 + i,
			"enemy_name": "腐食兽",
			"order": i + 1,
			"enemy_pos": Vector2i(i % Grid.SIZE, 0),
			"attack_pos": Vector2i(i % Grid.SIZE, 1),
			"status": BattleEngine.INTENT_STATUS_HIT,
			"target_kind": BattleEngine.TARGET_KIND_BUILDING,
			"target_id": -1,
			"target_name": "建筑",
			"target_hp": 2,
			"target_damage": 1,
			"has_attack": true,
		})
	hud.set_enemy_action_stack(rows)
	tr.assert_eq("hud stack keeps all enemy rows", hud.enemy_stack_row.get_child_count(), rows.size())
	tr.assert_true("enemy stack row lives inside scroll container", hud.enemy_stack_row.get_parent() is ScrollContainer)
	var row_node: Control = hud.enemy_stack_row.get_child(0)
	tr.assert_eq("enemy stack rows pass wheel input to scroll container", row_node.mouse_filter, Control.MOUSE_FILTER_PASS)
	var scroll: ScrollContainer = hud.enemy_stack_row.get_parent()
	var viewport_height := scroll.offset_bottom - scroll.offset_top
	var content_height := rows.size() * HUD.ENEMY_STACK_ROW_SIZE.y + (rows.size() - 1) * 6.0
	tr.assert_true("enemy stack scroll viewport clips overflowing rows", viewport_height < content_height)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = scroll.get_global_rect().get_center()
	var before_scroll := scroll.scroll_vertical
	hud._handle_enemy_stack_scroll_input(wheel)
	tr.assert_true("enemy stack wheel event moves scroll position", scroll.scroll_vertical > before_scroll)
	var drag_start := InputEventMouseButton.new()
	drag_start.button_index = MOUSE_BUTTON_LEFT
	drag_start.pressed = true
	drag_start.position = scroll.get_global_rect().get_center()
	hud._handle_enemy_stack_scroll_input(drag_start)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.position = drag_start.position + Vector2(0, -72)
	var before_drag_scroll := scroll.scroll_vertical
	hud._handle_enemy_stack_scroll_input(drag_motion)
	tr.assert_true("enemy stack drag event moves scroll position", scroll.scroll_vertical > before_drag_scroll)
	var drag_end := InputEventMouseButton.new()
	drag_end.button_index = MOUSE_BUTTON_LEFT
	drag_end.pressed = false
	drag_end.position = drag_motion.position
	hud._handle_enemy_stack_scroll_input(drag_end)
	tr.assert_eq("enemy stack visible with many rows", hud.enemy_stack_bg.visible, true)
	scene.free()

static func _test_hud_side_panels_use_approved_visual_balance(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.squad_strip_bg = hud.get_node("Root/SquadStripBg")
	hud.squad_strip_row = hud.get_node("Root/SquadStripBg/SquadStripRow")
	hud.enemy_stack_bg = hud.get_node("Root/EnemyStackBg")
	hud.enemy_stack_mode = hud.get_node("Root/EnemyStackBg/EnemyStackMode")
	hud.enemy_stack_row = hud.get_node("Root/EnemyStackBg/EnemyStackRow")
	hud.reward_panel_bg = hud.get_node("Root/RewardPanelBg")
	hud.reward_task_row = hud.get_node("Root/RewardPanelBg/RewardTaskRow")
	hud.info_panel_bg = hud.get_node("Root/InfoPanelBg")
	hud.boss_status_bg = hud.get_node("Root/BossStatusBg")
	hud._apply_layout_metrics()
	tr.assert_true("squad strip widens beyond old narrow column", hud.squad_strip_bg.offset_right - hud.squad_strip_bg.offset_left > 90.0)
	tr.assert_true("squad cards widen beyond old 64px cards", HUD.SQUAD_CARD_SIZE.x > 64.0)
	tr.assert_eq("squad strip outer frame is transparent", hud.squad_strip_bg.color, Color(0, 0, 0, 0))
	tr.assert_eq("squad strip omits generated outer frame", hud.squad_strip_bg.get_node_or_null("HUDFrame"), null)
	tr.assert_true("enemy stack narrows below old 260px panel", hud.enemy_stack_bg.offset_right - hud.enemy_stack_bg.offset_left < 240.0)
	tr.assert_eq("enemy intent rows match narrowed right column", HUD.ENEMY_STACK_ROW_SIZE.x, hud.enemy_stack_row.offset_right - hud.enemy_stack_row.offset_left)
	tr.assert_eq("reward rows match narrowed right column", hud.reward_task_row.offset_right - hud.reward_task_row.offset_left, hud.enemy_stack_row.offset_right - hud.enemy_stack_row.offset_left)
	var reward_panel_height := hud.reward_panel_bg.offset_bottom - hud.reward_panel_bg.offset_top
	tr.assert_true("reward panel contains task rows plus bottom padding", reward_panel_height >= hud.reward_task_row.offset_bottom + 8.0)
	tr.assert_eq("info panel aligns with narrowed right column", hud.info_panel_bg.offset_left, hud.enemy_stack_bg.offset_left)
	tr.assert_eq("boss panel aligns with narrowed right column", hud.boss_status_bg.offset_left, hud.enemy_stack_bg.offset_left)
	var rows: Array = [{
		"enemy_id": 301,
		"enemy_name": "腐食兽",
		"order": 1,
		"enemy_pos": Vector2i(3, 4),
		"attack_pos": Vector2i(3, 5),
		"status": BattleEngine.INTENT_STATUS_HIT,
		"target_kind": BattleEngine.TARGET_KIND_BUILDING,
		"target_id": -1,
		"target_name": "建筑",
		"target_hp": 2,
		"target_damage": 1,
		"has_attack": true,
	}]
	hud.set_enemy_action_stack(rows)
	var row_node: Control = hud.enemy_stack_row.get_child(0)
	var status_mark: Control = row_node.get_node("StatusMark")
	tr.assert_true("enemy status mark stays inside narrowed row", status_mark.offset_right <= HUD.ENEMY_STACK_ROW_SIZE.x)
	scene.free()

static func _test_hud_omits_persistent_map_feature_tags(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	tr.assert_eq("hud does not create persistent map feature panel", hud.get_node_or_null("Root/MapFeaturePanel"), null)
	tr.assert_true("map feature tags are not exposed as hud API", not hud.has_method("set_map_features"))
	scene.free()

static func _test_hud_sanctuary_preview_uses_bar_segments(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.sanctuary_label = hud.get_node("Root/TopRow/SanctuaryLabel")
	hud.set_sanctuary(9, 12)
	hud.set_sanctuary_preview_loss(3)
	var bar: Control = hud.sanctuary_label.get_node("SanctuaryBar")
	tr.assert_eq("sanctuary bar segment count", bar.get_child_count(), 12)
	tr.assert_eq("sanctuary preview loss state", hud.get_sanctuary_preview_loss(), 3)
	tr.assert_eq("sanctuary filled segment stays amber", (bar.get_child(5) as ColorRect).color, HUD.UI_HP_FILL)
	var preview_color := (bar.get_child(8) as ColorRect).color
	tr.assert_true("sanctuary preview segment uses red fill", preview_color.r > 0.9 and preview_color.g < 0.3)
	tr.assert_true("sanctuary UI omits numeric preview copy", not hud.sanctuary_label.text.contains("预计"))
	scene.free()

static func _test_hud_squad_cards_use_segmented_hp_bars(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.squad_strip_bg = hud.get_node("Root/SquadStripBg")
	hud.squad_strip_row = hud.get_node("Root/SquadStripBg/SquadStripRow")
	var hp2 := _add(BattleState.new(), _make_bh_with_stats({"max_hp": 2}), Vector2i(0, 0))
	var ui_portrait := GradientTexture2D.new()
	hp2.def.ui_portrait = ui_portrait
	var hp5_def := _make_bh_with_stats({"max_hp": 5})
	var hp5 := _add(BattleState.new(), hp5_def, Vector2i(1, 0))
	hp5.hp = 3
	var hp10_def := _make_bh_with_stats({"max_hp": 10})
	var hp10 := _add(BattleState.new(), hp10_def, Vector2i(2, 0))
	hp10.hp = 1
	hud.set_squad_status([hp2, hp5, hp10], hp2.id)
	tr.assert_eq("squad card count", hud.squad_strip_row.get_child_count(), 3)
	tr.assert_eq("squad card uses compact ITB-style row size", HUD.SQUAD_CARD_SIZE, Vector2(156, 66))
	for raw_card in hud.squad_strip_row.get_children():
		var squad_card: Control = raw_card
		tr.assert_eq("squad card keeps fixed minimum size", squad_card.custom_minimum_size, HUD.SQUAD_CARD_SIZE)
		tr.assert_true("squad card does not vertically expand", squad_card.size_flags_vertical != Control.SIZE_EXPAND_FILL)
	var first_portrait: TextureRect = hud.squad_strip_row.get_child(0).get_node("SquadPortrait")
	tr.assert_eq("squad card prefers UI portrait over board token", first_portrait.texture, ui_portrait)

	var hp2_bar: Control = hud.squad_strip_row.get_child(0).get_node("SquadHpBar")
	var hp5_bar: Control = hud.squad_strip_row.get_child(1).get_node("SquadHpBar")
	var hp10_bar: Control = hud.squad_strip_row.get_child(2).get_node("SquadHpBar")
	tr.assert_eq("2 hp squad segment count", hp2_bar.get_child_count(), 2)
	tr.assert_eq("5 hp squad segment count", hp5_bar.get_child_count(), 5)
	tr.assert_eq("10 hp squad segment count", hp10_bar.get_child_count(), 10)
	tr.assert_true("2 hp squad bar fits card", hp2_bar.offset_right <= HUD.SQUAD_CARD_SIZE.x - 8.0)
	tr.assert_true("5 hp squad bar fits card", hp5_bar.offset_right <= HUD.SQUAD_CARD_SIZE.x - 8.0)
	tr.assert_true("10 hp squad bar fits card", hp10_bar.offset_right <= HUD.SQUAD_CARD_SIZE.x - 8.0)
	tr.assert_eq("normal squad segment uses HP fill", (hp5_bar.get_child(0) as ColorRect).color, HUD.UI_HP_FILL)
	tr.assert_eq("empty squad segment uses dark fill", (hp5_bar.get_child(4) as ColorRect).color, HUD.UI_HP_EMPTY)
	tr.assert_eq("critical squad segment uses critical fill", (hp10_bar.get_child(0) as ColorRect).color, HUD.UI_HP_CRITICAL)
	tr.assert_eq("10 hp empty segment uses dark fill", (hp10_bar.get_child(9) as ColorRect).color, HUD.UI_HP_EMPTY)

	var labels: Array = []
	_collect_label_texts(hud.squad_strip_row, labels)
	var joined := " ".join(labels)
	tr.assert_true("squad cards omit old heart pip labels", not joined.contains("♥") and not joined.contains("♡"))
	scene.free()

static func _test_hud_ability_buttons_do_not_overlap_portrait(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.ability_bar_bg = hud.get_node("Root/AbilityBarBg")
	hud.ability_portrait_frame = hud.get_node("Root/SelectedUnitPanelBg/AbilityPortraitFrame")
	hud.ability_title = hud.get_node("Root/SelectedUnitPanelBg/AbilityTitle")
	hud.ability_portrait = hud.get_node("Root/SelectedUnitPanelBg/AbilityPortraitFrame/AbilityPortrait")
	hud.ability_hp_label = hud.get_node("Root/SelectedUnitPanelBg/AbilityHpLabel")
	hud.ability_info_label = hud.get_node("Root/SelectedUnitPanelBg/AbilityInfoLabel")
	hud.ability_row = hud.get_node("Root/AbilityBarBg/AbilityRow")
	hud._ensure_selected_unit_panel()
	hud._apply_layout_metrics()
	var token := GradientTexture2D.new()
	hud.show_ability_bar(
		{
			"name": "赏金猎人",
			"hp": 2,
			"max_hp": 2,
			"move": 2,
			"token": token,
		},
		[
			{"id": "attack", "name": "链锤击", "desc": "近战", "active": true, "is_default": true},
			{"id": "relic", "name": "护卫肩撞", "desc": "未装备", "active": false},
			{"id": "wait", "name": "悬赏处决", "desc": "结束", "active": false},
		]
	)
	var card: Control = hud.ability_bar_bg.get_node("SelectedUnitCardBg")
	var portrait: Control = card.get_node("AbilityPortraitFrame")
	var stack: Control = hud.ability_bar_bg.get_node("AbilityStack")
	var card_right := card.offset_right
	var portrait_right := card.offset_left + portrait.offset_right
	var minimum_gap := 18.0
	tr.assert_true("ability buttons stay right of unit card", stack.offset_left >= card_right + minimum_gap)
	tr.assert_true("ability buttons stay right of portrait", stack.offset_left >= portrait_right + minimum_gap)
	tr.assert_true("ability buttons keep lightweight dock width", stack.offset_right - stack.offset_left >= 590.0)
	tr.assert_eq("ability stack is horizontal", stack is HBoxContainer, true)
	tr.assert_true("ability buttons are visible", stack.get_child_count() == 3)
	for raw_slot in stack.get_children():
		var slot: Control = raw_slot
		tr.assert_true("ability slot keeps lightweight dock card width", slot.custom_minimum_size.x >= 190.0)
		tr.assert_true("ability slot keeps lightweight dock card height", slot.custom_minimum_size.y >= 70.0)
	var label_texts: Array = []
	_collect_label_texts(stack, label_texts)
	var labels := " ".join(label_texts)
	tr.assert_true("ability slot shows active skill description", labels.contains("近战"))
	tr.assert_true("ability slot shows disabled skill description", labels.contains("未装备"))
	tr.assert_true("ability slot shows third skill description", labels.contains("结束"))
	tr.assert_eq("ability slot compacts melee push summary", hud._compact_ability_slot_meta("近战 (1 格) 1 伤 + 推 1", "adjacent_enemy_or_boss"), "近战 · 1伤 · 推1")
	tr.assert_eq("ability slot compacts ranged pull summary", hud._compact_ability_slot_meta("3 格 1 伤 + 拉 1", "line_enemy_or_boss_range_3"), "3格直线 · 1伤 · 拉1")
	tr.assert_eq("ability slot compacts unlimited line summary", hud._compact_ability_slot_meta("无限直线 1 伤 + 推 1", "line_enemy_or_boss_unlimited"), "无限直线 · 1伤 · 推1")
	tr.assert_eq("ability slot keeps pull and side push summary", hud._compact_ability_slot_meta("2 格拉近 · 侧推", "line_enemy_range_2"), "2格直线 · 拉近 · 侧推")
	scene.free()

static func _test_hud_all_warden_skills_have_short_and_detail_copy(tr) -> void:
	var hud := HUD.new()
	var seen_ids: Dictionary = {}
	var expectations := {
		"bounty_chain_strike": {"slot": "近战 · 1伤 · 推1", "detail": "推动目标", "badge": "近战"},
		"bounty_guard_shoulder": {"slot": "近战 · 1伤 · 换位", "detail": "换位", "badge": "换位"},
		"bounty_execute": {"slot": "近战 · 1伤 · 击杀 · 2/2", "detail": "限次收尾", "badge": "近战"},
		"graverobber_hook_rope": {"slot": "3格直线 · 1伤 · 拉1", "detail": "拉近敌人", "badge": "直线"},
		"graverobber_rift_wedge": {"slot": "3格 · 1伤 · 地裂", "detail": "延迟目标裂隙", "badge": "裂隙"},
		"graverobber_backhand_throw": {"slot": "2格直线 · 拉近 · 侧推", "detail": "尝试侧推", "badge": "直线"},
		"mage_repulsion_bolt": {"slot": "无限直线 · 1伤 · 推1", "detail": "推动目标", "badge": "直线"},
		"mage_ward_fire": {"slot": "2格 · 护盾 · 减伤", "detail": "抵消下一次 1 点伤害", "badge": "建筑"},
		"mage_sigil": {"slot": "3格 · 减速 · 2/2", "detail": "持续 2 回合", "badge": "区域"},
	}
	for def_id in [&"warden_bountyhunter", &"warden_graverobber", &"warden_mage"]:
		for skill in WardenSkillCatalogScript.skills_for_warden(def_id):
			var id := String(skill.get("id", ""))
			seen_ids[id] = true
			var desc := String(skill.get("desc", ""))
			var target_rule := String(skill.get("target_rule", ""))
			var ability := {
				"id": id,
				"name": skill.get("name", ""),
				"desc": desc,
				"target_rule": target_rule,
				"active": true,
			}
			var expected: Dictionary = expectations.get(id, {})
			var slot_copy := hud._ability_slot_meta(ability)
			if int(skill.get("max_uses_per_battle", 0)) > 0:
				var remaining := int(skill.get("max_uses_per_battle", 0))
				ability["desc"] = "%s · %d/%d" % [desc, remaining, remaining]
				slot_copy = hud._ability_slot_meta(ability)
			var detail_copy := hud._ability_detail_body_text(ability, false)
			var badges := hud._ability_detail_badges(ability)
			tr.assert_true("%s has compact slot copy" % id, slot_copy != "" and slot_copy.length() <= 18)
			tr.assert_true("%s detail is explicit" % id, detail_copy != "" and not detail_copy.contains("尚未配置"))
			tr.assert_true("%s has at least one detail badge" % id, not badges.is_empty())
			tr.assert_true("%s detail adds explanation beyond raw desc" % id, detail_copy != desc)
			tr.assert_eq("%s slot copy matches skill implementation" % id, slot_copy, String(expected.get("slot", slot_copy)))
			tr.assert_true("%s detail copy names concrete effect" % id, detail_copy.contains(String(expected.get("detail", ""))))
			tr.assert_true("%s badge names target or effect" % id, badges.has(String(expected.get("badge", ""))))
			ability["is_armed"] = true
			tr.assert_true("%s armed slot keeps tactical summary" % id, hud._ability_slot_meta(ability).begins_with(slot_copy))
	tr.assert_eq("all current warden skills covered by detail copy", seen_ids.size(), 9)
	hud.free()

static func _test_hud_upgraded_skill_copy_uses_upgrade_values(tr) -> void:
	var hud := HUD.new()
	var ward_fire := WardenSkillCatalogScript.get_skill(WardenSkillCatalogScript.MAGE_WARD_FIRE, [WardenSkillCatalogScript.UPGRADE_MAGE_WARD_FIRE_SHIELD])
	var ability := {
		"id": String(ward_fire.get("id", "")),
		"name": ward_fire.get("name", ""),
		"desc": ward_fire.get("desc", ""),
		"target_rule": ward_fire.get("target_rule", ""),
		"active": true,
		"upgraded": true,
		"shield_amount": int(ward_fire.get("shield_amount", 0)),
	}
	tr.assert_eq("upgraded ward fire slot copy uses shield value", hud._ability_slot_meta(ability), "2格 · 护盾 · 减伤")
	tr.assert_true("upgraded ward fire detail uses shield value", hud._ability_detail_body_text(ability, false).contains("2 点伤害"))
	tr.assert_true("upgraded ward fire badges include upgrade", "强化" in hud._ability_detail_badges(ability))
	hud.free()

static func _test_hud_ability_detail_panel_shows_skill_context(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.ability_bar_bg = hud.get_node("Root/AbilityBarBg")
	hud.ability_portrait_frame = hud.get_node("Root/SelectedUnitPanelBg/AbilityPortraitFrame")
	hud.ability_title = hud.get_node("Root/SelectedUnitPanelBg/AbilityTitle")
	hud.ability_portrait = hud.get_node("Root/SelectedUnitPanelBg/AbilityPortraitFrame/AbilityPortrait")
	hud.ability_hp_label = hud.get_node("Root/SelectedUnitPanelBg/AbilityHpLabel")
	hud.ability_info_label = hud.get_node("Root/SelectedUnitPanelBg/AbilityInfoLabel")
	hud.ability_row = hud.get_node("Root/AbilityBarBg/AbilityRow")
	hud._ensure_selected_unit_panel()
	hud._ensure_ability_detail_panel()
	hud._apply_layout_metrics()
	hud.show_ability_bar(
		{
			"name": "赏金猎人",
			"hp": 4,
			"max_hp": 12,
			"move": 2,
			"token": GradientTexture2D.new(),
		},
		[
			{"id": "attack", "name": "链锤击", "desc": "近战 (1 格) 1 伤 + 推 1", "active": true, "is_default": true},
			{"id": "guard_shoulder", "name": "护卫肩撞", "desc": "换位 · 护建筑", "active": false},
			{"id": "wait", "name": "待命", "desc": "结束", "active": true},
		]
	)
	tr.assert_eq("ability detail hidden before hover", hud.ability_detail_panel.visible, false)
	hud._show_ability_detail({"id": "attack", "name": "链锤击", "desc": "近战 (1 格) 1 伤 + 推 1", "active": true, "slot_index": 0})
	tr.assert_eq("ability detail shows on hover", hud.ability_detail_panel.visible, true)
	tr.assert_eq("ability detail title uses skill name", hud.ability_detail_title.text, "链锤击")
	tr.assert_true("ability detail body explains push", hud.ability_detail_body.text.contains("推动目标"))
	tr.assert_true("ability detail footer explains arming", hud.ability_detail_footer.text.contains("点击技能"))
	tr.assert_eq("ability detail avoids mismatched art backdrop", hud.ability_detail_panel.get_node_or_null("Backdrop"), null)
	tr.assert_true("ability detail uses compact command tooltip width", hud.ability_detail_panel.offset_right - hud.ability_detail_panel.offset_left <= 340.0)
	tr.assert_true("ability detail uses compact command tooltip height", hud.ability_detail_panel.offset_bottom - hud.ability_detail_panel.offset_top <= 112.0)
	tr.assert_true("ability detail stays above command bar", hud.ability_detail_panel.offset_bottom <= hud.ability_bar_bg.offset_top - 8.0)
	tr.assert_true("ability detail remains within screen", hud.ability_detail_panel.offset_left >= 0.0 and hud.ability_detail_panel.offset_right <= 1280.0)
	tr.assert_true("ability detail badges include melee", _label_texts_contain(hud.ability_detail_badges, "近战"))
	hud._on_ability_slot_exited()
	tr.assert_eq("ability detail hides when hover exits without armed skill", hud.ability_detail_panel.visible, false)

	hud.show_ability_bar(
		{
			"name": "赏金猎人 ▸ 选择目标",
			"hp": 4,
			"max_hp": 12,
			"move": 2,
			"token": GradientTexture2D.new(),
		},
		[
			{"id": "attack", "name": "链锤击", "desc": "近战 (1 格) 1 伤 + 推 1", "active": true, "is_default": true, "is_armed": true},
			{"id": "guard_shoulder", "name": "护卫肩撞", "desc": "换位 · 护建筑", "active": false},
			{"id": "wait", "name": "待命", "desc": "结束", "active": true},
		]
	)
	tr.assert_eq("armed ability detail is pinned visible", hud.ability_detail_panel.visible, true)
	tr.assert_true("armed ability detail keeps specific skill copy", hud.ability_detail_body.text.contains("推动目标"))
	tr.assert_true("armed ability detail footer explains targeting", hud.ability_detail_footer.text.contains("选择有效目标"))
	hud._on_ability_slot_exited()
	tr.assert_eq("armed ability detail stays visible after hover exit", hud.ability_detail_panel.visible, true)
	hud.hide_ability_bar()
	tr.assert_eq("ability detail hides with ability bar", hud.ability_detail_panel.visible, false)
	scene.free()

static func _test_hud_disabled_ability_reports_reason(tr) -> void:
	var hud := HUD.new()
	var ability := {
		"id": "mage_ward_fire",
		"name": "护火",
		"desc": "护盾 · 减伤 1",
		"target_rule": "protected_building_range_2",
		"active": false,
		"disabled_reason": "冷却 1 回合",
		"disabled_reason_code": "cooldown",
		"cooldown_remaining": 1,
	}
	tr.assert_true("disabled ability footer shows actual reason", hud._ability_detail_footer_text(ability, false).contains("冷却 1 回合"))
	tr.assert_true("disabled ability badges do not say unimplemented", not hud._ability_detail_badges(ability).has("未接入"))
	tr.assert_true("disabled ability badges omit unavailable reason", not hud._ability_detail_badges(ability).has("冷却 1 回合"))
	tr.assert_true("disabled ability slot omits cooldown text", not hud._ability_slot_meta(ability).contains("冷却"))
	var unavailable: Array = []
	hud.ability_unavailable.connect(func(id: String, reason: String): unavailable.append({"id": id, "reason": reason}))
	hud.ability_bar_bg = ColorRect.new()
	hud.selected_unit_panel_bg = ColorRect.new()
	hud.ability_title = Label.new()
	hud.ability_hp_label = Label.new()
	hud.ability_info_label = Label.new()
	hud.ability_portrait = TextureRect.new()
	hud.ability_stack = HBoxContainer.new()
	hud.ability_console_frame = Panel.new()
	hud.selected_unit_card_bg = ColorRect.new()
	hud.ability_bar_bg.add_child(hud.ability_stack)
	hud.show_ability_bar(
		{"name": "法师", "hp": 4, "max_hp": 4, "move": 2},
		[ability]
	)
	var slot := hud.ability_stack.get_child(0)
	var button: Button = null
	for child in slot.get_children():
		if child is Button:
			button = child
			break
	tr.assert_true("disabled-looking ability button stays clickable", button != null and not button.disabled)
	button.pressed.emit()
	tr.assert_eq("disabled ability emits unavailable signal", unavailable.size(), 1)
	if not unavailable.is_empty():
		tr.assert_eq("unavailable signal reports ability id", unavailable[0].id, "mage_ward_fire")
		tr.assert_true("unavailable signal reports reason", String(unavailable[0].reason).contains("冷却 1 回合"))
	hud.free()

static func _test_hud_ability_cooldown_uses_visual_state(tr) -> void:
	var hud := HUD.new()
	hud.ability_bar_bg = ColorRect.new()
	hud.selected_unit_panel_bg = ColorRect.new()
	hud.ability_title = Label.new()
	hud.ability_hp_label = Label.new()
	hud.ability_info_label = Label.new()
	hud.ability_portrait = TextureRect.new()
	hud.ability_stack = HBoxContainer.new()
	hud.ability_console_frame = Panel.new()
	hud.selected_unit_card_bg = ColorRect.new()
	hud.ability_bar_bg.add_child(hud.ability_stack)
	hud.show_ability_bar(
		{"name": "赏金猎人", "hp": 3, "max_hp": 3, "move": 2},
		[
			{"id": "guard_shoulder", "name": "护卫肩撞", "desc": "换位 · 敌人 1 伤", "active": true, "cooldown_rounds": 1, "cooldown_remaining": 0},
			{"id": "bounty_execute", "name": "悬赏处决", "desc": "1 伤 · 击杀计数", "active": false, "cooldown_rounds": 2, "cooldown_remaining": 1, "disabled_reason": "冷却 1 回合"},
		]
	)
	var ready_slot: Control = hud.ability_stack.get_child(0)
	var cooling_slot: Control = hud.ability_stack.get_child(1)
	tr.assert_eq("ready cooldown skill omits ready clock", ready_slot.get_node_or_null("CooldownReadyIcon"), null)
	tr.assert_eq("ready cooldown skill omits cooldown ring", ready_slot.get_node_or_null("CooldownRing"), null)
	tr.assert_eq("ready cooldown skill omits card scrim", ready_slot.get_node_or_null("CooldownCardScrim"), null)
	tr.assert_eq("ready cooldown skill omits icon scrim", ready_slot.get_node_or_null("CooldownIconScrim"), null)
	tr.assert_true("cooling skill shows card scrim", cooling_slot.get_node_or_null("CooldownCardScrim") != null)
	tr.assert_true("cooling skill shows icon scrim", cooling_slot.get_node_or_null("CooldownIconScrim") != null)
	tr.assert_true("cooling skill shows progress ring", cooling_slot.get_node_or_null("CooldownRing") != null)
	var label_texts: Array = []
	_collect_label_texts(hud.ability_stack, label_texts)
	tr.assert_true("cooldown state is not duplicated as slot text", not " ".join(label_texts).contains("冷却"))
	hud.free()

static func _test_hud_selected_unit_uses_segmented_hp_bar(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.ability_bar_bg = hud.get_node("Root/AbilityBarBg")
	hud.ability_portrait_frame = hud.get_node("Root/SelectedUnitPanelBg/AbilityPortraitFrame")
	hud.ability_title = hud.get_node("Root/SelectedUnitPanelBg/AbilityTitle")
	hud.ability_portrait = hud.get_node("Root/SelectedUnitPanelBg/AbilityPortraitFrame/AbilityPortrait")
	hud.ability_hp_label = hud.get_node("Root/SelectedUnitPanelBg/AbilityHpLabel")
	hud.ability_info_label = hud.get_node("Root/SelectedUnitPanelBg/AbilityInfoLabel")
	hud.ability_row = hud.get_node("Root/AbilityBarBg/AbilityRow")
	hud._ensure_selected_unit_panel()
	hud._apply_layout_metrics()
	hud.show_ability_bar(
		{
			"name": "赏金猎人",
			"hp": 3,
			"max_hp": 10,
			"move": 2,
			"token": GradientTexture2D.new(),
		},
		[
			{"id": "attack", "name": "链锤击", "desc": "近战", "active": true, "is_default": true},
		]
	)
	var card: Control = hud.ability_bar_bg.get_node("SelectedUnitCardBg")
	var hp_bar: Control = card.get_node("SelectedUnitHpBar")
	tr.assert_eq("selected unit hp bar segment count follows max hp", hp_bar.get_child_count(), 10)
	tr.assert_true("selected unit hp bar fits selected card", hp_bar.offset_right <= card.offset_right - 8.0)
	tr.assert_eq("selected unit hp label uses numeric health", hud.ability_hp_label.text, "生命 3/10")
	tr.assert_true("selected unit hp label omits old heart pips", not hud.ability_hp_label.text.contains("♥") and not hud.ability_hp_label.text.contains("♡"))
	tr.assert_eq("selected unit filled segment uses HP fill", (hp_bar.get_child(0) as ColorRect).color, HUD.UI_HP_FILL)
	tr.assert_eq("selected unit empty segment uses dark fill", (hp_bar.get_child(9) as ColorRect).color, HUD.UI_HP_EMPTY)

	hud.show_ability_bar(
		{
			"name": "赏金猎人",
			"hp": 9,
			"max_hp": 18,
			"move": 2,
			"token": GradientTexture2D.new(),
		},
		[
			{"id": "attack", "name": "链锤击", "desc": "近战", "active": true, "is_default": true},
		]
	)
	hp_bar = card.get_node("SelectedUnitHpBar")
	tr.assert_eq("selected unit high max hp compresses visible segments", hp_bar.get_child_count(), HUD.HP_BAR_MAX_VISIBLE_SEGMENTS)
	tr.assert_true("compressed selected unit hp bar still fits selected card", hp_bar.offset_right <= card.offset_right - 8.0)
	tr.assert_eq("selected unit high max hp keeps numeric health", hud.ability_hp_label.text, "生命 9/18")
	scene.free()

static func _test_enemy_board_hover_does_not_show_enemy_info(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.info_panel_bg = hud.get_node("Root/InfoPanelBg")
	hud.info_title = hud.get_node("Root/InfoPanelBg/InfoTitle")
	hud.info_body = hud.get_node("Root/InfoPanelBg/InfoBody")
	scene.hud = hud
	var state := BattleState.new()
	var warden := _add(state, _make_bh(), Vector2i(2, 4))
	var enemy := _add(state, _make_carrion(), Vector2i(3, 4))
	state.phase = BattleState.Phase.PLAYER_ACTION
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	scene._hover_cell = enemy.position
	hud.show_info_panel("stale", "stale")
	scene._refresh_info_panel()
	tr.assert_eq("enemy board hover hides info panel", hud.info_panel_bg.visible, false)
	tr.assert_true("enemy board hover does not show enemy name", not hud.info_title.text.contains(enemy.def.display_name))
	tr.assert_eq("enemy board hover clears focused enemy", scene._focused_enemy_id, -1)
	scene._hover_cell = warden.position
	hud.show_info_panel("stale", "stale")
	scene._refresh_info_panel()
	tr.assert_eq("warden board hover also hides info panel", hud.info_panel_bg.visible, false)
	tr.assert_true("warden board hover does not show warden name", not hud.info_title.text.contains(warden.def.display_name))
	scene.free()

static func _test_enemy_push_events_defer_intent_refresh(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var state := BattleState.new()
	var enemy := _add(state, _make_carrion(), Vector2i(3, 4))
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	var pushed := BattleEvent.make(BattleEvent.Type.UNIT_PUSHED)
	pushed.unit_id = enemy.id
	pushed.from_pos = Vector2i(3, 4)
	pushed.to_pos = Vector2i(3, 3)
	var moved := BattleEvent.make(BattleEvent.Type.UNIT_MOVED)
	moved.unit_id = enemy.id
	moved.from_pos = Vector2i(3, 4)
	moved.to_pos = Vector2i(3, 3)
	tr.assert_true("enemy push defers intent refresh", scene._events_include_enemy_displacement([pushed]))
	tr.assert_true("enemy move defers intent refresh", scene._events_include_enemy_displacement([moved]))
	scene.free()

static func _test_outcome_banner_waits_for_event_playback(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.get_node("Root/Banner").visible = false
	scene.hud = hud
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.phase = BattleState.Phase.BATTLE_END
	engine.state.outcome = BattleState.Outcome.VICTORY
	scene.engine = engine
	scene._defer_state_refresh_until_events = true
	scene._on_state_changed()
	tr.assert_eq("outcome banner hidden until events finish", hud.get_node("Root/Banner").visible, false)
	scene.free()

static func _collect_label_texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_collect_label_texts(child, out)

static func _label_texts_contain(node: Node, needle: String) -> bool:
	var texts: Array = []
	_collect_label_texts(node, texts)
	return " ".join(texts).contains(needle)

static func _first_ability_button(hud: HUD) -> Button:
	if hud == null or hud.ability_stack == null or hud.ability_stack.get_child_count() == 0:
		return null
	for child in hud.ability_stack.get_child(0).get_children():
		if child is Button:
			return child
	return null

static func _test_unit_action_visual_resets_without_selection(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var state := BattleState.new()
	var warden := _add(state, _make_bh(), Vector2i(0, 0))
	state.phase = BattleState.Phase.PLAYER_ACTION
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	scene.diamond_board_view = DiamondBoardView.new()
	scene.hud = scene.get_node("HUD")
	scene.hud.squad_strip_bg = scene.hud.get_node("Root/SquadStripBg")
	scene.hud.squad_strip_row = scene.hud.get_node("Root/SquadStripBg/SquadStripRow")
	scene.hud.objective_label = scene.hud.get_node("Root/TopRow/ObjectiveLabel")
	warden.has_acted = true
	scene.selected_warden_id = -1
	scene._refresh_action_state_presentation()
	tr.assert_true("diamond board remains available after acted sync", scene.diamond_board_view != null)
	warden.has_acted = false
	warden.has_moved = false
	scene._refresh_action_state_presentation()
	scene.free()

static func _test_garrison_click_uses_event_position_for_deploy(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	scene.diamond_board_view = scene.get_node("DiamondBoardView")
	var input: InputController = scene.get_node("InputController")
	var engine := BattleEngine.new()
	engine.start_battle(
		Grid.new(),
		[_make_bh()],
		[],
		[Vector2i(3, 6)]
	)
	scene.engine = engine
	input.bind(scene)
	var requested: Array[BattleAction] = []
	input.action_requested.connect(func(action: BattleAction): requested.append(action))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	input.handle_board_input(event, scene.diamond_board_view.cell_to_pixel(Vector2i(3, 6)))
	tr.assert_eq("garrison click emits deploy action", requested.size(), 1)
	if not requested.is_empty():
		tr.assert_eq("garrison click action kind", requested[0].kind, BattleAction.Kind.DEPLOY)
		tr.assert_eq("garrison click action target", requested[0].target_pos, Vector2i(3, 6))
	scene.free()

static func _test_f1_debug_shortcut_forces_player_turn_win(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	scene.hud = hud
	scene.diamond_board_view = DiamondBoardView.new()
	hud.help_label = hud.get_node("Root/HelpLabel")
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.GARRISON
	engine.state.outcome = BattleState.Outcome.UNDECIDED
	scene.engine = engine
	scene.toggle_debug_mode()
	tr.assert_eq("F1 debug shortcut ignores garrison phase", engine.state.outcome, BattleState.Outcome.UNDECIDED)
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	scene.toggle_debug_mode()
	tr.assert_eq("F1 debug shortcut sets victory outcome", engine.state.outcome, BattleState.Outcome.VICTORY)
	tr.assert_eq("F1 debug shortcut enters battle end phase", engine.state.phase, BattleState.Phase.BATTLE_END)
	scene.free()

static func _test_enemy_stack_shows_no_attack_rows(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.enemy_stack_bg = hud.get_node("Root/EnemyStackBg")
	hud.enemy_stack_mode = hud.get_node("Root/EnemyStackBg/EnemyStackMode")
	hud.enemy_stack_row = hud.get_node("Root/EnemyStackBg/EnemyStackRow")
	scene.hud = hud
	scene.diamond_board_view = DiamondBoardView.new()

	var state := BattleState.new()
	var enemy := _add(state, _make_carrion(), Vector2i(0, 0))
	state.phase = BattleState.Phase.PLAYER_ACTION
	var plan := AIDecider.EnemyPlan.new()
	plan.origin_pos = enemy.position
	plan.move_to = enemy.position
	plan.attack_pos = Vector2i(-1, -1)
	state.enemy_warnings[enemy.id] = plan
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine

	scene._refresh_enemy_intent_overlay()
	tr.assert_eq("hud shows move-only enemy row", hud.enemy_stack_row.get_child_count(), 1)
	tr.assert_eq("board hides no-attack intent line", scene.diamond_board_view.get_enemy_intents().size(), 0)
	scene.free()

static func _test_battle_scene_updates_building_damage_preview_from_intents(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.enemy_stack_bg = hud.get_node("Root/EnemyStackBg")
	hud.enemy_stack_mode = hud.get_node("Root/EnemyStackBg/EnemyStackMode")
	hud.enemy_stack_row = hud.get_node("Root/EnemyStackBg/EnemyStackRow")
	hud.sanctuary_label = hud.get_node("Root/TopRow/SanctuaryLabel")
	scene.hud = hud
	scene.diamond_board_view = DiamondBoardView.new()

	var state := BattleState.new()
	var building_pos := Vector2i(3, 6)
	state.phase = BattleState.Phase.PLAYER_ACTION
	state.protected_targets = [building_pos]
	state.grid.set_tile(building_pos, Grid.TileType.BUILDING, 2)
	var enemy := _add(state, _make_basic_melee_enemy(), Vector2i(3, 5))
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	hud.set_sanctuary(12, 12)

	var rows: Array = [{
		"enemy_id": enemy.id,
		"enemy_name": "腐食兽",
		"enemy_hp": enemy.hp,
		"enemy_max_hp": enemy.def.max_hp,
		"order": 1,
		"enemy_pos": enemy.position,
		"attack_pos": building_pos,
		"status": BattleEngine.INTENT_STATUS_HIT,
		"target_kind": BattleEngine.TARGET_KIND_BUILDING,
		"target_id": -1,
		"target_name": "建筑",
		"target_hp": 2,
		"target_damage": 1,
		"target_pos": building_pos,
		"has_attack": true,
		"attack_fires": true,
	}]
	scene._refresh_enemy_intent_overlay(rows)
	tr.assert_eq("board receives building preview damage", scene.diamond_board_view.get_preview_protected_damage().get(building_pos, 0), 1)
	tr.assert_eq("hud receives sanctuary preview damage", hud.get_sanctuary_preview_loss(), 1)
	scene.free()

static func _test_battle_scene_updates_bell_wave_preview(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	scene.hud = scene.get_node("HUD")
	scene.diamond_board_view = DiamondBoardView.new()
	scene.engine = BattleEngine.new()
	scene.engine.state = BattleState.new()
	scene.engine.state.grid = Grid.new()
	scene.engine.state.phase = BattleState.Phase.PLAYER_ACTION
	scene.engine.state.pending_bell_wave = [Vector2i(3, 3), Vector2i(4, 3)]
	scene._refresh_enemy_intent_overlay()
	tr.assert_eq("board receives bell wave preview", scene.diamond_board_view.get_predicted_bell_wave(), [Vector2i(3, 3), Vector2i(4, 3)])
	scene.diamond_board_view.free()
	scene.free()

static func _test_battle_scene_armed_skill_shows_range_and_targets(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var state := BattleState.new()
	state.grid = Grid.new()
	state.phase = BattleState.Phase.PLAYER_ACTION
	var mage := _add(state, _make_mage(), Vector2i(3, 5))
	_add(state, _make_bh(), Vector2i(0, 0))
	var occupied := _add(state, _make_carrion(), Vector2i(3, 4))
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	scene.diamond_board_view = DiamondBoardView.new()
	scene.hud = scene.get_node("HUD")
	scene.selected_warden_id = mage.id
	scene._armed_ability_id = String(WardenSkillCatalogScript.MAGE_SIGIL)
	scene._refresh_selection_highlights()
	tr.assert_true("armed skill range includes nearby cells", scene.diamond_board_view.get_skill_range_cells().has(Vector2i(3, 4)))
	tr.assert_true("armed skill targets exclude occupied cell", not scene.diamond_board_view.get_skill_target_cells().has(occupied.position))
	tr.assert_true("armed skill targets include empty range cell", scene.diamond_board_view.get_skill_target_cells().has(Vector2i(3, 3)))
	tr.assert_eq("armed skill clears normal attack overlay", scene.diamond_board_view.get_attack_cells().size(), 0)
	scene._armed_ability_id = ""
	scene._refresh_selection_highlights()
	tr.assert_eq("disarmed skill range clears", scene.diamond_board_view.get_skill_range_cells().size(), 0)
	tr.assert_eq("disarmed skill targets clear", scene.diamond_board_view.get_skill_target_cells().size(), 0)
	scene.diamond_board_view.free()
	scene.free()

static func _test_battle_scene_sanctuary_bar_spends_real_protected_damage(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.sanctuary_label = hud.get_node("Root/TopRow/SanctuaryLabel")
	scene.hud = hud
	var state := BattleState.new()
	state.protected_damage_taken = 2
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	scene._sanctuary_integrity = 12
	scene._sanctuary_integrity_max = 12
	scene._refresh_persistent_hud()
	var bar: Control = hud.sanctuary_label.get_node("SanctuaryBar")
	tr.assert_eq("real protected damage spends sanctuary display", hud.sanctuary_integrity, 10)
	tr.assert_eq("spent sanctuary segment is empty", (bar.get_child(10) as ColorRect).color, HUD.UI_HP_EMPTY)
	tr.assert_eq("remaining sanctuary segment is filled", (bar.get_child(9) as ColorRect).color, HUD.UI_HP_FILL)
	scene.free()

static func _test_battle_scene_sanctuary_spends_damage_during_tile_events(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.sanctuary_label = hud.get_node("Root/TopRow/SanctuaryLabel")
	scene.hud = hud
	scene.diamond_board_view = DiamondBoardView.new()
	var state := BattleState.new()
	var building_pos := Vector2i(3, 6)
	state.protected_targets = [building_pos]
	state.grid.set_tile(building_pos, Grid.TileType.RUIN)
	state.protected_damage_taken = 2
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	scene._sanctuary_integrity = 12
	scene._sanctuary_integrity_max = 12
	var first_hit := BattleEvent.make(BattleEvent.Type.TILE_DAMAGED)
	first_hit.to_pos = building_pos
	first_hit.amount = 1
	var second_hit := BattleEvent.make(BattleEvent.Type.TILE_DAMAGED)
	second_hit.to_pos = building_pos
	second_hit.amount = 1
	var destroyed := BattleEvent.make(BattleEvent.Type.TILE_DESTROYED)
	destroyed.to_pos = building_pos

	scene._animating = true
	scene._begin_event_damage_playback([first_hit, second_hit, destroyed])
	tr.assert_eq("event playback starts from pre-batch sanctuary", hud.sanctuary_integrity, 12)
	tr.assert_eq("building display starts from pre-batch hp", scene.diamond_board_view.get_tile_display_override(building_pos).hp, 2)

	scene._anim_tile_changed(first_hit)
	tr.assert_eq("first tile hit spends sanctuary immediately", hud.sanctuary_integrity, 11)
	tr.assert_eq("first tile hit spends building display hp immediately", scene.diamond_board_view.get_tile_display_override(building_pos).hp, 1)

	scene._anim_tile_changed(second_hit)
	tr.assert_eq("second tile hit spends sanctuary immediately", hud.sanctuary_integrity, 10)
	tr.assert_true("building display override clears when damage destroys it", scene.diamond_board_view.get_tile_display_override(building_pos).is_empty())
	scene._anim_tile_changed(destroyed)
	scene._animating = false
	scene._end_event_damage_playback()
	tr.assert_true("event playback clears tile display overrides", scene.diamond_board_view.get_tile_display_override(building_pos).is_empty())
	scene.diamond_board_view.free()
	scene.free()

static func _test_battle_scene_unit_hp_spends_damage_during_unit_events(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.squad_strip_bg = hud.get_node("Root/SquadStripBg")
	hud.squad_strip_row = hud.get_node("Root/SquadStripBg/SquadStripRow")
	scene.hud = hud
	scene.diamond_board_view = DiamondBoardView.new()
	var state := BattleState.new()
	var warden := _add(state, _make_bh_with_stats({"max_hp": 2}), Vector2i(3, 6))
	warden.hp = 1
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	scene._event_unit_snapshots[warden.id] = warden.clone()
	scene._event_unit_snapshots[warden.id].hp = 2
	var damage := BattleEvent.make(BattleEvent.Type.UNIT_DAMAGED)
	damage.unit_id = warden.id
	damage.amount = 1
	damage.to_pos = warden.position

	scene._animating = true
	scene._begin_event_damage_playback([damage])
	tr.assert_eq("unit playback starts from pre-hit hp", scene.diamond_board_view.get_unit_display_override(warden.id).hp, 2)
	scene._refresh_live_damage_presentation()
	var pre_bar: Control = hud.squad_strip_row.get_child(0).get_node("SquadHpBar")
	tr.assert_eq("squad hp starts from pre-hit display", (pre_bar.get_child(1) as ColorRect).color, HUD.UI_HP_FILL)

	scene._consume_presented_unit_damage(damage)
	scene._refresh_live_damage_presentation()
	tr.assert_eq("unit hit spends board hp immediately", scene.diamond_board_view.get_unit_display_override(warden.id).hp, 1)
	var hit_bar: Control = hud.squad_strip_row.get_child(0).get_node("SquadHpBar")
	tr.assert_eq("unit hit spends squad hp immediately", (hit_bar.get_child(1) as ColorRect).color, HUD.UI_HP_EMPTY)
	scene._animating = false
	scene._end_event_damage_playback()
	scene.diamond_board_view.free()
	scene.free()

static func _test_selecting_warden_refreshes_hover_push_preview(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.enemy_stack_bg = hud.get_node("Root/EnemyStackBg")
	hud.enemy_stack_mode = hud.get_node("Root/EnemyStackBg/EnemyStackMode")
	hud.enemy_stack_row = hud.get_node("Root/EnemyStackBg/EnemyStackRow")
	hud.sanctuary_label = hud.get_node("Root/TopRow/SanctuaryLabel")
	scene.hud = hud
	scene.diamond_board_view = DiamondBoardView.new()

	var state := BattleState.new()
	state.phase = BattleState.Phase.PLAYER_ACTION
	var building_pos := Vector2i(3, 6)
	state.protected_targets = [building_pos]
	state.grid.set_tile(building_pos, Grid.TileType.BUILDING, 2)
	var pull_def := TestUnitDefs.generic_warden({
		"max_hp": 3,
		"move": 2,
		"attack_kind": UnitDef.AttackKind.RANGED_PULL,
		"attack_range": 3,
		"attack_damage": 1,
		"attack_force": 1,
	})
	var bh := _add(state, pull_def, Vector2i(3, 3))
	var enemy := _add(state, _make_carrion(), Vector2i(3, 5))
	var plan := AIDecider.EnemyPlan.new()
	plan.origin_pos = enemy.position
	plan.move_to = enemy.position
	plan.attack_pos = building_pos
	state.enemy_warnings[enemy.id] = plan
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	scene._sanctuary_integrity = 12
	scene._sanctuary_integrity_max = 12
	scene._hover_cell = enemy.position

	scene._refresh_enemy_intent_overlay()
	tr.assert_eq("baseline intent threatens building", scene.diamond_board_view.get_preview_protected_damage().get(building_pos, 0), 1)
	scene._on_warden_selected(bh.id)
	tr.assert_true("selecting warden refreshes hover preview after push", not scene.diamond_board_view.get_preview_protected_damage().has(building_pos))
	tr.assert_eq("hover push preview clears sanctuary preloss", hud.get_sanctuary_preview_loss(), 0)
	scene.free()

static func _test_hover_push_preview_marks_fall_on_edge_cell(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	scene.hud = scene.get_node("HUD")
	scene.diamond_board_view = DiamondBoardView.new()
	scene.engine = BattleEngine.new()
	scene.engine.state = BattleState.new()
	scene.engine.state.grid = Grid.new()
	scene.engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(scene.engine.state, _make_bh(), Vector2i(6, 4))
	var enemy := _add(scene.engine.state, _make_carrion(), Vector2i(7, 4))
	scene.selected_warden_id = bh.id
	scene._hover_cell = enemy.position
	scene._refresh_hover_preview()
	var has_edge_fall := false
	for marker in scene.diamond_board_view.get_preview_markers():
		if String(marker.get("kind", "")) == "fall" and marker.get("pos", Vector2i(-1, -1)) == enemy.position:
			has_edge_fall = true
	tr.assert_true("hover fall preview marks edge cell", has_edge_fall)
	scene.diamond_board_view.free()
	scene.free()

static func _test_hud_objective_summary_shows_protected_targets(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.objective_label = hud.get_node("Root/TopRow/ObjectiveLabel")
	var state := BattleState.new()
	state.max_rounds = 6
	state.protected_targets = [Vector2i(1, 6), Vector2i(3, 6), Vector2i(5, 6)]
	state.grid.set_tile(Vector2i(1, 6), Grid.TileType.BUILDING, 2)
	state.grid.set_tile(Vector2i(3, 6), Grid.TileType.RUIN)
	state.grid.set_tile(Vector2i(5, 6), Grid.TileType.BUILDING, 1)
	state.destroyed_protected_count = 1
	state.protected_damage_taken = 3
	hud.set_battle_status_summary(state)
	var text := hud.objective_label.text
	tr.assert_true("objective summary shows main goal", text.contains("目标：撑到第 6 轮"))
	tr.assert_true("objective summary omits protected target details in top bar", not text.contains("建筑 2/3 HP 2,0,1"))
	tr.assert_true("objective summary omits numeric sanctuary preview", not text.contains("预计 -"))
	scene.free()

static func _test_hud_objective_summary_shows_boss_state(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.objective_label = hud.get_node("Root/TopRow/ObjectiveLabel")
	var state := BattleState.new()
	state.max_rounds = 6
	state.boss_config_id = "knell_lord_demo_01"
	state.doom_count = 2
	state.doom_count_max = 3
	state.boss_anchor_positions = [Vector2i(1, 3), Vector2i(6, 3)]
	state.boss_anchor_hp = {Vector2i(1, 3): 2, Vector2i(6, 3): 0}
	state.boss_anchor_hp_max = 2
	state.heart_hits = 1
	state.heart_hit_cap = 3
	hud.set_battle_status_summary(state)
	var text := hud.objective_label.text
	tr.assert_true("boss summary shows main goal", text.contains("Boss：撑到第 6 轮"))
	tr.assert_true("boss summary omits doom details in top bar", not text.contains("Doom 2/3"))
	tr.assert_true("boss summary omits anchor hp in top bar", not text.contains("锚石 1/2 HP 2,0"))
	tr.assert_true("boss summary omits heart clock in top bar", not text.contains("心钟 1/3"))
	scene.free()

static func _test_hud_boss_status_panel_shows_script_and_window(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.objective_label = hud.get_node("Root/TopRow/ObjectiveLabel")
	hud.boss_status_bg = hud.get_node("Root/BossStatusBg")
	hud.boss_status_title = hud.get_node("Root/BossStatusBg/BossStatusTitle")
	hud.boss_status_body = hud.get_node("Root/BossStatusBg/BossStatusBody")
	var state := BattleState.new()
	state.grid = Grid.new()
	state.phase = BattleState.Phase.PLAYER_ACTION
	state.current_round = 5
	state.max_rounds = 6
	state.boss_config_id = "knell_lord_demo_01"
	state.doom_count = 2
	state.doom_count_max = 3
	state.boss_anchor_positions = [Vector2i(1, 3), Vector2i(6, 3)]
	state.boss_anchor_hp = {Vector2i(1, 3): 0, Vector2i(6, 3): 0}
	state.boss_anchor_hp_max = 2
	state.heart_position = Vector2i(4, 2)
	state.heart_exposed_until_round = 6
	state.heart_hits = 2
	state.heart_hit_cap = 3
	hud.set_battle_status_summary(state)
	var text := hud.boss_status_body.text
	tr.assert_eq("boss status panel visible", hud.boss_status_bg.visible, true)
	tr.assert_true("boss status names current script", text.contains("本轮脚本：第 5 轮残锚共鸣：已压制"))
	tr.assert_true("boss status names next script", text.contains("下一脚本：第 6 轮终局钟鸣：已压制"))
	tr.assert_true("boss status shows exposed window", text.contains("心钟：暴露中"))
	tr.assert_true("boss status shows doom reduction ready", text.contains("Doom -1 已就绪"))
	tr.assert_true("boss status body clips inside panel", hud.boss_status_body.clip_text)
	tr.assert_eq("boss status body wraps inside narrow column", hud.boss_status_body.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	tr.assert_true("boss status body stays inside panel bottom", hud.boss_status_body.offset_bottom <= hud.boss_status_bg.offset_bottom - hud.boss_status_bg.offset_top - 8.0)
	state.heart_doom_reduction_applied = true
	hud.set_boss_status(state)
	tr.assert_true("boss status shows doom reduction applied", hud.boss_status_body.text.contains("Doom -1 已生效"))
	scene.free()

static func _test_hud_hides_boss_status_panel_for_normal_battle(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.objective_label = hud.get_node("Root/TopRow/ObjectiveLabel")
	hud.boss_status_bg = hud.get_node("Root/BossStatusBg")
	hud.boss_status_title = hud.get_node("Root/BossStatusBg/BossStatusTitle")
	hud.boss_status_body = hud.get_node("Root/BossStatusBg/BossStatusBody")
	var state := BattleState.new()
	hud.boss_status_bg.visible = true
	hud.boss_status_title.text = "Boss"
	hud.boss_status_body.text = "Doom"
	hud.set_battle_status_summary(state)
	tr.assert_eq("normal battle hides boss panel", hud.boss_status_bg.visible, false)
	tr.assert_eq("normal battle clears boss title", hud.boss_status_title.text, "")
	tr.assert_eq("normal battle clears boss body", hud.boss_status_body.text, "")
	scene.free()

static func _test_battle_scene_boss_event_feedback_updates_help(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.help_label = hud.get_node("Root/HelpLabel")
	hud.boss_status_bg = hud.get_node("Root/BossStatusBg")
	hud.boss_status_title = hud.get_node("Root/BossStatusBg/BossStatusTitle")
	hud.boss_status_body = hud.get_node("Root/BossStatusBg/BossStatusBody")
	scene.hud = hud
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.boss_config_id = "knell_lord_demo_01"
	engine.state.doom_count = 2
	engine.state.doom_count_max = 3
	engine.state.boss_anchor_positions = [Vector2i(1, 3), Vector2i(6, 3)]
	engine.state.boss_anchor_hp = {Vector2i(1, 3): 0, Vector2i(6, 3): 2}
	engine.state.heart_hits = 1
	engine.state.heart_hit_cap = 3
	scene.engine = engine
	var doom := BattleEvent.make(BattleEvent.Type.PHASE_CHANGED)
	doom.extra = {"boss_doom": true}
	scene._update_boss_event_feedback(doom)
	tr.assert_true("boss doom feedback updates help", hud.help_label.text.contains("Boss Doom +1"))
	var heart := BattleEvent.make(BattleEvent.Type.TILE_DAMAGED)
	heart.extra = {"boss_heart_hit": true}
	scene._update_boss_event_feedback(heart)
	tr.assert_true("boss heart hit feedback updates help", hud.help_label.text.contains("心脏钟命中：1 / 3"))
	var anchor := BattleEvent.make(BattleEvent.Type.TILE_DESTROYED)
	anchor.extra = {"boss_anchor_destroyed": true}
	scene._update_boss_event_feedback(anchor)
	tr.assert_true("boss anchor feedback updates help", hud.help_label.text.contains("Boss 锚石破坏"))
	scene.free()

static func _test_battle_event_animator_clears_board_visual_positions(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var board := DiamondBoardView.new()
	var animator = BattleEventAnimatorScript.new()
	animator.bind(scene, board)
	board.set_unit_visual_position(9, board.cell_to_pixel(Vector2i(1, 1)))
	animator._clear_all_visual_positions()
	tr.assert_true("battle event animator clears transient board positions", not board.has_unit_visual_position(9))
	tr.assert_true("battle event animator exposes sequential playback entry point", animator.has_method(&"play_events"))
	board.free()
	scene.free()

static func _test_attack_fx_layers_replace_legacy_flash_state(tr) -> void:
	var board := DiamondBoardView.new()
	var layer := {
		"phase": "action",
		"from_cell": Vector2i(2, 5),
		"to_cell": Vector2i(2, 4),
		"attack_kind": UnitDef.AttackKind.RANGED_PUSH,
		"progress": 0.5,
	}
	board.set_attack_fx_layers([layer])
	tr.assert_eq("attack fx layer can be set", board.get_attack_fx_layers().size(), 1)
	tr.assert_eq("attack fx layer keeps phase", board.get_attack_fx_layers()[0].phase, "action")
	tr.assert_eq("attack fx layer uses documented from cell", board.get_attack_fx_layers()[0].from_cell, Vector2i(2, 5))
	tr.assert_eq("attack fx layer uses documented target cell", board.get_attack_fx_layers()[0].to_cell, Vector2i(2, 4))
	board.clear_attack_fx_layers()
	tr.assert_eq("attack fx layer clears", board.get_attack_fx_layers().size(), 0)
	var presenter = AttackFxPresenterScript.new()
	presenter.bind(null, board)
	presenter.clear()
	tr.assert_true("attack fx presenter exposes play_attack", presenter.has_method(&"play_attack"))
	board.free()

static func _test_battle_animation_timing_is_readable(tr) -> void:
	tr.assert_true("enemy movement timing is slower than old snap-like beat", BattleEventAnimatorScript.MOVE_DURATION >= 0.30)
	tr.assert_true("push timing remains readable", BattleEventAnimatorScript.PUSH_DURATION >= 0.24)
	tr.assert_true("fall timing remains readable", BattleEventAnimatorScript.FALL_DURATION >= 0.28)
	tr.assert_true("attack action timing is readable", AttackFxPresenterScript.ACTION_DURATION >= 0.22)
	tr.assert_true("impact timing is readable", AttackFxPresenterScript.IMPACT_DURATION >= 0.14)

static func _test_battle_sfx_presenter_uses_resource_paths_without_generation(tr) -> void:
	var sfx = BattleSfxPresenterScript.new()
	var fake_audio := _FakeAudioManager.new()
	sfx.bind_audio(fake_audio)
	tr.assert_true("battle sfx maps ranged push to shared resource id", BattleSfxPresenterScript.SOUND_IDS.get(&"ranged_push") == AudioManagerScript.SFX_RANGED_PUSH)
	tr.assert_true("battle sfx maps default impact to shared resource id", BattleSfxPresenterScript.SOUND_IDS.get(&"impact_hit") == AudioManagerScript.SFX_IMPACT_HIT)
	tr.assert_eq("missing battle sfx id has no shared resource id", sfx._audio_sound_id(&"missing_sound"), &"")
	sfx.play_attack_action(UnitDef.AttackKind.RANGED_PUSH)
	tr.assert_eq("battle sfx delegates attack action to audio manager", fake_audio.played_ids, [AudioManagerScript.SFX_RANGED_PUSH])
	sfx.play_impact(UnitDef.AttackKind.RANGED_PULL)
	tr.assert_eq("battle sfx delegates impact to audio manager", fake_audio.played_ids, [AudioManagerScript.SFX_RANGED_PUSH, AudioManagerScript.SFX_IMPACT_PULL])

static func _test_battle_scene_command_sfx_uses_audio_manager(tr) -> void:
	var scene := BattleScene.new()
	var fake_audio := _FakeAudioManager.new()
	scene.bind_audio(fake_audio)
	scene._on_ability_unavailable("attack", "冷却中")
	tr.assert_eq("unavailable ability plays feedback sfx", fake_audio.played_ids, [AudioManagerScript.SFX_ABILITY_UNAVAILABLE])
	scene._play_action_sfx(BattleAction.deploy(Vector2i(3, 6)))
	scene._play_action_sfx(BattleAction.confirm_deploy())
	scene._play_action_sfx(BattleAction.end_turn())
	tr.assert_eq("battle commands use shared sfx ids", fake_audio.played_ids.slice(1), [AudioManagerScript.SFX_TILE_SELECT, AudioManagerScript.SFX_DEPLOY_CONFIRM, AudioManagerScript.SFX_END_TURN])
	scene.free()

static func _test_battle_scene_outcome_and_death_sfx_uses_audio_manager(tr) -> void:
	var scene := BattleScene.new()
	var fake_audio := _FakeAudioManager.new()
	scene.bind_audio(fake_audio)
	scene.engine = BattleEngine.new()
	scene.engine.state = BattleState.new()
	scene.engine.state.outcome = BattleState.Outcome.VICTORY
	scene._emit_finish_if_ready()
	scene._anim_unit_died(BattleEvent.make(BattleEvent.Type.UNIT_DIED))
	tr.assert_eq("victory and death sfx delegate to audio manager", fake_audio.played_ids, [AudioManagerScript.SFX_VICTORY_STINGER, AudioManagerScript.SFX_UNIT_DEATH])
	scene.free()

static func _test_attack_fx_presenter_builds_staged_layers(tr) -> void:
	var presenter = AttackFxPresenterScript.new()
	var request := {
		"from_cell": Vector2i(2, 5),
		"to_cell": Vector2i(5, 2),
		"attack_kind": UnitDef.AttackKind.RANGED_PUSH,
		"direction": Vector2i(1, -1),
	}
	var action_layers: Array = presenter._action_layers(request, 0.22)
	tr.assert_eq("ranged attack starts with two visual stages", action_layers.size(), 2)
	tr.assert_eq("ranged attack keeps muzzle stage separate", action_layers[0].phase, "muzzle")
	tr.assert_eq("ranged attack keeps projectile stage separate", action_layers[1].phase, "projectile")
	var impact_layers: Array = presenter._impact_layers(request, 0.60)
	tr.assert_eq("attack impact keeps dust and impact stages", impact_layers.size(), 2)
	tr.assert_eq("attack impact dust draws before hit spark", impact_layers[0].phase, "dust")
	tr.assert_eq("attack impact hit spark draws last", impact_layers[1].phase, "impact")

static func _test_player_attack_fx_context_and_trigger(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var state := BattleState.new()
	state.grid = Grid.new()
	state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(state, _make_bh(), Vector2i(3, 5))
	var enemy := _add(state, _make_carrion(), Vector2i(3, 4))
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	scene._capture_player_attack_context(BattleAction.attack(bh.id, enemy.position))
	tr.assert_eq("player attack context captures from cell", scene._pending_player_attack_context.from_cell, bh.position)
	tr.assert_eq("player attack context captures target cell", scene._pending_player_attack_context.to_cell, enemy.position)
	var damage := BattleEvent.make(BattleEvent.Type.UNIT_DAMAGED)
	damage.unit_id = enemy.id
	damage.to_pos = enemy.position
	tr.assert_true("damage at target starts player attack fx", scene._event_starts_player_attack_fx(damage))
	var pushed := BattleEvent.make(BattleEvent.Type.UNIT_PUSHED)
	pushed.unit_id = enemy.id
	pushed.from_pos = enemy.position
	pushed.to_pos = Vector2i(3, 3)
	tr.assert_true("push to later cell does not start attack fx by itself", not scene._event_starts_player_attack_fx(pushed))
	scene.free()

static func _test_non_attack_skill_does_not_capture_player_attack_fx(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var state := BattleState.new()
	state.grid = Grid.new()
	state.phase = BattleState.Phase.PLAYER_ACTION
	var gr := _add(state, _make_gr(), Vector2i(3, 6))
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	scene._capture_player_attack_context(BattleAction.skill(gr.id, WardenSkillCatalog.GRAVEROBBER_RIFT_WEDGE, Vector2i(3, 3)))
	tr.assert_true("rift wedge does not capture attack fx context", scene._pending_player_attack_context.is_empty())
	scene.free()

static func _test_empty_event_batch_clears_unplayed_player_attack_fx(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	scene.engine = BattleEngine.new()
	scene.engine.state = BattleState.new()
	scene.engine.state.grid = Grid.new()
	scene.engine.state.phase = BattleState.Phase.PLAYER_ACTION
	scene._pending_player_attack_context = {"from_cell": Vector2i(0, 0), "to_cell": Vector2i(1, 0)}
	scene._on_events([])
	tr.assert_true("empty event batch clears unplayed attack fx context", scene._pending_player_attack_context.is_empty())
	scene.free()

static func _test_move_event_playback_refreshes_ability_bar(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.ability_bar_bg = hud.get_node("Root/AbilityBarBg")
	hud.ability_portrait_frame = hud.get_node("Root/SelectedUnitPanelBg/AbilityPortraitFrame")
	hud.ability_title = hud.get_node("Root/SelectedUnitPanelBg/AbilityTitle")
	hud.ability_portrait = hud.get_node("Root/SelectedUnitPanelBg/AbilityPortraitFrame/AbilityPortrait")
	hud.ability_hp_label = hud.get_node("Root/SelectedUnitPanelBg/AbilityHpLabel")
	hud.ability_info_label = hud.get_node("Root/SelectedUnitPanelBg/AbilityInfoLabel")
	hud.ability_row = hud.get_node("Root/AbilityBarBg/AbilityRow")
	hud._ensure_selected_unit_panel()
	hud._apply_layout_metrics()
	scene.hud = hud
	scene.diamond_board_view = DiamondBoardView.new()
	var state := BattleState.new()
	state.grid = Grid.new()
	state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(state, _make_bh(), Vector2i(3, 6))
	_add(state, _make_carrion(), Vector2i(3, 4))
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	scene.selected_warden_id = bh.id
	scene._refresh_ability_bar()
	var selected_before: Array = []
	var unavailable_before: Array = []
	hud.ability_selected.connect(func(id: String): selected_before.append(id))
	hud.ability_unavailable.connect(func(id: String, reason: String): unavailable_before.append({"id": id, "reason": reason}))
	_first_ability_button(hud).pressed.emit()
	tr.assert_eq("bounty chain starts unavailable before adjacent move", selected_before.size(), 0)
	tr.assert_eq("bounty chain reports unavailable before adjacent move", unavailable_before.size(), 1)

	bh.position = Vector2i(3, 5)
	scene._refresh_after_event_playback()
	var selected_after: Array = []
	var unavailable_after: Array = []
	hud.ability_selected.connect(func(id: String): selected_after.append(id))
	hud.ability_unavailable.connect(func(id: String, reason: String): unavailable_after.append({"id": id, "reason": reason}))
	_first_ability_button(hud).pressed.emit()
	tr.assert_eq("bounty chain selects after move playback refresh", selected_after.size(), 1)
	tr.assert_eq("bounty chain no longer reports unavailable after move playback", unavailable_after.size(), 0)
	scene.diamond_board_view.free()
	scene.free()

static func _test_attack_fx_layers_remain_attack_presentation_only(tr) -> void:
	var layer_request := {
		"from_cell": Vector2i(3, 5),
		"to_cell": Vector2i(3, 4),
		"attack_kind": UnitDef.AttackKind.MELEE_PUSH,
		"direction": Vector2i(0, -1),
	}
	var presenter = AttackFxPresenterScript.new()
	var impact_layers: Array = presenter._impact_layers(layer_request, 0.60)
	tr.assert_eq("impact layer keeps only attack presentation fields", impact_layers[1].keys().size(), 6)
	var action_layers: Array = presenter._action_layers(layer_request, 0.22)
	tr.assert_eq("action layer keeps only attack presentation fields", action_layers[1].keys().size(), 6)

static func _test_attack_fx_presenter_clear_restores_intents(tr) -> void:
	var board := DiamondBoardView.new()
	var presenter = AttackFxPresenterScript.new()
	presenter.bind(null, board)
	board.set_attack_fx_suppresses_intents(true)
	board.set_attack_fx_layers([{
		"phase": "action",
		"from_cell": Vector2i(2, 5),
		"to_cell": Vector2i(2, 4),
		"attack_kind": UnitDef.AttackKind.RANGED_PUSH,
		"progress": 0.5,
	}])
	presenter.clear()
	tr.assert_eq("attack fx presenter clear removes layers", board.get_attack_fx_layers().size(), 0)
	tr.assert_true("attack fx presenter clear restores intent overlays", not board._attack_fx_suppresses_intents)
	board.free()

static func _test_enemy_attack_fx_request_uses_event_positions(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var enemy := Unit.new(12, _make_carrion(), Vector2i(3, 1))
	var request := scene._build_attack_fx_request(enemy, Vector2i(3, 5), false, enemy.id, Vector2i(3, 4))
	tr.assert_eq("enemy attack fx request keeps event from cell", request.from_cell, Vector2i(3, 4))
	tr.assert_eq("enemy attack fx request keeps target cell", request.to_cell, Vector2i(3, 5))
	tr.assert_eq("enemy attack fx request uses attacker kind", request.attack_kind, UnitDef.AttackKind.MELEE_BUMP)
	tr.assert_eq("enemy attack fx request computes direction from event cells", request.direction, Vector2i(0, 1))
	scene.free()

static func _test_animator_primes_displacement_before_results(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var board := DiamondBoardView.new()
	var animator = BattleEventAnimatorScript.new()
	animator.bind(scene, board)
	var enemy := Unit.new(12, _make_carrion(), Vector2i(3, 3))
	animator.set_unit_snapshots({enemy.id: enemy.clone()})
	var pushed := BattleEvent.make(BattleEvent.Type.UNIT_PUSHED)
	pushed.unit_id = enemy.id
	pushed.from_pos = Vector2i(3, 4)
	pushed.to_pos = Vector2i(3, 3)
	animator._prime_displacement_visual_positions([pushed])
	tr.assert_true("animator primes pushed unit visual position", board.has_unit_visual_position(enemy.id))
	tr.assert_eq("primed visual position starts at event from cell", board.get_unit_visual_position(enemy.id), board.cell_to_pixel(pushed.from_pos))
	board.free()
	scene.free()

static func _test_outcome_banner_shows_reason(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.banner = hud.get_node("Root/Banner")
	hud.show_outcome(BattleState.Outcome.DEFEAT, "Boss Doom 满")
	tr.assert_true("outcome banner includes defeat text", hud.banner.text.contains("失 败"))
	tr.assert_true("outcome banner includes reason", hud.banner.text.contains("Boss Doom 满"))
	tr.assert_eq("outcome banner visible", hud.banner.visible, true)
	hud.show_outcome(BattleState.Outcome.VICTORY)
	tr.assert_eq("outcome banner keeps legacy text without reason", hud.banner.text, "胜 利")
	scene.free()

static func _test_battle_scene_outcome_reason_names_sources(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var victory := BattleState.new()
	victory.outcome = BattleState.Outcome.VICTORY
	victory.max_rounds = 6
	tr.assert_eq("victory reason names defended round", scene._battle_outcome_reason(victory), "守住第 6 轮")

	var boss_defeat := BattleState.new()
	boss_defeat.outcome = BattleState.Outcome.DEFEAT
	boss_defeat.boss_config_id = "knell_lord_demo_01"
	boss_defeat.doom_count = 3
	boss_defeat.doom_count_max = 3
	boss_defeat.boss_breached = true
	tr.assert_eq("boss defeat reason names doom", scene._battle_outcome_reason(boss_defeat), "Boss Doom 满")

	var warden_defeat := BattleState.new()
	warden_defeat.outcome = BattleState.Outcome.DEFEAT
	tr.assert_eq("team defeat reason names wardens", scene._battle_outcome_reason(warden_defeat), "守卫者全灭")

	var line_defeat := BattleState.new()
	line_defeat.outcome = BattleState.Outcome.DEFEAT
	_add(line_defeat, _make_bh(), Vector2i(0, 0))
	line_defeat.protected_targets = [Vector2i(1, 6)]
	line_defeat.grid.set_tile(Vector2i(1, 6), Grid.TileType.RUIN)
	tr.assert_eq("line defeat reason names breach", scene._battle_outcome_reason(line_defeat), "防线溃败")
	scene.free()

class _FakeAudioManager:
	var played_ids: Array = []

	func play_sfx(sound_id: StringName) -> void:
		played_ids.append(sound_id)
