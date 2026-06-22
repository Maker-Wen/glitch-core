class_name UnitDef extends Resource
## Static unit template loaded from .tres files. Inert data; runtime state lives in Unit.

enum Faction { WARDEN, ENEMY }
enum AttackKind {
	MELEE_PUSH,    # Adjacent 1-cell: damage + push N
	RANGED_PULL,   # Line N cells: damage + pull N toward attacker
	RANGED_PUSH,   # Line N cells: damage + push N away from attacker
	MELEE_BUMP,    # Adjacent 1-cell: damage only (Carrion Spawn)
}

@export var def_id: StringName = &""
@export var display_name: String = ""
@export var faction: int = Faction.WARDEN
@export var max_hp: int = 1
@export var move: int = 2
@export var attack_kind: int = AttackKind.MELEE_BUMP
@export var attack_range: int = 1  # 1 = melee adjacent; 3 = ranged 3 cells
@export var attack_damage: int = 1
@export var attack_force: int = 0  # push or pull magnitude (0 for MELEE_BUMP)
## Display color when no art asset is available (slice placeholder).
@export var color: Color = Color.WHITE
## Optional static token art for battle board rendering.
@export var token_texture: Texture2D = null
## Optional board-space correction for token art with a visually off-center base.
@export var token_board_offset: Vector2 = Vector2.ZERO
## Optional bust/portrait art for HUD cards. Falls back to token_texture.
@export var ui_portrait: Texture2D = null
