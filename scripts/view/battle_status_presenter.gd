extends RefCounted

static func battle_status_summary_text(state: BattleState) -> String:
	var parts: Array[String] = []
	var headline := "Boss：撑到第 %d 轮" if state.has_boss() else "目标：撑到第 %d 轮"
	parts.append(headline % state.max_rounds)
	var protected_text := _protected_target_status_text(state)
	if protected_text != "":
		parts.append(protected_text)
	if state.has_boss():
		parts.append(_boss_pressure_status_text(state))
	return "   ".join(parts)

static func boss_status_title_text(state: BattleState) -> String:
	if state == null or not state.has_boss():
		return ""
	return "裂心钟主"

static func boss_status_lines(state: BattleState) -> Array[String]:
	var lines: Array[String] = []
	if state == null or not state.has_boss():
		return lines
	lines.append("本轮脚本：%s" % _boss_action_text_for_round(state, state.current_round))
	lines.append("下一脚本：%s" % _next_boss_action_text(state))
	lines.append("Doom：%d / %d%s" % [
		state.doom_count,
		state.doom_count_max,
		"（溃败）" if state.is_boss_doom_breached() else "",
	])
	lines.append(_boss_anchor_line(state))
	lines.append(_boss_heart_exposure_line(state))
	lines.append(_boss_heart_hit_effect_line(state))
	return lines

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
		if state.is_boss_heart_exposed():
			parts.append("心钟暴露中")
		elif state.heart_hits >= 2 and not state.heart_doom_reduction_applied:
			parts.append("终局 Doom -1 就绪")
	return "   ".join(parts)

static func _boss_anchor_line(state: BattleState) -> String:
	if state.boss_anchor_positions.is_empty():
		return "锚石：未配置"
	var anchor_hp: Array[String] = []
	for pos in state.boss_anchor_positions:
		anchor_hp.append(str(maxi(0, int(state.boss_anchor_hp.get(pos, 0)))))
	return "锚石：%d / %d 存活，HP %s" % [
		state.boss_alive_anchor_count(),
		state.boss_anchor_positions.size(),
		",".join(anchor_hp),
	]

static func _boss_heart_exposure_line(state: BattleState) -> String:
	if state.heart_hit_cap <= 0:
		return "心钟：未配置"
	if state.heart_hits >= state.heart_hit_cap:
		return "心钟：已完全压制"
	if not state.boss_all_anchors_destroyed():
		return "心钟：锚石全毁后暴露"
	if state.is_boss_heart_exposed():
		return "心钟：暴露中，本玩家回合结束关闭"
	if state.heart_exposed_until_round > 0 and state.current_round <= state.heart_exposed_until_round:
		return "心钟：敌方阶段不可命中"
	return "心钟：暴露窗口已关闭"

static func _boss_heart_hit_effect_line(state: BattleState) -> String:
	var effects: Array[String] = []
	if state.heart_hits >= 1:
		effects.append("终局钟鸣已压制")
	else:
		effects.append("终局钟鸣未压制")
	if state.heart_hits >= 2:
		effects.append("Doom -1 已生效" if state.heart_doom_reduction_applied else "Doom -1 已就绪")
	else:
		effects.append("2 次命中可终局 Doom -1")
	if state.heart_hits >= 3:
		effects.append("暴露窗口任务完成")
	else:
		effects.append("3 次命中完成暴露窗口任务")
	return "心钟命中：%d / %d，%s" % [
		state.heart_hits,
		state.heart_hit_cap,
		"，".join(effects),
	]

static func _next_boss_action_text(state: BattleState) -> String:
	for round_number in [3, 5, 6]:
		if int(round_number) > state.current_round:
			return _boss_action_text_for_round(state, int(round_number))
	return "无后续 Doom 脚本"

static func _boss_action_text_for_round(state: BattleState, round_number: int) -> String:
	if state.boss_script_resolved_rounds.has(round_number):
		return "第 %d 轮已结算" % round_number
	match round_number:
		3:
			return "第 3 轮双锚共鸣：%s" % ("Doom +1" if state.boss_alive_anchor_count() >= 2 else "已压制")
		5:
			return "第 5 轮残锚共鸣：%s" % ("Doom +1" if state.boss_alive_anchor_count() >= 1 else "已压制")
		6:
			return "第 6 轮终局钟鸣：%s" % ("Doom +1" if state.heart_hits < 1 else "已压制")
	return "第 %d 轮无 Doom 脚本" % round_number
