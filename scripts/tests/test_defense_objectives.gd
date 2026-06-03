extends RefCounted
## Defense objective tests: stable max-round victory, protected target failure,
## and first-pass reward task accounting.

static func _make_bh() -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"bh"
	d.display_name = "BH"
	d.faction = UnitDef.Faction.WARDEN
	d.max_hp = 2
	d.move = 2
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

static func _deploy_one(engine: BattleEngine, at: Vector2i) -> void:
	engine.apply_action(BattleAction.deploy(at))
	engine.apply_action(BattleAction.confirm_deploy())

static func run(tr) -> void:
	_test_clear_enemies_does_not_end_battle(tr)
	_test_max_round_victory_with_protected_target_alive(tr)
	_test_all_protected_targets_destroyed_defeats(tr)
	_test_reward_tasks_finalize_at_battle_end(tr)
	_test_enemy_targets_and_damages_protected_building(tr)

static func _test_clear_enemies_does_not_end_battle(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(6, 6)
	grid.set_tile(building, Grid.TileType.BUILDING, 2)
	engine.start_battle(
		grid,
		[_make_bh()],
		[{"def": _make_carrion(1), "pos": Vector2i(3, 3)}],
		[Vector2i(3, 4)],
		[],
		[],
		3,
		[building],
		[BattleState.REWARD_TERMINAL_CLEAR]
	)
	_deploy_one(engine, Vector2i(3, 4))
	var warden := engine.state.wardens()[0]
	var enemy := engine.state.enemies()[0]
	enemy.position = Vector2i(3, 3)
	engine.apply_action(BattleAction.attack(warden.id, Vector2i(3, 3)))
	tr.assert_eq("enemy cleared", engine.state.enemies().size(), 0)
	tr.assert_eq("clear does not early-win", engine.state.outcome, BattleState.Outcome.UNDECIDED)
	tr.assert_eq("battle continues after clear", engine.state.current_round, 2)

static func _test_max_round_victory_with_protected_target_alive(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(6, 6)
	grid.set_tile(building, Grid.TileType.BUILDING, 2)
	engine.start_battle(
		grid,
		[_make_bh()],
		[],
		[Vector2i(3, 4)],
		[],
		[],
		1,
		[building],
		[]
	)
	_deploy_one(engine, Vector2i(3, 4))
	engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("max round survival wins", engine.state.outcome, BattleState.Outcome.VICTORY)

static func _test_all_protected_targets_destroyed_defeats(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(4, 4)
	grid.set_tile(building, Grid.TileType.BUILDING, 1)
	engine.start_battle(
		grid,
		[_make_bh()],
		[],
		[Vector2i(3, 4)],
		[],
		[],
		3,
		[building],
		[BattleState.REWARD_PERFECT_DEFENSE]
	)
	_deploy_one(engine, Vector2i(3, 4))
	var warden := engine.state.wardens()[0]
	PhysicsResolver.resolve_attack(engine.state, warden, warden, Vector2i(1, 0), 1, 0)
	engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("building became ruin", engine.state.grid.get_tile(building), Grid.TileType.RUIN)
	tr.assert_eq("all protected destroyed defeats", engine.state.outcome, BattleState.Outcome.DEFEAT)
	tr.assert_eq("perfect defense failed", engine.state.reward_failed[BattleState.REWARD_PERFECT_DEFENSE], true)

static func _test_reward_tasks_finalize_at_battle_end(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(7, 7)
	grid.set_tile(building, Grid.TileType.BUILDING, 2)
	engine.start_battle(
		grid,
		[_make_bh()],
		[],
		[Vector2i(3, 4)],
		[],
		[],
		1,
		[building],
		[
			BattleState.REWARD_PERFECT_DEFENSE,
			BattleState.REWARD_TERMINAL_CLEAR,
			BattleState.REWARD_PHYSICAL_KILLS_3,
		]
	)
	_deploy_one(engine, Vector2i(3, 4))
	engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("battle won", engine.state.outcome, BattleState.Outcome.VICTORY)
	tr.assert_eq("perfect defense complete", engine.state.reward_completed[BattleState.REWARD_PERFECT_DEFENSE], true)
	tr.assert_eq("terminal clear complete", engine.state.reward_completed[BattleState.REWARD_TERMINAL_CLEAR], true)
	tr.assert_eq("physical kills failed", engine.state.reward_failed[BattleState.REWARD_PHYSICAL_KILLS_3], true)

static func _test_enemy_targets_and_damages_protected_building(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(3, 3)
	grid.set_tile(building, Grid.TileType.BUILDING, 2)
	engine.start_battle(
		grid,
		[_make_bh()],
		[{"def": _make_carrion(2), "pos": Vector2i(3, 2)}],
		[Vector2i(7, 7)],
		[],
		[],
		3,
		[building],
		[BattleState.REWARD_PERFECT_DEFENSE]
	)
	_deploy_one(engine, Vector2i(7, 7))
	var enemy := engine.state.enemies()[0]
	var plan = engine.state.enemy_warnings[enemy.id]
	tr.assert_eq("enemy plans building attack", plan.attack_pos, building)
	engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("building damaged by enemy", engine.state.grid.tile_hp[building], 1)
	tr.assert_eq("perfect defense still not failed by damage alone",
		engine.state.reward_failed[BattleState.REWARD_PERFECT_DEFENSE], false)
