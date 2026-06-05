class_name RunState extends RefCounted
## Mutable state for the fixed demo roguelite run.

const RelicCatalogScript := preload("res://scripts/data/relic_catalog.gd")
const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")

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

var run_id: String = ""
var run_seed: int = 0
var difficulty_id: String = "normal"
var phase: int = Phase.MENU
var chapter_index: int = 1
var chapter_name: String = "外墙余烬"
var chapter_node_index: int = 0
var current_node_id: String = ""
var sanctuary_integrity: int = 7
var sanctuary_integrity_max: int = 7
var embers: int = 0
var corruption: int = 0
var wardens: Array[Dictionary] = []
var relics: Array[Dictionary] = []
var route_nodes: Array[Dictionary] = []
var visited_nodes: Array[String] = []
var claimed_reward_ids: Array[String] = []
var pending_reward: Dictionary = {}
var last_resolution: Dictionary = {}
var chapter_guardian_reward_used: bool = false
var result_outcome: String = ""

func setup_new_demo() -> void:
	run_id = "demo-%d" % Time.get_unix_time_from_system()
	run_seed = 1046
	difficulty_id = "normal"
	phase = Phase.PREP
	chapter_index = 1
	chapter_name = "外墙余烬"
	chapter_node_index = 0
	current_node_id = ""
	sanctuary_integrity = 7
	sanctuary_integrity_max = 7
	embers = 0
	corruption = 0
	relics.clear()
	visited_nodes.clear()
	claimed_reward_ids.clear()
	pending_reward.clear()
	last_resolution.clear()
	chapter_guardian_reward_used = false
	result_outcome = ""
	wardens = [
		{
			"warden_id": "warden_bountyhunter",
			"name": "赏金猎人",
			"role": "近战推进",
			"hp": 2,
			"hp_max": 2,
			"alive": true,
			"upgrades": [],
			"death_node_id": "",
		},
		{
			"warden_id": "warden_graverobber",
			"name": "盗墓人",
			"role": "远程牵引",
			"hp": 2,
			"hp_max": 2,
			"alive": true,
			"upgrades": [],
			"death_node_id": "",
		},
		{
			"warden_id": "warden_mage",
			"name": "大魔法师",
			"role": "远程推击",
			"hp": 2,
			"hp_max": 2,
			"alive": true,
			"upgrades": [],
			"death_node_id": "",
		},
	]
	route_nodes = _build_demo_route()

func next_unvisited_node() -> Dictionary:
	for node in route_nodes:
		if not bool(node.get("visited", false)):
			return node
	return {}

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

func is_route_complete() -> bool:
	return visited_nodes.size() >= route_nodes.size()

func is_battle_node(node: Dictionary) -> bool:
	var node_type := String(node.get("node_type", ""))
	return node_type == NODE_NORMAL or node_type == NODE_ELITE or node_type == NODE_BOSS

func resolve_event_node(choice_id: String) -> void:
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
	last_resolution = resolution.duplicate(true)
	var destroyed_targets := int(resolution.get("destroyed_protected_count", 0))
	var sanctuary_loss := 0
	if bool(resolution.get("line_breached", false)):
		sanctuary_loss = 3
	else:
		sanctuary_loss = clampi(destroyed_targets, 0, 3)
	sanctuary_integrity = maxi(0, sanctuary_integrity - sanctuary_loss)
	last_resolution["sanctuary_loss"] = sanctuary_loss
	last_resolution["sanctuary_after"] = sanctuary_integrity
	_update_wardens_from_battle(resolution)
	if alive_warden_count() <= 0 or sanctuary_integrity <= 0:
		result_outcome = "defeat"
		phase = Phase.RUN_RESULT
		pending_reward.clear()

func build_pending_reward(node: Dictionary, resolution: Dictionary) -> Dictionary:
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
		"fixed_rewards": [
			{
				"reward_type": "embers",
				"amount": base_embers,
				"reason": _base_reward_reason(node_type),
				"visible_order": 10,
			},
		],
		"choice_groups": [],
		"modifiers": [],
		"reroll": {
			"allowed": false,
			"cost_embers": 3,
			"used_count": 0,
			"max_count": 0,
		},
		"claim_state": {
			"generated": true,
			"fixed_claimed": false,
			"choice_claimed": false,
			"selected_option_ids": [],
		},
	}
	if bonus_embers > 0:
		reward.fixed_rewards.append({
			"reward_type": "embers",
			"amount": bonus_embers,
			"reason": "完成 %d 个奖励任务" % completed,
			"visible_order": 20,
		})
	if completed >= 2:
		reward.modifiers.append({
			"modifier_id": "reward_option_plus_1",
			"description": "完成 2 个奖励任务：奖励选项 +1。",
		})
	if completed >= 3 and (node_type == NODE_ELITE or node_type == NODE_BOSS):
		reward.modifiers.append({
			"modifier_id": "rare_weight_up",
			"description": "完成 3 个奖励任务：稀有遗物权重提高。",
		})
	var options := _reward_options_for(node_type, completed)
	if _should_offer_guardian_recovery(node_type, completed):
		options.append({
			"option_id": "repair_sanctuary",
			"option_type": "recovery",
			"rarity": "普通",
			"target_type": "sanctuary_integrity",
			"target_id": "",
			"title": "修复防线",
			"description": "守护值 +1。本章奖励任务恢复只可触发一次。",
			"preview_delta": {"sanctuary_integrity": 1},
			"tags": ["恢复", "防线"],
		})
		reward.modifiers.append({
			"modifier_id": "guardian_recovery_available",
			"description": "完成 3 个奖励任务：生成守护值恢复机会。",
		})
	elif _should_convert_guardian_recovery_to_embers(node_type, completed):
		reward.fixed_rewards.append({
			"reward_type": "embers",
			"amount": 3,
			"reason": "守护值已满，恢复机会转化",
			"visible_order": 30,
		})
		reward.modifiers.append({
			"modifier_id": "guardian_recovery_converted",
			"description": "完成 3 个奖励任务，但守护值已满：改为 +3 余烬。",
		})
	if not options.is_empty():
		reward.reward_phase = "chapter_choice" if node_type == NODE_BOSS else "choice"
		reward.choice_groups.append({
			"group_id": "main_choice",
			"group_type": _choice_group_type(node_type),
			"choose_count": 1,
			"display_count": options.size(),
			"options": options,
			"can_skip": true,
			"skip_reward": {"reward_type": "embers", "amount": 3, "reason": "跳过奖励"},
		})
	return reward

func claim_pending_reward(option_id: String = "") -> void:
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
			w["hp"] = clampi(hp, 0, int(w.get("hp_max", 2)))
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
					wardens[i]["hp_max"] = int(wardens[i].get("hp_max", 2)) + hp_max_gain
					wardens[i]["hp"] = mini(int(wardens[i].get("hp_max", 2)), int(wardens[i].get("hp", 1)) + hp_gain)
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

func _find_node_option(node: Dictionary, section: String, choice_id: String) -> Dictionary:
	var data: Dictionary = node.get(section, {})
	for option in data.get("options", []):
		if String(option.get("option_id", "")) == choice_id:
			return option
	return {}

func _apply_option_effects(effects: Array) -> void:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		_apply_fixed_reward(effect)

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

func _build_demo_route() -> Array[Dictionary]:
	return [
		{
			"node_id": "outer_wall_01",
			"title": "断墙前哨",
			"node_type": NODE_NORMAL,
			"layer": 1,
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
			"risk_level": 2,
			"pressure_tags": ["资源取舍"],
			"rift_strength": 0,
			"base_embers": 0,
			"visited": false,
			"summary": "事件占位。选择修复防线、搜刮余烬，或直接离开。",
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
			"node_id": "crack_courtyard_03",
			"title": "裂缝庭院",
			"node_type": NODE_NORMAL,
			"layer": 3,
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
			"node_id": "iron_gate_04",
			"title": "铁角闸门",
			"node_type": NODE_ELITE,
			"layer": 4,
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
			"node_id": "boss_outer_bell_01",
			"title": "钟楼外环",
			"node_type": NODE_BOSS,
			"layer": 6,
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
