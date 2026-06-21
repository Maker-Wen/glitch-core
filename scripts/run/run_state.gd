class_name RunState extends RefCounted
## Mutable state for the fixed demo roguelite run.

const RelicCatalogScript := preload("res://scripts/data/relic_catalog.gd")
const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const WardenBountyhunterDef := preload("res://scripts/data/defs/warden_bountyhunter.tres")
const WardenGraverobberDef := preload("res://scripts/data/defs/warden_graverobber.tres")
const WardenMageDef := preload("res://scripts/data/defs/warden_mage.tres")

enum Phase {
	MENU,
	PREP,
	ROUTE,
	NODE_PREVIEW,
	BATTLE,
	NODE_RESOLUTION,
	REWARD,
	RUN_RESULT,
}

const NODE_NORMAL := "normal"
const NODE_ELITE := "elite"
const NODE_BOSS := "boss"
const NODE_EVENT := "event"
const NODE_CAMP := "camp"
const NODE_SHOP := "shop"

const RUN_MODE_ROUTE := "route"
const EXPEDITION_BROKEN_WALL := "broken_wall"
const EXPEDITION_RIFT_CORRIDOR := "rift_corridor"
const EXPEDITION_SUPPLY_LINE := "supply_line"
const DEFAULT_SANCTUARY_INTEGRITY := 12
const COMMISSION_BOARD_SIZE := 3
const COMMISSION_BOSS_UNLOCK_COUNT := 5
const WARDEN_ROSTER_IDS := ["warden_bountyhunter", "warden_graverobber", "warden_mage"]
const WARDEN_HP_UPGRADE_IDS := {
	"upgrade_bountyhunter_vanguard": true,
	"upgrade_graverobber_field_pack": true,
	"upgrade_mage_arcane_ward": true,
}
var run_id: String = ""
var run_seed: int = 0
var difficulty_id: String = "normal"
var expedition_id: String = EXPEDITION_BROKEN_WALL
var expedition_name: String = "断墙外环"
var phase: int = Phase.MENU
var chapter_index: int = 1
var chapter_name: String = "外墙余烬"
var chapter_node_index: int = 0
var current_node_id: String = ""
var sanctuary_integrity: int = DEFAULT_SANCTUARY_INTEGRITY
var sanctuary_integrity_max: int = DEFAULT_SANCTUARY_INTEGRITY
var embers: int = 0
var corruption: int = 0
var wardens: Array[Dictionary] = []
var relics: Array[Dictionary] = []
var route_nodes: Array[Dictionary] = []
var active_commission_ids: Array[String] = []
var visited_nodes: Array[String] = []
var claimed_reward_ids: Array[String] = []
var pending_reward: Dictionary = {}
var last_resolution: Dictionary = {}
var last_route_notice: Dictionary = {}
var chapter_guardian_reward_used: bool = false
var result_outcome: String = ""

func setup_new_demo() -> void:
	run_id = "demo-%d" % Time.get_unix_time_from_system()
	run_seed = 1046
	difficulty_id = "normal"
	expedition_id = EXPEDITION_BROKEN_WALL
	expedition_name = "断墙外环"
	phase = Phase.PREP
	chapter_index = 1
	chapter_name = "外墙余烬"
	chapter_node_index = 0
	current_node_id = ""
	sanctuary_integrity = DEFAULT_SANCTUARY_INTEGRITY
	sanctuary_integrity_max = DEFAULT_SANCTUARY_INTEGRITY
	embers = 0
	corruption = 0
	relics.clear()
	visited_nodes.clear()
	claimed_reward_ids.clear()
	pending_reward.clear()
	last_resolution.clear()
	last_route_notice.clear()
	chapter_guardian_reward_used = false
	result_outcome = ""
	wardens = _initial_wardens()
	route_nodes = _build_demo_route()
	_initialize_commission_board()

func setup_new_random_route(seed: int = 0, selected_expedition_id: String = EXPEDITION_BROKEN_WALL) -> void:
	run_id = "random-%d" % Time.get_unix_time_from_system()
	run_seed = seed if seed > 0 else int(Time.get_unix_time_from_system())
	difficulty_id = "normal"
	expedition_id = selected_expedition_id
	expedition_name = _expedition_display_name(expedition_id)
	phase = Phase.PREP
	chapter_index = 1
	chapter_name = expedition_name
	chapter_node_index = 0
	current_node_id = ""
	sanctuary_integrity = DEFAULT_SANCTUARY_INTEGRITY
	sanctuary_integrity_max = DEFAULT_SANCTUARY_INTEGRITY
	embers = 0
	corruption = 0
	relics.clear()
	visited_nodes.clear()
	claimed_reward_ids.clear()
	pending_reward.clear()
	last_resolution.clear()
	last_route_notice.clear()
	chapter_guardian_reward_used = false
	result_outcome = ""
	wardens = _initial_wardens()
	route_nodes = _build_random_route(run_seed, expedition_id)
	_initialize_commission_board()

func next_unvisited_node() -> Dictionary:
	var available := available_route_nodes()
	if not available.is_empty():
		return available[0]
	return {}

func available_route_nodes() -> Array[Dictionary]:
	_refill_commission_board()
	var result: Array[Dictionary] = []
	for node_id in active_commission_ids:
		var node := node_by_id(node_id)
		if node.is_empty() or bool(node.get("visited", false)):
			continue
		result.append(node)
	return result

func is_route_node_available(node_id: String) -> bool:
	for node in available_route_nodes():
		if String(node.get("node_id", "")) == node_id:
			return true
	return false

func node_by_id(node_id: String) -> Dictionary:
	for node in route_nodes:
		if String(node.get("node_id", "")) == node_id:
			return node
	return {}

func current_node() -> Dictionary:
	if current_node_id.is_empty():
		return next_unvisited_node()
	return node_by_id(current_node_id)

func alive_wardens() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for w in wardens:
		if bool(w.get("alive", false)):
			result.append(w)
	return result

func alive_warden_count() -> int:
	return alive_wardens().size()

func sync_warden_base_stats() -> void:
	for i in range(wardens.size()):
		var w := wardens[i]
		var def := _warden_base_def(String(w.get("warden_id", "")))
		if def == null:
			continue
		var current_max := int(w.get("hp_max", def.max_hp))
		var target_max := def.max_hp + _warden_hp_upgrade_bonus(w)
		var current_hp := int(w.get("hp", target_max))
		if bool(w.get("alive", false)) and current_hp >= current_max:
			current_hp = target_max
		w["name"] = def.display_name
		w["role"] = _warden_role(String(w.get("warden_id", "")))
		w["hp_max"] = target_max
		w["hp"] = clampi(current_hp, 0, target_max)
		w["move"] = def.move
		w["attack_range"] = def.attack_range
		wardens[i] = w

func _base_max_hp_for_warden_id(warden_id: String) -> int:
	var def := _warden_base_def(warden_id)
	return def.max_hp if def != null else 1

func _current_max_hp_for_warden(warden: Dictionary) -> int:
	return _base_max_hp_for_warden_id(String(warden.get("warden_id", ""))) + _warden_hp_upgrade_bonus(warden)

func _initial_wardens() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for warden_id in WARDEN_ROSTER_IDS:
		var def := _warden_base_def(warden_id)
		if def == null:
			continue
		result.append({
			"warden_id": warden_id,
			"name": def.display_name,
			"role": _warden_role(warden_id),
			"hp": def.max_hp,
			"hp_max": def.max_hp,
			"move": def.move,
			"attack_range": def.attack_range,
			"alive": true,
			"upgrades": [],
			"death_node_id": "",
		})
	return result

func _warden_base_def(warden_id: String) -> UnitDef:
	match warden_id:
		"warden_bountyhunter":
			return WardenBountyhunterDef
		"warden_graverobber":
			return WardenGraverobberDef
		"warden_mage":
			return WardenMageDef
	return null

func _warden_role(warden_id: String) -> String:
	match warden_id:
		"warden_bountyhunter":
			return "近战抗压"
		"warden_graverobber":
			return "远程牵引"
		"warden_mage":
			return "远程推击"
	return ""

func _warden_hp_upgrade_bonus(warden: Dictionary) -> int:
	var result := 0
	for upgrade_id in warden.get("upgrades", []):
		if WARDEN_HP_UPGRADE_IDS.has(String(upgrade_id)):
			result += 1
	return result

func mark_current_node_visited() -> void:
	var node_id := current_node_id
	if node_id.is_empty():
		return
	for i in range(route_nodes.size()):
		if String(route_nodes[i].get("node_id", "")) == node_id:
			route_nodes[i]["visited"] = true
			break
	if not (node_id in visited_nodes):
		visited_nodes.append(node_id)
	chapter_node_index = visited_nodes.size()
	current_node_id = ""
	active_commission_ids.erase(node_id)
	_refill_commission_board()

func is_route_complete() -> bool:
	for node in route_nodes:
		if String(node.get("node_type", "")) == NODE_BOSS and bool(node.get("visited", false)):
			return true
	return not route_nodes.is_empty() and available_route_nodes().is_empty()

func is_battle_node(node: Dictionary) -> bool:
	var node_type := String(node.get("node_type", ""))
	return node_type == NODE_NORMAL or node_type == NODE_ELITE or node_type == NODE_BOSS

func max_visited_route_layer() -> int:
	var max_layer := 0
	for node in route_nodes:
		if bool(node.get("visited", false)):
			max_layer = maxi(max_layer, int(node.get("layer", 0)))
	return max_layer

func _initialize_commission_board() -> void:
	active_commission_ids.clear()
	_refill_commission_board()

func _refill_commission_board() -> void:
	_trim_active_commission_ids()
	if _boss_commission_should_unlock():
		active_commission_ids.clear()
		var boss := _boss_node()
		if not boss.is_empty():
			active_commission_ids.append(String(boss.get("node_id", "")))
		return
	while active_commission_ids.size() < COMMISSION_BOARD_SIZE:
		var candidates := _commission_refill_candidates()
		if candidates.is_empty():
			return
		active_commission_ids.append(String(candidates[0].get("node_id", "")))

func _trim_active_commission_ids() -> void:
	var trimmed: Array[String] = []
	for node_id in active_commission_ids:
		var node := node_by_id(node_id)
		if node.is_empty() or bool(node.get("visited", false)):
			continue
		if not (node_id in trimmed):
			trimmed.append(node_id)
	active_commission_ids = trimmed

func _commission_refill_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in route_nodes:
		var node_id := String(node.get("node_id", ""))
		if node_id.is_empty() or bool(node.get("visited", false)):
			continue
		if node_id in active_commission_ids:
			continue
		if String(node.get("node_type", "")) == NODE_BOSS:
			continue
		if _route_node_is_reachable(node):
			result.append(node)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var layer_a := int(a.get("layer", 0))
		var layer_b := int(b.get("layer", 0))
		if layer_a == layer_b:
			var lane_a := int(a.get("lane", 0))
			var lane_b := int(b.get("lane", 0))
			if lane_a == lane_b:
				return String(a.get("node_id", "")) < String(b.get("node_id", ""))
			return lane_a < lane_b
		return layer_a < layer_b
	)
	return result

func _boss_commission_should_unlock() -> bool:
	var boss := _boss_node()
	if boss.is_empty() or bool(boss.get("visited", false)):
		return false
	return _completed_non_boss_count() >= COMMISSION_BOSS_UNLOCK_COUNT

func _completed_non_boss_count() -> int:
	var count := 0
	for node_id in visited_nodes:
		var node := node_by_id(node_id)
		if not node.is_empty() and String(node.get("node_type", "")) != NODE_BOSS:
			count += 1
	return count

func _boss_node() -> Dictionary:
	for node in route_nodes:
		if String(node.get("node_type", "")) == NODE_BOSS:
			return node
	return {}

func resolve_event_node(choice_id: String) -> void:
	sync_warden_base_stats()
	var node := current_node()
	if node.is_empty() or String(node.get("node_type", "")) != NODE_EVENT:
		return
	var option := _find_node_option(node, "event", choice_id)
	if option.is_empty():
		return
	var before := _resource_snapshot()
	_apply_option_effects(option.get("effects", []))
	last_resolution = {
		"outcome": "event_resolved",
		"node_id": String(node.get("node_id", "")),
		"node_type": NODE_EVENT,
		"choice_id": choice_id,
		"choice_title": String(option.get("title", "")),
		"before": before,
		"after": _resource_snapshot(),
	}
	pending_reward.clear()
	mark_current_node_visited()
	phase = Phase.ROUTE

func resolve_camp_node(choice_id: String) -> void:
	sync_warden_base_stats()
	var node := current_node()
	if node.is_empty() or String(node.get("node_type", "")) != NODE_CAMP:
		return
	var option := _find_node_option(node, "camp", choice_id)
	if option.is_empty():
		return
	var before := _resource_snapshot()
	_apply_option_effects(option.get("effects", []))
	last_resolution = {
		"outcome": "camp_resolved",
		"node_id": String(node.get("node_id", "")),
		"node_type": NODE_CAMP,
		"choice_id": choice_id,
		"choice_title": String(option.get("title", "")),
		"before": before,
		"after": _resource_snapshot(),
	}
	pending_reward.clear()
	mark_current_node_visited()
	phase = Phase.ROUTE

func apply_battle_resolution(resolution: Dictionary) -> void:
	sync_warden_base_stats()
	last_resolution = resolution.duplicate(true)
	var sanctuary_loss := maxi(0, int(resolution.get("protected_damage_taken", 0)))
	sanctuary_integrity = maxi(0, sanctuary_integrity - sanctuary_loss)
	last_resolution["sanctuary_loss"] = sanctuary_loss
	last_resolution["sanctuary_after"] = sanctuary_integrity
	_update_wardens_from_battle(resolution)
	if alive_warden_count() <= 0 or sanctuary_integrity <= 0:
		result_outcome = "defeat"
		phase = Phase.RUN_RESULT
		pending_reward.clear()

func build_pending_reward(node: Dictionary, resolution: Dictionary) -> Dictionary:
	sync_warden_base_stats()
	var completed := int(resolution.get("completed_reward_count", 0))
	var node_type := String(node.get("node_type", NODE_NORMAL))
	var base_embers := int(node.get("base_embers", 7))
	var bonus_embers := _bonus_embers_for(node_type, completed)
	var reward_id := "%s-reward" % String(node.get("node_id", ""))
	if reward_id in claimed_reward_ids:
		return {}
	var reward := {
		"reward_id": reward_id,
		"source_node_id": String(node.get("node_id", "")),
		"source_type": "battle",
		"reward_phase": "fixed",
		"generated_seed": run_seed + int(node.get("layer", 0)) * 97 + completed,
		"fixed_rewards": [{"reward_type": "embers", "amount": base_embers, "reason": _base_reward_reason(node_type), "visible_order": 10}],
		"choice_groups": [],
		"modifiers": [],
		"reroll": {"allowed": false, "cost_embers": 3, "used_count": 0, "max_count": 0},
		"claim_state": {"generated": true, "fixed_claimed": false, "choice_claimed": false, "selected_option_ids": []},
	}
	if bonus_embers > 0:
		reward.fixed_rewards.append({"reward_type": "embers", "amount": bonus_embers, "reason": "完成 %d 个奖励任务" % completed, "visible_order": 20})
	if completed >= 2:
		reward.modifiers.append({"modifier_id": "reward_option_plus_1", "description": "完成 2 个奖励任务：奖励选项 +1。"})
	if completed >= 3 and (node_type == NODE_ELITE or node_type == NODE_BOSS):
		reward.modifiers.append({"modifier_id": "rare_weight_up", "description": "完成 3 个奖励任务：稀有遗物权重提高。"})
	var boss_heart_hits := int(resolution.get("boss_heart_hits", 0)) if node_type == NODE_BOSS else 0
	var boss_heart_bonus := _boss_heart_bonus_embers(boss_heart_hits)
	if boss_heart_bonus > 0:
		reward.fixed_rewards.append({"reward_type": "embers", "amount": boss_heart_bonus, "reason": "心脏钟命中 %d 次" % clampi(boss_heart_hits, 0, 3), "visible_order": 25})
		reward.modifiers.append({"modifier_id": "boss_heart_bell_bonus", "description": "Boss 心脏钟命中：额外 +%d 余烬。" % boss_heart_bonus})
	var options := _reward_options_for(node_type, completed)
	if _should_offer_guardian_recovery(node_type, completed):
		options.append({"option_id": "repair_sanctuary", "option_type": "recovery", "rarity": "普通", "target_type": "sanctuary_integrity", "target_id": "", "title": "修复防线", "description": "守护值 +1。本章奖励任务恢复只可触发一次。", "preview_delta": {"sanctuary_integrity": 1}, "tags": ["恢复", "防线"]})
		reward.modifiers.append({"modifier_id": "guardian_recovery_available", "description": "完成 3 个奖励任务：生成守护值恢复机会。"})
	elif _should_convert_guardian_recovery_to_embers(node_type, completed):
		reward.fixed_rewards.append({"reward_type": "embers", "amount": 3, "reason": "守护值已满，恢复机会转化", "visible_order": 30})
		reward.modifiers.append({"modifier_id": "guardian_recovery_converted", "description": "完成 3 个奖励任务，但守护值已满：改为 +3 余烬。"})
	if not options.is_empty():
		reward.reward_phase = "chapter_choice" if node_type == NODE_BOSS else "choice"
		reward.choice_groups.append({"group_id": "main_choice", "group_type": _choice_group_type(node_type), "choose_count": 1, "display_count": options.size(), "options": options, "can_skip": true, "skip_reward": {"reward_type": "embers", "amount": 3, "reason": "跳过奖励"}})
	return reward

func claim_pending_reward(option_id: String = "") -> void:
	sync_warden_base_stats()
	if pending_reward.is_empty():
		return
	var reward_id := String(pending_reward.get("reward_id", ""))
	if reward_id in claimed_reward_ids:
		pending_reward.clear()
		return
	var claim_state: Dictionary = pending_reward.get("claim_state", {})
	var choice_groups: Array = pending_reward.get("choice_groups", [])
	var requires_choice := false
	for group in choice_groups:
		if not group.get("options", []).is_empty():
			requires_choice = true
			break
	var selected_option := {}
	for group in choice_groups:
		for option in group.get("options", []):
			if String(option.get("option_id", "")) == option_id:
				selected_option = option
				break
		if not selected_option.is_empty():
			break
	var skip_selected := option_id == "skip"
	if requires_choice and selected_option.is_empty() and not skip_selected:
		return
	if not bool(claim_state.get("fixed_claimed", false)):
		for reward in pending_reward.get("fixed_rewards", []):
			_apply_fixed_reward(reward)
		claim_state["fixed_claimed"] = true
		if _pending_reward_has_modifier("guardian_recovery_converted"):
			chapter_guardian_reward_used = true
	if not bool(claim_state.get("choice_claimed", false)):
		if selected_option.is_empty() and skip_selected:
			for group in choice_groups:
				var skip_reward = group.get("skip_reward", null)
				if skip_reward != null:
					_apply_fixed_reward(skip_reward)
					break
			claim_state["choice_claimed"] = true
			claim_state["selected_option_ids"] = ["skip"]
		elif not selected_option.is_empty():
			_apply_reward_option(selected_option)
			claim_state["choice_claimed"] = true
			claim_state["selected_option_ids"] = [String(selected_option.get("option_id", ""))]
	pending_reward["claim_state"] = claim_state
	if not reward_id.is_empty():
		claimed_reward_ids.append(reward_id)
	pending_reward.clear()

func resolve_shop_node(choice_id: String) -> void:
	sync_warden_base_stats()
	var node := current_node()
	if node.is_empty() or String(node.get("node_type", "")) != NODE_SHOP:
		return
	var option := _find_node_option(node, "shop", choice_id)
	if option.is_empty():
		return
	if not can_afford_effects(option.get("effects", [])):
		return
	var before := _resource_snapshot()
	_apply_option_effects(option.get("effects", []))
	last_resolution = {
		"outcome": "shop_resolved",
		"node_id": String(node.get("node_id", "")),
		"node_type": NODE_SHOP,
		"choice_id": choice_id,
		"choice_title": String(option.get("title", "")),
		"before": before,
		"after": _resource_snapshot(),
	}
	pending_reward.clear()
	mark_current_node_visited()
	phase = Phase.ROUTE

func can_afford_effects(effects: Array) -> bool:
	var projected_embers := embers
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if String(effect.get("reward_type", "")) != "embers":
			continue
		projected_embers += int(effect.get("amount", 0))
		if projected_embers < 0:
			return false
	return true

func _next_route_layer() -> int:
	var max_layer := max_visited_route_layer()
	var best := 0
	for node in route_nodes:
		if bool(node.get("visited", false)):
			continue
		var layer := int(node.get("layer", 0))
		if layer <= max_layer:
			continue
		if best == 0 or layer < best:
			best = layer
	return best

func _route_node_is_reachable(node: Dictionary) -> bool:
	if _uses_commission_board():
		return _commission_node_is_reachable(node)
	var incoming := _incoming_route_edges(String(node.get("node_id", "")))
	if incoming.is_empty():
		return visited_nodes.is_empty()
	for source_id in incoming:
		if source_id in visited_nodes:
			return true
	return false

func _incoming_route_edges(node_id: String) -> Array[String]:
	var result: Array[String] = []
	for node in route_nodes:
		for target_id in node.get("outgoing_edges", []):
			if String(target_id) == node_id:
				result.append(String(node.get("node_id", "")))
	return result

func _uses_commission_board() -> bool:
	return not active_commission_ids.is_empty() or not route_nodes.is_empty()

func _commission_node_is_reachable(node: Dictionary) -> bool:
	var node_id := String(node.get("node_id", ""))
	if node_id.is_empty() or bool(node.get("visited", false)):
		return false
	if String(node.get("node_type", "")) == NODE_BOSS:
		return _boss_commission_should_unlock()
	if visited_nodes.is_empty():
		return int(node.get("layer", 0)) <= 2
	var earliest_unvisited_layer := _earliest_unvisited_non_boss_layer()
	if earliest_unvisited_layer <= 0:
		return false
	return int(node.get("layer", 0)) <= earliest_unvisited_layer + 1

func _earliest_unvisited_non_boss_layer() -> int:
	var best := 0
	for node in route_nodes:
		if bool(node.get("visited", false)) or String(node.get("node_type", "")) == NODE_BOSS:
			continue
		var layer := int(node.get("layer", 0))
		if best == 0 or layer < best:
			best = layer
	return best

func _find_node_option(node: Dictionary, group_key: String, choice_id: String) -> Dictionary:
	var group: Dictionary = node.get(group_key, {})
	for option in group.get("options", []):
		if typeof(option) != TYPE_DICTIONARY:
			continue
		if String(option.get("option_id", "")) == choice_id:
			return option
	return {}

func _update_wardens_from_battle(resolution: Dictionary) -> void:
	var by_id: Dictionary = {}
	for entry in resolution.get("wardens", []):
		by_id[String(entry.get("def_id", ""))] = entry
	for i in range(wardens.size()):
		var w := wardens[i]
		if not bool(w.get("alive", false)):
			continue
		var battle_w = by_id.get(String(w.get("warden_id", "")), null)
		if battle_w == null:
			w["alive"] = false
			w["hp"] = 0
			w["death_node_id"] = current_node_id
		else:
			var hp := int(battle_w.get("hp", int(w.get("hp", 0))))
			w["hp"] = clampi(hp, 0, int(w.get("hp_max", _current_max_hp_for_warden(w))))
			w["alive"] = hp > 0
			if hp <= 0:
				w["death_node_id"] = current_node_id
		wardens[i] = w

func _apply_fixed_reward(reward: Dictionary) -> void:
	var reward_type := String(reward.get("reward_type", ""))
	var amount := int(reward.get("amount", 0))
	match reward_type:
		"embers":
			embers += amount
		"sanctuary_integrity":
			sanctuary_integrity = clampi(sanctuary_integrity + amount, 0, sanctuary_integrity_max)
		"corruption":
			corruption = maxi(0, corruption + amount)
		"warden_hp":
			_apply_warden_hp_reward(reward)
		"relic":
			relics.append(reward.duplicate(true))

func _apply_reward_option(option: Dictionary) -> void:
	match String(option.get("option_type", "")):
		"relic":
			relics.append(option.duplicate(true))
		"upgrade":
			var target_id := String(option.get("target_id", ""))
			for i in range(wardens.size()):
				if String(wardens[i].get("warden_id", "")) == target_id and bool(wardens[i].get("alive", false)):
					var upgrades: Array = wardens[i].get("upgrades", [])
					upgrades.append(option.get("option_id", "upgrade"))
					wardens[i]["upgrades"] = upgrades
					var hp_max_gain := int(option.get("preview_delta", {}).get("warden_hp_max", 1))
					var hp_gain := int(option.get("preview_delta", {}).get("warden_hp", 1))
					var current_max := int(wardens[i].get("hp_max", _current_max_hp_for_warden(wardens[i])))
					wardens[i]["hp_max"] = current_max + hp_max_gain
					wardens[i]["hp"] = mini(int(wardens[i].get("hp_max", current_max)), int(wardens[i].get("hp", 1)) + hp_gain)
					break
		"recovery":
			sanctuary_integrity = mini(sanctuary_integrity_max, sanctuary_integrity + int(option.get("preview_delta", {}).get("sanctuary_integrity", 1)))
			chapter_guardian_reward_used = true
		"chapter_reward":
			relics.append(option.duplicate(true))
		"embers":
			_apply_fixed_reward({
				"reward_type": "embers",
				"amount": int(option.get("preview_delta", {}).get("embers", 0)),
				"reason": String(option.get("title", "奖励")),
			})

func _apply_warden_hp_reward(reward: Dictionary) -> void:
	var amount := int(reward.get("amount", 0))
	var target_id := String(reward.get("target_id", ""))
	for i in range(wardens.size()):
		var w := wardens[i]
		if not bool(w.get("alive", false)):
			continue
		if not target_id.is_empty() and String(w.get("warden_id", "")) != target_id:
			continue
		w["hp"] = clampi(int(w.get("hp", 0)) + amount, 0, int(w.get("hp_max", 0)))
		wardens[i] = w

func _apply_option_effects(effects: Array) -> void:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		_apply_fixed_reward(effect)

func _resource_snapshot() -> Dictionary:
	return {
		"sanctuary_integrity": sanctuary_integrity,
		"sanctuary_integrity_max": sanctuary_integrity_max,
		"embers": embers,
		"corruption": corruption,
		"wardens": wardens.duplicate(true),
	}

func _bonus_embers_for(node_type: String, completed: int) -> int:
	if completed <= 0:
		return 0
	if node_type == NODE_ELITE:
		return [0, 3, 5, 8][clampi(completed, 0, 3)]
	if node_type == NODE_BOSS:
		return [0, 3, 5, 8][clampi(completed, 0, 3)]
	return [0, 2, 4, 6][clampi(completed, 0, 3)]

func _boss_heart_bonus_embers(heart_hits: int) -> int:
	return [0, 2, 4, 6][clampi(heart_hits, 0, 3)]

func _reward_options_for(node_type: String, completed: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if node_type == NODE_BOSS:
		return _relic_options_for_pool(RelicCatalogScript.POOL_BOSS_CHAPTER, 3 + _option_bonus(completed), completed >= 3, true)
	if node_type == NODE_ELITE:
		return _relic_options_for_pool(RelicCatalogScript.POOL_ELITE, 3 + _option_bonus(completed), completed >= 3, false)
	options = _upgrade_options(2 + _option_bonus(completed))
	return options

func _relic_options_for_pool(pool_id: String, display_count: int, prefer_rare: bool, chapter_reward: bool) -> Array[Dictionary]:
	var common: Array[Dictionary] = []
	var rare: Array[Dictionary] = []
	var owned_ids := _owned_relic_ids()
	var alive_ids := _alive_warden_ids()
	for relic in RelicCatalogScript.relics_for_pool(pool_id):
		var relic_id := String(relic.get("relic_id", ""))
		if relic_id in owned_ids:
			continue
		var required_warden := String(relic.get("requires_warden", ""))
		if not required_warden.is_empty() and not (required_warden in alive_ids):
			continue
		if String(relic.get("rarity", "")) == "稀有":
			rare.append(relic)
		else:
			common.append(relic)
	var ordered: Array[Dictionary] = []
	if prefer_rare:
		ordered.append_array(rare)
		ordered.append_array(common)
	else:
		ordered.append_array(common)
		ordered.append_array(rare)
	var result: Array[Dictionary] = []
	for relic in ordered:
		if result.size() >= display_count:
			break
		result.append(RelicCatalogScript.to_reward_option(relic, "chapter_reward" if chapter_reward else "relic"))
	return result

func _upgrade_options(display_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for w in alive_wardens():
		if result.size() >= display_count:
			break
		var warden_id := String(w.get("warden_id", ""))
		if _warden_already_upgraded(w):
			continue
		match warden_id:
			"warden_bountyhunter":
				result.append(_upgrade_option(
					"upgrade_bountyhunter_vanguard",
					warden_id,
					"赏金猎人：前锋整备",
					"最大 HP +1，并立即治疗 1 点。"
				))
			"warden_graverobber":
				result.append(_upgrade_option(
					"upgrade_graverobber_field_pack",
					warden_id,
					"盗墓人：野外整备",
					"最大 HP +1，并立即治疗 1 点。"
				))
			"warden_mage":
				result.append(_upgrade_option(
					"upgrade_mage_arcane_ward",
					warden_id,
					"大魔法师：护火整备",
					"最大 HP +1，并立即治疗 1 点。"
				))
	return result

func _upgrade_option(option_id: String, target_id: String, title: String, description: String) -> Dictionary:
	return {
		"option_id": option_id,
		"option_type": "upgrade",
		"rarity": "普通",
		"target_type": "warden",
		"target_id": target_id,
		"title": title,
		"description": description,
		"preview_delta": {"warden_hp_max": 1, "warden_hp": 1},
		"tags": ["升级", "生存"],
	}

func _option_bonus(completed: int) -> int:
	return 1 if completed >= 2 else 0

func _base_reward_reason(node_type: String) -> String:
	match node_type:
		NODE_ELITE:
			return "精英战基础奖励"
		NODE_BOSS:
			return "Boss 战基础奖励"
	return "普通战基础奖励"

func _choice_group_type(node_type: String) -> String:
	match node_type:
		NODE_ELITE:
			return "relic"
		NODE_BOSS:
			return "chapter_reward"
	return "mixed"

func _should_offer_guardian_recovery(node_type: String, completed: int) -> bool:
	return completed >= 3 and node_type != NODE_BOSS and not chapter_guardian_reward_used and sanctuary_integrity < sanctuary_integrity_max

func _should_convert_guardian_recovery_to_embers(node_type: String, completed: int) -> bool:
	return completed >= 3 and node_type != NODE_BOSS and not chapter_guardian_reward_used and sanctuary_integrity >= sanctuary_integrity_max

func _pending_reward_has_modifier(modifier_id: String) -> bool:
	for modifier in pending_reward.get("modifiers", []):
		if String(modifier.get("modifier_id", "")) == modifier_id:
			return true
	return false

func _owned_relic_ids() -> Array[String]:
	var result: Array[String] = []
	for relic in relics:
		var relic_id := String(relic.get("relic_id", relic.get("option_id", "")))
		if not relic_id.is_empty():
			result.append(relic_id)
	return result

func _alive_warden_ids() -> Array[String]:
	var result: Array[String] = []
	for w in alive_wardens():
		result.append(String(w.get("warden_id", "")))
	return result

func _warden_already_upgraded(warden: Dictionary) -> bool:
	return not warden.get("upgrades", []).is_empty()

func _expedition_display_name(selected_expedition_id: String) -> String:
	match selected_expedition_id:
		EXPEDITION_RIFT_CORRIDOR:
			return "裂隙回廊"
		EXPEDITION_SUPPLY_LINE:
			return "废弃军需线"
	return "断墙外环"

func _build_random_route(seed: int, selected_expedition_id: String = EXPEDITION_BROKEN_WALL) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var layers: Array = []
	var pools := _expedition_route_pools(selected_expedition_id)
	layers.append([_random_route_node_from_demo(String(pools.get("start", "outer_wall_01")), "random_outer_wall_01", 1, 1)])
	layers.append(_random_route_layer(pools.get("early", []), 2, rng))
	layers.append(_random_route_layer(_random_route_pick(pools.get("middle", []), 3, rng), 3, rng))
	var layer_4_sources: Array = pools.get("elite", ["iron_gate_04"])
	layer_4_sources.append_array(_random_route_pick(pools.get("extra_elite", []), 1, rng))
	layers.append(_random_route_layer(layer_4_sources, 4, rng))
	layers.append(_random_route_layer(pools.get("prep", []), 5, rng))
	layers.append([_random_route_node_from_demo("boss_outer_bell_01", "random_boss_outer_bell_01", 6, 1)])
	_connect_random_route_layers(layers, rng)
	var result: Array[Dictionary] = []
	for layer_nodes in layers:
		for node in layer_nodes:
			result.append(node)
	return result

func _expedition_route_pools(selected_expedition_id: String) -> Dictionary:
	match selected_expedition_id:
		EXPEDITION_RIFT_CORRIDOR:
			return {
				"start": "outer_wall_01",
				"early": ["crack_courtyard_03", "extinguished_beacon_02", "quartermaster_cache_02"],
				"middle": ["pillar_graveyard_03", "broken_bridge_edge", "scout_ritual_03", "crack_courtyard_03"],
				"elite": ["iron_gate_04", "broken_bridge_edge"],
				"extra_elite": ["pillar_graveyard_03", "crack_courtyard_03"],
				"prep": ["ember_camp_05", "last_watch_event_05", "quartermaster_cache_05"],
			}
		EXPEDITION_SUPPLY_LINE:
			return {
				"start": "outer_wall_01",
				"early": ["quartermaster_cache_02", "extinguished_beacon_02", "crack_courtyard_03"],
				"middle": ["ember_camp_03", "scout_ritual_03", "pillar_graveyard_03", "quartermaster_cache_02"],
				"elite": ["iron_gate_04"],
				"extra_elite": ["ember_camp_03", "pillar_graveyard_03"],
				"prep": ["quartermaster_cache_05", "ember_camp_05", "last_watch_event_05"],
			}
	return {
		"start": "outer_wall_01",
		"early": ["extinguished_beacon_02", "quartermaster_cache_02", "crack_courtyard_03"],
		"middle": ["pillar_graveyard_03", "ember_camp_03", "scout_ritual_03", "broken_bridge_edge"],
		"elite": ["iron_gate_04"],
		"extra_elite": ["pillar_graveyard_03", "broken_bridge_edge"],
		"prep": ["ember_camp_05", "quartermaster_cache_05", "last_watch_event_05"],
	}

func _random_route_layer(source_ids: Array, layer: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var ordered := source_ids.duplicate()
	_shuffle_array(ordered, rng)
	var nodes: Array[Dictionary] = []
	var lane_count := ordered.size()
	for i in range(ordered.size()):
		var lane := i if lane_count <= 3 else clampi(i, 0, 2)
		var source_id := String(ordered[i])
		var node_id := "random_l%d_%d_%s" % [layer, lane, source_id]
		if source_id == "broken_bridge_edge":
			nodes.append(_random_broken_bridge_node(node_id, layer, lane))
		else:
			nodes.append(_random_route_node_from_demo(source_id, node_id, layer, lane))
	nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("lane", 0)) < int(b.get("lane", 0))
	)
	return nodes

func _random_route_pick(source_ids: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var ordered := source_ids.duplicate()
	_shuffle_array(ordered, rng)
	return ordered.slice(0, mini(count, ordered.size()))

func _shuffle_array(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = values[i]
		values[i] = values[j]
		values[j] = tmp

func _connect_random_route_layers(layers: Array, rng: RandomNumberGenerator) -> void:
	for layer_index in range(layers.size() - 1):
		var current: Array = layers[layer_index]
		var next: Array = layers[layer_index + 1]
		for i in range(current.size()):
			var targets := _random_route_targets(current[i], next, rng)
			current[i]["outgoing_edges"] = targets
		for next_node in next:
			var next_id := String(next_node.get("node_id", ""))
			if _random_route_has_incoming(current, next_id):
				continue
			var source := _nearest_route_node(current, int(next_node.get("lane", 0)))
			var edges: Array = source.get("outgoing_edges", [])
			if not (next_id in edges):
				edges.append(next_id)
				source["outgoing_edges"] = edges

func _random_route_targets(node: Dictionary, next: Array, rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	if next.is_empty():
		return result
	if next.size() == 1:
		result.append(String(next[0].get("node_id", "")))
		return result
	var lane := int(node.get("lane", 0))
	var primary := _nearest_route_node(next, lane)
	result.append(String(primary.get("node_id", "")))
	if rng.randi_range(0, 99) < 60:
		var secondary := _nearest_route_node_except(next, lane, String(primary.get("node_id", "")))
		var secondary_id := String(secondary.get("node_id", ""))
		if not secondary_id.is_empty() and not (secondary_id in result):
			result.append(secondary_id)
	return result

func _nearest_route_node(nodes: Array, lane: int) -> Dictionary:
	var best: Dictionary = nodes[0]
	var best_distance := absi(int(best.get("lane", 0)) - lane)
	for node in nodes:
		var distance := absi(int(node.get("lane", 0)) - lane)
		if distance < best_distance:
			best = node
			best_distance = distance
	return best

func _nearest_route_node_except(nodes: Array, lane: int, excluded_id: String) -> Dictionary:
	var best := {}
	var best_distance := 999
	for node in nodes:
		if String(node.get("node_id", "")) == excluded_id:
			continue
		var distance := absi(int(node.get("lane", 0)) - lane)
		if best.is_empty() or distance < best_distance:
			best = node
			best_distance = distance
	return best

func _random_route_has_incoming(current: Array, node_id: String) -> bool:
	for node in current:
		for target_id in node.get("outgoing_edges", []):
			if String(target_id) == node_id:
				return true
	return false

func _random_route_node_from_demo(source_id: String, node_id: String, layer: int, lane: int) -> Dictionary:
	var source := _demo_route_node_template(source_id)
	var node := source.duplicate(true)
	node["node_id"] = node_id
	node["layer"] = layer
	node["lane"] = lane
	node["outgoing_edges"] = []
	node["visited"] = false
	node["generated"] = true
	return node

func _demo_route_node_template(node_id: String) -> Dictionary:
	for node in _build_demo_route():
		if String(node.get("node_id", "")) == node_id:
			return node
	return {}

func _random_broken_bridge_node(node_id: String, layer: int, lane: int) -> Dictionary:
	var config := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE)
	return {
		"node_id": node_id,
		"title": String(config.get("display_name", "断桥边缘")),
		"node_type": NODE_NORMAL,
		"layer": layer,
		"lane": lane,
		"outgoing_edges": [],
		"risk_level": 3,
		"pressure_tags": config.get("pressure_tags", ["深渊边缘", "裂隙压力"]),
		"rift_strength": int(config.get("rift_strength", 1)),
		"base_embers": 8,
		"visited": false,
		"generated": true,
		"summary": "候补高风险普通战。断桥边缘压缩站位，奖励玩家利用推撞和裂隙节奏。",
		"battle": {
			"config_id": BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE,
			"map_id": String(config.get("map_id", "map_demo_broken_bridge_edge")),
			"variant": "bridge",
			"max_rounds": int(config.get("max_rounds", 5)),
		},
	}

func _build_demo_route() -> Array[Dictionary]:
	return [
		{
			"node_id": "outer_wall_01",
			"title": "断墙前哨",
			"node_type": NODE_NORMAL,
			"layer": 1,
			"lane": 1,
			"outgoing_edges": ["extinguished_beacon_02", "quartermaster_cache_02", "crack_courtyard_03"],
			"risk_level": 1,
			"pressure_tags": ["基础防守", "远程线压"],
			"rift_strength": 0,
			"base_embers": 7,
			"visited": false,
			"summary": "教学式普通战。少量腐食兽和长线压力压迫建筑。",
			"battle": {
				"config_id": BattleConfigCatalogScript.CONFIG_OUTER_WALL,
				"map_id": "map_demo_broken_wall_outpost",
				"variant": "intro",
				"max_rounds": 5,
			},
		},
		{
			"node_id": "extinguished_beacon_02",
			"title": "熄灭的灯塔",
			"node_type": NODE_EVENT,
			"layer": 2,
			"lane": 0,
			"outgoing_edges": ["pillar_graveyard_03", "ember_camp_03"],
			"risk_level": 2,
			"pressure_tags": ["资源取舍"],
			"rift_strength": 0,
			"base_embers": 0,
			"visited": false,
			"summary": "安全事件。用守护值和腐化换取早期资源节奏。",
			"event": {
				"impact_tags": ["余烬", "守护值", "腐化"],
				"options": [
					{
						"option_id": "rekindle_beacon",
						"title": "重燃灯塔",
						"description": "修复防线并带走少量余烬。",
						"effects": [
							{"reward_type": "sanctuary_integrity", "amount": 1, "reason": "灯塔余火"},
							{"reward_type": "embers", "amount": 2, "reason": "残余火星"},
						],
					},
					{
						"option_id": "salvage_lens",
						"title": "拆取透镜",
						"description": "获得大量余烬，但腐化 +1。",
						"effects": [
							{"reward_type": "embers", "amount": 9, "reason": "灯塔透镜"},
							{"reward_type": "corruption", "amount": 1, "reason": "暴露裂隙"},
						],
					},
					{
						"option_id": "leave_unlit",
						"title": "保持沉默",
						"description": "不改变资源，直接继续路线。",
						"effects": [],
					},
				],
			},
		},
		{
			"node_id": "quartermaster_cache_02",
			"title": "前线军需点",
			"node_type": NODE_SHOP,
			"layer": 2,
			"lane": 1,
			"outgoing_edges": ["pillar_graveyard_03", "scout_ritual_03"],
			"risk_level": 1,
			"pressure_tags": ["早期商店", "治疗或遗物"],
			"rift_strength": 0,
			"base_embers": 0,
			"visited": false,
			"summary": "第一战后的早期商店。适合把首战余烬转成生存或遗物。",
			"shop": {
				"options": [
					{
						"option_id": "buy_small_treatment",
						"title": "购买简易急救包",
						"description": "花 3 余烬，所有存活守卫者 HP +1。",
						"effects": [
							{"reward_type": "embers", "amount": -3, "reason": "简易急救包"},
							{"reward_type": "warden_hp", "amount": 1, "reason": "前线治疗"},
						],
					},
					{
						"option_id": "buy_barricade_kit",
						"title": "购买路障材料",
						"description": "花 4 余烬，守护值 +1。",
						"effects": [
							{"reward_type": "embers", "amount": -4, "reason": "路障材料"},
							{"reward_type": "sanctuary_integrity", "amount": 1, "reason": "前线加固"},
						],
					},
					{
						"option_id": "buy_cracked_charm",
						"title": "购买裂纹护符",
						"description": "花 5 余烬，获得 1 个原型遗物。",
						"effects": [
							{"reward_type": "embers", "amount": -5, "reason": "裂纹护符"},
							{"reward_type": "relic", "relic_id": "prototype_cracked_charm", "title": "裂纹护符", "reason": "早期商店遗物"},
						],
					},
				],
			},
		},
		{
			"node_id": "crack_courtyard_03",
			"title": "裂缝庭院",
			"node_type": NODE_NORMAL,
			"layer": 2,
			"lane": 2,
			"outgoing_edges": ["pillar_graveyard_03", "scout_ritual_03"],
			"risk_level": 2,
			"pressure_tags": ["基础防守", "裂隙压力", "远程线压"],
			"rift_strength": 1,
			"base_embers": 7,
			"visited": false,
			"summary": "浅裂隙和弓手锁定长线，奖励玩家主动打断意图。",
			"battle": {
				"config_id": BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
				"map_id": "map_demo_rift_courtyard",
				"variant": "archer",
				"max_rounds": 5,
			},
		},
		{
			"node_id": "pillar_graveyard_03",
			"title": "石柱墓园",
			"node_type": NODE_NORMAL,
			"layer": 3,
			"lane": 0,
			"outgoing_edges": ["iron_gate_04"],
			"risk_level": 3,
			"pressure_tags": ["堵路拥挤", "裂隙压力", "推撞连锁"],
			"rift_strength": 1,
			"base_embers": 8,
			"visited": false,
			"summary": "高收益普通战。石柱密集，考验推撞、挡线和出怪节奏。",
			"battle": {
				"config_id": BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD,
				"map_id": "map_demo_pillar_graveyard",
				"variant": "pillar",
				"max_rounds": 5,
			},
		},
		{
			"node_id": "ember_camp_03",
			"title": "巡火营地",
			"node_type": NODE_CAMP,
			"layer": 3,
			"lane": 1,
			"outgoing_edges": ["iron_gate_04"],
			"risk_level": 1,
			"pressure_tags": ["小幅恢复", "精英前整备"],
			"rift_strength": 0,
			"base_embers": 0,
			"visited": false,
			"summary": "精英前的轻量营地。收益低于 Boss 前营地，但能降低暴毙风险。",
			"camp": {
				"options": [
					{
						"option_id": "patch_wounds",
						"title": "包扎伤口",
						"description": "所有存活守卫者 HP +1，不超过上限。",
						"effects": [
							{"reward_type": "warden_hp", "amount": 1, "reason": "巡火包扎"},
						],
					},
					{
						"option_id": "brace_outer_wall",
						"title": "加固外墙",
						"description": "守护值 +1，不超过上限。",
						"effects": [
							{"reward_type": "sanctuary_integrity", "amount": 1, "reason": "巡火整备"},
						],
					},
				],
			},
		},
		{
			"node_id": "scout_ritual_03",
			"title": "斥候仪式坑",
			"node_type": NODE_EVENT,
			"layer": 3,
			"lane": 2,
			"outgoing_edges": ["iron_gate_04"],
			"risk_level": 2,
			"pressure_tags": ["腐化取舍", "精英前资源"],
			"rift_strength": 0,
			"base_embers": 0,
			"visited": false,
			"summary": "精英前事件。给玩家一次压低腐化或贪余烬的选择。",
			"event": {
				"impact_tags": ["余烬", "守护值", "腐化"],
				"options": [
					{
						"option_id": "seal_small_rift",
						"title": "封住小裂口",
						"description": "腐化 -1，并获得少量余烬。",
						"effects": [
							{"reward_type": "corruption", "amount": -1, "reason": "封印裂口"},
							{"reward_type": "embers", "amount": 2, "reason": "残留火星"},
						],
					},
					{
						"option_id": "take_buried_embers",
						"title": "挖出埋藏余烬",
						"description": "余烬 +6，但腐化 +1。",
						"effects": [
							{"reward_type": "embers", "amount": 6, "reason": "仪式余烬"},
							{"reward_type": "corruption", "amount": 1, "reason": "扰动裂隙"},
						],
					},
					{
						"option_id": "mark_safe_path",
						"title": "标记安全路径",
						"description": "守护值 +1。",
						"effects": [
							{"reward_type": "sanctuary_integrity", "amount": 1, "reason": "斥候标记"},
						],
					},
				],
			},
		},
		{
			"node_id": "iron_gate_04",
			"title": "铁角闸门",
			"node_type": NODE_ELITE,
			"layer": 4,
			"lane": 1,
			"outgoing_edges": ["ember_camp_05", "quartermaster_cache_05", "last_watch_event_05"],
			"risk_level": 3,
			"pressure_tags": ["精英冲撞", "堵路拥挤", "裂隙压力"],
			"rift_strength": 1,
			"base_embers": 11,
			"visited": false,
			"summary": "Demo 精英战。更多敌人和更紧的建筑压力。",
			"battle": {
				"config_id": BattleConfigCatalogScript.CONFIG_IRON_GATE,
				"map_id": "map_demo_ironhorn_gate",
				"variant": "elite",
				"max_rounds": 5,
			},
		},
		{
			"node_id": "ember_camp_05",
			"title": "残火营地",
			"node_type": NODE_CAMP,
			"layer": 5,
			"lane": 0,
			"outgoing_edges": ["boss_outer_bell_01"],
			"risk_level": 1,
			"pressure_tags": ["治疗或修复"],
			"rift_strength": 0,
			"base_embers": 0,
			"visited": false,
			"summary": "Boss 前免费恢复节点。每次营地只能选择 1 项。",
			"camp": {
				"options": [
					{
						"option_id": "heal_squad",
						"title": "治疗小队",
						"description": "所有存活守卫者 HP +1，不超过上限。",
						"effects": [
							{"reward_type": "warden_hp", "amount": 1, "reason": "营地治疗"},
						],
					},
					{
						"option_id": "repair_sanctuary",
						"title": "修复防线",
						"description": "守护值 +2，不超过上限。",
						"effects": [
							{"reward_type": "sanctuary_integrity", "amount": 2, "reason": "残火整备"},
						],
					},
				],
			},
		},
		{
			"node_id": "quartermaster_cache_05",
			"title": "军需仓库",
			"node_type": NODE_SHOP,
			"layer": 5,
			"lane": 1,
			"outgoing_edges": ["boss_outer_bell_01"],
			"risk_level": 1,
			"pressure_tags": ["商店", "治疗或遗物"],
			"rift_strength": 0,
			"base_embers": 0,
			"visited": false,
			"summary": "Boss 前补给节点。可花余烬治疗、修复或购买原型遗物。",
			"shop": {
				"options": [
					{
						"option_id": "buy_field_treatment",
						"title": "购买急救包",
						"description": "花 4 余烬，所有存活守卫者 HP +1。",
						"effects": [
							{"reward_type": "embers", "amount": -4, "reason": "急救包"},
							{"reward_type": "warden_hp", "amount": 1, "reason": "战地治疗"},
						],
					},
					{
						"option_id": "buy_repair_cart",
						"title": "购买修补材料",
						"description": "花 5 余烬，守护值 +1。",
						"effects": [
							{"reward_type": "embers", "amount": -5, "reason": "修补材料"},
							{"reward_type": "sanctuary_integrity", "amount": 1, "reason": "军需修复"},
						],
					},
					{
						"option_id": "buy_smoke_charm",
						"title": "购买烟雾护符",
						"description": "花 6 余烬，获得 1 个原型遗物。",
						"effects": [
							{"reward_type": "embers", "amount": -6, "reason": "烟雾护符"},
							{"reward_type": "relic", "relic_id": "prototype_smoke_charm", "title": "烟雾护符", "reason": "原型商店遗物"},
						],
					},
				],
			},
		},
		{
			"node_id": "last_watch_event_05",
			"title": "最后守夜",
			"node_type": NODE_EVENT,
			"layer": 5,
			"lane": 2,
			"outgoing_edges": ["boss_outer_bell_01"],
			"risk_level": 2,
			"pressure_tags": ["Boss 前取舍", "腐化风险"],
			"rift_strength": 0,
			"base_embers": 0,
			"visited": false,
			"summary": "Boss 前高风险事件。比营地和商店更贪，但会积累腐化。",
			"event": {
				"impact_tags": ["余烬", "守护值", "腐化"],
				"options": [
					{
						"option_id": "raise_last_barricade",
						"title": "立起最后路障",
						"description": "守护值 +1。",
						"effects": [
							{"reward_type": "sanctuary_integrity", "amount": 1, "reason": "最后路障"},
						],
					},
					{
						"option_id": "collect_bell_ash",
						"title": "收集钟灰",
						"description": "余烬 +5，但腐化 +1。",
						"effects": [
							{"reward_type": "embers", "amount": 5, "reason": "钟灰余烬"},
							{"reward_type": "corruption", "amount": 1, "reason": "钟灰污染"},
						],
					},
					{
						"option_id": "steel_the_watch",
						"title": "鼓舞守夜人",
						"description": "所有存活守卫者 HP +1，但腐化 +1。",
						"effects": [
							{"reward_type": "warden_hp", "amount": 1, "reason": "守夜鼓舞"},
							{"reward_type": "corruption", "amount": 1, "reason": "透支意志"},
						],
					},
				],
			},
		},
		{
			"node_id": "boss_outer_bell_01",
			"title": "钟楼外环",
			"node_type": NODE_BOSS,
			"layer": 6,
			"lane": 1,
			"outgoing_edges": [],
			"risk_level": 5,
			"pressure_tags": ["Boss 脚本", "裂隙压力", "远程线压"],
			"rift_strength": 2,
			"base_embers": 14,
			"visited": false,
			"summary": "Demo 终局 Boss。撑到第 6 回合并守住毁灭压力。",
			"battle": {
				"config_id": BattleConfigCatalogScript.CONFIG_OUTER_BELL,
				"map_id": "map_demo_outer_bell_ring",
				"boss_config_id": "knell_lord_demo_01",
				"variant": "boss",
				"max_rounds": 6,
			},
		},
	]
