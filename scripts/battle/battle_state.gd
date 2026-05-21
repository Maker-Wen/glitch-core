class_name BattleState extends RefCounted
## The full mutable game state for one battle. Cloneable for undo + preview.

enum Phase {
	GARRISON,
	ENEMY_WARNING,
	PLAYER_ACTION,
	ENEMY_EXECUTE,
	RIFT_SPAWN,
	BATTLE_END,
}

enum Outcome { UNDECIDED, VICTORY, DEFEAT }

var grid: Grid
var units: Array[Unit] = []
var current_round: int = 1
var max_rounds: int = 5
var phase: int = Phase.PLAYER_ACTION
var outcome: int = Outcome.UNDECIDED
## {unit_id: EnemyPlan} -- populated at start of each round.
var enemy_warnings: Dictionary = {}
## Garrison phase data:
## - pending_warden_defs: warden defs left to place, in order
## - placed_warden_ids: ids of wardens already placed
## - deploy_zone: set of valid cells {Vector2i: true}
var pending_warden_defs: Array[UnitDef] = []
var placed_warden_ids: Array[int] = []
var deploy_zone: Dictionary = {}
## Rift spawning (per design §3.4 / §5.3).
## - rift_positions: cells that contain a rift
## - pending_rift_spawns: Array of {pos: Vector2i, def: UnitDef} -- rifts that
##   were predicted last round and will spawn at the start of the NEXT round
##   warning. Empty on round 1 (no prior prediction).
var rift_positions: Array[Vector2i] = []
var pending_rift_spawns: Array = []
## Full schedule: Array of {round: int, pos: Vector2i, def: UnitDef}.
## At end of each round, entries matching current_round become predictions
## for next round.
var rift_schedule: Array = []
var _next_unit_id: int = 0

func _init() -> void:
	grid = Grid.new()

func clone() -> BattleState:
	var s := BattleState.new()
	s.grid = grid.clone()
	s.units.clear()
	for u in units:
		s.units.append(u.clone())
	s.current_round = current_round
	s.max_rounds = max_rounds
	s.phase = phase
	s.outcome = outcome
	s.enemy_warnings = enemy_warnings.duplicate(true)
	s.pending_warden_defs = pending_warden_defs.duplicate()
	s.placed_warden_ids = placed_warden_ids.duplicate()
	s.deploy_zone = deploy_zone.duplicate()
	s.rift_positions = rift_positions.duplicate()
	s.pending_rift_spawns = pending_rift_spawns.duplicate(true)
	s.rift_schedule = rift_schedule.duplicate(true)
	s._next_unit_id = _next_unit_id
	return s

func allocate_unit_id() -> int:
	var id := _next_unit_id
	_next_unit_id += 1
	return id

func find_unit(uid: int) -> Unit:
	for u in units:
		if u.id == uid:
			return u
	return null

## Returns the unit currently occupying `p` (alive OR alive=false but
## not yet removed). Pillar / building tiles are NOT units, return null.
func get_unit_at(p: Vector2i) -> Unit:
	for u in units:
		if u.position == p and u.alive:
			return u
	# also include dead-but-still-occupying for chain logic
	for u in units:
		if u.position == p and not u.alive:
			return u
	return null

func get_alive_unit_at(p: Vector2i) -> Unit:
	for u in units:
		if u.position == p and u.alive:
			return u
	return null

func wardens() -> Array[Unit]:
	var r: Array[Unit] = []
	for u in units:
		if u.alive and u.is_warden():
			r.append(u)
	return r

func enemies() -> Array[Unit]:
	var r: Array[Unit] = []
	for u in units:
		if u.alive and u.is_enemy():
			r.append(u)
	return r

func remove_dead_units() -> Array[int]:
	"""Tend cleanup. Returns the list of removed unit ids."""
	var removed: Array[int] = []
	var kept: Array[Unit] = []
	for u in units:
		if u.alive:
			kept.append(u)
		else:
			removed.append(u.id)
	units = kept
	return removed

## Build a {Vector2i: true} set of all currently-occupying unit cells.
## Used as the `blocked` arg for pathfinding.
func occupied_cells(exclude_unit_id: int = -1) -> Dictionary:
	var d: Dictionary = {}
	for u in units:
		if u.id == exclude_unit_id:
			continue
		d[u.position] = true
	return d
