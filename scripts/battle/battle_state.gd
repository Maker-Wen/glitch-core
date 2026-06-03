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

const REWARD_PERFECT_DEFENSE := &"perfect_defense"
const REWARD_TERMINAL_CLEAR := &"terminal_clear"
const REWARD_PHYSICAL_KILLS_3 := &"physical_kills_3"
const PHYSICAL_KILL_CAUSES := {
	&"fall": true,
	&"wall": true,
	&"bump": true,
}

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
## Cells that count as protected battle targets. If this is empty, battle
## victory/failure ignores buildings; slice tests can still run unit-only maps.
var protected_targets: Array[Vector2i] = []
var destroyed_protected_count: int = 0
var protected_damage_taken: int = 0
var physical_kills: int = 0
## Reward task ids and state. Current first-pass tasks:
## - perfect_defense: no protected target destroyed by battle end.
## - terminal_clear: no enemies alive at battle end.
## - physical_kills_3: at least 3 enemy kills by fall / wall / bump.
var reward_tasks: Array[StringName] = []
var reward_progress: Dictionary = {}
var reward_completed: Dictionary = {}
var reward_failed: Dictionary = {}
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
	s.protected_targets = protected_targets.duplicate()
	s.destroyed_protected_count = destroyed_protected_count
	s.protected_damage_taken = protected_damage_taken
	s.physical_kills = physical_kills
	s.reward_tasks = reward_tasks.duplicate()
	s.reward_progress = reward_progress.duplicate()
	s.reward_completed = reward_completed.duplicate()
	s.reward_failed = reward_failed.duplicate()
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

func has_protected_targets() -> bool:
	return not protected_targets.is_empty()

func is_protected_target(p: Vector2i) -> bool:
	return p in protected_targets

func alive_protected_targets() -> Array[Vector2i]:
	var alive: Array[Vector2i] = []
	for p in protected_targets:
		if grid.get_tile(p) == Grid.TileType.BUILDING and int(grid.tile_hp.get(p, 0)) > 0:
			alive.append(p)
	return alive

func set_reward_tasks(tasks: Array) -> void:
	reward_tasks.clear()
	reward_progress.clear()
	reward_completed.clear()
	reward_failed.clear()
	for t in tasks:
		var key := StringName(t)
		if key in reward_tasks:
			continue
		reward_tasks.append(key)
		reward_progress[key] = 0
		reward_completed[key] = false
		reward_failed[key] = false
	_refresh_reward_tasks(false)

func record_protected_tile_damage(pos: Vector2i, amount: int, destroyed: bool) -> void:
	if not is_protected_target(pos):
		return
	protected_damage_taken += amount
	if destroyed:
		destroyed_protected_count += 1
	_refresh_reward_tasks(false)

func record_enemy_kill(cause: StringName) -> void:
	if PHYSICAL_KILL_CAUSES.has(cause):
		physical_kills += 1
	_refresh_reward_tasks(false)

func finalize_reward_tasks() -> void:
	_refresh_reward_tasks(true)

func _refresh_reward_tasks(final: bool) -> void:
	for task in reward_tasks:
		match task:
			REWARD_PERFECT_DEFENSE:
				reward_progress[task] = destroyed_protected_count
				if destroyed_protected_count > 0:
					reward_failed[task] = true
				elif final:
					reward_completed[task] = true
			REWARD_TERMINAL_CLEAR:
				reward_progress[task] = enemies().size()
				if final:
					reward_completed[task] = enemies().is_empty()
					reward_failed[task] = not enemies().is_empty()
			REWARD_PHYSICAL_KILLS_3:
				reward_progress[task] = physical_kills
				if physical_kills >= 3:
					reward_completed[task] = true
				elif final:
					reward_failed[task] = true
