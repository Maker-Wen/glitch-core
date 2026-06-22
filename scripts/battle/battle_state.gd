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
const REWARD_PUSH_THREAT := &"push_threat"
const REWARD_ALL_WARDENS_SURVIVE := &"all_wardens_survive"
const REWARD_RIFT_SUPPRESSION := &"rift_suppression"
const REWARD_LOW_LOSS_LINE := &"low_loss_line"
const REWARD_ELITE_HUNT := &"elite_hunt"
const REWARD_KEY_TARGET_UNDAMAGED := &"key_target_undamaged"
const REWARD_ANCHOR_DESTROY := &"anchor_destroy"
const REWARD_PERFECT_WATCH := &"perfect_watch"
const REWARD_HEART_WINDOW := &"heart_window"
const DEF_IRONHORN := &"enemy_ironhorn"
const DEF_SHELL_BEETLE := &"enemy_shell_beetle"
const DEF_BONE_GRUB := &"enemy_bone_grub"
const DEF_BELL_THRALL := &"enemy_bell_thrall"
const BOSS_CONFIG_NONE := ""
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
var pending_warden_starting_hp: Array[int] = []
var pending_warden_upgrades: Array = []
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
## Boss bell wave hazards. Schedule entries matching current_round become
## warnings during that player turn, then resolve at the next round start.
var pending_bell_wave: Array[Vector2i] = []
var bell_wave_schedule: Array = []
## {cell: {dir: true}}. Only configured maps mark certain board edges as
## abyss edges; normal border fall behavior remains available elsewhere.
var abyss_edges: Dictionary = {}
## Direct schedule: Array of {round: int, pos: Vector2i, def: UnitDef}.
## Entries spawn at the start of their configured round without rift preview.
var scripted_spawn_schedule: Array = []
## Cells that count as protected battle targets. If this is empty, battle
## victory/failure ignores buildings; slice tests can still run unit-only maps.
var protected_targets: Array[Vector2i] = []
var destroyed_protected_count: int = 0
var protected_damage_taken: int = 0
var protected_damage_by_pos: Dictionary = {}
var protected_initial_hp: Dictionary = {}
var cracked_protected_targets: Dictionary = {}
var protected_shields: Dictionary = {}
var sigils: Array[Dictionary] = []
var warden_upgrades: Dictionary = {}
var skill_uses: Dictionary = {}
var skill_cooldowns: Dictionary = {}
var bounty_executes: Dictionary = {}
var physical_kills: int = 0
var killed_enemy_defs: Dictionary = {}
var warden_deaths: int = 0
var enemy_attack_misses: int = 0
var rift_suppressions: int = 0
## Reward task ids and state. Current first-pass tasks:
## - perfect_defense: no protected target destroyed by battle end.
## - terminal_clear: no enemies alive at battle end.
## - physical_kills_3: at least 3 enemy kills by fall / wall / bump.
var reward_tasks: Array[StringName] = []
var reward_progress: Dictionary = {}
var reward_completed: Dictionary = {}
var reward_failed: Dictionary = {}
var boss_config_id: String = BOSS_CONFIG_NONE
var boss_script_id: String = ""
var doom_count: int = 0
var doom_count_max: int = 0
var boss_breached: bool = false
var boss_anchor_positions: Array[Vector2i] = []
var boss_anchor_hp: Dictionary = {}
var boss_anchor_hp_max: int = 0
var heart_position: Vector2i = Vector2i(-1, -1)
var heart_hits: int = 0
var heart_hit_cap: int = 0
var heart_window_hits: int = 0
var heart_exposure_rounds: int = 1
var heart_exposed_until_round: int = 0
var heart_doom_reduction_applied: bool = false
var boss_script_resolved_rounds: Dictionary = {}
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
	s.pending_warden_starting_hp = pending_warden_starting_hp.duplicate()
	s.pending_warden_upgrades = pending_warden_upgrades.duplicate(true)
	s.placed_warden_ids = placed_warden_ids.duplicate()
	s.deploy_zone = deploy_zone.duplicate()
	s.rift_positions = rift_positions.duplicate()
	s.pending_rift_spawns = pending_rift_spawns.duplicate(true)
	s.rift_schedule = rift_schedule.duplicate(true)
	s.pending_bell_wave = pending_bell_wave.duplicate()
	s.bell_wave_schedule = bell_wave_schedule.duplicate(true)
	s.abyss_edges = abyss_edges.duplicate(true)
	s.scripted_spawn_schedule = scripted_spawn_schedule.duplicate(true)
	s.protected_targets = protected_targets.duplicate()
	s.destroyed_protected_count = destroyed_protected_count
	s.protected_damage_taken = protected_damage_taken
	s.protected_damage_by_pos = protected_damage_by_pos.duplicate()
	s.protected_initial_hp = protected_initial_hp.duplicate()
	s.cracked_protected_targets = cracked_protected_targets.duplicate()
	s.protected_shields = protected_shields.duplicate()
	s.sigils = sigils.duplicate(true)
	s.warden_upgrades = warden_upgrades.duplicate(true)
	s.skill_uses = skill_uses.duplicate()
	s.skill_cooldowns = skill_cooldowns.duplicate()
	s.bounty_executes = bounty_executes.duplicate()
	s.physical_kills = physical_kills
	s.killed_enemy_defs = killed_enemy_defs.duplicate()
	s.warden_deaths = warden_deaths
	s.enemy_attack_misses = enemy_attack_misses
	s.rift_suppressions = rift_suppressions
	s.reward_tasks = reward_tasks.duplicate()
	s.reward_progress = reward_progress.duplicate()
	s.reward_completed = reward_completed.duplicate()
	s.reward_failed = reward_failed.duplicate()
	s.boss_config_id = boss_config_id
	s.boss_script_id = boss_script_id
	s.doom_count = doom_count
	s.doom_count_max = doom_count_max
	s.boss_breached = boss_breached
	s.boss_anchor_positions = boss_anchor_positions.duplicate()
	s.boss_anchor_hp = boss_anchor_hp.duplicate(true)
	s.boss_anchor_hp_max = boss_anchor_hp_max
	s.heart_position = heart_position
	s.heart_hits = heart_hits
	s.heart_hit_cap = heart_hit_cap
	s.heart_window_hits = heart_window_hits
	s.heart_exposure_rounds = heart_exposure_rounds
	s.heart_exposed_until_round = heart_exposed_until_round
	s.heart_doom_reduction_applied = heart_doom_reduction_applied
	s.boss_script_resolved_rounds = boss_script_resolved_rounds.duplicate(true)
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

## Build a pathfinding block set for a moving unit. Same-faction units may be
## crossed, but enemies/opponents still block paths.
func opposing_occupied_cells(mover: Unit) -> Dictionary:
	var d: Dictionary = {}
	if mover == null or mover.def == null:
		return occupied_cells(mover.id if mover != null else -1)
	for u in units:
		if u.id == mover.id or u.def == null:
			continue
		if u.def.faction != mover.def.faction:
			d[u.position] = true
	return d

func is_abyss_edge(from_cell: Vector2i, direction: Vector2i) -> bool:
	if direction == Vector2i.ZERO or not abyss_edges.has(from_cell):
		return false
	var dirs: Dictionary = abyss_edges.get(from_cell, {})
	return bool(dirs.get(direction, false))

func abyss_edge_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for raw in abyss_edges.keys():
		cells.append(raw)
	return cells

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

func capture_protected_initial_hp() -> void:
	protected_initial_hp.clear()
	for p in protected_targets:
		if grid.get_tile(p) == Grid.TileType.BUILDING:
			protected_initial_hp[p] = int(grid.tile_hp.get(p, Grid.DEFAULT_BUILDING_HP))

func has_boss() -> bool:
	return boss_config_id != BOSS_CONFIG_NONE

func configure_boss(config: Dictionary) -> void:
	boss_config_id = String(config.get("boss_config_id", config.get("config_id", BOSS_CONFIG_NONE)))
	if boss_config_id == BOSS_CONFIG_NONE:
		return
	boss_script_id = String(config.get("boss_script_id", "knell_lord_demo_six_round"))
	doom_count = int(config.get("doom_count_initial", config.get("doom_count", 0)))
	doom_count_max = int(config.get("doom_count_max", 3))
	boss_breached = doom_count_max > 0 and doom_count >= doom_count_max
	boss_anchor_hp_max = int(config.get("anchor_hp", 2))
	heart_hit_cap = int(config.get("heart_hit_cap", 3))
	heart_hits = int(config.get("heart_hits", 0))
	heart_window_hits = int(config.get("heart_window_hits", 0))
	heart_position = _parse_cell(config.get("heart_position", Vector2i(-1, -1)))
	heart_exposure_rounds = maxi(1, int(config.get("heart_exposure_rounds", 1)))
	heart_exposed_until_round = int(config.get("heart_exposed_until_round", 0))
	heart_doom_reduction_applied = bool(config.get("heart_doom_reduction_applied", false))
	boss_anchor_positions.clear()
	boss_anchor_hp.clear()
	boss_script_resolved_rounds.clear()
	for raw in config.get("anchor_positions", []):
		var p := _parse_cell(raw)
		if not grid.in_bounds(p):
			continue
		if p in boss_anchor_positions:
			continue
		boss_anchor_positions.append(p)
		boss_anchor_hp[p] = boss_anchor_hp_max
		grid.set_tile(p, Grid.TileType.PILLAR)
		grid.tile_hp[p] = boss_anchor_hp_max

func is_boss_doom_breached() -> bool:
	return has_boss() and doom_count_max > 0 and doom_count >= doom_count_max

func is_boss_anchor(pos: Vector2i) -> bool:
	return pos in boss_anchor_positions

func is_boss_anchor_alive(pos: Vector2i) -> bool:
	return is_boss_anchor(pos) and int(boss_anchor_hp.get(pos, 0)) > 0

func boss_alive_anchor_count() -> int:
	var count := 0
	for pos in boss_anchor_positions:
		if is_boss_anchor_alive(pos):
			count += 1
	return count

func boss_destroyed_anchor_count() -> int:
	return boss_anchor_positions.size() - boss_alive_anchor_count()

func boss_all_anchors_destroyed() -> bool:
	return has_boss() and not boss_anchor_positions.is_empty() and boss_alive_anchor_count() <= 0

func is_boss_heart_exposed() -> bool:
	return has_boss() \
		and boss_all_anchors_destroyed() \
		and grid.in_bounds(heart_position) \
		and phase == Phase.PLAYER_ACTION \
		and current_round <= heart_exposed_until_round

func is_boss_heart_attackable(pos: Vector2i) -> bool:
	return pos == heart_position and is_boss_heart_exposed() and heart_hits < heart_hit_cap

func refresh_boss_heart_exposure() -> void:
	if not has_boss() or not boss_all_anchors_destroyed() or not grid.in_bounds(heart_position):
		return
	if heart_exposed_until_round <= 0:
		heart_exposed_until_round = current_round + heart_exposure_rounds

func damage_boss_anchor(pos: Vector2i, amount: int) -> Dictionary:
	if amount <= 0 or not is_boss_anchor_alive(pos):
		return {"damaged": 0, "destroyed": false, "tile": grid.get_tile(pos)}
	var old_hp := int(boss_anchor_hp.get(pos, 0))
	var new_hp := old_hp - amount
	var damaged := mini(amount, old_hp)
	if new_hp > 0:
		boss_anchor_hp[pos] = new_hp
		grid.tile_hp[pos] = new_hp
		return {"damaged": damaged, "destroyed": false, "tile": Grid.TileType.PILLAR}
	boss_anchor_hp[pos] = 0
	grid.tile_hp.erase(pos)
	grid.set_tile(pos, Grid.TileType.EMPTY)
	refresh_boss_heart_exposure()
	return {"damaged": damaged, "destroyed": true, "tile": Grid.TileType.PILLAR}

func repair_protected_target(pos: Vector2i, amount: int) -> int:
	if amount <= 0 or not is_protected_target(pos):
		return 0
	if grid.get_tile(pos) != Grid.TileType.BUILDING or not grid.tile_hp.has(pos):
		return 0
	var old_hp := int(grid.tile_hp.get(pos, Grid.DEFAULT_BUILDING_HP))
	var max_hp := int(protected_initial_hp.get(pos, old_hp))
	var new_hp := mini(max_hp, old_hp + amount)
	if new_hp <= old_hp:
		return 0
	grid.tile_hp[pos] = new_hp
	return new_hp - old_hp

func record_boss_heart_hit(amount: int = 1) -> void:
	if not has_boss() or amount <= 0:
		return
	var old_hits := heart_hits
	heart_hits = clampi(heart_hits + amount, 0, heart_hit_cap)
	if is_boss_heart_exposed():
		heart_window_hits = clampi(heart_window_hits + heart_hits - old_hits, 0, heart_hit_cap)
	_refresh_reward_tasks(false)

func apply_boss_heart_doom_reduction() -> bool:
	if not has_boss() or heart_doom_reduction_applied or heart_hits < 2 or doom_count <= 0:
		return false
	doom_count = maxi(0, doom_count - 1)
	heart_doom_reduction_applied = true
	return true

func _parse_cell(raw) -> Vector2i:
	if raw is Vector2i:
		return raw
	if raw is Dictionary:
		return Vector2i(int(raw.get("x", -1)), int(raw.get("y", -1)))
	if raw is Array and raw.size() >= 2:
		return Vector2i(int(raw[0]), int(raw[1]))
	return Vector2i(-1, -1)

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
	protected_damage_by_pos[pos] = int(protected_damage_by_pos.get(pos, 0)) + amount
	if destroyed:
		destroyed_protected_count += 1
	_refresh_reward_tasks(false)

func record_enemy_kill(cause: StringName, def_id: StringName = &"") -> void:
	if PHYSICAL_KILL_CAUSES.has(cause):
		physical_kills += 1
	if def_id != &"":
		killed_enemy_defs[def_id] = int(killed_enemy_defs.get(def_id, 0)) + 1
	_refresh_reward_tasks(false)

func record_warden_death() -> void:
	warden_deaths += 1
	_refresh_reward_tasks(false)

func record_enemy_attack_miss() -> void:
	enemy_attack_misses += 1
	_refresh_reward_tasks(false)

func record_rift_suppression() -> void:
	rift_suppressions += 1
	_refresh_reward_tasks(false)

func crack_protected_target(pos: Vector2i) -> void:
	if not is_protected_target(pos):
		return
	cracked_protected_targets[pos] = true

func consume_protected_crack(pos: Vector2i) -> bool:
	if not cracked_protected_targets.has(pos):
		return false
	cracked_protected_targets.erase(pos)
	return true

func has_protected_shield(pos: Vector2i) -> bool:
	return protected_shields.has(pos)

func protected_shield_amount(pos: Vector2i) -> int:
	return int(protected_shields.get(pos, 0))

func add_protected_shield(pos: Vector2i, amount: int = 1) -> bool:
	if not is_protected_target(pos):
		return false
	if amount <= 0:
		return false
	if protected_shields.has(pos):
		return false
	protected_shields[pos] = amount
	return true

func consume_protected_shield(pos: Vector2i, amount: int = 1) -> int:
	if not protected_shields.has(pos):
		return 0
	var current := int(protected_shields.get(pos, 0))
	var consumed := mini(current, maxi(1, amount))
	var remaining := current - consumed
	if remaining > 0:
		protected_shields[pos] = remaining
	else:
		protected_shields.erase(pos)
	return consumed

func clear_protected_shields() -> void:
	protected_shields.clear()

func set_warden_upgrades(unit_id: int, upgrade_ids: Array) -> void:
	warden_upgrades[unit_id] = upgrade_ids.duplicate()

func upgrades_for_warden(unit_id: int) -> Array:
	return warden_upgrades.get(unit_id, [])

func add_sigil(pos: Vector2i, owner_id: int, remaining_rounds: int = 2) -> bool:
	if has_sigil_at(pos):
		return false
	sigils.append({
		"pos": pos,
		"owner_id": owner_id,
		"remaining_rounds": remaining_rounds,
	})
	return true

func has_sigil_at(pos: Vector2i) -> bool:
	for sigil in sigils:
		if sigil.get("pos", Vector2i(-1, -1)) == pos and int(sigil.get("remaining_rounds", 0)) > 0:
			return true
	return false

func active_sigil_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for sigil in sigils:
		if int(sigil.get("remaining_rounds", 0)) > 0:
			cells.append(sigil.get("pos", Vector2i(-1, -1)))
	return cells

func decrement_sigils_after_enemy_moves() -> void:
	var kept: Array[Dictionary] = []
	for sigil in sigils:
		var copy := sigil.duplicate(true)
		copy["remaining_rounds"] = int(copy.get("remaining_rounds", 0)) - 1
		if int(copy.get("remaining_rounds", 0)) > 0:
			kept.append(copy)
	sigils = kept

func skill_use_key(unit_id: int, skill_id: StringName) -> String:
	return "%d:%s" % [unit_id, String(skill_id)]

func skill_use_count(unit_id: int, skill_id: StringName) -> int:
	return int(skill_uses.get(skill_use_key(unit_id, skill_id), 0))

func record_skill_use(unit_id: int, skill_id: StringName) -> void:
	var key := skill_use_key(unit_id, skill_id)
	skill_uses[key] = int(skill_uses.get(key, 0)) + 1

func skill_next_available_round(unit_id: int, skill_id: StringName) -> int:
	return int(skill_cooldowns.get(skill_use_key(unit_id, skill_id), 1))

func skill_cooldown_remaining(unit_id: int, skill_id: StringName) -> int:
	return maxi(0, skill_next_available_round(unit_id, skill_id) - current_round)

func start_skill_cooldown(unit_id: int, skill_id: StringName, cooldown_rounds: int) -> void:
	if cooldown_rounds <= 0:
		return
	skill_cooldowns[skill_use_key(unit_id, skill_id)] = current_round + cooldown_rounds + 1

func record_bounty_execute(unit_id: int) -> void:
	bounty_executes[unit_id] = int(bounty_executes.get(unit_id, 0)) + 1

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
			REWARD_PUSH_THREAT:
				reward_progress[task] = enemy_attack_misses
				if enemy_attack_misses >= 1:
					reward_completed[task] = true
				elif final:
					reward_failed[task] = true
			REWARD_ALL_WARDENS_SURVIVE:
				reward_progress[task] = warden_deaths
				if warden_deaths > 0:
					reward_failed[task] = true
				elif final:
					reward_completed[task] = true
			REWARD_RIFT_SUPPRESSION:
				reward_progress[task] = rift_suppressions
				if rift_suppressions >= 1:
					reward_completed[task] = true
				elif final:
					reward_failed[task] = true
			REWARD_LOW_LOSS_LINE:
				reward_progress[task] = protected_damage_taken
				if protected_damage_taken <= 1 and final:
					reward_completed[task] = true
				elif protected_damage_taken > 1:
					reward_failed[task] = true
			REWARD_ELITE_HUNT:
				var ironhorn_kills := int(killed_enemy_defs.get(DEF_IRONHORN, 0))
				reward_progress[task] = ironhorn_kills
				if ironhorn_kills >= 1:
					reward_completed[task] = true
				elif final:
					reward_failed[task] = true
			REWARD_KEY_TARGET_UNDAMAGED:
				var key_pos := _key_protected_target_pos()
				var key_damage := int(protected_damage_by_pos.get(key_pos, 0)) if key_pos != Vector2i(-1, -1) else 0
				reward_progress[task] = key_damage
				if key_damage > 0:
					reward_failed[task] = true
				elif final and key_pos != Vector2i(-1, -1):
					reward_completed[task] = true
			REWARD_ANCHOR_DESTROY:
				reward_progress[task] = boss_destroyed_anchor_count()
				if boss_all_anchors_destroyed():
					reward_completed[task] = true
				elif final:
					reward_failed[task] = true
			REWARD_PERFECT_WATCH:
				reward_progress[task] = destroyed_protected_count
				if destroyed_protected_count > 0:
					reward_failed[task] = true
				elif final:
					reward_completed[task] = true
			REWARD_HEART_WINDOW:
				reward_progress[task] = heart_window_hits
				if heart_window_hits >= heart_hit_cap and heart_hit_cap > 0:
					reward_completed[task] = true
				elif final:
					reward_failed[task] = true

func _key_protected_target_pos() -> Vector2i:
	if protected_targets.is_empty():
		return Vector2i(-1, -1)
	var best := protected_targets[0]
	var best_hp := int(protected_initial_hp.get(best, grid.tile_hp.get(best, Grid.DEFAULT_BUILDING_HP)))
	for p in protected_targets:
		var hp := int(protected_initial_hp.get(p, grid.tile_hp.get(p, Grid.DEFAULT_BUILDING_HP)))
		if hp > best_hp or (hp == best_hp and _cell_id(p) < _cell_id(best)):
			best = p
			best_hp = hp
	return best

func _cell_id(p: Vector2i) -> int:
	return p.y * Grid.SIZE + p.x
