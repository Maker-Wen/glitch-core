class_name PhysicsResolver extends RefCounted
## Atomic chain resolver for push / pull / relay-bump.
## Implements docs/design/combat_resolution_truth_table.md §1-§4 strictly.
##
## Time-point model (see truth table §1.2):
##   T0  attack declared
##   T1  damage snapshot (Cracksbane checkpoint -- not used in slice)
##   T2  damage applied to target
##   T3  force imparted; per-cell advance loop begins
##   T4..Tn  per-cell collision resolution
##   Tend  dead-flagged units cleared en masse

## Resolve an attack that deals `damage` to target then pushes it `force` cells
## in `direction`. For a pull, the caller passes the direction from target toward
## the attacker; mechanically identical to push.
##
## Mutates `state` in place. Returns event log in execution order.
static func resolve_attack(
	state: BattleState,
	attacker: Unit,
	target: Unit,
	direction: Vector2i,
	force: int,
	damage: int,
) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if target == null or not target.alive:
		return events

	# T1: damage snapshot. (Slice: no Cracksbane, so damage is unmodified.)
	# T2: apply damage
	_apply_damage(target, damage, events)

	# T3+: advance push chain
	if force > 0 and target.alive == false:
		# Dead units still occupy & still receive remaining push (truth table §3).
		pass
	if force > 0:
		_advance_push(state, target, direction, force, events, attacker)

	# Tend: cleanup dead-flagged units
	_finalize(state, events)
	return events

## Move a unit voluntarily (player MOVE action) from -> to along a path.
## No damage, no chain. Returns one UNIT_MOVED event.
static func resolve_move(
	state: BattleState,
	unit: Unit,
	to: Vector2i,
) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var from := unit.position
	unit.position = to
	var e := BattleEvent.make(BattleEvent.Type.UNIT_MOVED)
	e.unit_id = unit.id
	e.from_pos = from
	e.to_pos = to
	events.append(e)
	return events

# ------------- internal -------------

static func _apply_damage(u: Unit, dmg: int, events: Array[BattleEvent]) -> void:
	if dmg <= 0 or not u.alive:
		return
	u.hp -= dmg
	var ed := BattleEvent.make(BattleEvent.Type.UNIT_DAMAGED)
	ed.unit_id = u.id
	ed.amount = dmg
	ed.to_pos = u.position
	events.append(ed)
	if u.hp <= 0:
		u.alive = false
		var ek := BattleEvent.make(BattleEvent.Type.UNIT_DIED)
		ek.unit_id = u.id
		ek.to_pos = u.position
		events.append(ek)

## Push `subject` for `force` cells in `direction`. May trigger relay.
## `attacker` is the ORIGINAL unit who initiated this chain (for friendly-fire
## checks). Caller has already applied initial damage; this only handles
## displacement and per-cell collisions.
static func _advance_push(
	state: BattleState,
	subject: Unit,
	direction: Vector2i,
	force: int,
	events: Array[BattleEvent],
	attacker: Unit,
) -> void:
	var remaining := force
	while remaining > 0:
		var from := subject.position
		var to: Vector2i = from + direction
		# 1) Out of bounds -> fell into pit
		if not state.grid.in_bounds(to):
			subject.alive = false
			var ef := BattleEvent.make(BattleEvent.Type.UNIT_FELL)
			ef.unit_id = subject.id
			ef.from_pos = from
			ef.to_pos = to
			events.append(ef)
			# Also emit UNIT_DIED if not already dead
			# (for hp>0 units pushed off board)
			# Simplest: mark dead; UNIT_FELL implies death.
			return
		# 2) Pillar / building -> wall bump (truth table §2.1)
		var tile := state.grid.get_tile(to)
		if tile == Grid.TileType.PILLAR or tile == Grid.TileType.BUILDING:
			# Wall damage 1, push force voided
			_apply_damage(subject, 1, events)
			var ew := BattleEvent.make(BattleEvent.Type.BUMP_WALL)
			ew.unit_id = subject.id
			ew.from_pos = from
			ew.to_pos = to
			events.append(ew)
			# (Pillar/building HP not tracked in slice; tile_damage event reserved)
			return
		# 3) Another unit U -> relay (truth table §2.1 / §3.5)
		var other := state.get_unit_at(to)
		if other != null and other.id != subject.id:
			# Subject stops at U's previous cell; emit BUMP_UNIT
			var eb := BattleEvent.make(BattleEvent.Type.BUMP_UNIT)
			eb.unit_id = subject.id
			eb.from_pos = subject.position
			eb.to_pos = to
			eb.extra = {"struck": other.id}
			events.append(eb)
			# Subject moves into U's cell? NO -- truth table says A stops at U's
			# ORIGINAL cell. But U still occupies that cell until Tend, so subject
			# physically stops one short. However, when U is pushed away in the
			# next step, the cell becomes free. To keep both atomic, we move
			# subject INTO U's cell AFTER pushing U: but truth table is explicit
			# that A stops at U's prior position. Implementation:
			#   - First: U receives 1 dmg + remaining-1 push.
			#   - Then: subject takes U's old position.
			# This matches the truth-table semantics where dead-flagged U still
			# occupies until Tend; subject lands on that cell once U has moved.
			#
			# FRIENDLY-FIRE RULE (slice): the bump victim takes 0 damage if
			# they share faction with the ORIGINAL attacker who initiated this
			# chain. Relay physics still proceed normally.
			# Examples:
			#   - Warden attacks -> pushed enemy bumps another warden:
			#     attacker=warden, victim=warden -> 0 damage.
			#   - Warden attacks -> pushed enemy bumps another enemy:
			#     attacker=warden, victim=enemy -> 1 damage (different faction).
			#   - Enemy attacks -> pushed warden bumps another warden:
			#     attacker=enemy, victim=warden -> 1 damage.
			var bump_damage: int = 1
			if attacker != null and attacker.def != null and other.def != null:
				if attacker.def.faction == other.def.faction:
					bump_damage = 0
			_apply_damage(other, bump_damage, events)
			var transferred := remaining - 1
			# Subject's chain ends here regardless of relay outcome.
			# Move subject into U's prior cell (whether U moved or died-in-place).
			# Per truth table §3: dead-flagged U still occupies; relay rule says
			# subject "stops at U's previous cell". If U is still standing there
			# (e.g. transferred=0), subject CANNOT enter -- it stops one short.
			if transferred > 0:
				# Recurse-style: push other with transferred force
				_advance_push(state, other, direction, transferred, events, attacker)
				# After other moved (or died and stayed?), check cell
				if state.get_unit_at(to) == null:
					subject.position = to
					var ep := BattleEvent.make(BattleEvent.Type.UNIT_PUSHED)
					ep.unit_id = subject.id
					ep.from_pos = from
					ep.to_pos = to
					events.append(ep)
			else:
				# transferred == 0: U takes 1 dmg in place, subject stops short.
				pass
			return
		# 4) Empty -> slide
		subject.position = to
		var ep2 := BattleEvent.make(BattleEvent.Type.UNIT_PUSHED)
		ep2.unit_id = subject.id
		ep2.from_pos = from
		ep2.to_pos = to
		events.append(ep2)
		remaining -= 1

static func _finalize(state: BattleState, events: Array[BattleEvent]) -> void:
	var removed := state.remove_dead_units()
	for uid in removed:
		var er := BattleEvent.make(BattleEvent.Type.UNIT_REMOVED)
		er.unit_id = uid
		events.append(er)
