class_name DiamondBoardView extends Node2D
## ITB-style 2D diamond board.
##
## Battle rules remain in the existing 8x8 BattleState. This view only maps
## grid cells to a dimetric diamond projection and draws board, props, units,
## and tactical overlays in one consistent 2D visual language.

const INVALID_CELL := Vector2i(-1, -1)
const TILE_W := 102.0
const TILE_H := 52.0
const TILE_HALF := Vector2(TILE_W * 0.5, TILE_H * 0.5)
const BOARD_ORIGIN := Vector2(596.0, 46.0)
const BOARD_TOP_MAP_SIZE := Vector2(TILE_W * 8.0, TILE_H * 8.0)
const SLAB_DEPTH := 48.0
const UNIT_GROUND_Y := 1.0

const COLOR_BOARD_SHADOW := Color(0.0, 0.0, 0.0, 0.58)
const COLOR_BOARD_UNDER := Color(0.102, 0.112, 0.106)
const COLOR_BOARD_SIDE_L := Color(0.060, 0.067, 0.064)
const COLOR_BOARD_SIDE_R := Color(0.074, 0.082, 0.078)
const COLOR_BOARD_RIM_LIGHT := Color(0.70, 0.82, 0.76, 0.38)
const COLOR_BOARD_RIM_DARK := Color(0.0, 0.0, 0.0, 0.72)
const COLOR_TILE_A := Color(0.260, 0.276, 0.254)
const COLOR_TILE_B := Color(0.224, 0.242, 0.228)
const COLOR_TILE_EDGE_LIT := Color(0.78, 0.88, 0.82, 0.18)
const COLOR_TILE_EDGE_DARK := Color(0.0, 0.0, 0.0, 0.34)
const COLOR_TILE_DECAL_LIGHT := Color(0.86, 0.96, 0.82, 0.085)
const COLOR_TILE_DECAL_DARK := Color(0.0, 0.0, 0.0, 0.145)
const COLOR_GRID_LINE := Color(0.82, 0.90, 0.82, 0.014)
const COLOR_GRID_GROUT := Color(0.0, 0.0, 0.0, 0.030)
const COLOR_MOVE := Color(0.26, 0.64, 0.62, 0.22)
const COLOR_ATTACK := Color(0.95, 0.28, 0.34, 0.40)
const COLOR_HOVER := Color(1.0, 0.83, 0.30, 0.34)
const COLOR_DEPLOY := Color(0.13, 0.54, 0.52, 0.12)
const COLOR_DEPLOY_FRAME := Color(0.38, 0.96, 0.86, 0.72)
const COLOR_DEPLOY_INNER := Color(0.15, 0.66, 0.58, 0.22)
const COLOR_DEPLOY_CORNER := Color(0.68, 1.0, 0.88, 0.84)
const COLOR_INTENT := Color(1.0, 0.34, 0.42, 0.42)
const COLOR_FOCUS := Color(1.0, 0.74, 0.26, 0.50)
const COLOR_INTENT_LINE := Color(1.0, 0.23, 0.18, 0.82)
const COLOR_INTENT_TARGET_FILL := Color(0.55, 0.03, 0.02, 0.16)
const COLOR_INTENT_TARGET_FRAME := Color(1.0, 0.18, 0.12, 0.95)
const COLOR_INTENT_SOURCE := Color(1.0, 0.74, 0.28, 0.95)
const COLOR_INTENT_UNDERSTROKE := Color(0.030, 0.006, 0.004, 0.82)
const COLOR_CHARGE_LANE := Color(1.0, 0.46, 0.12, 0.34)
const COLOR_CHARGE_LANE_FRAME := Color(1.0, 0.67, 0.20, 0.88)
const COLOR_EXECUTE_CONFIRM := Color(1.0, 0.82, 0.30, 0.96)
const COLOR_RIFT_WARN := Color(1.0, 0.78, 0.20, 0.46)
const COLOR_CRACKED_GROUND := Color(1.0, 0.24, 0.12, 0.34)
const COLOR_CRACKED_GROUND_FRAME := Color(1.0, 0.66, 0.22, 0.88)
const COLOR_BELL_WAVE := Color(0.56, 0.72, 1.0, 0.30)
const COLOR_BELL_WAVE_FRAME := Color(0.74, 0.88, 1.0, 0.86)
const COLOR_ABYSS_EDGE := Color(0.98, 0.18, 0.10, 0.74)
const COLOR_ABYSS_EDGE_SHADOW := Color(0.0, 0.0, 0.0, 0.62)
const COLOR_PREVIEW_GHOST := Color(0.55, 0.82, 1.0, 0.46)
const COLOR_PREVIEW_DANGER := Color(1.0, 0.42, 0.28, 0.48)
const COLOR_ACCENT_WARDEN := Color(0.50, 0.82, 0.80, 1.0)
const COLOR_ACCENT_ENEMY := Color(0.72, 0.54, 0.28, 1.0)
const COLOR_ATTACK_AMBER := Color(0.76, 0.42, 0.15, 1.0)
const COLOR_ATTACK_BONE := Color(0.84, 0.72, 0.50, 1.0)
const COLOR_ATTACK_RETICLE := Color(0.88, 0.18, 0.10, 1.0)
const COLOR_ATTACK_DUST := Color(0.43, 0.33, 0.22, 1.0)
const COLOR_ATTACK_IRON := Color(0.050, 0.038, 0.028, 1.0)
const COLOR_ENEMY_ORDER_BACK := Color(0.055, 0.020, 0.020, 0.94)
const COLOR_ENEMY_ORDER_FACE := Color(0.24, 0.055, 0.030, 0.88)
const COLOR_ENEMY_ORDER_BORDER := Color(1.0, 0.37, 0.12, 0.92)
const COLOR_ENEMY_ORDER_TEXT := Color(1.0, 0.72, 0.42, 1.0)
const COLOR_BUILDING_HP_FRAME := Color(0.035, 0.032, 0.026, 0.90)
const COLOR_BUILDING_HP_EMPTY := Color(0.095, 0.078, 0.052, 0.92)
const COLOR_BUILDING_HP_FILL := Color(1.0, 0.58, 0.20, 0.96)
const COLOR_BUILDING_HP_PREVIEW := Color(1.0, 0.18, 0.12, 0.78)
const COLOR_BUILDING_HP_PREVIEW_GLOW := Color(1.0, 0.52, 0.22, 0.35)
const COLOR_UNIT_HP_FRAME := Color(0.020, 0.018, 0.016, 0.88)
const COLOR_UNIT_HP_EMPTY := Color(0.095, 0.065, 0.055, 0.92)
const COLOR_WARDEN_HP_FILL := Color(0.95, 0.56, 0.18, 0.96)
const COLOR_WARDEN_HP_CRITICAL := Color(1.0, 0.26, 0.22, 0.98)
const COLOR_ENEMY_HP_FILL := Color(0.82, 0.24, 0.18, 0.96)
const COLOR_ENEMY_HP_CRITICAL := Color(1.0, 0.14, 0.10, 0.98)

const PROP_TILE_ANCHOR_OFFSET := Vector2(0, 10)
const PROP_CONTACT_SHADOW := Color(0.0, 0.0, 0.0, 0.52)
const PROP_FLOOR_OCCLUSION := Color(0.0, 0.0, 0.0, 0.34)
const PROP_FOUNDATION_FILL := Color(0.128, 0.142, 0.130, 0.22)
const PROP_FOUNDATION_LIT := Color(0.62, 0.70, 0.62, 0.28)
const PROP_FOUNDATION_DARK := Color(0.0, 0.0, 0.0, 0.34)
const PROP_RUBBLE_DARK := Color(0.030, 0.034, 0.032, 0.48)
const PROP_RUBBLE_LIGHT := Color(0.48, 0.52, 0.46, 0.34)
const DRAW_UNIT_HP_PIPS := false
const DRAW_UNIT_BODY_HP_BARS := false
const DRAW_UNIT_OVERHEAD_HP_BARS := true
const BUILDING_HP_BAR_OFFSET := Vector2(-22, -23)
const BUILDING_HP_SEGMENT_SIZE := Vector2(12, 4)
const BUILDING_HP_SEGMENT_GAP := 2.0
const BUILDING_HP_FRAME_PAD := Vector2(2, 2)
const BUILDING_HP_MAX_SEGMENTS := Grid.DEFAULT_BUILDING_HP
const UNIT_OVERHEAD_HP_BAR_SIZE := Vector2(34, 7)
const UNIT_OVERHEAD_HP_SEGMENT_GAP := 2.0
const UNIT_OVERHEAD_HP_OFFSET := Vector2(-17, -88)
const UNIT_TOKEN_HEIGHT := 104.0
const UNIT_TOKEN_OFFSET := Vector2(0, 13)
const SPECIAL_TEX_TOP := Vector2(0.500, 0.139)
const SPECIAL_TEX_RIGHT := Vector2(0.848, 0.322)
const SPECIAL_TEX_BOTTOM := Vector2(0.500, 0.535)
const SPECIAL_TEX_LEFT := Vector2(0.152, 0.322)
const FLOOR_MAP_PATH := "res://art/tiles/tilemap/battle_board_floor_map.png"
const FLOOR_VARIANTS_PATH := "res://art/tiles/tilemap/battle_floor_tile_variants.png"
const FLOOR_VARIANT_COUNT := 12
const FLOOR_VARIANT_COLUMNS := 4
const FLOOR_VARIANT_ROWS := 3
const ATTACK_VFX_SHEET_PATH := "res://art/effects/battle_attack_vfx_sheet.png"
const ATTACK_VFX_FRAME_SIZE := Vector2(96, 96)
const ATTACK_VFX_COLUMNS := 6
const ATTACK_VFX_ROWS := 6
const ATTACK_FX_HEIGHT := 34.0
const ATTACK_FX_MUZZLE_HEIGHT := 48.0
const ATTACK_FX_TARGET_HEIGHT := 42.0
const FX_SEQUENCE_MUZZLE := &"muzzle"
const FX_SEQUENCE_PROJECTILE := &"projectile"
const FX_SEQUENCE_IMPACT := &"impact"
const FX_SEQUENCE_DUST := &"dust"
const FX_SEQUENCE_SLASH := &"slash"
const FX_SEQUENCE_TETHER := &"tether"
const FX_MUZZLE_FRAMES := 4
const FX_PROJECTILE_FRAMES := 4
const FX_IMPACT_FRAMES := 6
const FX_DUST_FRAMES := 6
const FX_SLASH_FRAMES := 5
const FX_TETHER_FRAMES := 4

const TEX_DEPLOY_FLOOR := preload("res://art/tiles/board_deploy_floor_tile.png")
const TEX_RIFT_FLOOR := preload("res://art/tiles/board_rift_floor_tile.png")
const TEX_PILLAR := preload("res://art/atlases/battle/battle_props.board_pillar_body.tres")
const TEX_BUILDING := preload("res://art/atlases/battle/battle_props.board_building_body.tres")
const TEX_RUIN := preload("res://art/atlases/battle/battle_props.board_ruin_body.tres")
const BattleBoardAssetProfilesScript := preload("res://scripts/data/battle_board_asset_profiles.gd")

var _state: BattleState = null
var _move_cells: Array = []
var _attack_cells: Array = []
var _predicted_rifts: Array = []
var _predicted_cracked_ground: Array = []
var _predicted_bell_wave: Array = []
var _enemy_intents: Array = []
var _attack_fx_suppresses_intents := false
var _preview_markers: Array = []
var _preview_paths: Array = []
var _preview_protected_damage: Dictionary = {}
var _tile_display_overrides: Dictionary = {}
var _hover_cell := INVALID_CELL
var _focused_enemy_id: int = -1
var _attack_fx_layers: Array = []
var _unit_visual_positions: Dictionary = {}
var _unit_visual_units: Dictionary = {}
var _unit_display_overrides: Dictionary = {}
var _pulse_t: float = 0.0
var _floor_variants_texture: Texture2D = null
var _floor_map_texture: Texture2D = null
var _attack_vfx_sheet_texture: Texture2D = null
var _board_asset_profiles: Dictionary = {}

func _ready() -> void:
	_floor_variants_texture = _load_png_texture(FLOOR_VARIANTS_PATH)
	_floor_map_texture = _load_floor_map_texture()
	_attack_vfx_sheet_texture = _load_png_texture(ATTACK_VFX_SHEET_PATH)
	_board_asset_profiles = BattleBoardAssetProfilesScript.load_runtime_profiles()
	set_process(true)

func _process(delta: float) -> void:
	if _predicted_rifts.is_empty() and _predicted_cracked_ground.is_empty() and _predicted_bell_wave.is_empty() and _attack_fx_layers.is_empty() and _preview_protected_damage.is_empty() and not _has_visible_deploy_overlay():
		return
	_pulse_t += delta
	queue_redraw()

func bind_state(state: BattleState) -> void:
	_state = state
	queue_redraw()

func set_selection_ranges(move_cells: Array, attack_cells: Array) -> void:
	_move_cells = move_cells.duplicate()
	_attack_cells = attack_cells.duplicate()
	queue_redraw()

func set_hover_cell(cell: Vector2i) -> void:
	if _hover_cell == cell:
		return
	_hover_cell = cell
	queue_redraw()

func clear_preview() -> void:
	_preview_markers.clear()
	_preview_paths.clear()
	_preview_protected_damage.clear()
	queue_redraw()

func set_preview_markers(markers: Array, paths: Array, protected_damage: Dictionary = {}) -> void:
	_preview_markers = markers.duplicate(true)
	_preview_paths = paths.duplicate(true)
	_preview_protected_damage = protected_damage.duplicate(true)
	queue_redraw()

func set_preview_protected_damage(protected_damage: Dictionary) -> void:
	_preview_protected_damage = protected_damage.duplicate(true)
	queue_redraw()

func set_tile_display_overrides(overrides: Dictionary) -> void:
	_tile_display_overrides = overrides.duplicate(true)
	queue_redraw()

func clear_tile_display_overrides() -> void:
	if _tile_display_overrides.is_empty():
		return
	_tile_display_overrides.clear()
	queue_redraw()

func set_unit_display_overrides(overrides: Dictionary) -> void:
	_unit_display_overrides = overrides.duplicate(true)
	queue_redraw()

func clear_unit_display_overrides() -> void:
	if _unit_display_overrides.is_empty():
		return
	_unit_display_overrides.clear()
	queue_redraw()

func set_enemy_intents(rows: Array) -> void:
	_enemy_intents = rows.duplicate(true)
	queue_redraw()

func set_predicted_rifts(cells: Array) -> void:
	_predicted_rifts = cells.duplicate()
	queue_redraw()

func set_predicted_cracked_ground(cells: Array) -> void:
	_predicted_cracked_ground = cells.duplicate()
	queue_redraw()

func set_predicted_bell_wave(cells: Array) -> void:
	_predicted_bell_wave = cells.duplicate()
	queue_redraw()

func set_focused_enemy(enemy_id: int) -> void:
	if _focused_enemy_id == enemy_id:
		return
	_focused_enemy_id = enemy_id
	queue_redraw()

func set_attack_fx_layers(layers: Array) -> void:
	_attack_fx_layers = layers.duplicate(true)
	queue_redraw()

func set_attack_fx_suppresses_intents(enabled: bool) -> void:
	if _attack_fx_suppresses_intents == enabled:
		return
	_attack_fx_suppresses_intents = enabled
	queue_redraw()

func clear_attack_fx_layers() -> void:
	_attack_fx_layers.clear()
	queue_redraw()

func get_attack_fx_layers() -> Array:
	return _attack_fx_layers.duplicate(true)

func set_unit_visual_position(unit_id: int, pos: Vector2, unit: Unit = null) -> void:
	_unit_visual_positions[unit_id] = pos
	if unit != null:
		_unit_visual_units[unit_id] = unit
	queue_redraw()

func clear_unit_visual_position(unit_id: int) -> void:
	if not _unit_visual_positions.has(unit_id):
		return
	_unit_visual_positions.erase(unit_id)
	_unit_visual_units.erase(unit_id)
	queue_redraw()

func clear_unit_visual_positions() -> void:
	if _unit_visual_positions.is_empty():
		return
	_unit_visual_positions.clear()
	_unit_visual_units.clear()
	queue_redraw()

func get_enemy_intents() -> Array:
	return _enemy_intents.duplicate(true)

func get_focused_enemy() -> int:
	return _focused_enemy_id

func get_preview_markers() -> Array:
	return _preview_markers.duplicate(true)

func get_preview_paths() -> Array:
	return _preview_paths.duplicate(true)

func get_preview_protected_damage() -> Dictionary:
	return _preview_protected_damage.duplicate(true)

func get_predicted_cracked_ground() -> Array:
	return _predicted_cracked_ground.duplicate()

func get_predicted_bell_wave() -> Array:
	return _predicted_bell_wave.duplicate()

func get_tile_display_override(cell: Vector2i) -> Dictionary:
	return _tile_display_overrides.get(cell, {}).duplicate(true)

func get_unit_display_override(unit_id: int) -> Dictionary:
	return _unit_display_overrides.get(unit_id, {}).duplicate(true)

func get_unit_visual_position(unit_id: int) -> Vector2:
	return _unit_visual_positions.get(unit_id, Vector2.INF)

func has_unit_visual_position(unit_id: int) -> bool:
	return _unit_visual_positions.has(unit_id)

func cell_to_pixel(cell: Vector2i, height: float = 0.0) -> Vector2:
	return BOARD_ORIGIN + Vector2(
		float(cell.x - cell.y) * TILE_HALF.x,
		float(cell.x + cell.y) * TILE_HALF.y - height
	)

func pixel_to_cell(local_pos: Vector2) -> Vector2i:
	var p := local_pos - BOARD_ORIGIN
	var gx := (p.x / TILE_HALF.x + p.y / TILE_HALF.y) * 0.5
	var gy := (p.y / TILE_HALF.y - p.x / TILE_HALF.x) * 0.5
	var candidates := [
		Vector2i(floori(gx), floori(gy)),
		Vector2i(roundi(gx), roundi(gy)),
		Vector2i(floori(gx), ceili(gy)),
		Vector2i(ceili(gx), floori(gy)),
		Vector2i(ceili(gx), ceili(gy)),
	]
	for cell in candidates:
		if not _cell_in_bounds(cell):
			continue
		var poly := _diamond(cell_to_pixel(cell))
		if Geometry2D.is_point_in_polygon(local_pos, poly):
			return cell
	return INVALID_CELL

func _draw() -> void:
	if _state == null or _state.grid == null:
		return
	_draw_board_shadow()
	_draw_board_slab()
	_draw_tiles()
	_draw_overlays()
	_draw_entities()
	_draw_attack_fx()
	_draw_preview()

func _draw_board_shadow() -> void:
	var top := _board_top_polygon()
	var shadow := PackedVector2Array()
	for p in top:
		shadow.append(p + Vector2(22, SLAB_DEPTH + 24))
	draw_colored_polygon(shadow, COLOR_BOARD_SHADOW)
	var mid_shadow := PackedVector2Array()
	for p in top:
		mid_shadow.append(p + Vector2(12, SLAB_DEPTH + 14))
	draw_colored_polygon(mid_shadow, Color(0, 0, 0, 0.34))
	var close_shadow := PackedVector2Array()
	for p in top:
		close_shadow.append(p + Vector2(4, SLAB_DEPTH + 7))
	draw_colored_polygon(close_shadow, Color(0, 0, 0, 0.26))

func _draw_board_slab() -> void:
	var top := _board_top_polygon()
	var down := Vector2(0, SLAB_DEPTH)
	draw_colored_polygon(PackedVector2Array([top[1], top[2], top[2] + down, top[1] + down]), COLOR_BOARD_SIDE_R)
	draw_colored_polygon(PackedVector2Array([top[2], top[3], top[3] + down, top[2] + down]), COLOR_BOARD_SIDE_L)
	draw_colored_polygon(PackedVector2Array([top[0], top[1], top[2], top[3]]), COLOR_BOARD_UNDER)
	_draw_edge_faces()
	draw_line(top[3], top[0], COLOR_BOARD_RIM_LIGHT, 2.0)
	draw_line(top[0], top[1], COLOR_BOARD_RIM_LIGHT, 2.0)
	draw_line(top[1], top[2], COLOR_BOARD_RIM_DARK, 3.0)
	draw_line(top[2], top[3], COLOR_BOARD_RIM_DARK, 3.0)

func _draw_edge_faces() -> void:
	var down := Vector2(0, SLAB_DEPTH)
	for y in Grid.SIZE:
		var right := _diamond(cell_to_pixel(Vector2i(Grid.SIZE - 1, y)))
		var tint := 0.05 * float(y % 2)
		draw_colored_polygon(
			PackedVector2Array([right[1], right[2], right[2] + down, right[1] + down]),
			COLOR_BOARD_SIDE_R.lightened(tint)
		)
		draw_line(right[1] + down, right[2] + down, Color(0, 0, 0, 0.26), 1.0)
		draw_line(right[2], right[2] + down, Color(0, 0, 0, 0.32), 1.0)
	for x in Grid.SIZE:
		var front := _diamond(cell_to_pixel(Vector2i(x, Grid.SIZE - 1)))
		var tint := 0.05 * float(x % 2)
		draw_colored_polygon(
			PackedVector2Array([front[2], front[3], front[3] + down, front[2] + down]),
			COLOR_BOARD_SIDE_L.lightened(tint)
		)
		draw_line(front[3] + down, front[2] + down, Color(0, 0, 0, 0.26), 1.0)
		draw_line(front[3], front[3] + down, Color(0, 0, 0, 0.34), 1.0)

func _draw_tiles() -> void:
	_draw_floor_tiles()
	var deploy_lookup := {}
	if _state.phase == BattleState.Phase.GARRISON:
		for cell in _state.deploy_zone:
			if _is_available_deploy_cell(cell):
				deploy_lookup[cell] = true
	for cell in _sorted_cells():
		var center := cell_to_pixel(cell)
		var top := _diamond(center)
		var deploy := deploy_lookup.has(cell)
		if _display_tile(cell) == Grid.TileType.RIFT or deploy:
			_draw_tile_surface(cell, deploy)
		_draw_tile_decals(cell)
		draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), COLOR_GRID_GROUT, 1.0)
		draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), COLOR_GRID_LINE, 1.0)

func _draw_floor_tiles() -> void:
	if _floor_variants_texture == null:
		_draw_floor_map_fallback()
		return
	for cell in _sorted_cells():
		_draw_floor_variant(cell)

func _draw_floor_variant(cell: Vector2i) -> void:
	var variant := _floor_variant_for_cell(cell)
	var source := Rect2(
		Vector2(float(variant % FLOOR_VARIANT_COLUMNS) * TILE_W, float(variant / FLOOR_VARIANT_COLUMNS) * TILE_H),
		Vector2(TILE_W, TILE_H)
	)
	var center := cell_to_pixel(cell)
	var rect := Rect2(center - TILE_HALF, Vector2(TILE_W, TILE_H))
	draw_texture_rect_region(_floor_variants_texture, rect, source)

func _draw_floor_map_fallback() -> void:
	if _floor_map_texture == null:
		return
	var rect := Rect2(BOARD_ORIGIN - Vector2(BOARD_TOP_MAP_SIZE.x * 0.5, TILE_HALF.y), BOARD_TOP_MAP_SIZE)
	draw_texture_rect(_floor_map_texture, rect, false)

func _load_floor_map_texture() -> Texture2D:
	return _load_png_texture(FLOOR_MAP_PATH)

func _load_png_texture(path: String) -> Texture2D:
	var image := Image.new()
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty() or image.load_png_from_buffer(bytes) != OK:
		var imported := load(path)
		if imported is Texture2D:
			return imported
		push_warning("Failed to load texture: %s" % path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(image)

func _draw_tile_surface(cell: Vector2i, deploy: bool) -> void:
	var center := cell_to_pixel(cell)
	var top := _diamond(center)
	var tile: int = _display_tile(cell)
	var base := _tile_base_color(cell, deploy)
	if tile == Grid.TileType.RIFT:
		base = base.lerp(Color(0.06, 0.18, 0.22), 0.62)
	_draw_tile_texture(top, cell, tile, deploy, base)
	if tile == Grid.TileType.RIFT:
		_draw_rift_tile_detail(center)

func _draw_tile_texture(top: PackedVector2Array, cell: Vector2i, tile: int, deploy: bool, fallback: Color) -> void:
	draw_colored_polygon(top, fallback)
	var texture := _tile_texture(tile, deploy)
	if texture == null:
		return
	var tint := _tile_texture_tint(cell, tile, deploy)
	draw_polygon(
		top,
		PackedColorArray([tint, tint, tint, tint]),
		_tile_texture_uvs(tile, deploy),
		texture
	)

func _tile_texture(tile: int, deploy: bool) -> Texture2D:
	if tile == Grid.TileType.RIFT:
		return TEX_RIFT_FLOOR
	if deploy:
		return TEX_DEPLOY_FLOOR
	return null

func _tile_texture_tint(cell: Vector2i, tile: int, deploy: bool) -> Color:
	if deploy:
		return Color(0.54, 0.86, 0.84, 0.24)
	if tile == Grid.TileType.RIFT:
		return Color(1.04, 1.10, 1.12, 0.96)
	return Color(1, 1, 1, 1)

func _tile_texture_uvs(tile: int, deploy: bool) -> PackedVector2Array:
	if deploy or tile == Grid.TileType.RIFT:
		return PackedVector2Array([SPECIAL_TEX_TOP, SPECIAL_TEX_RIGHT, SPECIAL_TEX_BOTTOM, SPECIAL_TEX_LEFT])
	return PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])

func _tile_base_color(cell: Vector2i, deploy: bool) -> Color:
	var color := COLOR_TILE_A if (cell.x + cell.y) % 2 == 0 else COLOR_TILE_B
	var row_t := float(cell.y) / float(maxi(1, Grid.SIZE - 1))
	color = color.lightened(row_t * 0.040)
	if deploy:
		color = color.lerp(Color(0.07, 0.20, 0.20), 0.08)
	return color

func _draw_rift_tile_detail(center: Vector2) -> void:
	draw_line(center + Vector2(-22, 2), center + Vector2(18, -7), Color(0.10, 1.0, 1.0, 0.40), 2.0)
	draw_line(center + Vector2(-9, -17), center + Vector2(9, 17), Color(0.10, 0.70, 1.0, 0.34), 1.5)
	_draw_ellipse(center + Vector2(0, 4), Vector2(26, 8), Color(0.0, 0.95, 1.0, 0.12))

func _draw_tile_decals(cell: Vector2i) -> void:
	var center := cell_to_pixel(cell)
	var noise := _cell_noise(cell, 509)
	if noise < 0.34:
		draw_line(center + Vector2(-27, -3), center + Vector2(-10, -12), COLOR_TILE_DECAL_LIGHT, 1.0)
		draw_line(center + Vector2(-10, -12), center + Vector2(5, -8), COLOR_TILE_DECAL_DARK, 1.0)
		draw_line(center + Vector2(7, 11), center + Vector2(28, 1), COLOR_TILE_DECAL_DARK, 1.0)
	elif noise < 0.68:
		draw_line(center + Vector2(-18, 7), center + Vector2(0, 13), COLOR_TILE_DECAL_DARK, 1.0)
		draw_line(center + Vector2(0, 13), center + Vector2(19, 5), COLOR_TILE_DECAL_LIGHT, 1.0)
		_draw_ellipse(center + Vector2(13, -5), Vector2(4, 1.2), COLOR_TILE_DECAL_LIGHT)
	else:
		var chip := _diamond_scaled(center + Vector2(15, 2), 0.13, 0.11)
		draw_colored_polygon(chip, COLOR_TILE_DECAL_DARK)
		draw_line(center + Vector2(-22, 0), center + Vector2(-9, 7), COLOR_TILE_DECAL_LIGHT, 1.0)
		draw_line(center + Vector2(-15, 9), center + Vector2(1, 15), COLOR_TILE_DECAL_LIGHT, 1.0)

func _cell_noise(cell: Vector2i, salt: int) -> float:
	var value := sin(float(cell.x * 37 + cell.y * 71 + salt * 113)) * 43758.5453
	return value - floor(value)

func _floor_variant_for_cell(cell: Vector2i) -> int:
	return int(floor(_cell_noise(cell, 211) * float(FLOOR_VARIANT_COUNT))) % FLOOR_VARIANT_COUNT

func _draw_overlays() -> void:
	if _state.phase == BattleState.Phase.GARRISON:
		for cell in _state.deploy_zone:
			if _is_available_deploy_cell(cell):
				_draw_deploy_cell(cell)
	for cell in _move_cells:
		_fill_diamond(cell, COLOR_MOVE, true, 1.1)
	for cell in _attack_cells:
		_fill_diamond(cell, COLOR_ATTACK, true, 2.0)
	for cell in _predicted_rifts:
		var pulse := 0.72 + 0.28 * sin(_pulse_t * 4.0)
		var color := COLOR_RIFT_WARN
		color.a *= pulse
		_fill_diamond(cell, color)
		_draw_label_at(cell_to_pixel(cell) + Vector2(0, 6), "!", 22, Color(1, 0.92, 0.52, pulse))
	for cell in _predicted_cracked_ground:
		_draw_cracked_ground_warning(cell)
	for cell in _predicted_bell_wave:
		_draw_bell_wave_warning(cell)
	_draw_abyss_edges()
	if not _attack_fx_suppresses_intents:
		var order_index := _enemy_order_index()
		for row in _enemy_intents:
			_draw_enemy_intent_row(row, order_index)
	if _cell_in_bounds(_hover_cell):
		_fill_diamond(_hover_cell, COLOR_HOVER, false, 2.5)

func _draw_cracked_ground_warning(cell: Vector2i) -> void:
	if not _cell_in_bounds(cell):
		return
	var pulse := 0.70 + 0.30 * sin(_pulse_t * 5.4)
	var fill := COLOR_CRACKED_GROUND
	fill.a *= pulse
	_fill_diamond(cell, fill, true, 1.4)
	var center := cell_to_pixel(cell)
	var frame := COLOR_CRACKED_GROUND_FRAME
	frame.a *= pulse
	var crack_dark := COLOR_INTENT_UNDERSTROKE
	crack_dark.a = 0.74 * pulse
	var crack_hot := COLOR_CRACKED_GROUND_FRAME
	crack_hot.a = 0.92 * pulse
	var points := [
		[center + Vector2(-25, -3), center + Vector2(-10, 2), center + Vector2(1, -7), center + Vector2(18, -2)],
		[center + Vector2(-14, 13), center + Vector2(-3, 5), center + Vector2(11, 10), center + Vector2(26, 3)],
		[center + Vector2(-2, -17), center + Vector2(3, -6), center + Vector2(-4, 4), center + Vector2(4, 17)],
	]
	for path in points:
		draw_polyline(PackedVector2Array(path), crack_dark, 3.2)
		draw_polyline(PackedVector2Array(path), crack_hot, 1.3)
	var inner := _diamond_scaled(center, 0.72, 0.72)
	draw_polyline(PackedVector2Array([inner[0], inner[1], inner[2], inner[3], inner[0]]), frame, 1.5)

func _draw_bell_wave_warning(cell: Vector2i) -> void:
	if not _cell_in_bounds(cell):
		return
	var pulse := 0.68 + 0.32 * sin(_pulse_t * 4.8)
	var fill := COLOR_BELL_WAVE
	fill.a *= pulse
	_fill_diamond(cell, fill, true, 1.3)
	var center := cell_to_pixel(cell)
	var frame := COLOR_BELL_WAVE_FRAME
	frame.a *= pulse
	var ring_a := _diamond_scaled(center, 0.84, 0.84)
	var ring_b := _diamond_scaled(center, 0.54, 0.54)
	draw_polyline(PackedVector2Array([ring_a[0], ring_a[1], ring_a[2], ring_a[3], ring_a[0]]), COLOR_INTENT_UNDERSTROKE, 3.0)
	draw_polyline(PackedVector2Array([ring_a[0], ring_a[1], ring_a[2], ring_a[3], ring_a[0]]), frame, 1.4)
	frame.a *= 0.72
	draw_polyline(PackedVector2Array([ring_b[0], ring_b[1], ring_b[2], ring_b[3], ring_b[0]]), frame, 1.1)
	var chime := COLOR_BELL_WAVE_FRAME
	chime.a = 0.66 * pulse
	draw_line(center + Vector2(-18, 0), center + Vector2(18, 0), chime, 1.2)
	draw_line(center + Vector2(0, -12), center + Vector2(0, 13), chime, 1.2)

func _is_available_deploy_cell(cell: Vector2i) -> bool:
	if _state == null or _state.grid == null:
		return false
	if _state.phase != BattleState.Phase.GARRISON:
		return false
	if not _cell_in_bounds(cell):
		return false
	if not _state.deploy_zone.has(cell):
		return false
	if _state.get_unit_at(cell) != null:
		return false
	return not _state.grid.blocks_movement(cell)

func _draw_deploy_cell(cell: Vector2i) -> void:
	var center := cell_to_pixel(cell)
	var pulse := 0.76 + 0.24 * sin(_pulse_t * 3.6 + float(cell.x + cell.y) * 0.24)
	var fill := COLOR_DEPLOY
	fill.a *= pulse
	_fill_diamond(cell, fill, true, 1.0)
	var inner := _diamond_scaled(center, 0.70, 0.70)
	var inner_color := COLOR_DEPLOY_INNER
	inner_color.a *= pulse
	draw_colored_polygon(inner, inner_color)
	var frame := COLOR_DEPLOY_FRAME
	frame.a *= pulse
	draw_polyline(PackedVector2Array([inner[0], inner[1], inner[2], inner[3], inner[0]]), frame, 1.6)
	var corner := COLOR_DEPLOY_CORNER
	corner.a *= pulse
	var top := _diamond(center)
	var inset := 12.0
	draw_line(top[3].lerp(top[0], 0.18), top[3].lerp(top[0], 0.18) + Vector2(inset, -inset * 0.34), corner, 1.8)
	draw_line(top[1].lerp(top[2], 0.18), top[1].lerp(top[2], 0.18) + Vector2(-inset, inset * 0.34), corner, 1.8)

func _has_visible_deploy_overlay() -> bool:
	if _state == null or _state.phase != BattleState.Phase.GARRISON:
		return false
	for raw_cell in _state.deploy_zone.keys():
		if _is_available_deploy_cell(raw_cell):
			return true
	return false

func _draw_abyss_edges() -> void:
	if _state == null or _state.abyss_edges.is_empty():
		return
	var pulse := 0.82 + 0.18 * sin(_pulse_t * 3.2)
	for raw_cell in _state.abyss_edges.keys():
		var cell: Vector2i = raw_cell
		if not _cell_in_bounds(cell):
			continue
		var dirs: Dictionary = _state.abyss_edges.get(cell, {})
		for raw_dir in dirs.keys():
			var direction: Vector2i = raw_dir
			_draw_abyss_edge(cell, direction, pulse)

func _draw_abyss_edge(cell: Vector2i, direction: Vector2i, pulse: float) -> void:
	var edge := _diamond_edge_for_direction(cell, direction)
	if edge.is_empty():
		return
	var normal := _screen_normal_for_direction(direction)
	var shadow_a: Vector2 = edge[0] + normal * 7.0
	var shadow_b: Vector2 = edge[1] + normal * 7.0
	draw_line(shadow_a, shadow_b, COLOR_ABYSS_EDGE_SHADOW, 7.0)
	var color := COLOR_ABYSS_EDGE
	color.a *= pulse
	draw_line(edge[0], edge[1], COLOR_INTENT_UNDERSTROKE, 5.2)
	draw_line(edge[0], edge[1], color, 2.6)
	var tick_color := color
	tick_color.a *= 0.78
	for t in [0.28, 0.50, 0.72]:
		var base: Vector2 = edge[0].lerp(edge[1], t)
		draw_line(base, base + normal * 9.0, tick_color, 1.5)

func _diamond_edge_for_direction(cell: Vector2i, direction: Vector2i) -> Array:
	var poly := _diamond(cell_to_pixel(cell))
	if direction == Vector2i(0, -1):
		return [poly[3], poly[0]]
	if direction == Vector2i(1, 0):
		return [poly[0], poly[1]]
	if direction == Vector2i(0, 1):
		return [poly[1], poly[2]]
	if direction == Vector2i(-1, 0):
		return [poly[2], poly[3]]
	return []

func _screen_normal_for_direction(direction: Vector2i) -> Vector2:
	var v := Vector2(float(direction.x - direction.y) * TILE_HALF.x, float(direction.x + direction.y) * TILE_HALF.y)
	if v.length_squared() < 0.001:
		return Vector2.ZERO
	return v.normalized()

func _draw_attack_fx() -> void:
	for layer in _attack_fx_layers:
		var from_cell: Vector2i = layer.get("from_cell", INVALID_CELL)
		var to_cell: Vector2i = layer.get("to_cell", INVALID_CELL)
		if not _cell_in_bounds(from_cell) or not _cell_in_bounds(to_cell):
			continue
		match String(layer.get("phase", "impact")):
			"action":
				_draw_attack_action(layer, from_cell, to_cell)
			"muzzle":
				_draw_attack_muzzle(layer, from_cell, to_cell)
			"projectile":
				_draw_projectile_action(layer, from_cell, to_cell, false)
			"tether":
				_draw_tether_action(layer, from_cell, to_cell)
			"slash":
				_draw_melee_action(layer, from_cell, to_cell, true)
			"strike":
				_draw_melee_action(layer, from_cell, to_cell, false)
			"dust":
				_draw_attack_dust(layer, from_cell, to_cell)
			"impact":
				_draw_attack_impact(layer, from_cell, to_cell)

func _draw_attack_action(layer: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var attack_kind := int(layer.get("attack_kind", UnitDef.AttackKind.MELEE_BUMP))
	match attack_kind:
		UnitDef.AttackKind.RANGED_PUSH:
			_draw_projectile_action(layer, from_cell, to_cell, false)
		UnitDef.AttackKind.RANGED_PULL:
			_draw_tether_action(layer, from_cell, to_cell)
		UnitDef.AttackKind.MELEE_PUSH:
			_draw_melee_action(layer, from_cell, to_cell, true)
		_:
			_draw_melee_action(layer, from_cell, to_cell, false)

func _draw_attack_impact(layer: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var progress := clampf(float(layer.get("progress", 1.0)), 0.0, 1.0)
	var hit_anchor := _attack_fx_target_anchor(to_cell)
	var pulse := clampf(1.0 - absf(progress - 0.28) * 1.08, 0.24, 1.0)
	_draw_attack_target_reticle(hit_anchor, 0.38 * (1.0 - progress * 0.35) + 0.16 * pulse)
	_draw_attack_vfx_frame(FX_SEQUENCE_IMPACT, hit_anchor, 0.0, 0.74 + 0.12 * sin(progress * PI), _fx_alpha(0.72 * pulse), progress)
	_draw_tactical_impact(hit_anchor, progress, pulse * 0.68)

func _draw_attack_muzzle(layer: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var from_px := _attack_fx_muzzle_anchor(from_cell)
	var to_px := _attack_fx_target_anchor(to_cell)
	var delta := to_px - from_px
	if delta.length_squared() < 0.001:
		return
	var progress := clampf(float(layer.get("progress", 1.0)), 0.0, 1.0)
	var dir := delta.normalized()
	var center := from_px + dir * 20.0
	var alpha := 0.92 * (1.0 - progress * 0.45)
	_draw_tactical_muzzle_tick(center, dir, alpha)

func _draw_projectile_action(layer: Dictionary, from_cell: Vector2i, to_cell: Vector2i, _heavy: bool) -> void:
	var from_px := _attack_fx_muzzle_anchor(from_cell)
	var to_px := _attack_fx_target_anchor(to_cell)
	var delta := to_px - from_px
	if delta.length_squared() < 0.001:
		return
	var progress := clampf(float(layer.get("progress", 1.0)), 0.0, 1.0)
	var dir := delta.normalized()
	var normal := dir.rotated(PI * 0.5)
	var arc_lift := sin(progress * PI) * 12.0
	var start := from_px + dir * 24.0
	var end_pt := to_px - dir * 18.0
	var head := start.lerp(end_pt, progress)
	head.y -= arc_lift
	var tail_progress := maxf(0.0, progress - 0.22)
	var tail := start.lerp(end_pt, tail_progress)
	tail.y -= sin(tail_progress * PI) * 12.0
	var active_tail := head - dir * (34.0 + 8.0 * sin(progress * PI))
	if progress < 0.24:
		active_tail = tail
	var bolt_alpha := clampf(0.42 + 0.30 * sin(progress * PI), 0.0, 0.72)
	var sprite_alpha := clampf(0.58 + 0.30 * sin(progress * PI), 0.0, 0.88)
	var sprite_scale := Vector2(1.02 + 0.12 * sin(progress * PI), 0.56)
	var sprite_center := active_tail.lerp(head, 0.58)
	if not _draw_attack_vfx_frame(FX_SEQUENCE_PROJECTILE, sprite_center, dir.angle(), sprite_scale, _fx_alpha(sprite_alpha), progress):
		_draw_tactical_projectile(active_tail, head, normal, bolt_alpha)
	else:
		_draw_attack_vfx_frame(
			FX_SEQUENCE_PROJECTILE,
			active_tail.lerp(head, 0.25),
			dir.angle(),
			Vector2(sprite_scale.x * 0.58, sprite_scale.y * 0.86),
			_fx_alpha(sprite_alpha * 0.50),
			fmod(progress + 0.37, 1.0)
		)
		_draw_projectile_afterimage(active_tail, head, normal, bolt_alpha * 0.42)
	if progress < 0.18:
		_draw_muzzle_burst(from_px + dir * 22.0, dir, (0.18 - progress) / 0.18)
	if progress > 0.46:
		var reticle_alpha := (progress - 0.46) / 0.54
		_draw_attack_target_reticle(to_px, 0.14 + reticle_alpha * 0.32)
	if progress > 0.80:
		var impact := COLOR_ATTACK_BONE
		impact.a = (progress - 0.80) / 0.20 * 0.46
		_draw_air_impact_hint(to_px, impact, dir)

func _draw_tether_action(layer: Dictionary, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var from_px := _attack_fx_muzzle_anchor(from_cell)
	var to_px := _attack_fx_target_anchor(to_cell)
	var delta := to_px - from_px
	if delta.length_squared() < 0.001:
		return
	var progress := clampf(float(layer.get("progress", 1.0)), 0.0, 1.0)
	var dir := delta.normalized()
	var start := from_px + dir * 24.0
	var reach := start.lerp(to_px - dir * 18.0, progress)
	var color := COLOR_ATTACK_DUST.lerp(COLOR_ATTACK_AMBER, 0.42)
	color.a = 0.36 + 0.30 * progress
	var under := COLOR_ATTACK_IRON
	under.a = 0.70
	draw_line(start, reach, under, 7.0)
	if _attack_vfx_sheet_texture != null:
		_draw_tether_vfx_strip(start, reach, dir, color, progress)
	else:
		draw_line(start, reach, color, 2.6)
	var hook := COLOR_ATTACK_DUST.lerp(COLOR_ATTACK_AMBER, 0.28)
	hook.a = 0.58 * progress
	draw_circle(reach, 4.5 + 2.0 * progress, hook)

func _draw_melee_action(layer: Dictionary, from_cell: Vector2i, to_cell: Vector2i, forceful: bool) -> void:
	var from_px := _attack_fx_muzzle_anchor(from_cell)
	var to_px := _attack_fx_target_anchor(to_cell)
	var delta := to_px - from_px
	if delta.length_squared() < 0.001:
		return
	var progress := clampf(float(layer.get("progress", 1.0)), 0.0, 1.0)
	var dir := delta.normalized()
	var normal := dir.rotated(PI * 0.5)
	var center := to_px - dir * (24.0 - 10.0 * progress)
	var reach := 24.0 + 14.0 * progress
	var color := COLOR_EXECUTE_CONFIRM
	color.a = 0.34 + 0.34 * progress
	var a := center - normal * reach * 0.62 - dir * 5.0
	var b := center + normal * reach * 0.62 + dir * 5.0
	var under := COLOR_ATTACK_IRON
	under.a = 0.78
	draw_line(a, b, under, 7.0 if forceful else 5.0)
	if not _draw_attack_vfx_frame(FX_SEQUENCE_SLASH, center, dir.angle(), 0.66 + 0.12 * sin(progress * PI), _fx_alpha(minf(0.86, color.a + 0.12)), progress):
		draw_line(a, b, color, 3.6 if forceful else 2.6)

func _draw_attack_dust(layer: Dictionary, _from_cell: Vector2i, to_cell: Vector2i) -> void:
	var progress := clampf(float(layer.get("progress", 1.0)), 0.0, 1.0)
	var center := _attack_fx_target_anchor(to_cell) + Vector2(0, 6)
	var direction: Vector2i = layer.get("direction", Vector2i.ZERO)
	var color := COLOR_ATTACK_DUST
	color.a = 0.14 * (1.0 - progress)
	_draw_attack_vfx_frame(FX_SEQUENCE_DUST, center, 0.0, 0.54 + 0.08 * progress, _fx_alpha(0.34 * (1.0 - progress * 0.55)), progress)
	_draw_attack_settle_scratches(center, direction, color, progress)

func _draw_entities() -> void:
	var unit_ids_by_cell := {}
	var unit_drawables: Array = []
	for unit in _state.units:
		if unit.def == null or (not _display_unit_alive(unit) and not has_unit_visual_position(unit.id)):
			continue
		var key := _unit_draw_cell(unit)
		unit_drawables.append(_unit_drawable(unit, key))
		unit_ids_by_cell[unit.id] = true
	for unit_id in _unit_visual_units.keys():
		if unit_ids_by_cell.has(unit_id):
			continue
		var visual_unit: Unit = _unit_visual_units[unit_id]
		if visual_unit == null or visual_unit.def == null:
			continue
		if not _display_unit_alive(visual_unit) and not has_unit_visual_position(visual_unit.id):
			continue
		var key := _unit_draw_cell(visual_unit)
		unit_drawables.append(_unit_drawable(visual_unit, key))

	var drawables: Array = []
	var overlay_drawables: Array = []
	var order := _enemy_order_index()
	for cell in _sorted_cells():
		_draw_prop_footprint_at_cell(cell)
		var prop := _prop_drawable(cell)
		if not prop.is_empty():
			drawables.append(prop)
			if prop.has("hp"):
				overlay_drawables.append({
					"kind": "building_hp",
					"sort_y": float(prop.sort_y) + 0.02,
					"sequence": int(prop.sequence),
					"origin": prop.get("hp_origin", cell_to_pixel(cell) + BUILDING_HP_BAR_OFFSET),
					"hp": int(prop.hp),
					"preview_damage": int(prop.preview_damage),
				})
	for drawable in unit_drawables:
		drawable["order_badge"] = int(order.get(drawable.unit.id, 0))
		drawables.append(drawable)
	drawables.sort_custom(_sort_entity_drawables)
	for drawable in drawables:
		match String(drawable.get("kind", "")):
			"prop":
				_draw_prop_drawable(drawable)
			"unit":
				_draw_unit_drawable(drawable)
	overlay_drawables.sort_custom(_sort_entity_drawables)
	for drawable in overlay_drawables:
		if String(drawable.get("kind", "")) == "building_hp":
			_draw_segmented_hp_bar(drawable.origin, int(drawable.hp), BUILDING_HP_MAX_SEGMENTS, COLOR_BUILDING_HP_FILL, int(drawable.preview_damage))

func _sort_entity_drawables(a: Dictionary, b: Dictionary) -> bool:
	var ay := float(a.get("sort_y", 0.0))
	var by := float(b.get("sort_y", 0.0))
	if not is_equal_approx(ay, by):
		return ay < by
	var acell: Vector2i = a.get("cell", INVALID_CELL)
	var bcell: Vector2i = b.get("cell", INVALID_CELL)
	if acell.x + acell.y != bcell.x + bcell.y:
		return acell.x + acell.y < bcell.x + bcell.y
	if acell.x != bcell.x:
		return acell.x < bcell.x
	return int(a.get("sequence", 0)) < int(b.get("sequence", 0))

func _display_unit_alive(unit: Unit) -> bool:
	if unit == null:
		return false
	var display: Dictionary = _unit_display_overrides.get(unit.id, {})
	if display.has("alive"):
		return bool(display.get("alive", unit.alive))
	return unit.alive

func _display_unit_hp(unit: Unit) -> int:
	if unit == null:
		return 0
	var display: Dictionary = _unit_display_overrides.get(unit.id, {})
	if display.has("hp"):
		return int(display.get("hp", unit.hp))
	return unit.hp

func _unit_draw_cell(unit: Unit) -> Vector2i:
	if unit != null and _unit_visual_positions.has(unit.id):
		var visual_cell := pixel_to_cell(_unit_visual_positions[unit.id])
		if _cell_in_bounds(visual_cell):
			return visual_cell
	return unit.position if unit != null else INVALID_CELL

func _prop_drawable(cell: Vector2i) -> Dictionary:
	var tile: int = _display_tile(cell)
	var profile := BattleBoardAssetProfilesScript.prop_profile_for_tile(tile, _board_asset_profiles)
	if profile.is_empty():
		return {}
	var texture := _prop_texture_for_tile(tile)
	if texture == null:
		return {}
	var foot_offset: Vector2 = profile.get("foot_offset", PROP_TILE_ANCHOR_OFFSET)
	var anchor: Vector2 = cell_to_pixel(cell) + foot_offset
	var sequence := cell.y * Grid.SIZE + cell.x
	var result := {
		"kind": "prop",
		"cell": cell,
		"tile": tile,
		"profile": profile,
		"texture": texture,
		"anchor": anchor,
		"sort_y": anchor.y + float(profile.get("sort_bias", 0.0)),
		"sequence": sequence,
	}
	if tile == Grid.TileType.BUILDING:
		result["hp"] = _display_tile_hp(cell, Grid.DEFAULT_BUILDING_HP)
		result["preview_damage"] = int(_preview_protected_damage.get(cell, 0))
		result["hp_origin"] = cell_to_pixel(cell) + profile.get("hp_offset", BUILDING_HP_BAR_OFFSET)
	return result

func _unit_drawable(unit: Unit, cell: Vector2i) -> Dictionary:
	var unit_pixel: Vector2 = _unit_visual_positions.get(unit.id, cell_to_pixel(unit.position))
	var foot := unit_pixel + Vector2(0, UNIT_GROUND_Y) + UNIT_TOKEN_OFFSET
	return {
		"kind": "unit",
		"cell": cell,
		"unit": unit,
		"foot": foot,
		"sort_y": foot.y,
		"sequence": 10000 + unit.id,
	}

func _draw_prop_at_cell(cell: Vector2i) -> void:
	_draw_prop_footprint_at_cell(cell)
	var drawable := _prop_drawable(cell)
	if not drawable.is_empty():
		_draw_prop_drawable(drawable)
	if drawable.has("hp"):
		_draw_segmented_hp_bar(drawable.get("hp_origin", cell_to_pixel(cell) + BUILDING_HP_BAR_OFFSET), int(drawable.hp), BUILDING_HP_MAX_SEGMENTS, COLOR_BUILDING_HP_FILL, int(drawable.preview_damage))

func _draw_prop_footprint_at_cell(cell: Vector2i) -> void:
	var tile: int = _display_tile(cell)
	var profile := BattleBoardAssetProfilesScript.prop_profile_for_tile(tile, _board_asset_profiles)
	if not profile.is_empty():
		_draw_prop_foundation(cell, profile)

func _draw_prop_drawable(drawable: Dictionary) -> void:
	var texture: Texture2D = drawable.get("texture", null)
	var profile: Dictionary = drawable.get("profile", {})
	if texture == null or profile.is_empty():
		return
	var anchor: Vector2 = drawable.get("anchor", Vector2.ZERO)
	var crop: Rect2 = profile.get("crop", profile.get("fallback_crop", Rect2()))
	var tint: Color = profile.get("tint", Color(0.78, 0.80, 0.76, 0.76))
	var rect := BattleBoardAssetProfilesScript.profile_draw_rect(anchor, profile)
	draw_texture_rect_region(texture, rect, crop, tint)

func _prop_texture_for_tile(tile: int) -> Texture2D:
	match tile:
		Grid.TileType.PILLAR:
			return TEX_PILLAR
		Grid.TileType.BUILDING:
			return TEX_BUILDING
		Grid.TileType.RUIN:
			return TEX_RUIN
	return null

func _draw_props() -> void:
	for cell in _sorted_cells():
		_draw_prop_at_cell(cell)

func _display_tile(cell: Vector2i) -> int:
	var display: Dictionary = _tile_display_overrides.get(cell, {})
	if display.has("tile"):
		return int(display.get("tile", Grid.TileType.EMPTY))
	return _state.grid.get_tile(cell)

func _display_tile_hp(cell: Vector2i, fallback: int) -> int:
	var display: Dictionary = _tile_display_overrides.get(cell, {})
	if display.has("hp"):
		return int(display.get("hp", fallback))
	return int(_state.grid.tile_hp.get(cell, fallback))

func _draw_prop_foundation(cell: Vector2i, profile: Dictionary) -> void:
	var cell_center := cell_to_pixel(cell)
	var foot_offset: Vector2 = profile.get("foot_offset", PROP_TILE_ANCHOR_OFFSET)
	var foundation_scale: Vector2 = profile.get("foundation_scale", Vector2(0.70, 0.40))
	var foundation_offset: Vector2 = profile.get("foundation_offset", Vector2(0, 6))
	var floor_strength := clampf(float(profile.get("floor_occlusion_strength", 0.34)), 0.0, 1.0)
	var shadow_strength := clampf(float(profile.get("contact_shadow_strength", 0.48)), 0.0, 1.0)
	var foot := cell_center + foot_offset
	var center := foot + foundation_offset

	var tile_color := _tile_base_color(cell, false)
	var embedded_fill := tile_color.darkened(0.18)
	embedded_fill.a = PROP_FOUNDATION_FILL.a * floor_strength
	draw_colored_polygon(_diamond_scaled(center + Vector2(0, 2), foundation_scale.x * 0.84, foundation_scale.y * 0.54), embedded_fill)

	var floor_occlusion := PROP_FLOOR_OCCLUSION
	floor_occlusion.a *= floor_strength * 0.58
	draw_colored_polygon(_diamond_scaled(center + Vector2(0, 4), foundation_scale.x * 0.92, foundation_scale.y * 0.46), floor_occlusion)

	var ambient_contact := PROP_CONTACT_SHADOW
	ambient_contact.a *= shadow_strength * 0.76
	draw_colored_polygon(_diamond_scaled(foot + Vector2(0, 2), foundation_scale.x * 0.52, foundation_scale.y * 0.20), ambient_contact)

	var core_contact := PROP_CONTACT_SHADOW
	core_contact.a *= minf(1.0, shadow_strength + 0.18)
	draw_colored_polygon(_diamond_scaled(foot + Vector2(0, 1), foundation_scale.x * 0.34, foundation_scale.y * 0.12), core_contact)
	_draw_prop_contact_edges(cell, center, foundation_scale, floor_strength, shadow_strength)
	_draw_prop_foundation_rubble(cell, center, foundation_scale, shadow_strength)

func _draw_prop_contact_edges(cell: Vector2i, center: Vector2, scale: Vector2, floor_strength: float, shadow_strength: float) -> void:
	var left_span := TILE_HALF.x * scale.x
	var half_height := TILE_HALF.y * scale.y
	var lit := PROP_FOUNDATION_LIT
	lit.a *= floor_strength
	var dark := PROP_FOUNDATION_DARK
	dark.a *= shadow_strength
	var seam := Color(0.0, 0.0, 0.0, 0.20 * shadow_strength)
	var front := center + Vector2(0, half_height * 0.78)
	var left := center + Vector2(-left_span * 0.56, half_height * 0.18)
	var right := center + Vector2(left_span * 0.56, half_height * 0.18)
	draw_line(left, front, seam, 2.2)
	draw_line(front, right, seam, 2.2)
	draw_line(left + Vector2(1, -1), front + Vector2(1, -1), lit, 0.9)
	draw_line(front, right, dark, 1.0)

	for i in range(3):
		var n := _cell_noise(cell, 661 + i * 23)
		var side := -1.0 if i != 1 else 1.0
		var start := center + Vector2(side * left_span * (0.14 + 0.14 * n), half_height * (0.08 + 0.20 * n))
		var end := start + Vector2(side * left_span * (0.14 + 0.08 * _cell_noise(cell, 683 + i * 19)), half_height * (0.18 + 0.14 * _cell_noise(cell, 701 + i * 29)))
		draw_line(start, end, seam, 1.6)
		var chip_lit := lit
		chip_lit.a *= 0.72
		draw_line(start + Vector2(0, -1), end + Vector2(0, -1), chip_lit, 0.7)

func _draw_prop_foundation_rubble(cell: Vector2i, center: Vector2, scale: Vector2, strength: float) -> void:
	for i in range(5):
		var n := _cell_noise(cell, 811 + i * 13)
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (TILE_HALF.x * scale.x * (0.18 + 0.42 * n))
		var y := TILE_HALF.y * scale.y * (0.28 + 0.56 * _cell_noise(cell, 877 + i * 17))
		var size := 0.045 + 0.035 * _cell_noise(cell, 929 + i * 19)
		var chip_center := center + Vector2(x, y)
		var chip := _diamond_scaled(chip_center, size, size * 0.72)
		var dark := PROP_RUBBLE_DARK
		dark.a *= maxf(0.45, strength)
		draw_colored_polygon(chip, dark)
		var light := PROP_RUBBLE_LIGHT
		light.a *= maxf(0.45, strength)
		draw_line(chip[3], chip[0], light, 0.8)

func _tile_lip_color(cell: Vector2i) -> Color:
	var deploy := _state != null and _state.phase == BattleState.Phase.GARRISON and _state.deploy_zone.has(cell)
	var color := _tile_base_color(cell, deploy)
	return Color(color.r, color.g, color.b, 0.82)

func _draw_rift_glow(cell: Vector2i) -> void:
	var center := cell_to_pixel(cell)
	var pulse := 0.72 + 0.28 * sin(_pulse_t * 4.0)
	_draw_ellipse(center + Vector2(0, 4), Vector2(30, 9), Color(0.0, 0.95, 1.0, 0.18 * pulse))
	draw_line(center + Vector2(-24, 3), center + Vector2(20, -6), Color(0.22, 1.0, 1.0, 0.42 * pulse), 2.0)
	draw_line(center + Vector2(-10, -16), center + Vector2(8, 18), Color(0.10, 0.72, 1.0, 0.36 * pulse), 1.5)

func _draw_units() -> void:
	var units := _state.units.duplicate()
	units.sort_custom(func(a: Unit, b: Unit) -> bool:
		if a.position.x + a.position.y == b.position.x + b.position.y:
			return a.position.x < b.position.x
		return a.position.x + a.position.y < b.position.x + b.position.y
	)
	var order := _enemy_order_index()
	for unit in units:
		if unit.def == null or (not _display_unit_alive(unit) and not has_unit_visual_position(unit.id)):
			continue
		_draw_unit(unit, int(order.get(unit.id, 0)))

func _draw_unit(unit: Unit, order_badge: int) -> void:
	var unit_pixel: Vector2 = _unit_visual_positions.get(unit.id, cell_to_pixel(unit.position))
	var foot := unit_pixel + Vector2(0, UNIT_GROUND_Y) + UNIT_TOKEN_OFFSET
	_draw_unit_at_foot(unit, foot, order_badge)

func _draw_unit_drawable(drawable: Dictionary) -> void:
	var unit: Unit = drawable.get("unit", null)
	if unit == null:
		return
	_draw_unit_at_foot(unit, drawable.get("foot", Vector2.ZERO), int(drawable.get("order_badge", 0)))

func _draw_unit_at_foot(unit: Unit, foot: Vector2, order_badge: int) -> void:
	if not _draw_unit_token(unit, foot):
		_draw_unit_miniature(unit, foot)
	if DRAW_UNIT_OVERHEAD_HP_BARS:
		_draw_unit_overhead_hp_bar(unit, foot + UNIT_OVERHEAD_HP_OFFSET)
	if DRAW_UNIT_HP_PIPS:
		_draw_hp(unit, foot + Vector2(-15, -UNIT_TOKEN_HEIGHT - 9.0))
	if order_badge > 0:
		_draw_enemy_order_marker(foot + Vector2(28, -UNIT_TOKEN_HEIGHT - 8.0), str(order_badge), unit.id == _focused_enemy_id)

func _draw_unit_token(unit: Unit, foot: Vector2) -> bool:
	var texture: Texture2D = unit.def.token_texture if unit.def != null else null
	if texture == null:
		return false
	var aspect := float(texture.get_width()) / float(maxi(1, texture.get_height()))
	var size := Vector2(UNIT_TOKEN_HEIGHT * aspect, UNIT_TOKEN_HEIGHT)
	var rect := Rect2(Vector2(foot.x - size.x * 0.5, foot.y - size.y), size)
	var tint := Color(1, 1, 1, 1)
	if unit.has_acted:
		tint = Color(0.46, 0.48, 0.48, 0.84)
	elif unit.has_moved:
		tint = Color(0.72, 0.74, 0.72, 0.90)
	draw_texture_rect(texture, rect, false, tint)
	return true

func _draw_unit_miniature(unit: Unit, foot: Vector2) -> void:
	var spent := unit.has_acted
	var moved := unit.has_moved and not spent
	var alpha := 0.62 if spent else 0.86 if moved else 1.0
	var id := StringName(unit.def.def_id)
	if unit.is_warden():
		_draw_warden_miniature(id, foot, alpha)
	else:
		_draw_enemy_miniature(id, foot, alpha)

func _draw_warden_miniature(id: StringName, foot: Vector2, alpha: float) -> void:
	var cloak := Color(0.125, 0.162, 0.166, alpha)
	var cloak_dark := Color(0.056, 0.066, 0.070, alpha)
	var metal := Color(0.48, 0.52, 0.48, alpha)
	var accent := Color(COLOR_ACCENT_WARDEN.r, COLOR_ACCENT_WARDEN.g, COLOR_ACCENT_WARDEN.b, 0.86 * alpha)
	var skin := Color(0.60, 0.52, 0.42, alpha)
	if id == &"warden_mage":
		cloak = Color(0.105, 0.126, 0.178, alpha)
		accent = Color(0.35, 0.82, 0.96, 0.90 * alpha)
	elif id == &"warden_graverobber":
		cloak = Color(0.148, 0.134, 0.112, alpha)
		accent = Color(0.62, 0.72, 0.58, 0.82 * alpha)
	_draw_unit_legs(foot, cloak_dark)
	_draw_unit_torso(foot + Vector2(0, -22), 15.0, 22.0, cloak, cloak_dark)
	_draw_unit_head(foot + Vector2(0, -44), 6.5, skin, cloak_dark)
	draw_line(foot + Vector2(-9, -34), foot + Vector2(8, -29), accent, 2.0)
	if id == &"warden_bountyhunter":
		draw_line(foot + Vector2(10, -33), foot + Vector2(25, -38), metal, 2.0)
		draw_line(foot + Vector2(19, -44), foot + Vector2(29, -33), metal.darkened(0.24), 1.4)
		draw_line(foot + Vector2(-8, -51), foot + Vector2(9, -51), cloak_dark, 2.0)
	elif id == &"warden_graverobber":
		draw_line(foot + Vector2(15, -39), foot + Vector2(25, -16), metal, 2.0)
		draw_line(foot + Vector2(21, -17), foot + Vector2(30, -13), metal.darkened(0.15), 1.6)
		draw_line(foot + Vector2(-6, -51), foot + Vector2(6, -51), cloak_dark, 1.8)
	elif id == &"warden_mage":
		draw_line(foot + Vector2(16, -49), foot + Vector2(20, -17), metal.darkened(0.08), 2.0)
		_draw_ellipse(foot + Vector2(16, -51), Vector2(4.5, 2.0), accent)
		draw_line(foot + Vector2(-7, -35), foot + Vector2(-17, -27), accent, 1.8)

func _draw_enemy_miniature(id: StringName, foot: Vector2, alpha: float) -> void:
	var body := Color(0.255, 0.212, 0.128, alpha)
	var dark := Color(0.062, 0.052, 0.040, alpha)
	var accent := Color(COLOR_ACCENT_ENEMY.r, COLOR_ACCENT_ENEMY.g, COLOR_ACCENT_ENEMY.b, 0.80 * alpha)
	if id == &"enemy_plague_archer":
		body = Color(0.198, 0.194, 0.135, alpha)
		_draw_unit_legs(foot, dark)
		_draw_unit_torso(foot + Vector2(0, -21), 13.0, 23.0, body, dark)
		_draw_unit_head(foot + Vector2(0, -44), 6.0, Color(0.48, 0.42, 0.25, alpha), dark)
		draw_arc(foot + Vector2(18, -34), 13.0, -PI * 0.45, PI * 0.45, 12, accent, 1.8)
		draw_line(foot + Vector2(18, -45), foot + Vector2(18, -22), Color(0.70, 0.64, 0.44, 0.58 * alpha), 1.0)
		draw_line(foot + Vector2(7, -34), foot + Vector2(26, -39), dark, 1.6)
	else:
		_draw_carrion_miniature(foot, body, dark, accent)

func _draw_carrion_miniature(foot: Vector2, body: Color, dark: Color, accent: Color) -> void:
	_draw_ellipse(foot + Vector2(0, -19), Vector2(15, 12), body)
	_draw_ellipse(foot + Vector2(10, -27), Vector2(8, 7), body.lightened(0.08))
	_draw_ellipse(foot + Vector2(-10, -17), Vector2(7, 6), body.darkened(0.10))
	draw_arc(foot + Vector2(0, -19), 15.0, PI * 0.12, PI * 0.90, 12, dark, 1.2)
	for i in range(3):
		var y := -12.0 + float(i) * -5.0
		draw_line(foot + Vector2(-8, y), foot + Vector2(-18, y + 4), dark, 1.5)
		draw_line(foot + Vector2(8, y), foot + Vector2(18, y + 4), dark, 1.5)
	draw_line(foot + Vector2(7, -28), foot + Vector2(13, -31), accent, 1.4)
	draw_line(foot + Vector2(8, -25), foot + Vector2(15, -25), accent.darkened(0.18), 1.2)

func _draw_unit_legs(foot: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		foot + Vector2(-7, -5),
		foot + Vector2(-2, -6),
		foot + Vector2(-3, -20),
		foot + Vector2(-10, -18),
	]), color)
	draw_colored_polygon(PackedVector2Array([
		foot + Vector2(7, -5),
		foot + Vector2(2, -6),
		foot + Vector2(3, -20),
		foot + Vector2(10, -18),
	]), color.darkened(0.08))

func _draw_unit_torso(center: Vector2, half_w: float, height: float, fill: Color, outline: Color) -> void:
	var top := center + Vector2(0, -height * 0.48)
	var bottom := center + Vector2(0, height * 0.52)
	var poly := PackedVector2Array([
		top + Vector2(-half_w * 0.56, 2),
		top + Vector2(half_w * 0.62, 0),
		bottom + Vector2(half_w, -2),
		bottom + Vector2(0, 5),
		bottom + Vector2(-half_w, -2),
	])
	draw_colored_polygon(poly, fill)
	draw_colored_polygon(PackedVector2Array([poly[1], poly[2], poly[3], center + Vector2(2, 4)]), Color(0, 0, 0, 0.12 * fill.a))
	draw_line(poly[0], poly[1], Color(0.86, 0.92, 0.82, 0.18 * fill.a), 1.0)
	draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[4], poly[0]]), outline, 1.0)

func _draw_unit_head(center: Vector2, radius: float, fill: Color, outline: Color) -> void:
	draw_circle(center + Vector2(2, 2), radius + 1.0, Color(0, 0, 0, 0.22 * fill.a))
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0, TAU, 20, outline, 1.0)

func _draw_hp(unit: Unit, origin: Vector2) -> void:
	var display_hp := _display_unit_hp(unit)
	for i in unit.def.max_hp:
		var color := Color(1.0, 0.88, 0.62) if i < display_hp else Color(0.20, 0.05, 0.06)
		var center := origin + Vector2(i * 8.0, 0)
		draw_circle(center, 4.2, Color(0.035, 0.028, 0.026, 0.86))
		draw_circle(center, 2.8, color)

func _draw_unit_overhead_hp_bar(unit: Unit, origin: Vector2) -> void:
	if unit == null or unit.def == null:
		return
	var max_hp := maxi(1, unit.def.max_hp)
	var display_hp := _display_unit_hp(unit)
	var filled := clampi(display_hp, 0, max_hp)
	var gap := UNIT_OVERHEAD_HP_SEGMENT_GAP if max_hp <= 5 else 1.0
	var segment_width := maxf(2.0, (UNIT_OVERHEAD_HP_BAR_SIZE.x - float(max_hp - 1) * gap) / float(max_hp))
	var fill := COLOR_WARDEN_HP_FILL if unit.is_warden() else COLOR_ENEMY_HP_FILL
	if display_hp <= 1:
		fill = COLOR_WARDEN_HP_CRITICAL if unit.is_warden() else COLOR_ENEMY_HP_CRITICAL
	var frame := Rect2(origin - Vector2(2, 2), UNIT_OVERHEAD_HP_BAR_SIZE + Vector2(4, 4))
	draw_rect(frame, COLOR_UNIT_HP_FRAME)
	for i in range(max_hp):
		var x := float(i) * (segment_width + gap)
		var rect := Rect2(origin + Vector2(x, 0), Vector2(segment_width, UNIT_OVERHEAD_HP_BAR_SIZE.y))
		draw_rect(rect, fill if i < filled else COLOR_UNIT_HP_EMPTY)

func _draw_preview() -> void:
	for path in _preview_paths:
		var from_cell: Vector2i = path.get("from", INVALID_CELL)
		var to_cell: Vector2i = path.get("to", INVALID_CELL)
		var color := COLOR_PREVIEW_DANGER if bool(path.get("enemy", false)) else COLOR_PREVIEW_GHOST
		if _cell_in_bounds(from_cell) and _cell_in_bounds(to_cell):
			_draw_arrow(cell_to_pixel(from_cell), cell_to_pixel(to_cell), color, 3.5)
	for marker in _preview_markers:
		var pos: Vector2i = marker.get("pos", INVALID_CELL)
		if not _cell_in_bounds(pos):
			continue
		var kind := String(marker.get("kind", ""))
		var color := COLOR_PREVIEW_DANGER if kind in ["skull", "fall", "ghost_enemy"] else COLOR_PREVIEW_GHOST
		_fill_diamond(pos, color, false, 2.0)
		var label := "X" if kind == "skull" else "!" if kind == "fall" else ">"
		_draw_label_at(cell_to_pixel(pos) + Vector2(0, 6), label, 18, Color(1.0, 0.88, 0.55))

func _fill_diamond(cell: Vector2i, color: Color, fill: bool = true, width: float = 2.0) -> void:
	if not _cell_in_bounds(cell):
		return
	var poly := _diamond(cell_to_pixel(cell))
	if fill:
		draw_colored_polygon(poly, color)
	var border := color
	border.a = minf(1.0, color.a + 0.24)
	draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), border, width)

func _draw_enemy_intent_row(row: Dictionary, order_index: Dictionary) -> void:
	var status := String(row.get("status", BattleEngine.INTENT_STATUS_HIT))
	if status == BattleEngine.INTENT_STATUS_REMOVED or status == BattleEngine.INTENT_STATUS_NO_ATTACK:
		return
	var attack_cell: Vector2i = row.get("attack_pos", INVALID_CELL)
	var enemy_cell: Vector2i = row.get("enemy_pos", INVALID_CELL)
	if not _cell_in_bounds(enemy_cell) or not _cell_in_bounds(attack_cell):
		return
	var enemy_id := int(row.get("enemy_id", -1))
	var focused := _focused_enemy_id == -1 or _focused_enemy_id == enemy_id
	var explicitly_focused := _focused_enemy_id == enemy_id
	var color := COLOR_INTENT_LINE
	if explicitly_focused:
		color = COLOR_EXECUTE_CONFIRM
	elif not focused:
		color.a *= 0.42
	_draw_intent_hazard_cells(row, focused, explicitly_focused)
	_draw_intent_threat_line(enemy_cell, attack_cell, color, 3.0 if explicitly_focused else 2.0)
	_draw_intent_target_frame(attack_cell, color, explicitly_focused)
	_draw_intent_source_marker(enemy_cell, enemy_id, color, explicitly_focused, order_index)

func _draw_intent_hazard_cells(row: Dictionary, focused: bool, explicitly_focused: bool) -> void:
	if String(row.get("hazard_type", "")) != BattleEngine.HAZARD_CHARGE_LANE:
		return
	var cells: Array = row.get("hazard_cells", [])
	if cells.is_empty():
		return
	var pulse := 0.78 + 0.22 * sin(_pulse_t * 5.0)
	var fill := COLOR_CHARGE_LANE
	fill.a *= pulse
	var frame := COLOR_CHARGE_LANE_FRAME
	frame.a *= pulse
	if explicitly_focused:
		fill = COLOR_EXECUTE_CONFIRM
		fill.a = 0.34 * pulse
		frame = COLOR_EXECUTE_CONFIRM
		frame.a = 0.92 * pulse
	elif not focused:
		fill.a *= 0.34
		frame.a *= 0.42
	for raw in cells:
		var cell: Vector2i = raw
		if not _cell_in_bounds(cell):
			continue
		_fill_diamond(cell, fill, true, 1.3)
		var center := cell_to_pixel(cell)
		var lane_poly := _diamond_scaled(center, 0.72, 0.72)
		draw_polyline(PackedVector2Array([lane_poly[0], lane_poly[1], lane_poly[2], lane_poly[3], lane_poly[0]]), frame, 1.8)

func _draw_intent_threat_line(from_cell: Vector2i, to_cell: Vector2i, color: Color, width: float) -> void:
	if from_cell == to_cell:
		return
	var from_px := cell_to_pixel(from_cell)
	var to_px := cell_to_pixel(to_cell)
	var dir := (to_px - from_px).normalized()
	if dir.length_squared() < 0.001:
		return
	var start := from_px + dir * 21.0
	var end_pt := to_px - dir * 19.0
	var under := COLOR_INTENT_UNDERSTROKE
	under.a = minf(under.a, color.a)
	draw_line(start, end_pt, under, width + 3.0)
	draw_line(start, end_pt, color, width)
	_draw_arrow_head(end_pt, dir, color, 10.0 + width)

func _draw_intent_target_frame(cell: Vector2i, color: Color, focused: bool) -> void:
	var center := cell_to_pixel(cell)
	var fill := COLOR_INTENT_TARGET_FILL
	fill.a *= 1.18 if focused else 1.0
	draw_colored_polygon(_diamond_scaled(center, 0.92, 0.92), fill)
	var outer := _diamond_scaled(center, 1.06, 1.06)
	var inner := _diamond_scaled(center, 0.84, 0.84)
	var frame := COLOR_INTENT_TARGET_FRAME if not focused else color
	draw_polyline(PackedVector2Array([outer[0], outer[1], outer[2], outer[3], outer[0]]), COLOR_INTENT_UNDERSTROKE, 5.0 if focused else 4.0)
	draw_polyline(PackedVector2Array([outer[0], outer[1], outer[2], outer[3], outer[0]]), frame, 2.6 if focused else 2.0)
	draw_polyline(PackedVector2Array([inner[0], inner[1], inner[2], inner[3], inner[0]]), frame, 1.2)

func _draw_intent_source_marker(cell: Vector2i, enemy_id: int, color: Color, focused: bool, order_index: Dictionary = {}) -> void:
	var center := cell_to_pixel(cell) + Vector2(0, 12)
	var radius := 9.0 if focused else 7.0
	_draw_ellipse(center, Vector2(radius + 3.0, 4.0), Color(0.02, 0.01, 0.006, 0.66))
	_draw_ellipse(center, Vector2(radius, 3.0), color)
	if enemy_id < 0:
		return
	var order := int(order_index.get(enemy_id, 0))
	if order > 0:
		_draw_label_at(center + Vector2(0, 3), str(order), 10, COLOR_ENEMY_ORDER_TEXT)

func _draw_execution_confirm(cell: Vector2i, pulse: float) -> void:
	var center := cell_to_pixel(cell)
	var inner_color := COLOR_EXECUTE_CONFIRM
	inner_color.a = 0.58 * pulse
	var inner := _diamond_scaled(center, 0.64 + 0.10 * pulse, 0.64 + 0.10 * pulse)
	draw_colored_polygon(inner, inner_color)
	draw_polyline(PackedVector2Array([inner[0], inner[1], inner[2], inner[3], inner[0]]), COLOR_EXECUTE_CONFIRM, 2.2)

func _draw_hit_sparks(cell: Vector2i, color: Color, pulse: float) -> void:
	_draw_hit_sparks_at(cell_to_pixel(cell), color, pulse)

func _draw_hit_sparks_at(center: Vector2, color: Color, pulse: float) -> void:
	_draw_tactical_impact(center, 0.28, clampf(pulse, 0.0, 1.0))

func _attack_fx_anchor(cell: Vector2i) -> Vector2:
	return cell_to_pixel(cell, ATTACK_FX_HEIGHT)

func _attack_fx_muzzle_anchor(cell: Vector2i) -> Vector2:
	return cell_to_pixel(cell, ATTACK_FX_MUZZLE_HEIGHT)

func _attack_fx_target_anchor(cell: Vector2i) -> Vector2:
	return cell_to_pixel(cell, ATTACK_FX_TARGET_HEIGHT)

func _draw_muzzle_burst(center: Vector2, dir: Vector2, strength: float) -> void:
	var alpha := clampf(strength, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var normal := dir.rotated(PI * 0.5)
	_draw_tactical_muzzle_tick(center, dir, 0.72 * alpha)
	var side := COLOR_ATTACK_BONE
	side.a = 0.28 * alpha
	draw_line(center - normal * 8.0, center + normal * 8.0, COLOR_ATTACK_IRON, 3.0)
	draw_line(center - normal * 6.0, center + normal * 6.0, side, 1.2)

func _draw_air_impact_hint(center: Vector2, color: Color, dir: Vector2) -> void:
	var normal := dir.rotated(PI * 0.5)
	var a := center - normal * 12.0 - dir * 2.0
	var b := center + normal * 12.0 + dir * 2.0
	draw_line(a, b, COLOR_ATTACK_IRON, 4.0)
	draw_line(a, b, color, 1.6)

func _draw_tactical_projectile(tail: Vector2, head: Vector2, normal: Vector2, alpha: float) -> void:
	var delta := head - tail
	if delta.length_squared() < 0.001:
		return
	var dir := delta.normalized()
	var under := COLOR_ATTACK_IRON
	under.a = 0.72 * alpha
	var amber := COLOR_ATTACK_AMBER
	amber.a = 0.70 * alpha
	var bone := COLOR_ATTACK_BONE
	bone.a = 0.44 * alpha
	draw_line(tail, head, under, 4.8)
	draw_line(tail + normal * 1.2, head + normal * 1.2, amber, 1.6)
	draw_line(tail - normal * 1.0, head - normal * 1.0, bone, 0.9)
	for i in range(2):
		var fragment_alpha := alpha * (0.42 - float(i) * 0.12)
		var fragment_under := COLOR_ATTACK_IRON
		fragment_under.a = 0.66 * fragment_alpha
		var fragment_color := COLOR_ATTACK_BONE
		fragment_color.a = 0.46 * fragment_alpha
		var offset := normal * ((float(i) * 2.0 - 1.0) * 4.2) - dir * (8.0 + float(i) * 10.0)
		var frag_head := head + offset
		var frag_tail := frag_head - dir * (18.0 - float(i) * 3.0)
		draw_line(frag_tail, frag_head, fragment_under, 2.8)
		draw_line(frag_tail + normal * 0.8, frag_head + normal * 0.8, fragment_color, 0.9)

func _draw_projectile_afterimage(tail: Vector2, head: Vector2, normal: Vector2, alpha: float) -> void:
	var delta := head - tail
	if delta.length_squared() < 0.001 or alpha <= 0.0:
		return
	var dir := delta.normalized()
	var under := COLOR_ATTACK_IRON
	under.a = 0.34 * alpha
	var ember := COLOR_ATTACK_AMBER
	ember.a = 0.28 * alpha
	for i in range(2):
		var offset := normal * ((float(i) - 0.5) * 5.0) - dir * (8.0 + float(i) * 8.0)
		var a := head + offset - dir * 22.0
		var b := head + offset - dir * 6.0
		draw_line(a, b, under, 2.6)
		draw_line(a + normal * 0.7, b + normal * 0.7, ember, 0.9)

func _draw_tactical_muzzle_tick(center: Vector2, dir: Vector2, alpha: float) -> void:
	var a := clampf(alpha, 0.0, 1.0)
	if a <= 0.0:
		return
	var normal := dir.rotated(PI * 0.5)
	var under := COLOR_ATTACK_IRON
	under.a = 0.78 * a
	var amber := COLOR_ATTACK_AMBER
	amber.a = 0.64 * a
	var bone := COLOR_ATTACK_BONE
	bone.a = 0.34 * a
	draw_line(center - dir * 8.0, center + dir * 15.0, under, 4.8)
	draw_line(center - dir * 3.0, center + dir * 11.0, amber, 1.8)
	draw_line(center - normal * 8.0, center + normal * 8.0, under, 3.0)
	draw_line(center - normal * 5.5, center + normal * 5.5, bone, 1.1)

func _draw_attack_target_reticle(center: Vector2, alpha: float) -> void:
	var a := clampf(alpha, 0.0, 1.0)
	if a <= 0.0:
		return
	var under := COLOR_ATTACK_IRON
	under.a = 0.72 * a
	var red := COLOR_ATTACK_RETICLE
	red.a = 0.76 * a
	var amber := COLOR_ATTACK_AMBER
	amber.a = 0.46 * a
	var half_w := 24.0
	var half_h := 11.0
	var gap_x := 11.0
	var gap_y := 4.5
	var segments := [
		[center + Vector2(-half_w, 0), center + Vector2(-gap_x, 0), red],
		[center + Vector2(gap_x, 0), center + Vector2(half_w, 0), red],
		[center + Vector2(0, -half_h), center + Vector2(0, -gap_y), amber],
		[center + Vector2(0, gap_y), center + Vector2(0, half_h), amber],
	]
	for segment in segments:
		draw_line(segment[0], segment[1], under, 3.2)
		draw_line(segment[0], segment[1], segment[2], 1.3)

func _draw_tactical_impact(center: Vector2, progress: float, pulse: float) -> void:
	var p := clampf(progress, 0.0, 1.0)
	var intensity := clampf(pulse, 0.0, 1.0)
	var fade := 1.0 - p * 0.38
	var under := COLOR_ATTACK_IRON
	under.a = 0.82 * intensity * fade
	var amber := COLOR_ATTACK_AMBER
	amber.a = 0.70 * intensity * fade
	var bone := COLOR_ATTACK_BONE
	bone.a = 0.62 * intensity * fade
	for i in range(6):
		var angle := -0.82 * PI + float(i) * PI / 5.0
		var dir := Vector2(cos(angle), sin(angle))
		var inner := center + dir * (5.0 + p * 5.0)
		var outer := center + dir * (18.0 + p * 12.0 + float(i % 2) * 4.0)
		var spark_color := bone if i % 2 == 0 else amber
		draw_line(inner, outer, under, 4.2)
		draw_line(inner, outer, spark_color, 1.6)
	var dot := amber
	dot.a = 0.58 * intensity * fade
	draw_circle(center, 3.6 + sin(p * PI) * 1.8, dot)

func _draw_attack_settle_scratches(center: Vector2, direction: Vector2i, color: Color, progress: float) -> void:
	if color.a <= 0.0:
		return
	var dir_px := Vector2(float(direction.x - direction.y) * TILE_HALF.x, float(direction.x + direction.y) * TILE_HALF.y)
	if dir_px.length_squared() < 0.001:
		dir_px = Vector2.RIGHT
	dir_px = dir_px.normalized()
	var normal := dir_px.rotated(PI * 0.5)
	var spread := 8.0 + 10.0 * progress
	var under := COLOR_ATTACK_IRON
	under.a = color.a * 1.4
	for i in range(2):
		var offset := normal * ((float(i) - 0.5) * spread)
		var start := center + offset - dir_px * (12.0 + progress * 8.0)
		var end_pt := center + offset + dir_px * (9.0 + progress * 10.0)
		draw_line(start, end_pt, under, 2.4)
		draw_line(start, end_pt, color, 1.0)

func _draw_attack_vfx_frame(sequence_id: StringName, center: Vector2, rotation: float, scale: Variant, tint: Color, progress: float) -> bool:
	var source := _attack_vfx_frame_region(sequence_id, progress)
	if _attack_vfx_sheet_texture == null or source.size == Vector2.ZERO:
		return false
	var draw_scale: Vector2
	if scale is Vector2:
		draw_scale = scale
	else:
		draw_scale = Vector2(float(scale), float(scale))
	draw_set_transform(center, rotation, draw_scale)
	draw_texture_rect_region(
		_attack_vfx_sheet_texture,
		Rect2(-ATTACK_VFX_FRAME_SIZE * 0.5, ATTACK_VFX_FRAME_SIZE),
		source,
		tint
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

func _draw_tether_vfx_strip(start: Vector2, end_pt: Vector2, dir: Vector2, tint: Color, progress: float) -> void:
	var length := start.distance_to(end_pt)
	if length < 1.0:
		return
	var step := 34.0
	var count := maxi(1, ceili(length / step))
	for i in range(count):
		var t := (float(i) + 0.5) / float(count)
		var center := start.lerp(end_pt, t)
		_draw_attack_vfx_frame(FX_SEQUENCE_TETHER, center, dir.angle(), 0.44, _fx_alpha(tint.a), fmod(progress + t * 0.35, 1.0))

func _fx_alpha(alpha: float) -> Color:
	var result := Color.WHITE
	result.a = alpha
	return result

func _attack_vfx_frame_region(sequence_id: StringName, progress: float) -> Rect2:
	var row := _attack_vfx_sequence_row(sequence_id)
	var count := _attack_vfx_sequence_frame_count(sequence_id)
	if row < 0 or count <= 0:
		return Rect2()
	var frame := clampi(floori(clampf(progress, 0.0, 0.9999) * float(count)), 0, count - 1)
	return Rect2(
		Vector2(float(frame) * ATTACK_VFX_FRAME_SIZE.x, float(row) * ATTACK_VFX_FRAME_SIZE.y),
		ATTACK_VFX_FRAME_SIZE
	)

func _attack_vfx_sequence_row(sequence_id: StringName) -> int:
	match sequence_id:
		FX_SEQUENCE_MUZZLE:
			return 0
		FX_SEQUENCE_PROJECTILE:
			return 1
		FX_SEQUENCE_IMPACT:
			return 2
		FX_SEQUENCE_DUST:
			return 3
		FX_SEQUENCE_SLASH:
			return 4
		FX_SEQUENCE_TETHER:
			return 5
		_:
			return -1

func _attack_vfx_sequence_frame_count(sequence_id: StringName) -> int:
	match sequence_id:
		FX_SEQUENCE_MUZZLE:
			return FX_MUZZLE_FRAMES
		FX_SEQUENCE_PROJECTILE:
			return FX_PROJECTILE_FRAMES
		FX_SEQUENCE_IMPACT:
			return FX_IMPACT_FRAMES
		FX_SEQUENCE_DUST:
			return FX_DUST_FRAMES
		FX_SEQUENCE_SLASH:
			return FX_SLASH_FRAMES
		FX_SEQUENCE_TETHER:
			return FX_TETHER_FRAMES
		_:
			return 0

func _draw_arrow(from_px: Vector2, to_px: Vector2, color: Color, width: float) -> void:
	var dir := (to_px - from_px).normalized()
	if dir.length_squared() < 0.001:
		return
	var start := from_px + dir * 18.0
	var end_pt := to_px - dir * 15.0
	draw_line(start, end_pt, color, width)
	var head := 10.0
	_draw_arrow_head(end_pt, dir, color, head)

func _draw_arrow_head(end_pt: Vector2, dir: Vector2, color: Color, head: float) -> void:
	var left := end_pt - dir * head + dir.rotated(PI * 0.5) * head * 0.55
	var right := end_pt - dir * head - dir.rotated(PI * 0.5) * head * 0.55
	draw_colored_polygon(PackedVector2Array([end_pt, left, right]), color)

func _draw_segmented_hp_bar(origin: Vector2, hp: int, max_hp: int, color: Color, preview_damage: int = 0) -> void:
	var segment_count := maxi(1, max_hp)
	var filled_count := clampi(hp, 0, segment_count)
	var preview_count := clampi(preview_damage, 0, filled_count)
	var preview_start := filled_count - preview_count
	var pulse := 0.72 + 0.28 * (0.5 + 0.5 * sin(_pulse_t * 7.0))
	var total_width := float(segment_count) * BUILDING_HP_SEGMENT_SIZE.x + float(segment_count - 1) * BUILDING_HP_SEGMENT_GAP
	var frame := Rect2(
		origin - BUILDING_HP_FRAME_PAD,
		Vector2(total_width, BUILDING_HP_SEGMENT_SIZE.y) + BUILDING_HP_FRAME_PAD * 2.0
	)
	draw_rect(frame, COLOR_BUILDING_HP_FRAME)
	for i in range(segment_count):
		var segment := Rect2(
			origin + Vector2(float(i) * (BUILDING_HP_SEGMENT_SIZE.x + BUILDING_HP_SEGMENT_GAP), 0),
			BUILDING_HP_SEGMENT_SIZE
		)
		if i < filled_count:
			if i >= preview_start:
				var glow := COLOR_BUILDING_HP_PREVIEW_GLOW
				glow.a *= pulse
				draw_rect(segment.grow(1.0), glow)
				var preview := COLOR_BUILDING_HP_PREVIEW
				preview.a *= pulse
				draw_rect(segment, preview)
				_draw_preview_crack(segment)
			else:
				draw_rect(segment, color)
		else:
			draw_rect(segment, COLOR_BUILDING_HP_EMPTY)

func _draw_preview_crack(rect: Rect2) -> void:
	var crack_color := Color(1.0, 0.78, 0.42, 0.86)
	var a := rect.position + Vector2(rect.size.x * 0.24, 1.0)
	var b := rect.position + Vector2(rect.size.x * 0.54, rect.size.y - 1.0)
	var c := rect.position + Vector2(rect.size.x * 0.78, 1.0)
	draw_polyline(PackedVector2Array([a, b, c]), crack_color, 1.0)

func _draw_enemy_order_marker(center: Vector2, text: String, focused: bool) -> void:
	var half_size := Vector2(14, 9)
	var back := PackedVector2Array([
		center + Vector2(-half_size.x - 3, 0),
		center + Vector2(-half_size.x + 2, -half_size.y),
		center + Vector2(half_size.x - 2, -half_size.y),
		center + Vector2(half_size.x + 4, 0),
		center + Vector2(half_size.x - 2, half_size.y),
		center + Vector2(-half_size.x + 2, half_size.y),
	])
	var face := PackedVector2Array([
		center + Vector2(-half_size.x, 0),
		center + Vector2(-half_size.x + 4, -half_size.y + 2),
		center + Vector2(half_size.x - 4, -half_size.y + 2),
		center + Vector2(half_size.x, 0),
		center + Vector2(half_size.x - 4, half_size.y - 2),
		center + Vector2(-half_size.x + 4, half_size.y - 2),
	])
	var border := COLOR_ENEMY_ORDER_BORDER
	var face_color := COLOR_ENEMY_ORDER_FACE
	if focused:
		border.a = 1.0
		face_color = face_color.lightened(0.10)
	draw_colored_polygon(back, COLOR_ENEMY_ORDER_BACK)
	draw_colored_polygon(face, face_color)
	draw_polyline(PackedVector2Array([back[0], back[1], back[2], back[3], back[4], back[5], back[0]]), border, 1.7 if focused else 1.2)
	draw_line(center + Vector2(half_size.x - 4, -half_size.y + 2), center + Vector2(half_size.x + 4, 0), border, 1.5 if focused else 1.0)
	_draw_label_at(center + Vector2(-1, 4), text, 12, COLOR_ENEMY_ORDER_TEXT)

func _draw_label_at(pos: Vector2, text: String, size: int, color: Color) -> void:
	var font: Font = ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() != null else ThemeDB.fallback_font
	if font == null:
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	draw_string(font, pos - text_size * 0.5, text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, color)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)

func _diamond(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -TILE_HALF.y),
		center + Vector2(TILE_HALF.x, 0),
		center + Vector2(0, TILE_HALF.y),
		center + Vector2(-TILE_HALF.x, 0),
	])

func _diamond_scaled(center: Vector2, scale_x: float, scale_y: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -TILE_HALF.y * scale_y),
		center + Vector2(TILE_HALF.x * scale_x, 0),
		center + Vector2(0, TILE_HALF.y * scale_y),
		center + Vector2(-TILE_HALF.x * scale_x, 0),
	])

func _board_top_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		cell_to_pixel(Vector2i(0, 0)) + Vector2(0, -TILE_HALF.y),
		cell_to_pixel(Vector2i(Grid.SIZE - 1, 0)) + Vector2(TILE_HALF.x, 0),
		cell_to_pixel(Vector2i(Grid.SIZE - 1, Grid.SIZE - 1)) + Vector2(0, TILE_HALF.y),
		cell_to_pixel(Vector2i(0, Grid.SIZE - 1)) + Vector2(-TILE_HALF.x, 0),
	])

func _enemy_order_index() -> Dictionary:
	var result := {}
	if _state == null:
		return result
	var i := 1
	for row in _enemy_intents:
		var enemy_id := int(row.get("enemy_id", -1))
		if enemy_id >= 0 and not result.has(enemy_id):
			result[enemy_id] = i
			i += 1
	return result

func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < Grid.SIZE and cell.y >= 0 and cell.y < Grid.SIZE

func _sorted_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in Grid.SIZE:
		for x in Grid.SIZE:
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x + a.y == b.x + b.y:
			return a.x < b.x
		return a.x + a.y < b.x + b.y
	)
	return cells
