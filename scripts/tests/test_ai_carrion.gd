extends RefCounted
## AIDecider tests for Carrion Spawn (slice scope).

static func _add(s: BattleState, faction: int, hp: int, move_v: int, pos: Vector2i) -> Unit:
	var def := UnitDef.new()
	def.faction = faction
	def.max_hp = hp
	def.move = move_v
	def.attack_kind = UnitDef.AttackKind.MELEE_BUMP
	def.attack_range = 1
	def.attack_damage = 1
	var u := Unit.new(s.allocate_unit_id(), def, pos)
	u.hp = hp
	s.units.append(u)
	return u

static func run(tr) -> void:
	_test_carrion_moves_toward_nearest_warden(tr)
	_test_carrion_attacks_when_adjacent(tr)

static func _test_carrion_moves_toward_nearest_warden(tr) -> void:
	var s := BattleState.new()
	var carrion := _add(s, UnitDef.Faction.ENEMY, 1, 2, Vector2i(5, 4))
	var warden_far := _add(s, UnitDef.Faction.WARDEN, 2, 2, Vector2i(0, 0))
	var warden_near := _add(s, UnitDef.Faction.WARDEN, 2, 2, Vector2i(3, 4))
	var plans := AIDecider.plan_enemy_turn(s)
	tr.assert_true("has plan for carrion", plans.has(carrion.id))
	var plan = plans[carrion.id]
	# Carrion should move toward warden_near at (3,4), so first hop is west to (4,4).
	tr.assert_eq("first move toward nearest warden", plan.move_to, Vector2i(4, 4))

static func _test_carrion_attacks_when_adjacent(tr) -> void:
	var s := BattleState.new()
	var w := _add(s, UnitDef.Faction.WARDEN, 2, 2, Vector2i(3, 4))
	var carrion := _add(s, UnitDef.Faction.ENEMY, 1, 2, Vector2i(4, 4))
	var plans := AIDecider.plan_enemy_turn(s)
	var plan = plans[carrion.id]
	tr.assert_eq("attacks warden at (3,4)", plan.attack_pos, Vector2i(3, 4))
