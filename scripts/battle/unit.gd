class_name Unit extends RefCounted
## Runtime instance of a unit in a BattleState. Holds mutable HP/position/flags.
## Static template lives in UnitDef.

var id: int = -1
var def: UnitDef
var hp: int = 1
var position: Vector2i = Vector2i.ZERO
var alive: bool = true
var has_moved: bool = false  ## moved this turn; can no longer move (but may still attack)
var has_acted: bool = false  ## fully done for the turn (attacked / ended / used both moves)
var cracked: bool = false  ## slice doesn't use; reserved for §3.6

func _init(p_id: int = -1, p_def: UnitDef = null, p_position: Vector2i = Vector2i.ZERO) -> void:
	id = p_id
	def = p_def
	position = p_position
	if def != null:
		hp = def.max_hp

func clone() -> Unit:
	var u := Unit.new()
	u.id = id
	u.def = def  # def is immutable Resource; safe to share
	u.hp = hp
	u.position = position
	u.alive = alive
	u.has_moved = has_moved
	u.has_acted = has_acted
	u.cracked = cracked
	return u

func is_warden() -> bool:
	return def != null and def.faction == UnitDef.Faction.WARDEN

func is_enemy() -> bool:
	return def != null and def.faction == UnitDef.Faction.ENEMY
