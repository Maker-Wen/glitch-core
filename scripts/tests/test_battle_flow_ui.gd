extends RefCounted
## Regression coverage for enemy intent rows consumed by battle-flow UI.

static func _make_bh() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"bh"
	d.display_name = "赏金猎人"
	d.faction = UnitDef.Faction.WARDEN
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.MELEE_PUSH
	d.attack_range = 1
	d.attack_damage = 1
	d.attack_force = 1
	return d

static func _make_carrion() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"carrion"
	d.display_name = "腐食兽"
	d.faction = UnitDef.Faction.ENEMY
	d.max_hp = 2
	d.move = 2
	d.attack_kind = UnitDef.AttackKind.MELEE_BUMP
	d.attack_range = 1
	d.attack_damage = 1
	d.attack_force = 0
	return d

static func _add(s: BattleState, def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	s.units.append(u)
	return u

static func _make_engine_with_locked_melee() -> Dictionary:
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(engine.state, _make_bh(), Vector2i(3, 5))
	var decoy := _add(engine.state, _make_bh(), Vector2i(0, 0))
	var carrion := _add(engine.state, _make_carrion(), Vector2i(3, 4))
	var plan := AIDecider.EnemyPlan.new()
	plan.origin_pos = carrion.position
	plan.move_to = carrion.position
	plan.attack_pos = bh.position
	engine.state.enemy_warnings[carrion.id] = plan
	return {"engine": engine, "bh": bh, "decoy": decoy, "carrion": carrion}

static func run(tr) -> void:
	_test_current_intent_row_has_hit_state(tr)
	_test_preview_push_slides_attack_line_without_mutating_state(tr)
	_test_preview_kill_marks_removed_row(tr)
	_test_pushed_enemy_attack_slot_still_resolves(tr)
	_test_pushed_enemy_attack_can_hit_shifted_target(tr)
	_test_hud_stack_focus_does_not_rebuild_rows(tr)
	_test_hud_stack_rows_use_low_text_status_marks(tr)
	_test_overlay_damage_badges_aggregate_by_cell(tr)
	_test_overlay_clear_all_ranges_clears_enemy_intents(tr)
	_test_enemy_push_events_defer_intent_refresh(tr)
	_test_outcome_banner_waits_for_event_playback(tr)
	_test_unit_action_visual_resets_without_selection(tr)
	_test_garrison_click_uses_event_position_for_deploy(tr)
	_test_enemy_stack_shows_no_attack_rows(tr)
	_test_hud_objective_summary_shows_protected_targets(tr)
	_test_hud_objective_summary_shows_boss_state(tr)
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

static func _test_preview_push_slides_attack_line_without_mutating_state(tr) -> void:
	var ctx := _make_engine_with_locked_melee()
	var engine: BattleEngine = ctx.engine
	var bh: Unit = ctx.bh
	var carrion: Unit = ctx.carrion
	var rows := engine.preview_enemy_intent_ui_state(BattleAction.attack(bh.id, carrion.position))
	tr.assert_eq("preview keeps one row", rows.size(), 1)
	tr.assert_eq("pushed preview keeps attack slot active", rows[0].attack_fires, true)
	tr.assert_eq("pushed preview attack line slides forward", rows[0].attack_pos, Vector2i(3, 4))
	tr.assert_eq("pushed preview has no damage when line hits empty cell", rows[0].target_damage, 0)
	tr.assert_eq("real enemy did not move", carrion.position, Vector2i(3, 4))
	tr.assert_eq("real enemy hp did not change", carrion.hp, 2)

static func _test_preview_kill_marks_removed_row(tr) -> void:
	var ctx := _make_engine_with_locked_melee()
	var engine: BattleEngine = ctx.engine
	var bh: Unit = ctx.bh
	var carrion: Unit = ctx.carrion
	carrion.hp = 1
	carrion.def.max_hp = 1
	var rows := engine.preview_enemy_intent_ui_state(BattleAction.attack(bh.id, carrion.position))
	tr.assert_eq("removed preview keeps row", rows.size(), 1)
	tr.assert_eq("preview row removed", rows[0].status, BattleEngine.INTENT_STATUS_REMOVED)
	tr.assert_true("real enemy still exists after preview", engine.state.find_unit(carrion.id) != null)

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

static func _test_overlay_damage_badges_aggregate_by_cell(tr) -> void:
	var overlay := PreviewOverlay.new()
	var badges: Dictionary = {}
	overlay._add_damage_badge(badges, Vector2i(2, 3), 1, false, false)
	overlay._add_damage_badge(badges, Vector2i(2, 3), 1, true, false)
	overlay._add_damage_badge(badges, Vector2i(4, 3), 1, false, true)
	tr.assert_eq("same cell damage badge amount aggregates", badges[Vector2i(2, 3)].amount, 2)
	tr.assert_eq("separate damage badge kept", badges[Vector2i(4, 3)].amount, 1)
	tr.assert_true("aggregated badge keeps focused state", badges[Vector2i(2, 3)].focused)
	tr.assert_eq("visible aggregate badge is not dimmed", badges[Vector2i(2, 3)].dimmed, false)
	overlay.free()

static func _test_overlay_clear_all_ranges_clears_enemy_intents(tr) -> void:
	var overlay := PreviewOverlay.new()
	overlay.set_enemy_intents([{
		"enemy_id": 1,
		"enemy_pos": Vector2i(3, 3),
		"attack_pos": Vector2i(3, 4),
		"status": BattleEngine.INTENT_STATUS_HIT,
		"attack_fires": true,
	}])
	overlay.set_focused_enemy(1)
	overlay.clear_all_ranges()
	tr.assert_eq("clear all hides enemy intents during animation", overlay.enemy_intents.size(), 0)
	tr.assert_eq("clear all resets enemy focus", overlay.focused_enemy_id, -1)
	overlay.free()

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

static func _test_unit_action_visual_resets_without_selection(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var state := BattleState.new()
	var warden := _add(state, _make_bh(), Vector2i(0, 0))
	state.phase = BattleState.Phase.PLAYER_ACTION
	var engine := BattleEngine.new()
	engine.state = state
	scene.engine = engine
	var view := UnitView.new()
	scene.unit_views[warden.id] = view
	warden.has_acted = true
	scene.selected_warden_id = -1
	scene._sync_unit_view_action_states()
	tr.assert_eq("view dark after acted", view._has_acted, true)
	warden.has_acted = false
	warden.has_moved = false
	scene._sync_unit_view_action_states()
	tr.assert_eq("view bright after next round reset", view._has_acted, false)
	tr.assert_eq("view moved flag reset", view._has_moved, false)
	view.free()
	scene.free()

static func _test_garrison_click_uses_event_position_for_deploy(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	scene.grid_view = scene.get_node("Board/GridView")
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
	input.handle_board_input(event, GridView.cell_to_pixel(Vector2i(3, 6)))
	tr.assert_eq("garrison click emits deploy action", requested.size(), 1)
	if not requested.is_empty():
		tr.assert_eq("garrison click action kind", requested[0].kind, BattleAction.Kind.DEPLOY)
		tr.assert_eq("garrison click action target", requested[0].target_pos, Vector2i(3, 6))
	scene.free()

static func _test_enemy_stack_shows_no_attack_rows(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var hud: HUD = scene.get_node("HUD")
	hud.enemy_stack_bg = hud.get_node("Root/EnemyStackBg")
	hud.enemy_stack_mode = hud.get_node("Root/EnemyStackBg/EnemyStackMode")
	hud.enemy_stack_row = hud.get_node("Root/EnemyStackBg/EnemyStackRow")
	scene.hud = hud
	var preview := PreviewOverlay.new()
	scene.preview = preview

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
	tr.assert_eq("board hides no-attack intent line", preview.enemy_intents.size(), 0)
	preview.free()
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
	hud.set_battle_status_summary(state)
	var text := hud.objective_label.text
	tr.assert_true("objective summary shows main goal", text.contains("目标：撑到第 6 轮"))
	tr.assert_true("objective summary shows protected target count and hp", text.contains("建筑 2/3 HP 2,0,1"))
	tr.assert_true("objective summary shows projected sanctuary loss", text.contains("预计 -1"))
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
	tr.assert_true("boss summary shows doom", text.contains("Doom 2/3"))
	tr.assert_true("boss summary shows anchor hp", text.contains("锚石 1/2 HP 2,0"))
	tr.assert_true("boss summary shows heart clock", text.contains("心钟 1/3"))
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
