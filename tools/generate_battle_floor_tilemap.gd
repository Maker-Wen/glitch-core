extends SceneTree
## Generates edge-compatible 102x52 isometric floor tile variants.
##
## Run with:
##   godot --headless --path . -s tools/generate_battle_floor_tilemap.gd

const MATERIAL_PATHS := [
	"res://art/tiles/tilemap/battle_floor_material_gpt-image-2.png",
	"res://art/tiles/tilemap/battle_floor_material_gemini.png",
]
const FALLBACK_SOURCE_PATH := "res://art/tiles/board_floor_tile.png"
const OUT_DIR := "res://art/tiles/tilemap"
const OUT_ATLAS_PATH := "%s/battle_floor_tile_variants.png" % OUT_DIR
const OUT_PREVIEW_PATH := "%s/battle_board_floor_map.png" % OUT_DIR
const GRID_SIZE := 8
const TILE_W := 102
const TILE_H := 52
const HALF_W := TILE_W * 0.5
const HALF_H := TILE_H * 0.5
const VARIANT_COUNT := 12
const ATLAS_COLUMNS := 4
const ATLAS_ROWS := 3
const ATLAS_SIZE := Vector2i(TILE_W * ATLAS_COLUMNS, TILE_H * ATLAS_ROWS)
const PREVIEW_SIZE := Vector2i(TILE_W * GRID_SIZE, TILE_H * GRID_SIZE)
const MATERIAL_CENTER := Vector2(0.500, 0.405)
const MATERIAL_SPAN := Vector2(0.046, 0.030)
const FALLBACK_CENTER := Vector2(0.500, 0.323)
const FALLBACK_SPAN := Vector2(0.052, 0.025)

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var source_path := ""
	var source: Image = null
	for candidate in MATERIAL_PATHS:
		source = _load_image_any_format(candidate)
		if source != null:
			source_path = candidate
			break
	if source == null:
		source_path = FALLBACK_SOURCE_PATH
		source = _load_image_any_format(source_path)
	if source == null:
		push_error("Failed to load battle floor material")
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)

	var material_is_tile_block := source_path == FALLBACK_SOURCE_PATH
	var atlas := _generate_variant_atlas(source, material_is_tile_block)
	var preview := _generate_preview_map(atlas)
	atlas.save_png(OUT_ATLAS_PATH)
	preview.save_png(OUT_PREVIEW_PATH)
	_write_png_import_stub(OUT_ATLAS_PATH)
	_write_png_import_stub(OUT_PREVIEW_PATH)
	print("battle floor tile variants generated: %s" % OUT_ATLAS_PATH)
	print("battle floor preview generated: %s" % OUT_PREVIEW_PATH)
	quit(0)

func _load_image_any_format(path: String) -> Image:
	var bytes := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(path))
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) == OK:
		return image
	image = Image.new()
	if image.load_jpg_from_buffer(bytes) == OK:
		return image
	image = Image.new()
	if image.load_webp_from_buffer(bytes) == OK:
		return image
	return null

func _generate_variant_atlas(source: Image, material_is_tile_block: bool) -> Image:
	var atlas := Image.create(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for variant in VARIANT_COUNT:
		_draw_variant_tile(atlas, source, variant, _variant_origin(variant), material_is_tile_block)
	return atlas

func _generate_preview_map(atlas: Image) -> Image:
	var preview := Image.create(PREVIEW_SIZE.x, PREVIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	preview.fill(Color(0, 0, 0, 0))
	for cell in _sorted_cells():
		_blit_preview_tile(preview, atlas, cell, _variant_for_cell(cell))
	return preview

func _draw_variant_tile(out: Image, source: Image, variant: int, origin: Vector2i, material_is_tile_block: bool) -> void:
	var center := Vector2(origin) + Vector2(HALF_W, HALF_H)
	var tint := _variant_tint(variant)
	var uv_offset := Vector2(
		(_noise_variant(variant, 19) - 0.5) * 0.720,
		(_noise_variant(variant, 23) - 0.5) * 0.560
	)
	var angle_steps := int(floor(_noise_variant(variant, 29) * 4.0)) % 4
	for py in range(origin.y, origin.y + TILE_H):
		for px in range(origin.x, origin.x + TILE_W):
			var dx := float(px) + 0.5 - center.x
			var dy := float(py) + 0.5 - center.y
			var edge_metric := absf(dx) / HALF_W + absf(dy) / HALF_H
			if edge_metric > 1.0:
				continue
			var local_uv := _rotate_local_uv(Vector2(dx / HALF_W, dy / HALF_H), angle_steps)
			var center_uv := FALLBACK_CENTER if material_is_tile_block else MATERIAL_CENTER
			var span_uv := FALLBACK_SPAN if material_is_tile_block else MATERIAL_SPAN
			var uv := center_uv + Vector2(local_uv.x * span_uv.x, local_uv.y * span_uv.y) + uv_offset
			if not material_is_tile_block:
				uv = Vector2(_wrap01(uv.x), _wrap01(uv.y))
			var material := _flatten_material(_sample_image(source, uv), tint)
			var color := tint.lerp(material, 0.26 if not material_is_tile_block else 0.32)
			color = _apply_top_lighting(color, edge_metric, dx, dy)
			color = _apply_grain(color, px, py, variant)
			color.a = clampf((1.0 - edge_metric) / 0.026, 0.0, 1.0)
			out.set_pixel(px, py, color)
	_bake_tile_edges(out, origin)
	_bake_inner_facets(out, variant, center)
	_bake_variant_wear(out, variant, center)

func _blit_preview_tile(preview: Image, atlas: Image, cell: Vector2i, variant: int) -> void:
	var center := Vector2i(
		int(TILE_W * GRID_SIZE * 0.5 + float(cell.x - cell.y) * HALF_W),
		int(HALF_H + float(cell.x + cell.y) * HALF_H)
	)
	var dest_origin := center - Vector2i(int(HALF_W), int(HALF_H))
	var src_origin := _variant_origin(variant)
	for y in TILE_H:
		for x in TILE_W:
			var color := atlas.get_pixel(src_origin.x + x, src_origin.y + y)
			if color.a <= 0.01:
				continue
			_blend_pixel(preview, dest_origin.x + x, dest_origin.y + y, color)

func _variant_tint(variant: int) -> Color:
	var variation := (_noise_variant(variant, 7) - 0.5) * 0.050
	var cool := (_noise_variant(variant, 11) - 0.5) * 0.024
	return Color(0.292 + variation - cool, 0.318 + variation, 0.296 + variation + cool, 1.0)

func _apply_top_lighting(color: Color, edge_metric: float, dx: float, dy: float) -> Color:
	var edge_strength := clampf((edge_metric - 0.860) / 0.140, 0.0, 1.0)
	if edge_strength <= 0.0:
		return color
	if dy < 0.0 or dx < 0.0:
		color = color.lightened(edge_strength * 0.034)
	if dy > 0.0 or dx > 0.0:
		color = color.darkened(edge_strength * 0.062)
	return color

func _bake_tile_edges(out: Image, origin: Vector2i) -> void:
	var center := Vector2(origin) + Vector2(HALF_W, HALF_H)
	var top := center + Vector2(0, -HALF_H)
	var right := center + Vector2(HALF_W, 0)
	var bottom := center + Vector2(0, HALF_H)
	var left := center + Vector2(-HALF_W, 0)
	_draw_line(out, top, right, Color(0.78, 0.86, 0.78, 0.105), 1.0)
	_draw_line(out, left, top, Color(0.78, 0.86, 0.78, 0.082), 1.0)
	_draw_line(out, right, bottom, Color(0.0, 0.0, 0.0, 0.155), 1.0)
	_draw_line(out, bottom, left, Color(0.0, 0.0, 0.0, 0.135), 1.0)

func _bake_inner_facets(out: Image, variant: int, center: Vector2) -> void:
	if _noise_variant(variant, 31) < 0.38:
		return
	var angle := -0.18 + _noise_variant(variant, 37) * 0.36
	var dir := Vector2(cos(angle), sin(angle) * 0.45).normalized()
	var tangent := Vector2(-dir.y, dir.x).normalized()
	var offset := (_noise_variant(variant, 43) - 0.5) * 12.0
	var length := 24.0 + _noise_variant(variant, 45) * 20.0
	var p := center + tangent * offset
	_draw_line(out, p - dir * length * 0.5, p + dir * length * 0.5, Color(0.0, 0.0, 0.0, 0.038), 0.8)
	_draw_line(out, p - dir * length * 0.5 + Vector2(0, -1), p + dir * length * 0.5 + Vector2(0, -1), Color(0.78, 0.86, 0.78, 0.028), 0.7)

func _bake_variant_wear(out: Image, variant: int, center: Vector2) -> void:
	var scratch_count := int(floor(_noise_variant(variant, 41) * 3.0))
	for i in scratch_count:
		var angle := -0.42 + _noise_variant(variant, 47 + i) * 0.84
		var dir := Vector2(cos(angle), sin(angle) * 0.48).normalized()
		var pos := center + Vector2(
			(_noise_variant(variant, 53 + i) - 0.5) * 46.0,
			(_noise_variant(variant, 59 + i) - 0.5) * 18.0
		)
		var length := 8.0 + _noise_variant(variant, 61 + i) * 14.0
		_draw_line(out, pos - dir * length * 0.5, pos + dir * length * 0.5, Color(0.86, 0.92, 0.82, 0.060), 0.8)
	if _noise_variant(variant, 67) > 0.42:
		var spot := center + Vector2((_noise_variant(variant, 71) - 0.5) * 42.0, (_noise_variant(variant, 73) - 0.5) * 18.0)
		_draw_soft_spot(out, spot, 6.0 + _noise_variant(variant, 79) * 10.0, Color(0.0, 0.0, 0.0, 0.030))

func _draw_soft_spot(out: Image, center: Vector2, radius: float, color: Color) -> void:
	var min_x := maxi(0, floori(center.x - radius))
	var max_x := mini(out.get_width() - 1, ceili(center.x + radius))
	var min_y := maxi(0, floori(center.y - radius * 0.45))
	var max_y := mini(out.get_height() - 1, ceili(center.y + radius * 0.45))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx := float(x) - center.x
			var dy := (float(y) - center.y) / 0.45
			var dist := sqrt(dx * dx + dy * dy)
			if dist > radius:
				continue
			var alpha := color.a * (1.0 - dist / radius)
			_blend_pixel(out, x, y, Color(color.r, color.g, color.b, alpha))

func _draw_line(out: Image, from_pos: Vector2, to_pos: Vector2, color: Color, width: float) -> void:
	var steps := maxi(1, ceili(from_pos.distance_to(to_pos)))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := from_pos.lerp(to_pos, t)
		_stamp(out, p, width, color)

func _stamp(out: Image, center: Vector2, radius: float, color: Color) -> void:
	var min_x := maxi(0, floori(center.x - radius))
	var max_x := mini(out.get_width() - 1, ceili(center.x + radius))
	var min_y := maxi(0, floori(center.y - radius))
	var max_y := mini(out.get_height() - 1, ceili(center.y + radius))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dist := Vector2(float(x), float(y)).distance_to(center)
			if dist > radius:
				continue
			var alpha := color.a * clampf(1.0 - dist / maxf(radius, 0.001), 0.25, 1.0)
			_blend_pixel(out, x, y, Color(color.r, color.g, color.b, alpha))

func _blend_pixel(out: Image, x: int, y: int, over: Color) -> void:
	if x < 0 or x >= out.get_width() or y < 0 or y >= out.get_height():
		return
	var base := out.get_pixel(x, y)
	var a := clampf(over.a, 0.0, 1.0)
	var out_alpha := a + base.a * (1.0 - a)
	if out_alpha <= 0.001:
		out.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var color := Color(
		(over.r * a + base.r * base.a * (1.0 - a)) / out_alpha,
		(over.g * a + base.g * base.a * (1.0 - a)) / out_alpha,
		(over.b * a + base.b * base.a * (1.0 - a)) / out_alpha,
		out_alpha
	)
	out.set_pixel(x, y, color)

func _sample_image(image: Image, uv: Vector2) -> Color:
	var x := clampi(roundi(uv.x * float(image.get_width() - 1)), 0, image.get_width() - 1)
	var y := clampi(roundi(uv.y * float(image.get_height() - 1)), 0, image.get_height() - 1)
	var color := image.get_pixel(x, y)
	if color.a < 0.05:
		return Color(0.30, 0.32, 0.30, 1.0)
	color.a = 1.0
	return color

func _flatten_material(color: Color, tile_tint: Color) -> Color:
	var luminance: float = color.r * 0.30 + color.g * 0.59 + color.b * 0.11
	var low_contrast := Color(
		clampf(tile_tint.r + (luminance - 0.42) * 0.18, 0.0, 1.0),
		clampf(tile_tint.g + (luminance - 0.42) * 0.18, 0.0, 1.0),
		clampf(tile_tint.b + (luminance - 0.42) * 0.16, 0.0, 1.0),
		1.0
	)
	return low_contrast.lerp(color, 0.06)

func _apply_grain(color: Color, px: int, py: int, variant: int) -> Color:
	var n: float = sin(float(px * 17 + py * 43 + variant * 131)) * 43758.5453
	var grain: float = (n - floor(n) - 0.5) * 0.012
	return Color(
		clampf(color.r + grain, 0.0, 1.0),
		clampf(color.g + grain, 0.0, 1.0),
		clampf(color.b + grain, 0.0, 1.0),
		color.a
	)

func _variant_origin(variant: int) -> Vector2i:
	return Vector2i((variant % ATLAS_COLUMNS) * TILE_W, int(floor(float(variant) / float(ATLAS_COLUMNS))) * TILE_H)

func _variant_for_cell(cell: Vector2i) -> int:
	return int(floor(_noise_cell(cell, 211) * float(VARIANT_COUNT))) % VARIANT_COUNT

func _sorted_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in GRID_SIZE:
		for x in GRID_SIZE:
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x + a.y == b.x + b.y:
			return a.x < b.x
		return a.x + a.y < b.x + b.y
	)
	return cells

func _rotate_local_uv(uv: Vector2, steps: int) -> Vector2:
	match steps:
		1:
			return Vector2(-uv.y, uv.x)
		2:
			return Vector2(-uv.x, -uv.y)
		3:
			return Vector2(uv.y, -uv.x)
	return uv

func _wrap01(value: float) -> float:
	var wrapped := value - floorf(value)
	return clampf(wrapped, 0.0, 1.0)

func _noise_cell(cell: Vector2i, salt: int) -> float:
	var value := sin(float(cell.x * 37 + cell.y * 71 + salt * 113)) * 43758.5453
	return value - floor(value)

func _noise_variant(variant: int, salt: int) -> float:
	var value := sin(float(variant * 67 + salt * 113)) * 43758.5453
	return value - floor(value)

func _write_png_import_stub(path: String) -> void:
	var file := FileAccess.open("%s.import" % path, FileAccess.WRITE)
	file.store_string("\n".join([
		"[remap]",
		"",
		"importer=\"texture\"",
		"type=\"CompressedTexture2D\"",
		"path=\"\"",
		"metadata={",
		"\"vram_texture\": false",
		"}",
		"",
		"[deps]",
		"",
		"source_file=\"%s\"" % path,
		"dest_files=[]",
		"",
		"[params]",
		"",
		"compress/mode=0",
		"compress/high_quality=false",
		"compress/lossy_quality=0.7",
		"compress/uastc_level=0",
		"compress/rdo_quality_loss=0.0",
		"compress/hdr_compression=1",
		"compress/normal_map=0",
		"compress/channel_pack=0",
		"mipmaps/generate=false",
		"mipmaps/limit=-1",
		"roughness/mode=0",
		"roughness/src_normal=\"\"",
		"process/channel_remap/red=0",
		"process/channel_remap/green=1",
		"process/channel_remap/blue=2",
		"process/fix_alpha_border=true",
		"process/premult_alpha=false",
		"process/normal_map_invert_y=false",
		"process/hdr_as_srgb=false",
		"process/hdr_clamp_exposure=false",
		"process/size_limit=0",
		"detect_3d/compress_to=1",
		"",
	]))
