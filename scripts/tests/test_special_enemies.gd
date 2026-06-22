extends RefCounted
## Regression tests for Demo-specific enemy behavior.

const TestUnitDefs := preload("res://scripts/tests/test_unit_defs.gd")

static func _make_warden() -> UnitDef:
	return TestUnitDefs.generic_warden({"max_hp": 3, "move": 2, "attack_force": 2})

static func _enemy(def_id: StringName, hp: int, move: int, attack_kind: int, attack_range: int = 1, force: int = 0) -> UnitDef:
	return TestUnitDefs.generic_enemy({
		"def_id": def_id,
		"display_name": str(def_id),
		"max_hp": hp,
		"move": move,
		"attack_kind": attack_kind,
		"attack_range": attack_range,
		"attack_damage": 1,
		"attack_force": force,
	})

static func _add(s: BattleState, def: UnitDef, pos: Vector2i) -> Unit:
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	s.units.append(u)
	return u

static func run(tr) -> void:
	_test_bone_grub_ignores_wardens_without_buildings(tr)
	_test_bone_grub_targets_buildings(tr)
	_test_bell_thrall_prefers_building_over_warden(tr)
	_test_shell_beetle_reduces_push_force(tr)
	_test_bell_thrall_cracks_building_for_next_hit(tr)
	_test_ironhorn_uses_charge_line_pressure(tr)
	_test_ironhorn_intent_exports_charge_lane_hazard(tr)
	_test_ironhorn_charge_lane_preview_updates_after_push(tr)
	_test_bell_wave_warns_then_damages_unit(tr)
	_test_bell_wave_does_not_damage_buildings(tr)

static func _test_bone_grub_ignores_wardens_without_buildings(tr) -> void:
	var s := BattleState.new()
	var grub := _add(s, _enemy(BattleState.DEF_BONE_GRUB, 1, 4, UnitDef.AttackKind.MELEE_BUMP), Vector2i(3, 3))
	_add(s, _make_warden(), Vector2i(3, 4))
	var plan = AIDecider.plan_enemy_turn(s)[grub.id]
	tr.assert_eq("bone grub does not bite adjacent warden", plan.attack_pos, Vector2i(-1, -1))
	tr.assert_eq("bone grub stays without building target", plan.move_to, grub.position)

static func _test_bone_grub_targets_buildings(tr) -> void:
	var s := BattleState.new()
	var building := Vector2i(3, 4)
	s.grid.set_tile(building, Grid.TileType.BUILDING, 2)
	s.protected_targets = [building]
	s.capture_protected_initial_hp()
	var grub := _add(s, _enemy(BattleState.DEF_BONE_GRUB, 1, 4, UnitDef.AttackKind.MELEE_BUMP), Vector2i(3, 3))
	var plan = AIDecider.plan_enemy_turn(s)[grub.id]
	tr.assert_eq("bone grub attacks adjacent building", plan.attack_pos, building)

static func _test_bell_thrall_prefers_building_over_warden(tr) -> void:
	var s := BattleState.new()
	var building := Vector2i(7, 7)
	s.grid.set_tile(building, Grid.TileType.BUILDING, 2)
	s.protected_targets = [building]
	s.capture_protected_initial_hp()
	var thrall := _add(s, _enemy(BattleState.DEF_BELL_THRALL, 2, 2, UnitDef.AttackKind.MELEE_BUMP), Vector2i(3, 4))
	var warden := _add(s, _make_warden(), Vector2i(3, 5))
	warden.hp = 1
	var plan = AIDecider.plan_enemy_turn(s)[thrall.id]
	tr.assert_true("bell thrall ignores exposed warden for building plan", plan.attack_pos != warden.position)
	tr.assert_true("bell thrall moves toward protected building", Grid.manhattan(plan.move_to, building) < Grid.manhattan(thrall.position, building))

static func _test_shell_beetle_reduces_push_force(tr) -> void:
	var s := BattleState.new()
	var warden := _add(s, _make_warden(), Vector2i(2, 4))
	var beetle := _add(s, _enemy(BattleState.DEF_SHELL_BEETLE, 4, 1, UnitDef.AttackKind.MELEE_BUMP), Vector2i(3, 4))
	PhysicsResolver.resolve_attack(s, warden, beetle, Vector2i(1, 0), 2, 0)
	tr.assert_eq("shell beetle push reduced by 1", beetle.position, Vector2i(4, 4))

static func _test_bell_thrall_cracks_building_for_next_hit(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(3, 3)
	grid.set_tile(building, Grid.TileType.BUILDING, 3)
	engine.start_battle(
		grid,
		[_make_warden()],
		[{"def": _enemy(BattleState.DEF_BELL_THRALL, 2, 2, UnitDef.AttackKind.MELEE_BUMP), "pos": Vector2i(3, 2)}],
		[Vector2i(7, 7)],
		[],
		[],
		3,
		[building],
		[]
	)
	engine.apply_action(BattleAction.deploy(Vector2i(7, 7)))
	engine.apply_action(BattleAction.confirm_deploy())
	engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("bell thrall first hit deals 1", engine.state.grid.tile_hp[building], 2)
	tr.assert_true("bell thrall cracks building", engine.state.cracked_protected_targets.has(building))
	engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("cracked building next hit takes +1", engine.state.grid.get_tile(building), Grid.TileType.RUIN)

static func _test_ironhorn_uses_charge_line_pressure(tr) -> void:
	var s := BattleState.new()
	var building := Vector2i(3, 3)
	s.grid.set_tile(building, Grid.TileType.BUILDING, 2)
	s.protected_targets = [building]
	s.capture_protected_initial_hp()
	var ironhorn := _add(s, _enemy(BattleState.DEF_IRONHORN, 3, 2, UnitDef.AttackKind.RANGED_PUSH, 3, 2), Vector2i(3, 0))
	var plans := AIDecider.plan_enemy_turn(s)
	var plan = plans[ironhorn.id]
	tr.assert_true("ironhorn has charge-line attack", plan.has_attack())
	tr.assert_eq("ironhorn targets building line", plan.attack_pos, building)

static func _test_ironhorn_intent_exports_charge_lane_hazard(tr) -> void:
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var building := Vector2i(3, 3)
	engine.state.grid.set_tile(building, Grid.TileType.BUILDING, 2)
	engine.state.protected_targets = [building]
	engine.state.capture_protected_initial_hp()
	var ironhorn := _add(engine.state, _enemy(BattleState.DEF_IRONHORN, 3, 2, UnitDef.AttackKind.RANGED_PUSH, 3, 2), Vector2i(3, 0))
	engine.state.enemy_warnings = AIDecider.plan_enemy_turn(engine.state)
	var rows := engine.get_enemy_intent_ui_state()
	tr.assert_eq("ironhorn intent row count", rows.size(), 1)
	tr.assert_eq("ironhorn row has charge lane hazard", rows[0].hazard_type, BattleEngine.HAZARD_CHARGE_LANE)
	tr.assert_eq("ironhorn charge lane reaches building", _cell_signature(rows[0].hazard_cells), "3,1|3,2|3,3")
	tr.assert_eq("ironhorn intent still targets building", rows[0].attack_pos, building)

static func _test_ironhorn_charge_lane_preview_updates_after_push(tr) -> void:
	var engine := BattleEngine.new()
	engine.state = BattleState.new()
	engine.state.grid = Grid.new()
	engine.state.phase = BattleState.Phase.PLAYER_ACTION
	var building := Vector2i(2, 3)
	engine.state.grid.set_tile(building, Grid.TileType.BUILDING, 2)
	engine.state.protected_targets = [building]
	engine.state.capture_protected_initial_hp()
	var warden := _add(engine.state, _make_warden(), Vector2i(1, 0))
	var decoy := _add(engine.state, _make_warden(), Vector2i(7, 7))
	var ironhorn := _add(engine.state, _enemy(BattleState.DEF_IRONHORN, 3, 0, UnitDef.AttackKind.RANGED_PUSH, 3, 2), Vector2i(2, 0))
	var plan := AIDecider.EnemyPlan.new()
	plan.origin_pos = ironhorn.position
	plan.move_to = ironhorn.position
	plan.attack_pos = building
	engine.state.enemy_warnings[ironhorn.id] = plan
	var rows := engine.preview_enemy_intent_ui_state(BattleAction.attack(warden.id, ironhorn.position))
	tr.assert_eq("preview keeps ironhorn row", rows.size(), 1)
	tr.assert_eq("preview charge lane hazard type", rows[0].hazard_type, BattleEngine.HAZARD_CHARGE_LANE)
	tr.assert_eq("preview charge lane shifts after push", _cell_signature(rows[0].hazard_cells), "4,1|4,2|4,3")
	tr.assert_eq("preview pushed charge misses building", rows[0].status, BattleEngine.INTENT_STATUS_MISS)
	tr.assert_eq("real ironhorn did not move during preview", ironhorn.position, Vector2i(2, 0))

static func _test_bell_wave_warns_then_damages_unit(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var hazard := Vector2i(4, 4)
	engine.start_battle(
		grid,
		[_make_warden()],
		[],
		[hazard],
		[],
		[],
		3,
		[],
		[],
		[],
		{},
		[],
		{},
		[{"round": 1, "cells": [hazard]}]
	)
	engine.apply_action(BattleAction.deploy(hazard))
	var warden := engine.state.wardens()[0]
	engine.apply_action(BattleAction.confirm_deploy())
	tr.assert_eq("bell wave warning visible in round 1", engine.state.pending_bell_wave, [hazard])
	tr.assert_eq("bell wave warning does not damage immediately", warden.hp, warden.def.max_hp)
	var events := engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("bell wave warning clears after resolving", engine.state.pending_bell_wave.size(), 0)
	tr.assert_eq("bell wave damages standing warden by 1", warden.hp, warden.def.max_hp - 1)
	tr.assert_true("bell wave emits unit damage event", _has_unit_damage_event(events, warden.id))

static func _test_bell_wave_does_not_damage_buildings(tr) -> void:
	var engine := BattleEngine.new()
	var grid := Grid.new()
	var building := Vector2i(4, 4)
	var safe_deploy := Vector2i(7, 7)
	grid.set_tile(building, Grid.TileType.BUILDING, 2)
	engine.start_battle(
		grid,
		[_make_warden()],
		[],
		[safe_deploy],
		[],
		[],
		3,
		[building],
		[],
		[],
		{},
		[],
		{},
		[{"round": 1, "cells": [building]}]
	)
	engine.apply_action(BattleAction.deploy(safe_deploy))
	engine.apply_action(BattleAction.confirm_deploy())
	tr.assert_eq("blocked bell wave schedule filtered", engine.state.pending_bell_wave.size(), 0)
	engine.apply_action(BattleAction.end_turn())
	tr.assert_eq("bell wave does not damage buildings", int(engine.state.grid.tile_hp.get(building, 0)), 2)

static func _has_unit_damage_event(events: Array, unit_id: int) -> bool:
	for raw in events:
		var e: BattleEvent = raw
		if e.type == BattleEvent.Type.UNIT_DAMAGED and e.unit_id == unit_id:
			return true
	return false

static func _cell_signature(cells: Array) -> String:
	var parts: Array[String] = []
	for raw in cells:
		var cell: Vector2i = raw
		parts.append("%d,%d" % [cell.x, cell.y])
	return "|".join(parts)
