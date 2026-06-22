extends RefCounted
## Shared test fixtures for UnitDef resources.
## Default fixtures duplicate production .tres data; per-test overrides should
## only be used when the scenario intentionally fixes a stat boundary.

const WARDEN_BOUNTYHUNTER := preload("res://scripts/data/defs/warden_bountyhunter.tres")
const WARDEN_GRAVEROBBER := preload("res://scripts/data/defs/warden_graverobber.tres")
const WARDEN_MAGE := preload("res://scripts/data/defs/warden_mage.tres")
const ENEMY_CARRION_SPAWN := preload("res://scripts/data/defs/enemy_carrion_spawn.tres")
const ENEMY_PLAGUE_ARCHER := preload("res://scripts/data/defs/enemy_plague_archer.tres")
const ENEMY_BONE_GRUB := preload("res://scripts/data/defs/enemy_bone_grub.tres")
const ENEMY_IRONHORN := preload("res://scripts/data/defs/enemy_ironhorn.tres")
const ENEMY_SHELL_BEETLE := preload("res://scripts/data/defs/enemy_shell_beetle.tres")
const ENEMY_BELL_THRALL := preload("res://scripts/data/defs/enemy_bell_thrall.tres")

static func bountyhunter(overrides: Dictionary = {}) -> UnitDef:
	return _copy_with_overrides(WARDEN_BOUNTYHUNTER, overrides)

static func graverobber(overrides: Dictionary = {}) -> UnitDef:
	return _copy_with_overrides(WARDEN_GRAVEROBBER, overrides)

static func mage(overrides: Dictionary = {}) -> UnitDef:
	return _copy_with_overrides(WARDEN_MAGE, overrides)

static func carrion_spawn(overrides: Dictionary = {}) -> UnitDef:
	return _copy_with_overrides(ENEMY_CARRION_SPAWN, overrides)

static func plague_archer(overrides: Dictionary = {}) -> UnitDef:
	return _copy_with_overrides(ENEMY_PLAGUE_ARCHER, overrides)

static func bone_grub(overrides: Dictionary = {}) -> UnitDef:
	return _copy_with_overrides(ENEMY_BONE_GRUB, overrides)

static func ironhorn(overrides: Dictionary = {}) -> UnitDef:
	return _copy_with_overrides(ENEMY_IRONHORN, overrides)

static func shell_beetle(overrides: Dictionary = {}) -> UnitDef:
	return _copy_with_overrides(ENEMY_SHELL_BEETLE, overrides)

static func bell_thrall(overrides: Dictionary = {}) -> UnitDef:
	return _copy_with_overrides(ENEMY_BELL_THRALL, overrides)

static func generic_warden(overrides: Dictionary = {}) -> UnitDef:
	var base := bountyhunter({"def_id": &"warden_test", "display_name": "守卫者"})
	return _apply_overrides(base, overrides)

static func generic_enemy(overrides: Dictionary = {}) -> UnitDef:
	var base := carrion_spawn({"def_id": &"enemy_test", "display_name": "敌人"})
	return _apply_overrides(base, overrides)

static func _copy_with_overrides(base: UnitDef, overrides: Dictionary) -> UnitDef:
	var def: UnitDef = base.duplicate(true)
	return _apply_overrides(def, overrides)

static func _apply_overrides(def: UnitDef, overrides: Dictionary) -> UnitDef:
	for key in overrides.keys():
		def.set(StringName(str(key)), overrides[key])
	return def
