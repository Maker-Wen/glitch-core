class_name RelicCatalog extends RefCounted
## Demo relic definitions used by Run rewards.

const POOL_ELITE := "elite"
const POOL_BOSS_CHAPTER := "boss_chapter"

static func demo_relics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append(_relic("relic_chain_weight", "链锤改装", "普通", "角色", ["位移"], "赏金猎人的链锤击推力 +1。", "每场", [POOL_ELITE], "warden_bountyhunter"))
	result.append(_relic("relic_staff_resonance", "长杖共鸣", "普通", "角色", ["位移"], "大魔法师推动目标撞击后，对目标施加碎裂。", "每场", [POOL_ELITE], "warden_mage"))
	result.append(_relic("relic_grave_hook", "坟土钩爪", "普通", "角色", ["位移"], "盗墓人把敌人拉到相邻后，可移动 1 格。", "每场", [POOL_ELITE], "warden_graverobber"))
	result.append(_relic("relic_ember_charm", "余烬护符", "普通", "防守", [], "每场第一次普通建筑受伤 -1。", "每场第一次", [POOL_ELITE], ""))
	result.append(_relic("relic_rift_nail", "裂隙钉", "普通", "裂隙", [], "守卫者站在地裂上时，延迟出怪且不受地裂伤害。", "每场", [POOL_ELITE], ""))
	result.append(_relic("relic_wall_blueprint", "残墙图纸", "普通", "防守", ["裂隙"], "战斗开局可放置 1 个 HP=1 临时路障。", "开局", [POOL_ELITE], ""))
	result.append(_relic("relic_scorched_banner", "焦土旗帜", "普通", "防守", [], "废墟相邻的敌人移动 -1。", "每场", [POOL_ELITE], ""))
	result.append(_relic("relic_artisan_bone", "工匠遗骨", "普通", "防守", ["任务"], "修复建筑时，如果该建筑相邻有敌人，对该敌人造成 1 伤。", "每场", [POOL_ELITE], ""))
	result.append(_relic("relic_broken_bell_echo", "断钟回响", "稀有", "位移", [], "每回合第一次撞击会把被撞单位继续推 1 格。", "每回合第一次", [POOL_ELITE, POOL_BOSS_CHAPTER], ""))
	result.append(_relic("relic_black_iron_wedge", "黑铁楔", "稀有", "防守", ["位移"], "敌人被推向建筑时，先受到 1 伤；若死亡则不伤建筑。", "每场", [POOL_ELITE, POOL_BOSS_CHAPTER], ""))
	result.append(_relic("relic_cracked_lens", "裂纹透镜", "稀有", "位移", ["角色"], "对碎裂敌人的第一次攻击额外 +1 伤害，每回合 1 次。", "每回合 1 次", [POOL_ELITE, POOL_BOSS_CHAPTER], "warden_mage"))
	result.append(_relic("relic_watch_oath", "守夜誓约", "稀有", "任务", ["防守"], "每章第一次完成 3 个奖励任务时，守护值 +1。", "每章 1 次", [POOL_ELITE, POOL_BOSS_CHAPTER], ""))
	return result

static func relics_for_pool(pool_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for relic in demo_relics():
		if pool_id in relic.get("source_pools", []):
			result.append(relic.duplicate(true))
	return result

static func get_relic(relic_id: String) -> Dictionary:
	for relic in demo_relics():
		if String(relic.get("relic_id", "")) == relic_id:
			return relic.duplicate(true)
	return {}

static func to_reward_option(relic: Dictionary, option_type: String = "relic") -> Dictionary:
	var tags: Array = [String(relic.get("primary_tag", ""))]
	tags.append_array(relic.get("secondary_tags", []))
	return {
		"option_id": String(relic.get("relic_id", "")),
		"option_type": option_type,
		"relic_id": String(relic.get("relic_id", "")),
		"rarity": String(relic.get("rarity", "")),
		"target_type": "global",
		"target_id": String(relic.get("requires_warden", "")),
		"title": String(relic.get("display_name", "")),
		"display_name": String(relic.get("display_name", "")),
		"relic_type": _type_text(relic),
		"primary_tag": String(relic.get("primary_tag", "")),
		"secondary_tags": relic.get("secondary_tags", []).duplicate(true),
		"description": String(relic.get("preview_text", "")),
		"preview_delta": {},
		"tags": tags,
		"trigger_timing": String(relic.get("trigger_timing", "")),
		"effect_ops": relic.get("effect_ops", []).duplicate(true),
	}

static func _relic(
	relic_id: String,
	display_name: String,
	rarity: String,
	primary_tag: String,
	secondary_tags: Array,
	preview_text: String,
	trigger_timing: String,
	source_pools: Array,
	requires_warden: String
) -> Dictionary:
	return {
		"relic_id": relic_id,
		"display_name": display_name,
		"rarity": rarity,
		"primary_tag": primary_tag,
		"secondary_tags": secondary_tags,
		"chapter_unlock": 1,
		"source_pools": source_pools,
		"unique": true,
		"effect_ops": [{"op": relic_id, "status": "data_only"}],
		"cost_ops": [],
		"trigger_timing": trigger_timing,
		"per_battle_limit": 0,
		"per_chapter_limit": 0,
		"mutex_group": "",
		"requires_warden": requires_warden,
		"preview_text": preview_text,
	}

static func _type_text(relic: Dictionary) -> String:
	var parts: Array[String] = [String(relic.get("primary_tag", ""))]
	for tag in relic.get("secondary_tags", []):
		parts.append(String(tag))
	return " / ".join(parts)
