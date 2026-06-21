class_name EnemyTargeting extends RefCounted
## Target selection and line scans for enemy AI.
##
## This module owns "what should this enemy attack?". AIDecider owns turn
## orchestration; BattlePathing owns "how should this enemy move there?".

const NO_TARGET := Vector2i(-1, -1)

static func best_attack_target_pos(state: BattleState, enemy: Unit) -> Vector2i:
	if enemy == null:
		return NO_TARGET
	var candidates: Array[Dictionary] = []
	for p in state.alive_protected_targets():
		var hp: int = state.grid.tile_hp.get(p, Grid.DEFAULT_BUILDING_HP)
		var dist := Grid.manhattan(enemy.position, p)
		candidates.append({
			"pos": p,
			"kind": "building",
			"score": target_score(enemy, "building", dist, hp),
			"dist": dist,
			"hp": hp,
			"id": cell_id(p),
		})
	if not is_bone_grub(enemy):
		for w in state.wardens():
			var dist := Grid.manhattan(enemy.position, w.position)
			candidates.append({
				"pos": w.position,
				"kind": "warden",
				"score": target_score(enemy, "warden", dist, w.hp),
				"dist": dist,
				"hp": w.hp,
				"id": w.id,
			})
	if candidates.is_empty():
		return NO_TARGET
	candidates.sort_custom(target_candidate_less)
	return candidates[0].pos

static func target_score(enemy: Unit, kind: String, distance: int, hp: int) -> int:
	var base := 0
	if kind == "building":
		base = 100
		if is_bone_grub(enemy) or is_bell_thrall(enemy) or is_ironhorn(enemy):
			base += 100
	else:
		base = 86
		if is_bell_thrall(enemy) or is_ironhorn(enemy):
			base -= 40
		base += maxi(0, 4 - hp) * 8
	base += maxi(0, 8 - distance) * 3
	return base

static func target_candidate_less(a: Dictionary, b: Dictionary) -> bool:
	var score_a := int(a.get("score", 0))
	var score_b := int(b.get("score", 0))
	if score_a != score_b:
		return score_a > score_b
	var kind_a := String(a.get("kind", ""))
	var kind_b := String(b.get("kind", ""))
	if kind_a != kind_b:
		return kind_a == "building"
	var dist_a := int(a.get("dist", 0))
	var dist_b := int(b.get("dist", 0))
	if dist_a != dist_b:
		return dist_a < dist_b
	var hp_a := int(a.get("hp", 0))
	var hp_b := int(b.get("hp", 0))
	if hp_a != hp_b:
		return hp_a < hp_b
	return int(a.get("id", 0)) < int(b.get("id", 0))

static func adjacent_attack_target_cell(state: BattleState, from: Vector2i, enemy: Unit = null) -> Vector2i:
	## Returns an adjacent protected building first, then adjacent warden.
	var best_building := NO_TARGET
	for d in Grid.DIRS:
		var p := from + d
		if state.grid.get_tile(p) == Grid.TileType.BUILDING and state.is_protected_target(p):
			if best_building == NO_TARGET or cell_id(p) < cell_id(best_building):
				best_building = p
	if best_building != NO_TARGET:
		return best_building
	if is_bone_grub(enemy):
		return NO_TARGET
	var best: Unit = null
	for d in Grid.DIRS:
		var t := state.get_alive_unit_at(from + d)
		if t == null or not t.is_warden():
			continue
		if best == null or t.id < best.id:
			best = t
	return best.position if best != null else NO_TARGET

static func scan_line_for_warden(state: BattleState, from: Vector2i, range_steps: int, self_id: int) -> Vector2i:
	for d in Grid.DIRS:
		for step in range(1, range_steps + 1):
			var p: Vector2i = from + d * step
			if not state.grid.in_bounds(p) or state.grid.blocks_movement(p):
				break
			var u := state.get_alive_unit_at(p)
			if u == null or u.id == self_id:
				continue
			if u.is_warden():
				return p
			break
	return NO_TARGET

static func scan_line_for_attack_target(state: BattleState, from: Vector2i, range_steps: int, self_id: int) -> Vector2i:
	for d in Grid.DIRS:
		for step in range(1, range_steps + 1):
			var p: Vector2i = from + d * step
			if not state.grid.in_bounds(p) or state.grid.blocks_movement(p):
				if state.grid.in_bounds(p) \
					and state.grid.get_tile(p) == Grid.TileType.BUILDING \
					and state.is_protected_target(p):
					return p
				break
			var u := state.get_alive_unit_at(p)
			if u == null or u.id == self_id:
				continue
			if u.is_warden():
				return p
			break
	return NO_TARGET

static func scan_with_shadow(
	state: BattleState,
	from: Vector2i,
	range_steps: int,
	self_id: int,
	shadow: Dictionary
) -> Vector2i:
	var pos_to_id: Dictionary = {}
	for uid in shadow.keys():
		if uid == self_id:
			continue
		pos_to_id[shadow[uid]] = uid
	for d in Grid.DIRS:
		for step in range(1, range_steps + 1):
			var p: Vector2i = from + d * step
			if not state.grid.in_bounds(p) or state.grid.blocks_movement(p):
				if state.grid.in_bounds(p) \
					and state.grid.get_tile(p) == Grid.TileType.BUILDING \
					and state.is_protected_target(p):
					return p
				break
			if not pos_to_id.has(p):
				continue
			var blocker_id: int = pos_to_id[p]
			var blocker := state.find_unit(blocker_id)
			if blocker != null and blocker.is_warden():
				return p
			break
	return NO_TARGET

static func is_bone_grub(enemy: Unit) -> bool:
	return enemy != null and enemy.def != null and enemy.def.def_id == BattleState.DEF_BONE_GRUB

static func is_bell_thrall(enemy: Unit) -> bool:
	return enemy != null and enemy.def != null and enemy.def.def_id == BattleState.DEF_BELL_THRALL

static func is_ironhorn(enemy: Unit) -> bool:
	return enemy != null and enemy.def != null and enemy.def.def_id == BattleState.DEF_IRONHORN

static func cell_id(p: Vector2i) -> int:
	return p.y * Grid.SIZE + p.x
