extends SceneTree
## Generates a transparent decal atlas for board hazard warning cells.
##
## Run with:
##   godot --headless --path . -s tools/generate_battle_hazard_decals.gd

const OUT_PATH := "res://art/effects/battle_hazard_decals.png"
const TILE_W := 102
const TILE_H := 52
const DECAL_COUNT := 3
const ATLAS_SIZE := Vector2i(TILE_W * DECAL_COUNT, TILE_H)

const DECAL_RIFT := 0
const DECAL_BELL := 1
const DECAL_CHARGE := 2

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/effects"))
	var atlas := Image.create(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	_draw_rift_decal(atlas, _origin(DECAL_RIFT))
	_draw_bell_decal(atlas, _origin(DECAL_BELL))
	_draw_charge_decal(atlas, _origin(DECAL_CHARGE))
	var result := atlas.save_png(OUT_PATH)
	_write_png_import_stub(OUT_PATH)
	print("battle hazard decals generated: %s result=%s" % [OUT_PATH, str(result)])
	quit(0 if result == OK else 1)

func _origin(index: int) -> Vector2i:
	return Vector2i(index * TILE_W, 0)

func _center(origin: Vector2i) -> Vector2:
	return Vector2(float(origin.x) + TILE_W * 0.5, float(origin.y) + TILE_H * 0.5)

func _draw_rift_decal(image: Image, origin: Vector2i) -> void:
	var c := _center(origin)
	_ellipse(image, c + Vector2(0, 5), Vector2(25, 7), Color(0.04, 0.015, 0.006, 0.18), 0.0, 4.0)
	_broken_line(image, c + Vector2(-28, 4), c + Vector2(-11, -1), Color(0.0, 0.0, 0.0, 0.40), 4.0, 5)
	_broken_line(image, c + Vector2(-11, -1), c + Vector2(4, 5), Color(0.0, 0.0, 0.0, 0.38), 4.0, 5)
	_broken_line(image, c + Vector2(4, 5), c + Vector2(26, -5), Color(0.0, 0.0, 0.0, 0.36), 4.0, 6)
	_broken_line(image, c + Vector2(-27, 4), c + Vector2(-12, 0), Color(0.86, 0.42, 0.16, 0.34), 1.15, 5)
	_broken_line(image, c + Vector2(-9, -1), c + Vector2(3, 4), Color(0.95, 0.55, 0.20, 0.36), 1.0, 4)
	_broken_line(image, c + Vector2(7, 4), c + Vector2(25, -4), Color(0.82, 0.39, 0.15, 0.32), 1.1, 5)
	_broken_line(image, c + Vector2(-2, -15), c + Vector2(4, 14), Color(0.23, 0.54, 0.55, 0.16), 0.9, 5)
	_specks(image, c, Color(0.86, 0.45, 0.16, 0.20), 8, 26.0, 11.0, 17)

func _draw_bell_decal(image: Image, origin: Vector2i) -> void:
	var c := _center(origin)
	_ellipse(image, c + Vector2(0, 3), Vector2(32, 10), Color(0.06, 0.08, 0.09, 0.11), 0.0, 5.0)
	for radius in [Vector2(34, 13), Vector2(23, 8), Vector2(13, 4.5)]:
		_arc_outline(image, c + Vector2(0, 1), radius, 0.15, 2.65, Color(0.0, 0.0, 0.0, 0.22), 2.2, 11)
		_arc_outline(image, c + Vector2(0, 1), radius, 3.42, 5.95, Color(0.0, 0.0, 0.0, 0.18), 2.0, 11)
		_arc_outline(image, c + Vector2(0, 1), radius, 0.22, 2.44, Color(0.42, 0.60, 0.70, 0.26), 0.9, 11)
		_arc_outline(image, c + Vector2(0, 1), radius, 3.56, 5.72, Color(0.42, 0.60, 0.70, 0.20), 0.85, 11)
	_broken_line(image, c + Vector2(-16, 0), c + Vector2(16, 0), Color(0.50, 0.67, 0.74, 0.18), 0.9, 5)
	_broken_line(image, c + Vector2(0, -10), c + Vector2(0, 12), Color(0.50, 0.67, 0.74, 0.15), 0.8, 4)
	_specks(image, c, Color(0.48, 0.62, 0.68, 0.13), 8, 34.0, 13.0, 47)

func _draw_charge_decal(image: Image, origin: Vector2i) -> void:
	var c := _center(origin)
	var trail := [
		c + Vector2(-34, -6),
		c + Vector2(-14, -2),
		c + Vector2(7, -1),
		c + Vector2(30, 0),
	]
	for i in range(trail.size() - 1):
		_broken_line(image, trail[i], trail[i + 1], Color(0.0, 0.0, 0.0, 0.34), 4.2, 5)
		_broken_line(image, trail[i], trail[i + 1], Color(0.70, 0.32, 0.13, 0.24), 1.1, 5)
	var tip := c + Vector2(32, 0)
	var left := c + Vector2(18, -8)
	var right := c + Vector2(18, 8)
	_broken_line(image, left, tip, Color(0.0, 0.0, 0.0, 0.30), 3.0, 3)
	_broken_line(image, right, tip, Color(0.0, 0.0, 0.0, 0.30), 3.0, 3)
	_broken_line(image, left, tip, Color(0.78, 0.38, 0.15, 0.28), 0.95, 3)
	_broken_line(image, right, tip, Color(0.78, 0.38, 0.15, 0.26), 0.95, 3)
	_specks(image, c, Color(0.68, 0.30, 0.11, 0.15), 9, 34.0, 11.0, 59)

func _broken_line(image: Image, a: Vector2, b: Vector2, color: Color, width: float, segments: int) -> void:
	var dir := b - a
	for i in range(segments):
		if i % 3 == 2:
			continue
		var start_t := float(i) / float(segments)
		var end_t := float(i + 1) / float(segments)
		var inset := 0.10 + 0.04 * float((i * 7) % 3)
		var from := a + dir * minf(end_t, start_t + inset)
		var to := a + dir * maxf(start_t, end_t - inset * 0.65)
		if from.distance_to(to) > 1.0:
			_line(image, from, to, color, width)

func _arc_outline(image: Image, center: Vector2, radii: Vector2, start_angle: float, end_angle: float, color: Color, width: float, segments: int) -> void:
	var prev := Vector2.ZERO
	for i in range(segments + 1):
		if i % 4 == 3:
			prev = Vector2.ZERO
			continue
		var t := float(i) / float(maxi(1, segments))
		var angle := lerpf(start_angle, end_angle, t)
		var p := center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		if prev != Vector2.ZERO:
			_line(image, prev, p, color, width)
		prev = p

func _specks(image: Image, center: Vector2, color: Color, count: int, radius_x: float, radius_y: float, salt: int) -> void:
	for i in range(count):
		var nx := _noise01(i, salt) * 2.0 - 1.0
		var ny := _noise01(i, salt + 13) * 2.0 - 1.0
		if absf(nx) + absf(ny) * 0.75 > 1.25:
			continue
		var p := center + Vector2(nx * radius_x, ny * radius_y)
		var speck := color
		speck.a *= 0.55 + _noise01(i, salt + 29) * 0.45
		_ellipse(image, p, Vector2(0.9 + _noise01(i, salt + 41) * 1.4, 0.5 + _noise01(i, salt + 53) * 0.8), speck, 0.0, 1.0)

func _noise01(index: int, salt: int) -> float:
	var value := sin(float(index * 37 + salt * 101)) * 43758.5453
	return value - floor(value)

func _line(image: Image, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var min_x := int(floor(minf(a.x, b.x) - width - 1.0))
	var max_x := int(ceil(maxf(a.x, b.x) + width + 1.0))
	var min_y := int(floor(minf(a.y, b.y) - width - 1.0))
	var max_y := int(ceil(maxf(a.y, b.y) + width + 1.0))
	var ab := b - a
	var len_sq := maxf(0.001, ab.length_squared())
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
			var closest := a + ab * t
			var dist := p.distance_to(closest)
			if dist > width * 0.5 + 1.0:
				continue
			var c := color
			c.a *= clampf((width * 0.5 + 1.0 - dist), 0.0, 1.0)
			_blend_pixel(image, x, y, c)

func _ellipse(image: Image, center: Vector2, radii: Vector2, color: Color, rotation: float = 0.0, softness: float = 1.0) -> void:
	var max_radius := maxf(radii.x, radii.y) + softness
	var min_x := int(floor(center.x - max_radius))
	var max_x := int(ceil(center.x + max_radius))
	var min_y := int(floor(center.y - max_radius))
	var max_y := int(ceil(center.y + max_radius))
	var cos_r := cos(-rotation)
	var sin_r := sin(-rotation)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(x + 0.5, y + 0.5) - center
			var local := Vector2(p.x * cos_r - p.y * sin_r, p.x * sin_r + p.y * cos_r)
			var normalized := Vector2(local.x / maxf(0.001, radii.x), local.y / maxf(0.001, radii.y))
			var dist := normalized.length()
			var edge := softness / maxf(1.0, minf(radii.x, radii.y))
			if dist > 1.0 + edge:
				continue
			var c := color
			c.a *= clampf((1.0 + edge - dist) / maxf(0.001, edge), 0.0, 1.0)
			_blend_pixel(image, x, y, c)

func _ellipse_outline(image: Image, center: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var max_radius := maxf(radii.x, radii.y) + width + 1.0
	for y in range(int(floor(center.y - max_radius)), int(ceil(center.y + max_radius)) + 1):
		for x in range(int(floor(center.x - max_radius)), int(ceil(center.x + max_radius)) + 1):
			var p := Vector2(x + 0.5, y + 0.5) - center
			var normalized := Vector2(p.x / maxf(0.001, radii.x), p.y / maxf(0.001, radii.y))
			var dist := absf(normalized.length() - 1.0) * minf(radii.x, radii.y)
			if dist > width:
				continue
			var c := color
			c.a *= clampf((width - dist) / maxf(0.001, width), 0.0, 1.0)
			_blend_pixel(image, x, y, c)

func _poly(image: Image, points: Array, color: Color) -> void:
	var min_x := 9999.0
	var max_x := -9999.0
	var min_y := 9999.0
	var max_y := -9999.0
	for point: Vector2 in points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	for y in range(int(floor(min_y)) - 1, int(ceil(max_y)) + 2):
		for x in range(int(floor(min_x)) - 1, int(ceil(max_x)) + 2):
			if _point_in_poly(Vector2(x + 0.5, y + 0.5), points):
				_blend_pixel(image, x, y, color)

func _point_in_poly(point: Vector2, points: Array) -> bool:
	var inside := false
	var j := points.size() - 1
	for i in range(points.size()):
		var pi: Vector2 = points[i]
		var pj: Vector2 = points[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x:
			inside = not inside
		j = i
	return inside

func _blend_pixel(image: Image, x: int, y: int, source: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height() or source.a <= 0.0:
		return
	var dest := image.get_pixel(x, y)
	var out_a := source.a + dest.a * (1.0 - source.a)
	if out_a <= 0.0:
		image.set_pixel(x, y, Color(0, 0, 0, 0))
		return
	var out := Color()
	out.r = (source.r * source.a + dest.r * dest.a * (1.0 - source.a)) / out_a
	out.g = (source.g * source.a + dest.g * dest.a * (1.0 - source.a)) / out_a
	out.b = (source.b * source.a + dest.b * dest.a * (1.0 - source.a)) / out_a
	out.a = out_a
	image.set_pixel(x, y, out)

func _write_png_import_stub(path: String) -> void:
	var import_path := "%s.import" % ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(import_path):
		return
	var file := FileAccess.open(import_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\nuid=\"uid://battlehazarddecals\"\npath=\"res://.godot/imported/%s.ctex\"\n\n[deps]\n\nsource_file=\"%s\"\ndest_files=[]\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\nprocess/fix_alpha_border=true\n" % [path.get_file(), path])
