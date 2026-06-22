extends RefCounted
## Regression coverage for formal battle undo windows.

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _bh() -> UnitDef:
	return TestUnitDefs.bountyhunter()

static func _carrion(overrides: Dictionary = {}) -> UnitDef:
	return TestUnitDefs.carrion_spawn(overrides)

static func _add(s: BattleState, def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	s.units.append(u)
	return u

static func _engine_player_turn() -> Dictionary:
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(engine.state, _bh(), Vector2i(3, 5))
	var enemy := _add(engine.state, _carrion(), Vector2i(3, 3))
	var plan := AIDecider.EnemyPlan.new()
	plan.origin_pos = enemy.position
	plan.move_to = enemy.position
	plan.attack_pos = bh.position
	engine.state.enemy_warnings[enemy.id] = plan
	return {"engine": engine, "bh": bh, "enemy": enemy}

static func _engine_garrison() -> BattleEngine:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var deploy_zone: Array[Vector2i] = [Vector2i(0, 6), Vector2i(1, 6)]
	engine.start_battle(grid, [_bh()], [], deploy_zone)
	return engine

static func run(tr) -> void:
	_test_player_turn_undo_restores_action(tr)
	_test_end_turn_locks_formal_undo(tr)
	_test_auto_enemy_execute_locks_formal_undo(tr)
	_test_garrison_deploy_undo_and_confirm_lock(tr)
	_test_battle_end_disables_formal_undo(tr)

static func _test_player_turn_undo_restores_action(tr) -> void:
	var ctx := _engine_player_turn()
	var engine: BattleEngine = ctx.engine
	var bh: Unit = ctx.bh
	engine.apply_action(BattleAction.move(bh.id, Vector2i(3, 6)))
	tr.assert_true("formal undo available after move", engine.can_undo())
	tr.assert_eq("warden moved before undo", bh.position, Vector2i(3, 6))
	engine.apply_action(BattleAction.undo())
	var restored := engine.state.find_unit(bh.id)
	tr.assert_eq("undo restores warden position", restored.position, Vector2i(3, 5))
	tr.assert_true("undo consumes formal snapshot", not engine.can_undo())

static func _test_end_turn_locks_formal_undo(tr) -> void:
	var ctx := _engine_player_turn()
	var engine: BattleEngine = ctx.engine
	var bh: Unit = ctx.bh
	engine.apply_action(BattleAction.move(bh.id, Vector2i(3, 6)))
	engine.apply_action(BattleAction.end_turn())
	tr.assert_true("end turn clears formal undo", not engine.can_undo())
	var locked_round := engine.state.current_round
	var locked_phase := engine.state.phase
	engine.apply_action(BattleAction.undo())
	tr.assert_eq("formal undo after lock keeps round", engine.state.current_round, locked_round)
	tr.assert_eq("formal undo after lock keeps phase", engine.state.phase, locked_phase)

static func _test_auto_enemy_execute_locks_formal_undo(tr) -> void:
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	engine.state.max_rounds = 5
	var bh := _add(engine.state, _bh(), Vector2i(3, 5))
	var enemy := _add(engine.state, _carrion({"max_hp": 1}), Vector2i(3, 4))
	enemy.hp = 1
	engine.apply_action(BattleAction.attack(bh.id, enemy.position))
	tr.assert_eq("last action advanced to next round", engine.state.current_round, 2)
	tr.assert_true("auto enemy execute clears formal undo", not engine.can_undo())

static func _test_garrison_deploy_undo_and_confirm_lock(tr) -> void:
	var engine := _engine_garrison()
	tr.assert_true("no deploy undo before deploy", not engine.can_undo())
	engine.apply_action(BattleAction.deploy(Vector2i(0, 6)))
	tr.assert_true("deploy creates formal undo", engine.can_undo())
	tr.assert_eq("warden deployed", engine.state.wardens().size(), 1)
	engine.apply_action(BattleAction.undo())
	tr.assert_eq("undo removes deployed warden", engine.state.wardens().size(), 0)
	tr.assert_eq("undo restores pending warden", engine.state.pending_warden_defs.size(), 1)
	engine.apply_action(BattleAction.deploy(Vector2i(0, 6)))
	engine.apply_action(BattleAction.confirm_deploy())
	tr.assert_true("confirm deploy leaves garrison", engine.state.phase != BattleState.Phase.GARRISON)
	tr.assert_true("confirm deploy clears formal undo", not engine.can_undo())

static func _test_battle_end_disables_formal_undo(tr) -> void:
	var ctx := _engine_player_turn()
	var engine: BattleEngine = ctx.engine
	engine.debug_force_victory()
	tr.assert_true("battle end disables formal undo", not engine.can_undo())
