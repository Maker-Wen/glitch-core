class_name BattleAction extends RefCounted
## Player intent. Validated + applied by BattleEngine.

enum Kind {
	MOVE,        # Move actor_id to target_pos
	ATTACK,      # Attack the unit at target_pos with actor_id's weapon
	END_TURN,    # Skip remaining wardens; enemy executes
	UNDO,
	DEPLOY,      # Garrison phase: place the next pending warden at target_pos
	CONFIRM_DEPLOY,  # Garrison phase: finalize deployment, start enemy approach + Round 1
}

var kind: int
var actor_id: int = -1
var target_pos: Vector2i = Vector2i.ZERO

static func move(p_actor_id: int, p_target: Vector2i) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.MOVE
	a.actor_id = p_actor_id
	a.target_pos = p_target
	return a

static func attack(p_actor_id: int, p_target: Vector2i) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.ATTACK
	a.actor_id = p_actor_id
	a.target_pos = p_target
	return a

static func end_turn() -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.END_TURN
	return a

static func undo() -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.UNDO
	return a

static func deploy(p_target: Vector2i) -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.DEPLOY
	a.target_pos = p_target
	return a

static func confirm_deploy() -> BattleAction:
	var a := BattleAction.new()
	a.kind = Kind.CONFIRM_DEPLOY
	return a
