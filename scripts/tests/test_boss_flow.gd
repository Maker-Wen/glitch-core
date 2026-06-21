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
	_test_heart_exposure_window_expires_after_next_round(tr)
	_test_round_six_wins_when_doom_below_cap(tr)
	_test_second_heart_hit_reduces_doom_at_finale(tr)
	_test_third_heart_hit_completes_reward_task(tr)
	_test_push_collision_can_hit_boss_heart(tr)
	_test_enemy_execute_cannot_extend_heart_window(tr)
	_test_unit_on_heart_cell_blocks_push_collision_hit(tr)
	_test_far_tile_attack_rejected_for_boss_objects(tr)
	_test_boss_summary_contains_run_fields(tr)
	_test_boss_summary_contains_heart_hits(tr)

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

static func _test_heart_exposure_window_expires_after_next_round(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine)
	engine.state.damage_boss_anchor(Vector2i(2, 3), 2)
	engine.state.damage_boss_anchor(Vector2i(5, 3), 2)
	tr.assert_eq("heart exposed immediately after anchors", engine.state.is_boss_heart_exposed(), true)
	tr.assert_eq("heart exposed until next round", engine.state.heart_exposed_until_round, 2)
	engine.state.current_round = 3
	tr.assert_eq("heart exposure expires after next round", engine.state.is_boss_heart_exposed(), false)

static func _test_round_six_wins_when_doom_below_cap(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine)
	engine.state.damage_boss_anchor(Vector2i(2, 3), 2)
	engine.state.damage_boss_anchor(Vector2i(5, 3), 2)
	_end_rounds(engine, 6)
	tr.assert_eq("boss suppressed doom stays below cap", engine.state.doom_count, 1)
	tr.assert_eq("boss round six survival wins", engine.state.outcome, BattleState.Outcome.VICTORY)

static func _test_second_heart_hit_reduces_doom_at_finale(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine)
	engine.state.damage_boss_anchor(Vector2i(2, 3), 2)
	engine.state.damage_boss_anchor(Vector2i(5, 3), 2)
	engine.state.doom_count = 1
	engine.state.record_boss_heart_hit(2)
	_end_rounds(engine, 6)
	tr.assert_eq("second heart hit reduces doom before victory", engine.state.doom_count, 0)
	tr.assert_eq("heart doom reduction applied once", engine.state.heart_doom_reduction_applied, true)
	tr.assert_eq("heart reduction keeps boss victory", engine.state.outcome, BattleState.Outcome.VICTORY)

static func _test_third_heart_hit_completes_reward_task(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine)
	engine.state.damage_boss_anchor(Vector2i(2, 3), 2)
	engine.state.damage_boss_anchor(Vector2i(5, 3), 2)
	engine.state.set_reward_tasks([BattleState.REWARD_HEART_WINDOW])
	engine.state.record_boss_heart_hit(3)
	tr.assert_eq("heart window progress reaches cap", engine.state.reward_progress[BattleState.REWARD_HEART_WINDOW], 3)
	tr.assert_eq("heart window reward completes", engine.state.reward_completed[BattleState.REWARD_HEART_WINDOW], true)
	tr.assert_eq("heart window does not early-win", engine.state.outcome, BattleState.Outcome.UNDECIDED)

static func _test_push_collision_can_hit_boss_heart(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine, [{"def": _make_carrion(3), "pos": Vector2i(4, 4)}])
	engine.state.damage_boss_anchor(Vector2i(2, 3), 2)
	engine.state.damage_boss_anchor(Vector2i(5, 3), 2)
	var warden := engine.state.wardens()[0]
	warden.position = Vector2i(4, 5)
	var enemy := engine.state.enemies()[0]
	enemy.position = Vector2i(4, 4)
	engine.apply_action(BattleAction.attack(warden.id, Vector2i(4, 4)))
	tr.assert_eq("push collision records heart hit", engine.state.heart_hits, 1)
	tr.assert_eq("push collision keeps battle undecided", engine.state.outcome, BattleState.Outcome.UNDECIDED)

static func _test_enemy_execute_cannot_extend_heart_window(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine)
	engine.state.damage_boss_anchor(Vector2i(2, 3), 2)
	engine.state.damage_boss_anchor(Vector2i(5, 3), 2)
	engine.state.current_round = 2
	engine.state.phase = BattleState.Phase.ENEMY_EXECUTE
	var enemy := Unit.new(engine.state.allocate_unit_id(), _make_carrion(3), Vector2i(4, 4))
	engine.state.units.append(enemy)
	var attacker := engine.state.wardens()[0]
	attacker.position = Vector2i(4, 5)
	PhysicsResolver.resolve_attack(engine.state, attacker, enemy, Vector2i(0, -1), 1, 1)
	tr.assert_eq("enemy execute push cannot hit expired heart window", engine.state.heart_hits, 0)

static func _test_unit_on_heart_cell_blocks_push_collision_hit(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine)
	engine.state.damage_boss_anchor(Vector2i(2, 3), 2)
	engine.state.damage_boss_anchor(Vector2i(5, 3), 2)
	var blocker := Unit.new(engine.state.allocate_unit_id(), _make_carrion(3), Vector2i(4, 3))
	var pushed := Unit.new(engine.state.allocate_unit_id(), _make_carrion(3), Vector2i(4, 4))
	engine.state.units.append(blocker)
	engine.state.units.append(pushed)
	var attacker := engine.state.wardens()[0]
	attacker.position = Vector2i(4, 5)
	PhysicsResolver.resolve_attack(engine.state, attacker, pushed, Vector2i(0, -1), 1, 1)
	tr.assert_eq("unit on heart cell blocks heart hit", engine.state.heart_hits, 0)
	tr.assert_eq("blocker damaged by unit collision", blocker.hp, 2)

static func _test_far_tile_attack_rejected_for_boss_objects(tr) -> void:
	var engine := BattleEngine.new()
	_start_boss(engine)
	var warden := engine.state.wardens()[0]
	warden.position = Vector2i(2, 6)
	engine.apply_action(BattleAction.attack(warden.id, Vector2i(2, 3)))
	tr.assert_eq("far anchor attack rejected", engine.state.boss_anchor_hp[Vector2i(2, 3)], 2)
	engine.state.damage_boss_anchor(Vector2i(2, 3), 2)
	engine.state.damage_boss_anchor(Vector2i(5, 3), 2)
	warden.has_acted = false
	engine.apply_action(BattleAction.attack(warden.id, Vector2i(4, 3)))
	tr.assert_eq("far heart attack rejected", engine.state.heart_hits, 0)

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
	tr.assert_eq("summary boss breach does not count as line breach", summary.line_breached, false)
	tr.assert_eq("summary boss doom does not add protected damage", summary.protected_damage_taken, 0)
	tr.assert_eq("summary boss config id", summary.boss_config_id, "knell_lord_demo_01")
	scene.free()

static func _test_boss_summary_contains_heart_hits(tr) -> void:
	var scene: BattleScene = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	var engine := BattleEngine.new()
	_start_boss(engine)
	engine.state.record_boss_heart_hit(2)
	scene.engine = engine
	var summary := scene._build_battle_summary()
	tr.assert_eq("summary boss heart hits", summary.boss_heart_hits, 2)
	scene.free()
