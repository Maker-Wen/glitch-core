extends RefCounted

static func battle_status_summary_text(state: BattleState) -> String:
	var parts: Array[String] = []
	var headline := "Boss：撑到第 %d 轮" if state.has_boss() else "目标：撑到第 %d 轮"
	parts.append(headline % state.max_rounds)
	var protected_text := _protected_target_status_text(state)
	if protected_text != "":
		parts.append(protected_text)
	parts.append("预计 -%d" % projected_sanctuary_loss(state))
	if state.has_boss():
		parts.append(_boss_pressure_status_text(state))
	return "   ".join(parts)

static func projected_sanctuary_loss(state: BattleState) -> int:
	if state.has_boss() and (state.boss_breached or state.is_boss_doom_breached()):
		return 3
	if state.has_protected_targets() and state.alive_protected_targets().is_empty():
		return 3
	return clampi(state.destroyed_protected_count, 0, 3)

static func _protected_target_status_text(state: BattleState) -> String:
	if not state.has_protected_targets():
		return ""
	var hp_values: Array[String] = []
	for pos in state.protected_targets:
		var hp := 0
		if state.grid != null and state.grid.get_tile(pos) == Grid.TileType.BUILDING:
			hp = maxi(0, int(state.grid.tile_hp.get(pos, 0)))
		hp_values.append(str(hp))
	return "建筑 %d/%d HP %s" % [
		state.alive_protected_targets().size(),
		state.protected_targets.size(),
		",".join(hp_values),
	]

static func _boss_pressure_status_text(state: BattleState) -> String:
	var parts: Array[String] = []
	parts.append("Doom %d/%d" % [state.doom_count, state.doom_count_max])
	if not state.boss_anchor_positions.is_empty():
		var anchor_hp: Array[String] = []
		for pos in state.boss_anchor_positions:
			anchor_hp.append(str(maxi(0, int(state.boss_anchor_hp.get(pos, 0)))))
		parts.append("锚石 %d/%d HP %s" % [
			state.boss_alive_anchor_count(),
			state.boss_anchor_positions.size(),
			",".join(anchor_hp),
		])
	if state.heart_hit_cap > 0:
		parts.append("心钟 %d/%d" % [state.heart_hits, state.heart_hit_cap])
	return "   ".join(parts)
