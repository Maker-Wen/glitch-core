extends RefCounted
## Regression: preview_action must only return events for the player's action.
## It must NOT trigger enemy execution / auto-advance turn / spawn rifts.

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
	_test_preview_does_not_advance_turn(tr)
	_test_preview_returns_only_player_action_events(tr)
	_test_preview_state_unchanged(tr)
	_test_preview_relay_events(tr)

static func _test_preview_does_not_advance_turn(tr) -> void:
	# Single warden hits last enemy. apply_action would advance the round.
	# preview_action must NOT.
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(engine.state, _make_bh(), Vector2i(3, 5))
	var enemy := _add(engine.state, _make_carrion(), Vector2i(3, 4))
	var before_round: int = engine.state.current_round
	var events := engine.preview_action(BattleAction.attack(bh.id, Vector2i(3, 4)))
	tr.assert_eq("real state round unchanged", engine.state.current_round, before_round)
	tr.assert_eq("real state BH still active", bh.has_acted, false)
	# Events should NOT contain ROUND_STARTED / ENEMY-only movement events.
	var has_round_event: bool = false
	for e in events:
		if e.type == BattleEvent.Type.ROUND_STARTED or e.type == BattleEvent.Type.ROUND_ENDED:
			has_round_event = true
	tr.assert_true("no ROUND_STARTED/ENDED in preview events", not has_round_event)

static func _test_preview_returns_only_player_action_events(tr) -> void:
	# Set up 4 enemies. Preview should only contain events related to the attacked
	# unit, NOT each enemy's "next-turn" movement.
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(engine.state, _make_bh(), Vector2i(3, 5))
	var target := _add(engine.state, _make_carrion(), Vector2i(3, 4))
	# Distant enemies that would otherwise move on enemy_execute
	_add(engine.state, _make_carrion(), Vector2i(0, 0))
	_add(engine.state, _make_carrion(), Vector2i(7, 0))
	_add(engine.state, _make_carrion(), Vector2i(7, 7))
	var events := engine.preview_action(BattleAction.attack(bh.id, Vector2i(3, 4)))
	# Collect set of unit ids touched by movement/push events.
	var moved_ids: Dictionary = {}
	for e in events:
		if e.type == BattleEvent.Type.UNIT_MOVED or e.type == BattleEvent.Type.UNIT_PUSHED:
			moved_ids[e.unit_id] = true
	# Only the target should have any displacement events.
	tr.assert_true("only attack target appears in displacement events", moved_ids.size() <= 1)
	if moved_ids.size() == 1:
		tr.assert_true("the moved unit is the target", moved_ids.has(target.id))

static func _test_preview_state_unchanged(tr) -> void:
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var bh := _add(engine.state, _make_bh(), Vector2i(3, 5))
	var enemy := _add(engine.state, _make_carrion(), Vector2i(3, 4))
	var enemy_pos_before := enemy.position
	var enemy_hp_before := enemy.hp
	engine.preview_action(BattleAction.attack(bh.id, Vector2i(3, 4)))
	tr.assert_eq("enemy position unchanged after preview", enemy.position, enemy_pos_before)
	tr.assert_eq("enemy hp unchanged after preview", enemy.hp, enemy_hp_before)

static func _test_preview_relay_events(tr) -> void:
	# Confirm a real relay (B -> C) produces displacement events for both units
	# but does NOT pollute with unrelated movements.
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var bh_def := _make_bh()
	bh_def.attack_force = 2  # heavy push to trigger relay
	var bh := _add(engine.state, bh_def, Vector2i(3, 5))
	var b := _add(engine.state, _make_carrion(), Vector2i(3, 4))  # hp=2
	var c := _add(engine.state, _make_carrion(), Vector2i(3, 3))  # hp=2
	# Unrelated bystander
	var bystander := _add(engine.state, _make_carrion(), Vector2i(7, 0))
	var events := engine.preview_action(BattleAction.attack(bh.id, Vector2i(3, 4)))
	# Each affected unit should yield at most ONE end-position (the resolver may
	# emit multiple step events; consumer should fold them).
	var displaced_ids: Dictionary = {}
	for e in events:
		if e.type == BattleEvent.Type.UNIT_PUSHED or e.type == BattleEvent.Type.UNIT_MOVED:
			displaced_ids[e.unit_id] = true
	tr.assert_true("relay touches B and C only", displaced_ids.has(b.id) and displaced_ids.has(c.id))
	tr.assert_true("bystander not touched", not displaced_ids.has(bystander.id))
