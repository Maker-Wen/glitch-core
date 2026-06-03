class_name GridView extends Node2D
## Renders the 8x8 board background + tile features.

const CELL_SIZE := 72
const COLOR_TILE_A := Color(0.16, 0.15, 0.18)
const COLOR_TILE_B := Color(0.12, 0.11, 0.14)
const COLOR_PILLAR := Color(0.32, 0.30, 0.34)
const COLOR_PILLAR_EDGE := Color(0.55, 0.5, 0.4)
const COLOR_BUILDING := Color(0.42, 0.33, 0.24)
const COLOR_BUILDING_EDGE := Color(0.78, 0.62, 0.38)
const COLOR_RUIN := Color(0.18, 0.16, 0.15)
## Inactive rifts: subtle dark crack on the tile, no red glow. Players can
## still see WHERE rifts are (for tactical planning per §5.3) but rifts
## without imminent spawns don't draw the eye. The PreviewOverlay overlays a
## bright red+gold "↑" indicator when a rift is about to spawn.
const COLOR_RIFT_INACTIVE := Color(0.22, 0.18, 0.20, 0.85)
const COLOR_GRID_LINE := Color(0.05, 0.04, 0.06, 0.6)
const TILE_DRAW_SIZE := Vector2(94, 94)
const FEATURE_DRAW_SIZE := Vector2(104, 104)

const TEX_EMPTY := preload("res://art/tiles/board_empty_tile.png")
const TEX_PILLAR := preload("res://art/tiles/board_pillar_tile.png")
const TEX_BUILDING := preload("res://art/tiles/board_building_tile.png")
const TEX_RUIN := preload("res://art/tiles/board_ruin_tile.png")
const TEX_RIFT := preload("res://art/tiles/board_rift_tile.png")

var _grid: Grid

func bind(grid: Grid) -> void:
	_grid = grid
	queue_redraw()

func _draw() -> void:
	if _grid == null:
		return
	for y in Grid.SIZE:
		for x in Grid.SIZE:
			var rect := Rect2(Vector2(x, y) * CELL_SIZE, Vector2.ONE * CELL_SIZE)
			var c := COLOR_TILE_A if (x + y) % 2 == 0 else COLOR_TILE_B
			draw_rect(rect, c)
			_draw_tile_texture(TEX_EMPTY, rect, TILE_DRAW_SIZE)
			var tile: int = _grid.get_tile(Vector2i(x, y))
			match tile:
				Grid.TileType.PILLAR:
					_draw_tile_texture(TEX_PILLAR, rect, FEATURE_DRAW_SIZE)
				Grid.TileType.BUILDING:
					_draw_tile_texture(TEX_BUILDING, rect, FEATURE_DRAW_SIZE)
					var hp: int = _grid.tile_hp.get(Vector2i(x, y), Grid.DEFAULT_BUILDING_HP)
					draw_string(
						ThemeDB.fallback_font,
						rect.position + Vector2(12, 22),
						"HP %d" % hp,
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						14,
						Color(1.0, 0.9, 0.65),
					)
				Grid.TileType.RUIN:
					_draw_tile_texture(TEX_RUIN, rect, FEATURE_DRAW_SIZE)
				Grid.TileType.RIFT:
					# Subtle dark crack -- visible enough that the player knows
					# this is a rift cell, but quiet enough that round 1 looks
					# clean. When the rift is about to spawn an enemy, the
					# PreviewOverlay adds the bright "↑" indicator on top.
					_draw_tile_texture(TEX_RIFT, rect, TILE_DRAW_SIZE)
	# Grid lines
	for i in range(Grid.SIZE + 1):
		var x_px: int = i * CELL_SIZE
		var y_px: int = i * CELL_SIZE
		var max_px: int = Grid.SIZE * CELL_SIZE
		draw_line(Vector2(x_px, 0), Vector2(x_px, max_px), COLOR_GRID_LINE)
		draw_line(Vector2(0, y_px), Vector2(max_px, y_px), COLOR_GRID_LINE)

func _draw_tile_texture(texture: Texture2D, cell_rect: Rect2, size: Vector2) -> void:
	var center := cell_rect.position + cell_rect.size * 0.5
	var draw_rect := Rect2(center - size * 0.5, size)
	draw_texture_rect(texture, draw_rect, false)

## Convert grid cell to local pixel center.
static func cell_to_pixel(p: Vector2i) -> Vector2:
	return Vector2(p) * CELL_SIZE + Vector2.ONE * (CELL_SIZE * 0.5)

static func pixel_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL_SIZE), floori(p.y / CELL_SIZE))
