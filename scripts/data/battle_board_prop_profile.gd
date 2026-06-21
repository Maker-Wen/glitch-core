class_name BattleBoardPropProfile extends Resource
## Authoring contract for a prop rendered on the diamond battle board.
##
## A profile is the single source of truth for how a scene prop source image
## sits on one board cell. The atlas builder serializes it for runtime use and
## validates that the PNG still matches the declared gameplay footprint.

@export var id: StringName
@export var source: String
@export var texture: String
@export var body_crop: Rect2
@export var body_anchor_px: Vector2
@export var board_foot_offset: Vector2 = Vector2(0, 10)
@export var hp_offset: Vector2 = Vector2(-22, -23)
@export var target_height: float = 64.0
@export var max_draw_width: float = 72.0
@export var footprint_scale: float = 0.7
@export var foundation_scale: Vector2 = Vector2(0.78, 0.48)
@export var foundation_offset: Vector2 = Vector2(0, 6)
@export var floor_occlusion_strength: float = 0.34
@export var contact_shadow_strength: float = 0.48
@export var sort_bias: float = 0.0
@export var tint: Color = Color(0.78, 0.80, 0.76, 0.80)
@export var min_edge_margin: int = 4
@export var min_horizontal_margin: int = 64
@export var max_alpha_width_ratio: float = 0.84
