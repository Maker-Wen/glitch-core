class_name BattleEvent extends RefCounted
## Immutable record of a single state mutation produced by BattleEngine /
## PhysicsResolver. View layer consumes these in order to animate.

enum Type {
	UNIT_SPAWNED,
	UNIT_MOVED,        # Voluntary move (player action)
	UNIT_PUSHED,       # Forced displacement (physics)
	UNIT_DAMAGED,      # HP decreased
	UNIT_DIED,         # alive = false (still occupies cell until UNIT_REMOVED)
	UNIT_REMOVED,      # Cleared from grid at chain end (Tend)
	UNIT_FELL,         # Pushed off board (instant kill)
	UNIT_CRACKED,      # Reserved
	BUMP_WALL,         # Hit pillar / building / boundary -> wall damage
	BUMP_UNIT,         # Hit another unit -> relay
	TILE_DAMAGED,      # Pillar / building HP -1 (reserved for later phases)
	TILE_DESTROYED,    # Reserved
	PHASE_CHANGED,
	ROUND_STARTED,
	ROUND_ENDED,
	BATTLE_ENDED,
	ENEMY_ATTACK_STARTED,  # UI timing: highlight the acting enemy slot.
	ENEMY_ATTACK_MISSED,   # UI timing: locked attack slot resolved with no hit.
}

var type: int
var unit_id: int = -1
var from_pos: Vector2i = Vector2i.ZERO
var to_pos: Vector2i = Vector2i.ZERO
var amount: int = 0
var extra: Dictionary = {}

static func make(p_type: int) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = p_type
	return e
