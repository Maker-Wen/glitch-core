extends RefCounted
## Same-faction units may be crossed during movement, but occupied cells remain
## invalid destinations.

static func _make_def(faction: int, move: int = 2) -> UnitDef:
	var d := UnitDef.new()
	d.def_id = &"warden" if faction == UnitDef.Faction.WARDEN else &"enemy"
	d.faction = faction
	d.max_hp = 2
	d.move = move
	d.attack_kind = UnitDef.AttackKind.MELEE_BUMP
	d.attack_range = 1
	d.attack_damage = 1
	return d

static func _add(s: BattleState, def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	s.units.append(u)
	return u

static func _make_player_engine() -> BattleEngine:
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	return engine

static func run(tr) -> void:
	_test_warden_paths_through_warden(tr)
	_test_warden_cannot_stop_on_warden(tr)
	_test_enemy_still_blocks_warden_path(tr)
	_test_enemy_paths_through_enemy(tr)
	_test_enemy_cannot_claim_enemy_cell(tr)

static func _test_warden_paths_through_warden(tr) -> void:
	var engine := _make_player_engine()
	var warden_def := _make_def(UnitDef.Faction.WARDEN, 2)
	var mover := _add(engine.state, warden_def, Vector2i(1, 1))
	_add(engine.state, warden_def, Vector2i(2, 1))
	var legal := engine.get_legal_moves(mover.id)
	tr.assert_true("warden can reach cell beyond allied warden", Vector2i(3, 1) in legal)
	tr.assert_true("allied warden cell is not a destination", not (Vector2i(2, 1) in legal))
	engine.apply_action(BattleAction.move(mover.id, Vector2i(3, 1)))
	tr.assert_eq("warden moved through allied warden", mover.position, Vector2i(3, 1))

static func _test_warden_cannot_stop_on_warden(tr) -> void:
	var engine := _make_player_engine()
	var warden_def := _make_def(UnitDef.Faction.WARDEN, 2)
	var mover := _add(engine.state, warden_def, Vector2i(1, 1))
	_add(engine.state, warden_def, Vector2i(2, 1))
	var events := engine.apply_action(BattleAction.move(mover.id, Vector2i(2, 1)))
	tr.assert_eq("occupied allied cell move produces no events", events.size(), 0)
	tr.assert_eq("warden stays before occupied allied cell", mover.position, Vector2i(1, 1))

static func _test_enemy_still_blocks_warden_path(tr) -> void:
	var engine := _make_player_engine()
	var warden_def := _make_def(UnitDef.Faction.WARDEN, 2)
	var enemy_def := _make_def(UnitDef.Faction.ENEMY, 2)
	var mover := _add(engine.state, warden_def, Vector2i(1, 1))
	_add(engine.state, enemy_def, Vector2i(2, 1))
	var legal := engine.get_legal_moves(mover.id)
	tr.assert_true("enemy cell is not a destination", not (Vector2i(2, 1) in legal))
	tr.assert_true("warden cannot path through enemy", not (Vector2i(3, 1) in legal))

static func _test_enemy_paths_through_enemy(tr) -> void:
	var s := BattleState.new()
	s.grid = Grid.new()
	var enemy_def := _make_def(UnitDef.Faction.ENEMY, 2)
	var warden_def := _make_def(UnitDef.Faction.WARDEN, 2)
	var mover := _add(s, enemy_def, Vector2i(1, 1))
	_add(s, enemy_def, Vector2i(2, 1))
	var warden := _add(s, warden_def, Vector2i(4, 1))
	var plans := AIDecider.plan_enemy_turn(s)
	var plan = plans[mover.id]
	tr.assert_eq("enemy paths through allied enemy", plan.move_to, Vector2i(3, 1))
	tr.assert_eq("enemy attacks from post-move adjacency", plan.attack_pos, warden.position)

static func _test_enemy_cannot_claim_enemy_cell(tr) -> void:
	var s := BattleState.new()
	s.grid = Grid.new()
	var enemy_def := _make_def(UnitDef.Faction.ENEMY, 1)
	var warden_def := _make_def(UnitDef.Faction.WARDEN, 2)
	var mover := _add(s, enemy_def, Vector2i(1, 1))
	var ally := _add(s, enemy_def, Vector2i(2, 1))
	_add(s, warden_def, Vector2i(4, 1))
	var plans := AIDecider.plan_enemy_turn(s)
	var plan = plans[mover.id]
	tr.assert_true("enemy does not stop on allied enemy", plan.move_to != ally.position)
