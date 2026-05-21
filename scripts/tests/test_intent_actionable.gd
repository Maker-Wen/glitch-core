extends RefCounted
## Regression: enemy intent (warning) must be marked non-actionable after the
## player pushes / kills the enemy so the UI threat overlay disappears.

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
	return d

static func _add(s: BattleState, def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	s.units.append(u)
	return u

static func run(tr) -> void:
	_test_pushed_enemy_intent_falls_flat(tr)
	_test_killed_enemy_intent_falls_flat(tr)
	_test_enemy_adjacent_intent_actionable(tr)

static func _test_pushed_enemy_intent_falls_flat(tr) -> void:
	# Carrion adjacent to BH plans to attack BH. After BH pushes Carrion away,
	# the plan must no longer be actionable.
	# Use a second decoy warden so the turn doesn't auto-advance after BH acts.
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(engine.state, _make_bh(), Vector2i(3, 5))
	var decoy := _add(engine.state, _make_bh(), Vector2i(0, 0))  # idle warden
	var carrion := _add(engine.state, _make_carrion(), Vector2i(3, 4))
	# Manually set the plan (in a real round, _begin_round computes this).
	var plan := AIDecider.EnemyPlan.new()
	plan.origin_pos = carrion.position
	plan.move_to = carrion.position  # already adjacent, no move
	plan.attack_pos = bh.position
	engine.state.enemy_warnings[carrion.id] = plan
	# Plan should be actionable initially.
	tr.assert_true("initial plan is actionable", engine.is_plan_actionable(carrion.id))
	# BH attacks Carrion -- push (3,4) -> (3,3). Now no longer adjacent to BH.
	# Decoy hasn't acted, so the turn does not auto-advance.
	engine.apply_action(BattleAction.attack(bh.id, Vector2i(3, 4)))
	tr.assert_eq("carrion pushed north", carrion.position, Vector2i(3, 3))
	tr.assert_eq("round still 1", engine.state.current_round, 1)
	tr.assert_true("plan no longer actionable after push", not engine.is_plan_actionable(carrion.id))

static func _test_killed_enemy_intent_falls_flat(tr) -> void:
	# Carrion with HP=1 dies in one hit. Its plan must not be actionable.
	# Use decoy warden to prevent auto-advance.
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(engine.state, _make_bh(), Vector2i(3, 5))
	var decoy := _add(engine.state, _make_bh(), Vector2i(0, 0))
	var weak_def := _make_carrion()
	weak_def.max_hp = 1
	var carrion := _add(engine.state, weak_def, Vector2i(3, 4))
	carrion.hp = 1
	var plan := AIDecider.EnemyPlan.new()
	plan.origin_pos = carrion.position
	plan.move_to = carrion.position
	plan.attack_pos = bh.position
	engine.state.enemy_warnings[carrion.id] = plan
	engine.apply_action(BattleAction.attack(bh.id, Vector2i(3, 4)))
	# Carrion should be removed entirely (dies + UNIT_REMOVED at Tend).
	tr.assert_eq("carrion removed", engine.state.find_unit(carrion.id), null)
	tr.assert_true("dead enemy plan not actionable", not engine.is_plan_actionable(carrion.id))

static func _test_enemy_adjacent_intent_actionable(tr) -> void:
	# Sanity: an undisturbed adjacent enemy IS actionable.
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(engine.state, _make_bh(), Vector2i(3, 5))
	var carrion := _add(engine.state, _make_carrion(), Vector2i(3, 4))
	var plan := AIDecider.EnemyPlan.new()
	plan.origin_pos = carrion.position
	plan.move_to = carrion.position
	plan.attack_pos = bh.position
	engine.state.enemy_warnings[carrion.id] = plan
	tr.assert_true("undisturbed enemy plan actionable", engine.is_plan_actionable(carrion.id))
