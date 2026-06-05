extends RefCounted
## Demo Boss regression tests: doom script, anchors, no early victory, summary fields.

static func _make_bh() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"warden_bountyhunter"
	d.display_name = "BH"
	d.faction = UnitDef.Faction.WARDEN
	d.max_hp = 2
	d.move = 3
	d.attack_kind = UnitDef.AttackKind.MELEE_PUSH
	d.attack_range = 1
	d.attack_damage = 1
	d.attack_force = 1
	return d

static func _make_carrion(hp: int = 1) -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"carrion"
	d.display_name = "腐食兽"
	d.faction = UnitDef.Faction.ENEMY
	d.max_hp = hp
	d.move = 1
	d.attack_kind = UnitDef.AttackKind.MELEE_BUMP
	d.attack_range = 1
	d.attack_damage = 1
	d.attack_force = 0
	return d

static func _boss_config(doom_initial: int = 0) -> Dictionary:
	return {
		"boss_config_id": "knell_lord_demo_01",
		"boss_script_id": "knell_lord_demo_six_round",
		"doom_count_initial": doom_initial,
		"doom_count_max": 3,
		"anchor_positions": [Vector2i(2, 3), Vector2i(5, 3)],
		"anchor_hp": 2,
		"heart_position": Vector2i(4, 3),
		"heart_hit_cap": 3,
	}

static func _start_boss(engine: BattleEngine, enemies: Array = [], doom_initial: int = 0) -> void:
	var grid := Grid.new()
	var building := Vector2i(7, 7)
	grid.set_tile(building, Grid.TileType.BUILDING, 2)
	engine.start_battle(
		grid,
		[_make_bh()],
		enemies,
		[Vector2i(2, 4)],
		[],
		[],
		6,
		[building],
		[],
		[],
		_boss_config(doom_initial)
	)
	engine.apply_action(BattleAction.deploy(Vector2i(2, 4)))
	engine.apply_action(BattleAction.confirm_deploy())

static func _end_rounds(engine: BattleEngine, count: int) -> void:
	for _i in range(count):
		if engine.state.outcome != BattleState.Outcome.UNDECIDED:
			return
		engine.apply_action(BattleAction.end_turn())

static func run(tr) -> void:
	_test_clearing_enemies_does_not_early_win_boss(tr)
	_test_destroying_all_anchors_does_not_early_win_boss(tr)
	_test_unit_collision_damages_boss_anchor(tr)
	_test_doom_cap_triggers_boss_breach(tr)
	_test_round_six_wins_when_doom_below_cap(tr)
	_test_boss_summary_contains_run_fields(tr)

static func _test_clearing_enemies_does_not_early_win_boss(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine, [{"def": _make_carrion(1), "pos": Vector2i(3, 4)}])
	var warden := engine.state.wardens()[0]
	engine.state.enemies()[0].position = Vector2i(3, 4)
	engine.apply_action(BattleAction.attack(warden.id, Vector2i(3, 4)))
	tr.assert_eq("boss enemy cleared", engine.state.enemies().size(), 0)
	tr.assert_eq("boss clear does not early-win", engine.state.outcome, BattleState.Outcome.UNDECIDED)
	tr.assert_true("boss battle continues after clear", engine.state.current_round < engine.state.max_rounds)

static func _test_destroying_all_anchors_does_not_early_win_boss(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine)
	engine.state.damage_boss_anchor(Vector2i(2, 3), 2)
	engine.state.damage_boss_anchor(Vector2i(5, 3), 2)
	tr.assert_eq("all boss anchors destroyed", engine.state.boss_alive_anchor_count(), 0)
	tr.assert_eq("anchor clear does not early-win", engine.state.outcome, BattleState.Outcome.UNDECIDED)
	tr.assert_eq("heart exposed after anchors", engine.state.is_boss_heart_exposed(), true)

static func _test_unit_collision_damages_boss_anchor(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine, [{"def": _make_carrion(3), "pos": Vector2i(2, 2)}])
	var warden := engine.state.wardens()[0]
	warden.position = Vector2i(2, 1)
	var enemy := engine.state.enemies()[0]
	enemy.position = Vector2i(2, 2)
	var events := engine.apply_action(BattleAction.attack(warden.id, Vector2i(2, 2)))
	tr.assert_eq("collision damaged boss anchor once", engine.state.boss_anchor_hp[Vector2i(2, 3)], 1)
	tr.assert_eq("boss anchor collision not protected damage", engine.state.protected_damage_taken, 0)
	tr.assert_eq("boss anchor collision keeps battle undecided", engine.state.outcome, BattleState.Outcome.UNDECIDED)
	var tile_damaged := false
	for e in events:
		if e.type == BattleEvent.Type.TILE_DAMAGED and e.to_pos == Vector2i(2, 3):
			tile_damaged = true
	tr.assert_eq("collision emits anchor tile damage", tile_damaged, true)

	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	warden.has_acted = false
	warden.position = Vector2i(2, 1)
	enemy.position = Vector2i(2, 2)
	enemy.hp = enemy.def.max_hp
	enemy.alive = true
	engine.apply_action(BattleAction.attack(warden.id, Vector2i(2, 2)))
	tr.assert_eq("second collision destroys anchor", engine.state.is_boss_anchor_alive(Vector2i(2, 3)), false)
	tr.assert_eq("destroying one anchor does not early-win", engine.state.outcome, BattleState.Outcome.UNDECIDED)

static func _test_doom_cap_triggers_boss_breach(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine, [], 2)
	_end_rounds(engine, 3)
	tr.assert_eq("round three doom reaches cap", engine.state.doom_count, 3)
	tr.assert_eq("doom cap defeats battle", engine.state.outcome, BattleState.Outcome.DEFEAT)
	tr.assert_eq("doom cap marks boss breached", engine.state.boss_breached, true)

static func _test_round_six_wins_when_doom_below_cap(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine)
	engine.state.damage_boss_anchor(Vector2i(2, 3), 2)
	engine.state.damage_boss_anchor(Vector2i(5, 3), 2)
	_end_rounds(engine, 6)
	tr.assert_eq("boss suppressed doom stays below cap", engine.state.doom_count, 1)
	tr.assert_eq("boss round six survival wins", engine.state.outcome, BattleState.Outcome.VICTORY)

static func _test_boss_summary_contains_run_fields(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var engine := BattleEngine.new()
	_start_boss(engine, [], 2)
	_end_rounds(engine, 3)
	scene.engine = engine
	var summary := scene._build_battle_summary()
	tr.assert_eq("summary boss doom count", summary.boss_doom_count, 3)
	tr.assert_eq("summary boss doom max", summary.boss_doom_count_max, 3)
	tr.assert_eq("summary boss breached", summary.boss_breached, true)
	tr.assert_eq("summary boss line breach for run loss", summary.line_breached, true)
	tr.assert_eq("summary boss config id", summary.boss_config_id, "knell_lord_demo_01")
	scene.free()
