class_name WardenSkillCatalog extends RefCounted
## Static metadata for player-side warden active skills.
## Runtime legality and effects live in BattleEngine.

const BOUNTY_CHAIN_STRIKE := &"bounty_chain_strike"
const BOUNTY_GUARD_SHOULDER := &"bounty_guard_shoulder"
const BOUNTY_EXECUTE := &"bounty_execute"
const GRAVEROBBER_HOOK_ROPE := &"graverobber_hook_rope"
const GRAVEROBBER_RIFT_WEDGE := &"graverobber_rift_wedge"
const GRAVEROBBER_BACKHAND_THROW := &"graverobber_backhand_throw"
const MAGE_REPULSION_BOLT := &"mage_repulsion_bolt"
const MAGE_WARD_FIRE := &"mage_ward_fire"
const MAGE_SIGIL := &"mage_sigil"

const UPGRADE_BOUNTY_CHAIN_STRIKE_FORCE := "upgrade_bounty_chain_strike_force"
const UPGRADE_BOUNTY_GUARD_SHOULDER_READY := "upgrade_bounty_guard_shoulder_ready"
const UPGRADE_BOUNTY_EXECUTE_TEMPO := "upgrade_bounty_execute_tempo"
const UPGRADE_GRAVEROBBER_HOOK_ROPE_RANGE := "upgrade_graverobber_hook_rope_range"
const UPGRADE_GRAVEROBBER_RIFT_WEDGE_RANGE := "upgrade_graverobber_rift_wedge_range"
const UPGRADE_GRAVEROBBER_BACKHAND_THROW_RANGE := "upgrade_graverobber_backhand_throw_range"
const UPGRADE_MAGE_WARD_FIRE_SHIELD := "upgrade_mage_ward_fire_shield"
const UPGRADE_MAGE_SIGIL_DURATION := "upgrade_mage_sigil_duration"

const TARGET_ADJACENT_ENEMY_OR_BOSS := &"adjacent_enemy_or_boss"
const TARGET_ADJACENT_ENEMY := &"adjacent_enemy"
const TARGET_ADJACENT_UNIT := &"adjacent_unit"
const TARGET_LINE_ENEMY_OR_BOSS_RANGE_3 := &"line_enemy_or_boss_range_3"
const TARGET_LINE_ENEMY_OR_BOSS_UNLIMITED := &"line_enemy_or_boss_unlimited"
const TARGET_LINE_ENEMY_RANGE_2 := &"line_enemy_range_2"
const TARGET_RIFT_RANGE_3 := &"rift_range_3"
const TARGET_PROTECTED_BUILDING_RANGE_2 := &"protected_building_range_2"
const TARGET_EMPTY_RANGE_3 := &"empty_range_3"

static func skills_for_warden(def_id: StringName, upgrade_ids: Array = []) -> Array[Dictionary]:
	match def_id:
		&"warden_bountyhunter":
			return [
				get_skill(BOUNTY_CHAIN_STRIKE, upgrade_ids),
				get_skill(BOUNTY_GUARD_SHOULDER, upgrade_ids),
				get_skill(BOUNTY_EXECUTE, upgrade_ids),
			]
		&"warden_graverobber":
			return [
				get_skill(GRAVEROBBER_HOOK_ROPE, upgrade_ids),
				get_skill(GRAVEROBBER_RIFT_WEDGE, upgrade_ids),
				get_skill(GRAVEROBBER_BACKHAND_THROW, upgrade_ids),
			]
		&"warden_mage":
			return [
				get_skill(MAGE_REPULSION_BOLT, upgrade_ids),
				get_skill(MAGE_WARD_FIRE, upgrade_ids),
				get_skill(MAGE_SIGIL, upgrade_ids),
			]
	return []

static func get_skill(skill_id: StringName, upgrade_ids: Array = []) -> Dictionary:
	var skill: Dictionary = {}
	match skill_id:
		BOUNTY_CHAIN_STRIKE:
			skill = _skill(skill_id, "链锤击", "1 伤 + 推 1", "⚔", 0, TARGET_ADJACENT_ENEMY_OR_BOSS, 0)
		BOUNTY_GUARD_SHOULDER:
			skill = _skill(skill_id, "护卫肩撞", "换位 · 敌人 1 伤", "⛨", 1, TARGET_ADJACENT_UNIT, 0, 1, {"damage": 1, "range": 1})
		BOUNTY_EXECUTE:
			skill = _skill(skill_id, "悬赏处决", "1 伤 · 击杀计数", "◆", 2, TARGET_ADJACENT_ENEMY, 2, 2, {"damage": 1, "range": 1})
		GRAVEROBBER_HOOK_ROPE:
			skill = _skill(skill_id, "倒钩索", "3 格 1 伤 + 拉 1", "⚔", 0, TARGET_LINE_ENEMY_OR_BOSS_RANGE_3, 0, 0, {"range": 3})
		GRAVEROBBER_RIFT_WEDGE:
			skill = _skill(skill_id, "裂隙楔", "3 格延迟地裂 · 踩裂隙 1 伤", "▰", 1, TARGET_RIFT_RANGE_3, 0, 1, {"damage": 1, "range": 3})
		GRAVEROBBER_BACKHAND_THROW:
			skill = _skill(skill_id, "反手抛", "2 格拉近 · 侧推", "↶", 2, TARGET_LINE_ENEMY_RANGE_2, 0, 1, {"damage": 1, "force": 1, "range": 2})
		MAGE_REPULSION_BOLT:
			skill = _skill(skill_id, "斥力弹", "无限直线 1 伤 + 推 1", "⚔", 0, TARGET_LINE_ENEMY_OR_BOSS_UNLIMITED, 0, 0, {"range": 0})
		MAGE_WARD_FIRE:
			skill = _skill(skill_id, "护火", "护盾 · 减伤 1", "✚", 1, TARGET_PROTECTED_BUILDING_RANGE_2, 0, 1, {"range": 2, "shield_amount": 1})
		MAGE_SIGIL:
			skill = _skill(skill_id, "法阵", "2 回合减速区", "◇", 2, TARGET_EMPTY_RANGE_3, 2, 1, {"range": 3, "duration_rounds": 2})
	if skill.is_empty():
		return {}
	return _apply_upgrades(skill, upgrade_ids)

static func upgrade_options_for_warden(warden_id: String, owned_upgrade_ids: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for upgrade in _all_skill_upgrades():
		if String(upgrade.get("warden_id", "")) != warden_id:
			continue
		var upgrade_id := String(upgrade.get("upgrade_id", ""))
		if upgrade_id in owned_upgrade_ids:
			continue
		result.append(to_reward_option(upgrade))
	return result

static func to_reward_option(upgrade: Dictionary) -> Dictionary:
	return {
		"option_id": String(upgrade.get("upgrade_id", "")),
		"option_type": "upgrade",
		"upgrade_kind": "skill",
		"rarity": String(upgrade.get("rarity", "普通")),
		"target_type": "warden",
		"target_id": String(upgrade.get("warden_id", "")),
		"skill_id": String(upgrade.get("skill_id", "")),
		"title": String(upgrade.get("title", "技能强化")),
		"description": String(upgrade.get("description", "")),
		"preview_delta": {},
		"tags": upgrade.get("tags", ["升级", "技能"]),
	}

static func is_skill_upgrade(upgrade_id: String) -> bool:
	return not skill_upgrade(upgrade_id).is_empty()

static func skill_upgrade(upgrade_id: String) -> Dictionary:
	for upgrade in _all_skill_upgrades():
		if String(upgrade.get("upgrade_id", "")) == upgrade_id:
			return upgrade
	return {}

static func primary_skill_id_for_warden(def_id: StringName) -> StringName:
	match def_id:
		&"warden_bountyhunter":
			return BOUNTY_CHAIN_STRIKE
		&"warden_graverobber":
			return GRAVEROBBER_HOOK_ROPE
		&"warden_mage":
			return MAGE_REPULSION_BOLT
	return &""

static func _skill(
	id: StringName,
	name: String,
	desc: String,
	icon: String,
	slot: int,
	target_rule: StringName,
	max_uses_per_battle: int,
	cooldown_rounds: int = 0,
	extra: Dictionary = {}
) -> Dictionary:
	var result := {
		"id": id,
		"name": name,
		"desc": desc,
		"icon": icon,
		"slot": slot,
		"target_rule": target_rule,
		"max_uses_per_battle": max_uses_per_battle,
		"cooldown_rounds": cooldown_rounds,
	}
	for key in extra.keys():
		result[key] = extra[key]
	return result

static func _apply_upgrades(skill: Dictionary, upgrade_ids: Array) -> Dictionary:
	var result := skill.duplicate(true)
	var applied: Array[String] = []
	for raw_id in upgrade_ids:
		var upgrade := skill_upgrade(String(raw_id))
		if upgrade.is_empty():
			continue
		if String(upgrade.get("skill_id", "")) != String(result.get("id", "")):
			continue
		for key in upgrade.get("set", {}).keys():
			result[key] = upgrade.get("set", {})[key]
		if upgrade.has("desc"):
			result["desc"] = String(upgrade.get("desc", result.get("desc", "")))
		applied.append(String(upgrade.get("upgrade_id", "")))
	if not applied.is_empty():
		result["upgraded"] = true
		result["upgrade_ids"] = applied
	return result

static func _all_skill_upgrades() -> Array[Dictionary]:
	return [
		_skill_upgrade(
			UPGRADE_BOUNTY_CHAIN_STRIKE_FORCE,
			"warden_bountyhunter",
			BOUNTY_CHAIN_STRIKE,
			"赏金猎人：加重链锤",
			"链锤击推动距离 +1。",
			"1 伤 + 推 2",
			{"force": 2}
		),
		_skill_upgrade(
			UPGRADE_BOUNTY_GUARD_SHOULDER_READY,
			"warden_bountyhunter",
			BOUNTY_GUARD_SHOULDER,
			"赏金猎人：稳肩",
			"护卫肩撞不再进入冷却。",
			"换位 · 敌人 1 伤 · 无冷却",
			{"cooldown_rounds": 0}
		),
		_skill_upgrade(
			UPGRADE_BOUNTY_EXECUTE_TEMPO,
			"warden_bountyhunter",
			BOUNTY_EXECUTE,
			"赏金猎人：追加悬赏",
			"悬赏处决每场战斗可多使用 1 次。",
			"1 伤 · 击杀计数 · 3 次",
			{"max_uses_per_battle": 3}
		),
		_skill_upgrade(
			UPGRADE_GRAVEROBBER_HOOK_ROPE_RANGE,
			"warden_graverobber",
			GRAVEROBBER_HOOK_ROPE,
			"盗墓人：长索",
			"倒钩索射程 +1。",
			"4 格 1 伤 + 拉 1",
			{"range": 4}
		),
		_skill_upgrade(
			UPGRADE_GRAVEROBBER_RIFT_WEDGE_RANGE,
			"warden_graverobber",
			GRAVEROBBER_RIFT_WEDGE,
			"盗墓人：远楔",
			"裂隙楔作用范围 +1。",
			"4 格延迟地裂 · 踩裂隙 1 伤",
			{"range": 4}
		),
		_skill_upgrade(
			UPGRADE_GRAVEROBBER_BACKHAND_THROW_RANGE,
			"warden_graverobber",
			GRAVEROBBER_BACKHAND_THROW,
			"盗墓人：反手长抛",
			"反手抛射程 +1。",
			"3 格拉近 · 侧推",
			{"range": 3}
		),
		_skill_upgrade(
			UPGRADE_MAGE_WARD_FIRE_SHIELD,
			"warden_mage",
			MAGE_WARD_FIRE,
			"大魔法师：旺火",
			"护火提供 2 点护盾。",
			"护盾 · 减伤 2",
			{"shield_amount": 2}
		),
		_skill_upgrade(
			UPGRADE_MAGE_SIGIL_DURATION,
			"warden_mage",
			MAGE_SIGIL,
			"大魔法师：持久法阵",
			"法阵持续时间 +1 回合。",
			"3 回合减速区",
			{"duration_rounds": 3}
		),
	]

static func _skill_upgrade(
	upgrade_id: String,
	warden_id: String,
	skill_id: StringName,
	title: String,
	description: String,
	desc: String,
	set_values: Dictionary
) -> Dictionary:
	return {
		"upgrade_id": upgrade_id,
		"warden_id": warden_id,
		"skill_id": String(skill_id),
		"title": title,
		"description": description,
		"desc": desc,
		"set": set_values,
		"rarity": "普通",
		"tags": ["升级", "技能"],
	}
