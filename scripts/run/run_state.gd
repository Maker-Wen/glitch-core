class_name RunState extends RefCounted
## Mutable state for a commission-deck roguelite run.

const RelicCatalogScript := preload("res://scripts/data/relic_catalog.gd")
const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const RunExpeditionCatalogScript := preload("res://scripts/data/run_expedition_catalog.gd")
const WardenSkillCatalogScript := preload("res://scripts/battle/warden_skill_catalog.gd")
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
const MAP_POOL_START := "start"
const MAP_POOL_NORMAL := "normal"
const MAP_POOL_ELITE := "elite"
const MAP_POOL_BOSS := "boss"
const DEFAULT_SANCTUARY_INTEGRITY := 12
const COMMISSION_BOARD_SIZE := 3
const COMMISSION_BOSS_UNLOCK_COUNT := 8
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
## Internal commission deck nodes for the current expedition map.
## Kept as route_nodes for save/test compatibility; this is not a player-facing node graph.
var route_nodes: Array[Dictionary] = []
var commission_deck_ids: Array[String] = []
var commission_draw_pile_ids: Array[String] = []
var discarded_commission_ids: Array[String] = []
var active_commission_ids: Array[String] = []
var commission_hand_size: int = COMMISSION_BOARD_SIZE
var boss_unlock_count: int = COMMISSION_BOSS_UNLOCK_COUNT
var refresh_charges: int = 0
var refresh_charges_max: int = 0
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
	route_nodes = _build_commission_deck(run_seed, expedition_id)
	_initialize_commission_deck_state()

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
	route_nodes = _build_commission_deck(run_seed, expedition_id)
	_initialize_commission_deck_state()

func current_commission() -> Dictionary:
	var available := available_commissions()
	if not available.is_empty():
		return available[0]
	return {}

func next_unvisited_node() -> Dictionary:
	return current_commission()

func available_commissions() -> Array[Dictionary]:
	_refill_commission_board()
	var result: Array[Dictionary] = []
	for node_id in active_commission_ids:
		var node := node_by_id(node_id)
		if node.is_empty() or bool(node.get("visited", false)):
			continue
		result.append(node)
	return result

func available_route_nodes() -> Array[Dictionary]:
	return available_commissions()

func is_commission_available(node_id: String) -> bool:
	for node in available_commissions():
		if String(node.get("node_id", "")) == node_id:
			return true
	return false

func is_route_node_available(node_id: String) -> bool:
	return is_commission_available(node_id)

func node_by_id(node_id: String) -> Dictionary:
	for node in route_nodes:
		if String(node.get("node_id", "")) == node_id:
			return node
	return {}

func current_node() -> Dictionary:
	if current_node_id.is_empty():
		return current_commission()
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
	return not route_nodes.is_empty() and available_commissions().is_empty()

func is_battle_node(node: Dictionary) -> bool:
	var node_type := String(node.get("node_type", ""))
	return node_type == NODE_NORMAL or node_type == NODE_ELITE or node_type == NODE_BOSS

func max_visited_route_layer() -> int:
	var max_layer := 0
	for node in route_nodes:
		if bool(node.get("visited", false)):
			max_layer = maxi(max_layer, int(node.get("layer", 0)))
	return max_layer

func _initialize_commission_deck_state() -> void:
	var deck_config := _commission_deck_config()
	commission_hand_size = maxi(1, int(deck_config.get("hand_size", COMMISSION_BOARD_SIZE)))
	boss_unlock_count = maxi(1, int(deck_config.get("boss_unlock_count", COMMISSION_BOSS_UNLOCK_COUNT)))
	refresh_charges_max = maxi(0, int(deck_config.get("initial_refresh_charges", 0)))
	refresh_charges = refresh_charges_max
	commission_deck_ids.clear()
	commission_draw_pile_ids.clear()
	discarded_commission_ids.clear()
	active_commission_ids.clear()
	for node in route_nodes:
		var node_id := String(node.get("node_id", ""))
		if node_id.is_empty() or String(node.get("node_type", "")) == NODE_BOSS:
			continue
		commission_deck_ids.append(node_id)
		commission_draw_pile_ids.append(node_id)
	_refill_commission_board()

func _refill_commission_board() -> void:
	_trim_active_commission_ids()
	var boss := _boss_node()
	if not boss.is_empty() and bool(boss.get("visited", false)):
		active_commission_ids.clear()
		return
	if _boss_commission_should_unlock():
		active_commission_ids.clear()
		if not boss.is_empty():
			active_commission_ids.append(String(boss.get("node_id", "")))
		return
	while active_commission_ids.size() < commission_hand_size:
		var next_id := _draw_next_commission_id()
		if next_id.is_empty():
			return
		active_commission_ids.append(next_id)

func _trim_active_commission_ids() -> void:
	var trimmed: Array[String] = []
	for node_id in active_commission_ids:
		var node := node_by_id(node_id)
		if node.is_empty() or bool(node.get("visited", false)):
			continue
		if not (node_id in trimmed):
			trimmed.append(node_id)
	active_commission_ids = trimmed

func _draw_next_commission_id() -> String:
	while not commission_draw_pile_ids.is_empty():
		var node_id := String(commission_draw_pile_ids.pop_front())
		var node := node_by_id(node_id)
		if node.is_empty() or bool(node.get("visited", false)):
			continue
		if node_id in active_commission_ids:
			continue
		if String(node.get("node_type", "")) == NODE_BOSS:
			continue
		return node_id
	return ""

func can_refresh_commission(slot_index: int) -> bool:
	_trim_active_commission_ids()
	if refresh_charges <= 0 or _boss_commission_should_unlock():
		return false
	if slot_index < 0 or slot_index >= active_commission_ids.size():
		return false
	var node := node_by_id(active_commission_ids[slot_index])
	if node.is_empty() or String(node.get("node_type", "")) == NODE_BOSS:
		return false
	return _next_drawable_commission_index() >= 0

func refresh_commission(slot_index: int) -> bool:
	if not can_refresh_commission(slot_index):
		return false
	var old_id := active_commission_ids[slot_index]
	var next_index := _next_drawable_commission_index()
	if next_index < 0:
		return false
	var replacement_id := String(commission_draw_pile_ids[next_index])
	commission_draw_pile_ids.remove_at(next_index)
	active_commission_ids[slot_index] = replacement_id
	if not (old_id in discarded_commission_ids):
		discarded_commission_ids.append(old_id)
	refresh_charges -= 1
	return true

func _next_drawable_commission_index() -> int:
	for i in range(commission_draw_pile_ids.size()):
		var node_id := String(commission_draw_pile_ids[i])
		var node := node_by_id(node_id)
		if node.is_empty() or bool(node.get("visited", false)):
			continue
		if node_id in active_commission_ids:
			continue
		if String(node.get("node_type", "")) == NODE_BOSS:
			continue
		return i
	return -1

func _boss_commission_should_unlock() -> bool:
	var boss := _boss_node()
	if boss.is_empty() or bool(boss.get("visited", false)):
		return false
	return _completed_non_boss_count() >= boss_unlock_count

func completed_commission_count() -> int:
	return _completed_non_boss_count()

func commission_goal_count() -> int:
	return boss_unlock_count

func remaining_commission_deck_count() -> int:
	var count := 0
	for node_id in commission_draw_pile_ids:
		var node := node_by_id(String(node_id))
		if not node.is_empty() and not bool(node.get("visited", false)):
			count += 1
	return count

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
	var boss_heart_hits := int(resolution.get("boss_heart_hits", 0)) if node_type == NODE_BOSS else 0
	var boss_heart_bonus := _boss_heart_bonus_embers(boss_heart_hits)
	if boss_heart_bonus > 0:
		reward.fixed_rewards.append({"reward_type": "embers", "amount": boss_heart_bonus, "reason": "心脏钟命中 %d 次" % clampi(boss_heart_hits, 0, 3), "visible_order": 25})
		reward.modifiers.append({"modifier_id": "boss_heart_bell_bonus", "description": "Boss 心脏钟命中：额外 +%d 余烬。" % boss_heart_bonus})
	if _should_offer_guardian_recovery(node_type, completed):
		reward.fixed_rewards.append({"reward_type": "sanctuary_integrity", "amount": 1, "reason": "本次地图首次完美守住防线", "visible_order": 30})
		reward.modifiers.append({"modifier_id": "guardian_recovery_fixed", "description": "完成 3 个奖励任务：守护值恢复 +1。"})
	elif _should_convert_guardian_recovery_to_embers(node_type, completed):
		reward.fixed_rewards.append({"reward_type": "embers", "amount": 3, "reason": "守护值已满，恢复机会转化", "visible_order": 30})
		reward.modifiers.append({"modifier_id": "guardian_recovery_converted", "description": "完成 3 个奖励任务，但守护值已满：改为 +3 余烬。"})
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
		if _pending_reward_has_modifier("guardian_recovery_converted") or _pending_reward_has_modifier("guardian_recovery_fixed"):
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

func _commission_node_is_reachable(node: Dictionary) -> bool:
	var node_id := String(node.get("node_id", ""))
	if node_id.is_empty() or bool(node.get("visited", false)):
		return false
	if String(node.get("node_type", "")) == NODE_BOSS:
		return _boss_commission_should_unlock()
	if visited_nodes.is_empty():
		return int(node.get("layer", 0)) <= 2
	var layer_limit := _commission_refill_layer_limit()
	return layer_limit > 0 and int(node.get("layer", 0)) <= layer_limit

func _commission_refill_layer_limit() -> int:
	if visited_nodes.is_empty():
		return 2
	var limit := 0
	for node_id in active_commission_ids:
		var node := node_by_id(node_id)
		if node.is_empty() or bool(node.get("visited", false)):
			continue
		if String(node.get("node_type", "")) == NODE_BOSS:
			continue
		limit = maxi(limit, int(node.get("layer", 0)) + 1)
	if limit > 0:
		return limit
	var earliest_unvisited_layer := _earliest_unvisited_non_boss_layer()
	return earliest_unvisited_layer + 1 if earliest_unvisited_layer > 0 else 0

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
					var option_id := String(option.get("option_id", "upgrade"))
					if not (option_id in upgrades):
						upgrades.append(option_id)
					wardens[i]["upgrades"] = upgrades
					var preview_delta: Dictionary = option.get("preview_delta", {})
					var hp_max_gain := int(preview_delta.get("warden_hp_max", 0))
					var hp_gain := int(preview_delta.get("warden_hp", 0))
					if hp_max_gain > 0 or hp_gain > 0:
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
		var skill_options := WardenSkillCatalogScript.upgrade_options_for_warden(warden_id, w.get("upgrades", []))
		if not skill_options.is_empty():
			result.append(skill_options[0])
			continue
		if _warden_has_hp_upgrade(w):
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

func _warden_has_hp_upgrade(warden: Dictionary) -> bool:
	for upgrade_id in warden.get("upgrades", []):
		if WARDEN_HP_UPGRADE_IDS.has(String(upgrade_id)):
			return true
	return false

func _expedition_display_name(selected_expedition_id: String) -> String:
	return RunExpeditionCatalogScript.display_name(selected_expedition_id)

func _build_random_route(seed: int, selected_expedition_id: String = EXPEDITION_BROKEN_WALL) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var layers: Array = []
	var expedition_config := RunExpeditionCatalogScript.get_config(selected_expedition_id)
	var pools: Dictionary = expedition_config.get("node_pools", {})
	layers.append([_random_route_node_from_demo(String(pools.get("start", "outer_wall_01")), "random_outer_wall_01", 1, 1)])
	layers.append(_random_route_layer(pools.get("early", []), 2, rng))
	layers.append(_random_route_layer(_random_route_pick(pools.get("middle", []), 3, rng), 3, rng))
	var layer_4_sources: Array = pools.get("elite", ["iron_gate_04"])
	layer_4_sources.append_array(_random_route_pick(pools.get("extra_elite", []), 1, rng))
	layers.append(_random_route_layer(layer_4_sources, 4, rng))
	layers.append(_random_route_layer(pools.get("prep", []), 5, rng))
	layers.append([_random_route_node_from_demo("boss_outer_bell_01", "random_boss_outer_bell_01", 6, 1)])
	_connect_random_route_layers(layers, rng)
	_assign_random_route_battle_maps(layers, expedition_config, rng)
	var result: Array[Dictionary] = []
	for layer_nodes in layers:
		for node in layer_nodes:
			result.append(node)
	return result

func expedition_map_pool_config_ids(selected_expedition_id: String, pool_key: String) -> Array[String]:
	return RunExpeditionCatalogScript.map_pool_config_ids(selected_expedition_id, pool_key)

func battle_map_assignment_debug_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in route_nodes:
		if not is_battle_node(node):
			continue
		var battle: Dictionary = node.get("battle", {})
		result.append({
			"run_seed": run_seed,
			"expedition_id": expedition_id,
			"expedition_name": expedition_name,
			"node_id": String(node.get("node_id", "")),
			"layer": int(node.get("layer", 0)),
			"lane": int(node.get("lane", 0)),
			"node_type": String(node.get("node_type", "")),
			"pool_key": String(battle.get("map_pool_key", "")),
			"config_id": String(battle.get("config_id", "")),
			"map_id": String(battle.get("map_id", "")),
			"archetype": String(battle.get("map_archetype", "")),
			"variant": String(battle.get("variant", "")),
			"pressure_cost": int(battle.get("map_pressure_cost", 0)),
			"repeat_group": String(battle.get("map_no_repeat_group", "")),
			"enemy_family_hint": String(battle.get("map_enemy_family_hint", "")),
			"assignment_relaxed": String(battle.get("map_assignment_relaxed", "")),
		})
	return result

func battle_map_assignment_debug_text() -> String:
	var rows := battle_map_assignment_debug_rows()
	var lines: Array[String] = [
		"seed=%d expedition=%s rows=%d" % [run_seed, expedition_id, rows.size()],
	]
	for row in rows:
		var relaxed := String(row.get("assignment_relaxed", ""))
		if relaxed.is_empty():
			relaxed = "strict"
		lines.append("L%d/%s %s pool=%s config=%s archetype=%s pressure=%d repeat=%s relaxed=%s" % [
			int(row.get("layer", 0)),
			String(row.get("node_type", "")),
			String(row.get("node_id", "")),
			String(row.get("pool_key", "")),
			String(row.get("config_id", "")),
			String(row.get("archetype", "")),
			int(row.get("pressure_cost", 0)),
			String(row.get("repeat_group", "")),
			relaxed,
		])
	return "\n".join(lines)

func _expedition_route_pools(selected_expedition_id: String) -> Dictionary:
	return RunExpeditionCatalogScript.route_pools(selected_expedition_id)

func _commission_deck_config() -> Dictionary:
	return RunExpeditionCatalogScript.commission_deck_config(expedition_id)

func _build_commission_deck(seed: int, selected_expedition_id: String = EXPEDITION_BROKEN_WALL) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var expedition_config := RunExpeditionCatalogScript.get_config(selected_expedition_id)
	var deck_config: Dictionary = expedition_config.get("commission_deck", {})
	var deck_size := maxi(COMMISSION_BOARD_SIZE, int(deck_config.get("deck_size", 16)))
	var max_consecutive_non_combat := maxi(1, int(deck_config.get("max_consecutive_non_combat", 2)))
	var type_counts: Dictionary = deck_config.get("type_counts", {}).duplicate(true)
	_normalize_commission_type_counts(type_counts, deck_size)
	var type_sequence := _generate_commission_type_sequence(type_counts, deck_size, rng, max_consecutive_non_combat)
	var pools: Dictionary = expedition_config.get("node_pools", {})
	var result: Array[Dictionary] = []
	var used_source_counts := {}
	for i in range(type_sequence.size()):
		var node_type := String(type_sequence[i])
		var source_id := _pick_commission_source_id_for_type(node_type, i, pools, rng)
		var layer := _commission_layer_for_type(node_type, i, type_sequence.size())
		var lane := i % COMMISSION_BOARD_SIZE
		var source_use_count := int(used_source_counts.get(source_id, 0))
		used_source_counts[source_id] = source_use_count + 1
		var node_id := source_id if source_use_count == 0 else _commission_generated_node_id(i, source_id, node_type)
		var node := _commission_node_from_source(source_id, node_id, layer, lane)
		if node.is_empty():
			continue
		node["deck_index"] = i
		node["depth_band"] = _commission_depth_band(i, type_sequence.size())
		result.append(node)
	var boss := _commission_node_from_source("boss_outer_bell_01", "boss_outer_bell_01", 6, 1)
	if not boss.is_empty():
		boss["deck_index"] = result.size()
		boss["depth_band"] = "boss"
		result.append(boss)
	_assign_commission_deck_battle_maps(result, expedition_config, rng)
	return result

func _normalize_commission_type_counts(type_counts: Dictionary, deck_size: int) -> void:
	for node_type in [NODE_NORMAL, NODE_ELITE, NODE_EVENT, NODE_CAMP, NODE_SHOP]:
		type_counts[node_type] = maxi(0, int(type_counts.get(node_type, 0)))
	var total := 0
	for node_type in type_counts.keys():
		total += maxi(0, int(type_counts.get(node_type, 0)))
	if total < deck_size:
		type_counts[NODE_NORMAL] = int(type_counts.get(NODE_NORMAL, 0)) + deck_size - total
	elif total > deck_size:
		var overflow := total - deck_size
		for node_type in [NODE_SHOP, NODE_CAMP, NODE_EVENT, NODE_ELITE, NODE_NORMAL]:
			if overflow <= 0:
				break
			var current := int(type_counts.get(node_type, 0))
			var removed := mini(current, overflow)
			type_counts[node_type] = current - removed
			overflow -= removed
	if int(type_counts.get(NODE_NORMAL, 0)) <= 0:
		type_counts[NODE_NORMAL] = 1

func _generate_commission_type_sequence(type_counts: Dictionary, deck_size: int, rng: RandomNumberGenerator, max_consecutive_non_combat: int = 2) -> Array[String]:
	var remaining := type_counts.duplicate(true)
	var sequence: Array[String] = []
	for opening_type in [NODE_NORMAL, NODE_EVENT, NODE_SHOP]:
		if sequence.size() >= mini(COMMISSION_BOARD_SIZE, deck_size):
			break
		if int(remaining.get(opening_type, 0)) <= 0:
			continue
		sequence.append(opening_type)
		remaining[opening_type] = int(remaining.get(opening_type, 0)) - 1
	while sequence.size() < deck_size:
		var candidates := _commission_type_candidates_for_position(remaining, sequence, deck_size, max_consecutive_non_combat)
		if candidates.is_empty():
			break
		var node_type := _weighted_type_pick(candidates, remaining, rng)
		sequence.append(node_type)
		remaining[node_type] = int(remaining.get(node_type, 0)) - 1
	return sequence

func _commission_type_candidates_for_position(remaining: Dictionary, sequence: Array[String], deck_size: int, max_consecutive_non_combat: int = 2) -> Array[String]:
	var result: Array[String] = []
	var force_combat := sequence.size() >= 2 \
		and not _commission_type_is_combat(sequence[sequence.size() - 1]) \
		and not _commission_type_is_combat(sequence[sequence.size() - 2])
	var late_start := deck_size / 2
	for node_type in [NODE_NORMAL, NODE_ELITE, NODE_EVENT, NODE_CAMP, NODE_SHOP]:
		if int(remaining.get(node_type, 0)) <= 0:
			continue
		if force_combat and not _commission_type_is_combat(node_type):
			continue
		if node_type == NODE_ELITE and sequence.size() < 5 and _remaining_non_elite_count(remaining) > 0:
			continue
		if (node_type == NODE_CAMP or node_type == NODE_SHOP) and sequence.size() < 2 and _remaining_alternative_count(remaining, node_type) > 0:
			continue
		if node_type == NODE_CAMP and sequence.size() < late_start and _remaining_alternative_count(remaining, node_type) > 0:
			continue
		if not sequence.is_empty() and node_type == sequence[sequence.size() - 1] and not _commission_type_is_combat(node_type) and _remaining_alternative_count(remaining, node_type) > 0:
			continue
		result.append(node_type)
	var feasible := _feasible_commission_type_candidates(result, remaining, sequence, max_consecutive_non_combat)
	if not feasible.is_empty():
		return feasible
	if result.is_empty():
		for node_type in [NODE_NORMAL, NODE_ELITE, NODE_EVENT, NODE_CAMP, NODE_SHOP]:
			if int(remaining.get(node_type, 0)) > 0:
				result.append(node_type)
		feasible = _feasible_commission_type_candidates(result, remaining, sequence, max_consecutive_non_combat)
		if not feasible.is_empty():
			return feasible
	return result

func _feasible_commission_type_candidates(candidates: Array[String], remaining: Dictionary, sequence: Array[String], max_consecutive_non_combat: int) -> Array[String]:
	var result: Array[String] = []
	for node_type in candidates:
		var after := remaining.duplicate(true)
		after[node_type] = int(after.get(node_type, 0)) - 1
		var suffix := _non_combat_suffix_after_pick(sequence, node_type)
		if _commission_type_sequence_can_complete(after, suffix, max_consecutive_non_combat):
			result.append(node_type)
	return result

func _non_combat_suffix_after_pick(sequence: Array[String], node_type: String) -> int:
	if _commission_type_is_combat(node_type):
		return 0
	var suffix := 1
	for i in range(sequence.size() - 1, -1, -1):
		if _commission_type_is_combat(String(sequence[i])):
			break
		suffix += 1
	return suffix

func _commission_type_sequence_can_complete(remaining: Dictionary, current_non_combat_suffix: int, max_consecutive_non_combat: int) -> bool:
	var combat_remaining := 0
	var non_combat_remaining := 0
	for node_type in [NODE_NORMAL, NODE_ELITE, NODE_EVENT, NODE_CAMP, NODE_SHOP]:
		if _commission_type_is_combat(node_type):
			combat_remaining += maxi(0, int(remaining.get(node_type, 0)))
		else:
			non_combat_remaining += maxi(0, int(remaining.get(node_type, 0)))
	var initial_capacity := maxi(0, max_consecutive_non_combat - current_non_combat_suffix)
	var separated_capacity := combat_remaining * max_consecutive_non_combat
	return non_combat_remaining <= initial_capacity + separated_capacity

func _weighted_type_pick(candidates: Array[String], remaining: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for node_type in candidates:
		total += maxi(1, int(remaining.get(node_type, 0)))
	var roll := rng.randi_range(1, total)
	var cursor := 0
	for node_type in candidates:
		cursor += maxi(1, int(remaining.get(node_type, 0)))
		if roll <= cursor:
			return node_type
	return candidates[0]

func _remaining_non_elite_count(remaining: Dictionary) -> int:
	var total := 0
	for node_type in [NODE_NORMAL, NODE_EVENT, NODE_CAMP, NODE_SHOP]:
		total += maxi(0, int(remaining.get(node_type, 0)))
	return total

func _remaining_alternative_count(remaining: Dictionary, excluded_type: String) -> int:
	var total := 0
	for node_type in [NODE_NORMAL, NODE_ELITE, NODE_EVENT, NODE_CAMP, NODE_SHOP]:
		if node_type == excluded_type:
			continue
		total += maxi(0, int(remaining.get(node_type, 0)))
	return total

func _commission_type_is_combat(node_type: String) -> bool:
	return node_type == NODE_NORMAL or node_type == NODE_ELITE

func _pick_commission_source_id_for_type(node_type: String, deck_index: int, pools: Dictionary, rng: RandomNumberGenerator) -> String:
	if deck_index == 0 and node_type == NODE_NORMAL:
		var start_ids := _pool_source_ids(pools.get("start", []))
		if not start_ids.is_empty():
			return start_ids[0]
	if deck_index == 1 and node_type == NODE_EVENT:
		for source_id in _pool_source_ids(pools.get("early", [])):
			if _source_node_type(source_id) == NODE_EVENT:
				return source_id
	if deck_index == 2 and node_type == NODE_SHOP:
		for source_id in _pool_source_ids(pools.get("early", [])):
			if _source_node_type(source_id) == NODE_SHOP:
				return source_id
	if deck_index == 3 and node_type == NODE_NORMAL:
		for source_id in _pool_source_ids(pools.get("early", [])):
			if _source_node_type(source_id) == NODE_NORMAL:
				return source_id
	var source_ids := _commission_source_ids_for_type(node_type, deck_index, pools)
	if source_ids.is_empty():
		source_ids = _all_commission_source_ids_for_type(node_type, pools)
	if source_ids.is_empty():
		return _fallback_source_id_for_type(node_type)
	return String(source_ids[rng.randi_range(0, source_ids.size() - 1)])

func _commission_source_ids_for_type(node_type: String, deck_index: int, pools: Dictionary) -> Array[String]:
	var band_keys: Array[String] = []
	if deck_index <= 2:
		band_keys = ["start", "early", "middle"]
	elif deck_index <= 8:
		band_keys = ["middle", "early", "elite", "extra_elite", "prep"]
	else:
		band_keys = ["prep", "middle", "elite", "extra_elite", "early"]
	var result: Array[String] = []
	for key in band_keys:
		for source_id in _pool_source_ids(pools.get(key, [])):
			if _source_node_type(source_id) == node_type and not (source_id in result):
				result.append(source_id)
	return result

func _all_commission_source_ids_for_type(node_type: String, pools: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in ["start", "early", "middle", "elite", "extra_elite", "prep"]:
		for source_id in _pool_source_ids(pools.get(key, [])):
			if _source_node_type(source_id) == node_type and not (source_id in result):
				result.append(source_id)
	return result

func _pool_source_ids(raw_pool) -> Array[String]:
	var result: Array[String] = []
	if typeof(raw_pool) == TYPE_STRING:
		result.append(String(raw_pool))
	elif typeof(raw_pool) == TYPE_ARRAY:
		for source_id in raw_pool:
			result.append(String(source_id))
	return result

func _source_node_type(source_id: String) -> String:
	if source_id == "broken_bridge_edge":
		return NODE_NORMAL
	var source := _demo_route_node_template(source_id)
	return String(source.get("node_type", ""))

func _fallback_source_id_for_type(node_type: String) -> String:
	match node_type:
		NODE_ELITE:
			return "iron_gate_04"
		NODE_EVENT:
			return "scout_ritual_03"
		NODE_CAMP:
			return "ember_camp_05"
		NODE_SHOP:
			return "quartermaster_cache_05"
	return "crack_courtyard_03"

func _commission_layer_for_type(node_type: String, deck_index: int, deck_size: int) -> int:
	if deck_index == 0 and node_type == NODE_NORMAL:
		return 1
	match node_type:
		NODE_ELITE:
			return 4
		NODE_CAMP:
			return 5 if deck_index >= deck_size / 2 else 3
		NODE_SHOP:
			return 5 if deck_index >= deck_size / 2 else 2
		NODE_EVENT:
			return 5 if deck_index >= deck_size - 4 else 3
	if deck_index < deck_size / 3:
		return 2
	if deck_index < deck_size * 2 / 3:
		return 3
	return 4

func _commission_depth_band(deck_index: int, deck_size: int) -> String:
	if deck_index < deck_size / 3:
		return "early"
	if deck_index < deck_size * 2 / 3:
		return "mid"
	return "late"

func _commission_generated_node_id(deck_index: int, source_id: String, node_type: String) -> String:
	return "deck_%02d_%s_%s" % [deck_index + 1, node_type, source_id.replace("-", "_")]

func _commission_node_from_source(source_id: String, node_id: String, layer: int, lane: int) -> Dictionary:
	if source_id == "broken_bridge_edge":
		return _random_broken_bridge_node(node_id, layer, lane)
	return _random_route_node_from_demo(source_id, node_id, layer, lane)

func _assign_commission_deck_battle_maps(nodes: Array[Dictionary], expedition_config: Dictionary, rng: RandomNumberGenerator) -> void:
	var layers: Array = []
	var by_layer := {}
	for node in nodes:
		var layer := int(node.get("layer", 0))
		if not by_layer.has(layer):
			by_layer[layer] = []
		by_layer[layer].append(node)
	var keys := by_layer.keys()
	keys.sort()
	for layer in keys:
		layers.append(by_layer[layer])
	_assign_random_route_battle_maps(layers, expedition_config, rng)

func _assign_random_route_battle_maps(layers: Array, expedition_config: Dictionary, rng: RandomNumberGenerator) -> void:
	var map_pool: Dictionary = expedition_config.get("map_pool", {})
	if map_pool.is_empty():
		return
	var used_repeat_groups_by_pool := {}
	for layer_nodes in layers:
		for node in layer_nodes:
			if not is_battle_node(node):
				continue
			var pool_key := _map_pool_key_for_node(node)
			var candidates: Array = map_pool.get(pool_key, [])
			if candidates.is_empty() and pool_key != MAP_POOL_NORMAL:
				candidates = map_pool.get(MAP_POOL_NORMAL, [])
			if candidates.is_empty():
				continue
			if not used_repeat_groups_by_pool.has(pool_key):
				used_repeat_groups_by_pool[pool_key] = {}
			var used_repeat_groups: Dictionary = used_repeat_groups_by_pool.get(pool_key, {})
			var pick := _pick_map_pool_entry_for_node(candidates, node, pool_key, expedition_config, used_repeat_groups, rng)
			if pick.is_empty():
				continue
			_apply_battle_map_entry(node, pick, pool_key)
			var repeat_group := String(pick.get("no_repeat_group", ""))
			if not repeat_group.is_empty():
				used_repeat_groups[repeat_group] = true

func _pick_map_pool_entry_for_node(candidates: Array, node: Dictionary, pool_key: String, expedition_config: Dictionary, used_repeat_groups: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var filtered := _filtered_map_pool_candidates(candidates, node, pool_key, expedition_config, used_repeat_groups, false, false)
	if not filtered.is_empty():
		var result := _weighted_map_pool_pick(filtered, rng)
		result["map_assignment_relaxed"] = ""
		return result
	var repeat_reset_filtered := _filtered_map_pool_candidates(candidates, node, pool_key, expedition_config, {}, false, false)
	if not repeat_reset_filtered.is_empty():
		used_repeat_groups.clear()
		var result := _weighted_map_pool_pick(repeat_reset_filtered, rng)
		result["map_assignment_relaxed"] = ""
		return result
	filtered = _filtered_map_pool_candidates(candidates, node, pool_key, expedition_config, used_repeat_groups, true, false)
	if not filtered.is_empty():
		var result := _weighted_map_pool_pick(filtered, rng)
		result["map_assignment_relaxed"] = "repeat"
		return result
	filtered = _filtered_map_pool_candidates(candidates, node, pool_key, expedition_config, used_repeat_groups, true, true)
	if not filtered.is_empty():
		var result := _weighted_map_pool_pick(filtered, rng)
		result["map_assignment_relaxed"] = "pressure"
		return result
	if candidates.is_empty():
		return {}
	var result := _weighted_map_pool_pick(candidates, rng)
	result["map_assignment_relaxed"] = "unfiltered"
	return result

func _filtered_map_pool_candidates(candidates: Array, node: Dictionary, pool_key: String, expedition_config: Dictionary, used_repeat_groups: Dictionary, relax_repeat: bool, relax_pressure: bool) -> Array:
	var result: Array = []
	for entry in candidates:
		var candidate: Dictionary = entry
		if not _map_entry_matches_node(candidate, node):
			continue
		if not relax_pressure and not _map_entry_within_pressure_budget(candidate, pool_key, expedition_config):
			continue
		var repeat_group := String(candidate.get("no_repeat_group", ""))
		if not relax_repeat and not repeat_group.is_empty() and used_repeat_groups.has(repeat_group):
			continue
		result.append(candidate)
	return result

func _map_entry_matches_node(entry: Dictionary, node: Dictionary) -> bool:
	var config_id := String(entry.get("config_id", ""))
	if BattleConfigCatalogScript.get_config(config_id).is_empty():
		return false
	var node_type := String(node.get("node_type", ""))
	var allowed_node_types: Array = entry.get("allowed_node_types", [])
	if not allowed_node_types.is_empty() and not (node_type in allowed_node_types):
		return false
	var layer := int(node.get("layer", 0))
	var min_layer := int(entry.get("min_layer", 1))
	var max_layer := int(entry.get("max_layer", 99))
	return layer >= min_layer and layer <= max_layer

func _map_entry_within_pressure_budget(entry: Dictionary, pool_key: String, expedition_config: Dictionary) -> bool:
	var budget: Dictionary = expedition_config.get("pressure_budget", {})
	var max_pressure := int(budget.get(pool_key, 0))
	if max_pressure <= 0:
		return true
	return int(entry.get("pressure_cost", 0)) <= max_pressure

func _map_pool_key_for_node(node: Dictionary) -> String:
	var node_type := String(node.get("node_type", ""))
	match node_type:
		NODE_BOSS:
			return MAP_POOL_BOSS
		NODE_ELITE:
			return MAP_POOL_ELITE
	if int(node.get("layer", 0)) <= 1:
		return MAP_POOL_START
	return MAP_POOL_NORMAL

func _weighted_map_pool_pick(candidates: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total_weight := 0
	for entry in candidates:
		total_weight += maxi(1, int(entry.get("weight", 1)))
	if total_weight <= 0:
		return candidates[0].duplicate(true)
	var roll := rng.randi_range(1, total_weight)
	var cursor := 0
	for entry in candidates:
		cursor += maxi(1, int(entry.get("weight", 1)))
		if roll <= cursor:
			return entry.duplicate(true)
	return candidates[0].duplicate(true)

func _apply_battle_map_entry(node: Dictionary, map_entry: Dictionary, pool_key: String) -> void:
	var config_id := String(map_entry.get("config_id", ""))
	var config := BattleConfigCatalogScript.get_config(config_id)
	if config.is_empty():
		return
	node["title"] = String(config.get("display_name", node.get("title", "")))
	node["pressure_tags"] = map_entry.get("pressure_tags", config.get("pressure_tags", [])).duplicate()
	node["rift_strength"] = int(config.get("rift_strength", node.get("rift_strength", 0)))
	node["risk_level"] = int(map_entry.get("risk_level", node.get("risk_level", 1)))
	node["base_embers"] = int(map_entry.get("base_embers", node.get("base_embers", 7)))
	node["summary"] = String(map_entry.get("summary", node.get("summary", "")))
	var battle: Dictionary = node.get("battle", {}).duplicate(true)
	battle["config_id"] = config_id
	battle["map_id"] = String(config.get("map_id", battle.get("map_id", "")))
	battle["variant"] = String(map_entry.get("variant", battle.get("variant", _variant_for_config_id(config_id))))
	battle["max_rounds"] = int(config.get("max_rounds", battle.get("max_rounds", 5)))
	battle["map_pool_key"] = pool_key
	battle["map_archetype"] = String(map_entry.get("archetype", battle.get("variant", "")))
	battle["map_no_repeat_group"] = String(map_entry.get("no_repeat_group", config_id))
	battle["map_pressure_cost"] = int(map_entry.get("pressure_cost", config.get("pressure_tags", []).size()))
	battle["map_enemy_family_hint"] = String(map_entry.get("enemy_family_hint", "mixed"))
	battle["map_assignment_relaxed"] = String(map_entry.get("map_assignment_relaxed", ""))
	battle["map_preview_flags"] = map_entry.get("preview_flags", []).duplicate()
	var boss_config_id := String(config.get("boss_config_id", ""))
	if boss_config_id.is_empty():
		battle.erase("boss_config_id")
	else:
		battle["boss_config_id"] = boss_config_id
	node["battle"] = battle

func _variant_for_config_id(config_id: String) -> String:
	match config_id:
		BattleConfigCatalogScript.CONFIG_OUTER_WALL:
			return "intro"
		BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD:
			return "archer"
		BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD:
			return "pillar"
		BattleConfigCatalogScript.CONFIG_IRON_GATE:
			return "elite"
		BattleConfigCatalogScript.CONFIG_OUTER_BELL:
			return "boss"
		BattleConfigCatalogScript.CONFIG_BROKEN_BRIDGE_EDGE:
			return "bridge"
	return "pillars"

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
	# Legacy route edges are retained for debug/save compatibility. The player-facing
	# flow is driven by the commission board, not by a visible node graph.
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
