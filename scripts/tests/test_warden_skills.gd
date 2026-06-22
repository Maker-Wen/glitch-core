extends RefCounted
## Regression tests for the 3-skill warden active skill system.

const SkillCatalog := preload("res://scripts/battle/warden_skill_catalog.gd")
const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_state_with(engine: BattleEngine, grid: Grid, units: Array) -> void:
	engine.state = BattleState.new()
	engine.state.grid = grid
	for entry in units:
		var u := Unit.new(engine.state.allocate_unit_id(), entry["def"], entry["pos"])
		engine.state.units.append(u)
		if entry.has("hp"):
			u.hp = entry["hp"]
	engine.state.phase = BattleState.Phase.PLAYER_ACTION

static func _warden(def_id: StringName, attack_kind: int, range_steps: int = 1, force: int = 0) -> UnitDef:
	var overrides := {
		"def_id": def_id,
		"display_name": str(def_id),
		"attack_kind": attack_kind,
		"attack_range": range_steps,
		"attack_damage": 1,
		"attack_force": force,
	}
	match String(def_id):
		"warden_bountyhunter":
			return TestUnitDefs.bountyhunter(overrides)
		"warden_graverobber":
			return TestUnitDefs.graverobber(overrides)
		"warden_mage":
			return TestUnitDefs.mage(overrides)
	return TestUnitDefs.generic_warden(overrides)

static func _enemy(hp: int = 2, move: int = 2) -> UnitDef:
	return TestUnitDefs.generic_enemy({
		"max_hp": hp,
		"move": move,
		"attack_kind": UnitDef.AttackKind.MELEE_BUMP,
		"attack_range": 1,
		"attack_damage": 1,
		"attack_force": 0,
	})

static func _add(s: BattleState, def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	s.units.append(u)
	return u

static func _bh() -> UnitDef:
	return _warden(&"warden_bountyhunter", UnitDef.AttackKind.MELEE_PUSH, 1, 1)

static func _gr() -> UnitDef:
	return _warden(&"warden_graverobber", UnitDef.AttackKind.RANGED_PULL, 3, 1)

static func _mage() -> UnitDef:
	return _warden(&"warden_mage", UnitDef.AttackKind.RANGED_PUSH, 3, 1)

static func run(tr) -> void:
	_test_skill_catalog_slots(tr)
	_test_skill_catalog_applies_upgrades(tr)
	_test_attack_alias_matches_primary_skill(tr)
	_test_guard_shoulder_swaps_and_damages_enemy(tr)
	_test_bounty_execute_limited_and_counts_direct_kill(tr)
	_test_upgraded_bounty_execute_adds_one_use(tr)
	_test_rift_wedge_delays_schedule_and_damages_enemy_on_rift(tr)
	_test_upgraded_hook_rope_extends_legal_range(tr)
	_test_mage_repulsion_bolt_ignores_distance_limit(tr)
	_test_mage_repulsion_bolt_still_needs_clear_line(tr)
	_test_backhand_throw_side_pushes_left_first(tr)
	_test_ward_fire_shields_without_repairing_building(tr)
	_test_upgraded_ward_fire_blocks_two_damage(tr)
	_test_ward_fire_shield_reduces_next_building_hit(tr)
	_test_ward_fire_unused_shield_expires_after_enemy_attack_phase(tr)
	_test_sigil_slows_enemy_move_and_expires(tr)
	_test_upgraded_sigil_lasts_three_enemy_moves(tr)
	_test_skill_preview_does_not_mutate_state(tr)

static func _test_skill_catalog_slots(tr) -> void:
	tr.assert_eq("bountyhunter has three skills", SkillCatalog.skills_for_warden(&"warden_bountyhunter").size(), 3)
	tr.assert_eq("graverobber has three skills", SkillCatalog.skills_for_warden(&"warden_graverobber").size(), 3)
	tr.assert_eq("mage has three skills", SkillCatalog.skills_for_warden(&"warden_mage").size(), 3)

static func _test_skill_catalog_applies_upgrades(tr) -> void:
	var ward_fire := SkillCatalog.get_skill(SkillCatalog.MAGE_WARD_FIRE, [SkillCatalog.UPGRADE_MAGE_WARD_FIRE_SHIELD])
	tr.assert_true("ward fire skill marks upgraded", bool(ward_fire.get("upgraded", false)))
	tr.assert_eq("ward fire shield upgrade amount", int(ward_fire.get("shield_amount", 0)), 2)
	tr.assert_eq("ward fire shield upgrade desc", String(ward_fire.get("desc", "")), "护盾 · 减伤 2")
	var hook := SkillCatalog.get_skill(SkillCatalog.GRAVEROBBER_HOOK_ROPE, [SkillCatalog.UPGRADE_GRAVEROBBER_HOOK_ROPE_RANGE])
	tr.assert_eq("hook rope range upgrade", int(hook.get("range", 0)), 4)
	var mage_bolt := SkillCatalog.get_skill(SkillCatalog.MAGE_REPULSION_BOLT)
	tr.assert_eq("mage bolt has unlimited line targeting", mage_bolt.get("target_rule", &""), SkillCatalog.TARGET_LINE_ENEMY_OR_BOSS_UNLIMITED)
	tr.assert_eq("mage bolt range metadata is unlimited sentinel", int(mage_bolt.get("range", -1)), 0)

static func _test_attack_alias_matches_primary_skill(tr) -> void:
	var e1 := BattleEngine.new()
	var e2 := BattleEngine.new()
	var grid := Grid.new()
	var bh := _bh()
	var foe := _enemy()
	_make_state_with(e1, grid, [{"def": bh, "pos": Vector2i(3, 5)}, {"def": bh, "pos": Vector2i(0, 0)}, {"def": foe, "pos": Vector2i(3, 4)}])
	_make_state_with(e2, grid.clone(), [{"def": bh, "pos": Vector2i(3, 5)}, {"def": bh, "pos": Vector2i(0, 0)}, {"def": foe, "pos": Vector2i(3, 4)}])
	e1.apply_action(BattleAction.attack(e1.state.units[0].id, Vector2i(3, 4)))
	e2.apply_action(BattleAction.skill(e2.state.units[0].id, SkillCatalog.BOUNTY_CHAIN_STRIKE, Vector2i(3, 4)))
	tr.assert_eq("attack alias target position", e1.state.units[2].position, e2.state.units[2].position)
	tr.assert_eq("attack alias target hp", e1.state.units[2].hp, e2.state.units[2].hp)

static func _test_guard_shoulder_swaps_and_damages_enemy(tr) -> void:
	var engine := BattleEngine.new()
	_make_state_with(engine, Grid.new(), [{"def": _bh(), "pos": Vector2i(3, 5)}, {"def": _bh(), "pos": Vector2i(0, 0)}, {"def": _enemy(), "pos": Vector2i(3, 4)}])
	var bh: Unit = engine.state.units[0]
	var foe: Unit = engine.state.units[2]
	engine.apply_action(BattleAction.skill(bh.id, SkillCatalog.BOUNTY_GUARD_SHOULDER, foe.position))
	tr.assert_eq("guard shoulder swaps warden", bh.position, Vector2i(3, 4))
	tr.assert_eq("guard shoulder swaps enemy", foe.position, Vector2i(3, 5))
	tr.assert_eq("guard shoulder damages enemy", foe.hp, 1)

static func _test_bounty_execute_limited_and_counts_direct_kill(tr) -> void:
	var engine := BattleEngine.new()
	_make_state_with(engine, Grid.new(), [{"def": _bh(), "pos": Vector2i(3, 5)}, {"def": _bh(), "pos": Vector2i(0, 0)}, {"def": _enemy(1), "pos": Vector2i(3, 4)}])
	var bh: Unit = engine.state.units[0]
	engine.apply_action(BattleAction.skill(bh.id, SkillCatalog.BOUNTY_EXECUTE, Vector2i(3, 4)))
	tr.assert_eq("bounty execute records kill", int(engine.state.bounty_executes.get(bh.id, 0)), 1)
	tr.assert_eq("bounty execute records use", engine.state.skill_use_count(bh.id, SkillCatalog.BOUNTY_EXECUTE), 1)
	engine.state.units.append(Unit.new(engine.state.allocate_unit_id(), _enemy(1), Vector2i(4, 4)))
	bh.has_acted = false
	bh.position = Vector2i(4, 5)
	tr.assert_eq("bounty execute enters cooldown", engine.get_skill_availability(bh.id, SkillCatalog.BOUNTY_EXECUTE).get("reason_code", ""), "cooldown")
	engine.state.current_round = engine.state.skill_next_available_round(bh.id, SkillCatalog.BOUNTY_EXECUTE)
	engine.apply_action(BattleAction.skill(bh.id, SkillCatalog.BOUNTY_EXECUTE, Vector2i(4, 4)))
	tr.assert_eq("bounty execute second use consumed", engine.state.skill_use_count(bh.id, SkillCatalog.BOUNTY_EXECUTE), 2)
	bh.has_acted = false
	engine.state.units.append(Unit.new(engine.state.allocate_unit_id(), _enemy(1), Vector2i(5, 4)))
	bh.position = Vector2i(5, 5)
	tr.assert_eq("bounty execute no targets after limit", engine.get_legal_skill_targets(bh.id, SkillCatalog.BOUNTY_EXECUTE).size(), 0)

static func _test_upgraded_bounty_execute_adds_one_use(tr) -> void:
	var engine := BattleEngine.new()
	_make_state_with(engine, Grid.new(), [{"def": _bh(), "pos": Vector2i(3, 5)}, {"def": _enemy(1), "pos": Vector2i(3, 4)}])
	var bh: Unit = engine.state.units[0]
	engine.state.set_warden_upgrades(bh.id, [SkillCatalog.UPGRADE_BOUNTY_EXECUTE_TEMPO])
	var availability := engine.get_skill_availability(bh.id, SkillCatalog.BOUNTY_EXECUTE)
	tr.assert_eq("upgraded execute max uses", int(availability.get("max_uses", 0)), 3)
	tr.assert_eq("upgraded execute uses remaining", int(availability.get("uses_remaining", 0)), 3)

static func _test_rift_wedge_delays_schedule_and_damages_enemy_on_rift(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var rift := Vector2i(3, 3)
	grid.set_tile(rift, Grid.TileType.RIFT)
	_make_state_with(engine, grid, [{"def": _gr(), "pos": Vector2i(3, 6)}, {"def": _gr(), "pos": Vector2i(0, 0)}, {"def": _enemy(), "pos": rift}])
	engine.state.rift_schedule = [{"round": 1, "pos": rift, "def": _enemy()}]
	var gr: Unit = engine.state.units[0]
	var foe: Unit = engine.state.units[2]
	engine.apply_action(BattleAction.skill(gr.id, SkillCatalog.GRAVEROBBER_RIFT_WEDGE, rift))
	tr.assert_eq("rift wedge delays schedule", int(engine.state.rift_schedule[0].round), 2)
	tr.assert_eq("rift wedge damages enemy on rift", foe.hp, 1)

static func _test_upgraded_hook_rope_extends_legal_range(tr) -> void:
	var engine := BattleEngine.new()
	_make_state_with(engine, Grid.new(), [{"def": _gr(), "pos": Vector2i(3, 6)}, {"def": _enemy(), "pos": Vector2i(3, 2)}])
	var gr: Unit = engine.state.units[0]
	tr.assert_eq("base hook cannot reach range four", engine.get_legal_skill_targets(gr.id, SkillCatalog.GRAVEROBBER_HOOK_ROPE).size(), 0)
	engine.state.set_warden_upgrades(gr.id, [SkillCatalog.UPGRADE_GRAVEROBBER_HOOK_ROPE_RANGE])
	tr.assert_eq("upgraded hook reaches range four", engine.get_legal_skill_targets(gr.id, SkillCatalog.GRAVEROBBER_HOOK_ROPE), [Vector2i(3, 2)])

static func _test_mage_repulsion_bolt_ignores_distance_limit(tr) -> void:
	var engine := BattleEngine.new()
	_make_state_with(engine, Grid.new(), [{"def": _mage(), "pos": Vector2i(3, 7)}, {"def": _mage(), "pos": Vector2i(0, 0)}, {"def": _enemy(), "pos": Vector2i(3, 2)}])
	var mage: Unit = engine.state.units[0]
	var foe: Unit = engine.state.units[2]
	tr.assert_eq("mage bolt reaches beyond three cells", engine.get_legal_skill_targets(mage.id, SkillCatalog.MAGE_REPULSION_BOLT), [Vector2i(3, 2)])
	engine.apply_action(BattleAction.skill(mage.id, SkillCatalog.MAGE_REPULSION_BOLT, foe.position))
	tr.assert_eq("mage bolt damages distant enemy", foe.hp, 1)
	tr.assert_eq("mage bolt pushes distant enemy away", foe.position, Vector2i(3, 1))

static func _test_mage_repulsion_bolt_still_needs_clear_line(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	grid.set_tile(Vector2i(3, 4), Grid.TileType.PILLAR, 1)
	_make_state_with(engine, grid, [{"def": _mage(), "pos": Vector2i(3, 7)}, {"def": _enemy(), "pos": Vector2i(3, 2)}])
	var mage: Unit = engine.state.units[0]
	tr.assert_eq("mage bolt does not pass through blockers", engine.get_legal_skill_targets(mage.id, SkillCatalog.MAGE_REPULSION_BOLT).size(), 0)
	var range_preview := engine.get_skill_target_range(mage.id, SkillCatalog.MAGE_REPULSION_BOLT)
	tr.assert_true("mage bolt range preview reaches blocker", range_preview.has(Vector2i(3, 4)))
	tr.assert_true("mage bolt range preview does not pass blocker", not range_preview.has(Vector2i(3, 3)))

static func _test_backhand_throw_side_pushes_left_first(tr) -> void:
	var engine := BattleEngine.new()
	_make_state_with(engine, Grid.new(), [{"def": _gr(), "pos": Vector2i(3, 5)}, {"def": _gr(), "pos": Vector2i(0, 0)}, {"def": _enemy(), "pos": Vector2i(3, 3)}])
	var gr: Unit = engine.state.units[0]
	var foe: Unit = engine.state.units[2]
	engine.apply_action(BattleAction.skill(gr.id, SkillCatalog.GRAVEROBBER_BACKHAND_THROW, foe.position))
	tr.assert_eq("backhand throw pulls then left-side pushes", foe.position, Vector2i(2, 4))

static func _test_ward_fire_shields_without_repairing_building(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(3, 4)
	grid.set_tile(building, Grid.TileType.BUILDING, 1)
	_make_state_with(engine, grid, [{"def": _mage(), "pos": Vector2i(3, 6)}, {"def": _mage(), "pos": Vector2i(0, 0)}])
	engine.state.protected_targets = [building]
	engine.state.protected_initial_hp[building] = 2
	var mage: Unit = engine.state.units[0]
	engine.apply_action(BattleAction.skill(mage.id, SkillCatalog.MAGE_WARD_FIRE, building))
	tr.assert_eq("ward fire does not repair building", int(engine.state.grid.tile_hp.get(building, 0)), 1)
	tr.assert_true("ward fire shields damaged building", engine.state.has_protected_shield(building))
	mage.has_acted = false
	tr.assert_eq("ward fire enters cooldown", engine.get_skill_availability(mage.id, SkillCatalog.MAGE_WARD_FIRE).get("reason_code", ""), "cooldown")
	engine.state.current_round = engine.state.skill_next_available_round(mage.id, SkillCatalog.MAGE_WARD_FIRE)
	tr.assert_eq("ward fire has no target while shielded", engine.get_legal_skill_targets(mage.id, SkillCatalog.MAGE_WARD_FIRE).size(), 0)

static func _test_upgraded_ward_fire_blocks_two_damage(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(3, 3)
	grid.set_tile(building, Grid.TileType.BUILDING, 3)
	var enemy_def := _enemy(2, 2)
	enemy_def.attack_damage = 2
	_make_state_with(engine, grid, [{"def": _mage(), "pos": Vector2i(3, 5)}, {"def": _mage(), "pos": Vector2i(0, 0)}, {"def": enemy_def, "pos": Vector2i(3, 2)}])
	engine.state.protected_targets = [building]
	engine.state.protected_initial_hp[building] = 3
	var mage: Unit = engine.state.units[0]
	engine.state.set_warden_upgrades(mage.id, [SkillCatalog.UPGRADE_MAGE_WARD_FIRE_SHIELD])
	engine.apply_action(BattleAction.skill(mage.id, SkillCatalog.MAGE_WARD_FIRE, building))
	var plan := AIDecider.EnemyPlan.new()
	plan.origin_pos = engine.state.units[2].position
	plan.move_to = engine.state.units[2].position
	plan.attack_pos = building
	engine.state.enemy_warnings[engine.state.units[2].id] = plan
	engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("upgraded shield blocks two building damage", int(engine.state.grid.tile_hp.get(building, 0)), 3)
	tr.assert_true("upgraded shield is consumed", not engine.state.has_protected_shield(building))

static func _test_ward_fire_shield_reduces_next_building_hit(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(3, 3)
	grid.set_tile(building, Grid.TileType.BUILDING, 2)
	engine.start_battle(grid, [_mage()], [{"def": _enemy(), "pos": Vector2i(3, 2)}], [Vector2i(7, 7)], [], [], 3, [building], [])
	engine.apply_action(BattleAction.deploy(Vector2i(7, 7)))
	engine.apply_action(BattleAction.confirm_deploy())
	engine.state.add_protected_shield(building)
	engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("shield prevents one building damage", int(engine.state.grid.tile_hp.get(building, 0)), 2)
	tr.assert_true("shield is consumed by blocked building hit", not engine.state.has_protected_shield(building))

static func _test_ward_fire_unused_shield_expires_after_enemy_attack_phase(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(3, 3)
	grid.set_tile(building, Grid.TileType.BUILDING, 2)
	_make_state_with(engine, grid, [{"def": _mage(), "pos": Vector2i(7, 7)}])
	engine.state.protected_targets = [building]
	engine.state.protected_initial_hp[building] = 2
	engine.state.add_protected_shield(building)
	engine.apply_action(BattleAction.end_turn())
	tr.assert_true("unused shield expires after enemy attack phase", not engine.state.has_protected_shield(building))

static func _test_sigil_slows_enemy_move_and_expires(tr) -> void:
	var s := BattleState.new()
	var building := Vector2i(3, 4)
	s.grid.set_tile(building, Grid.TileType.BUILDING, 2)
	s.protected_targets = [building]
	s.capture_protected_initial_hp()
	var foe := _add(s, _enemy(2, 3), Vector2i(3, 0))
	s.add_sigil(Vector2i(3, 1), 99, 2)
	var plan = AIDecider.plan_enemy_turn(s)[foe.id]
	tr.assert_eq("sigil slows enemy movement by one", plan.move_to, Vector2i(3, 2))
	s.decrement_sigils_after_enemy_moves()
	tr.assert_eq("sigil remains after first enemy move", s.sigils.size(), 1)
	s.decrement_sigils_after_enemy_moves()
	tr.assert_eq("sigil expires after second enemy move", s.sigils.size(), 0)

static func _test_upgraded_sigil_lasts_three_enemy_moves(tr) -> void:
	var engine := BattleEngine.new()
	_make_state_with(engine, Grid.new(), [{"def": _mage(), "pos": Vector2i(3, 6)}, {"def": _mage(), "pos": Vector2i(0, 0)}, {"def": _enemy(), "pos": Vector2i(7, 7)}])
	var mage: Unit = engine.state.units[0]
	engine.state.set_warden_upgrades(mage.id, [SkillCatalog.UPGRADE_MAGE_SIGIL_DURATION])
	engine.apply_action(BattleAction.skill(mage.id, SkillCatalog.MAGE_SIGIL, Vector2i(3, 4)))
	tr.assert_eq("upgraded sigil starts at three rounds", int(engine.state.sigils[0].get("remaining_rounds", 0)), 3)
	engine.state.decrement_sigils_after_enemy_moves()
	engine.state.decrement_sigils_after_enemy_moves()
	tr.assert_eq("upgraded sigil remains after two moves", engine.state.sigils.size(), 1)
	engine.state.decrement_sigils_after_enemy_moves()
	tr.assert_eq("upgraded sigil expires after third move", engine.state.sigils.size(), 0)

static func _test_skill_preview_does_not_mutate_state(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var rift := Vector2i(3, 3)
	grid.set_tile(rift, Grid.TileType.RIFT)
	_make_state_with(engine, grid, [{"def": _gr(), "pos": Vector2i(3, 6)}, {"def": _gr(), "pos": Vector2i(0, 0)}])
	engine.state.rift_schedule = [{"round": 1, "pos": rift, "def": _enemy()}]
	var gr: Unit = engine.state.units[0]
	engine.preview_action(BattleAction.skill(gr.id, SkillCatalog.GRAVEROBBER_RIFT_WEDGE, rift))
	tr.assert_eq("preview does not delay real schedule", int(engine.state.rift_schedule[0].round), 1)
	tr.assert_eq("preview does not consume skill use", engine.state.skill_use_count(gr.id, SkillCatalog.GRAVEROBBER_RIFT_WEDGE), 0)
