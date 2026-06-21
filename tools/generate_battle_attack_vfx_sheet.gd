extends SceneTree

const OUT_PATH := "res://art/effects/battle_attack_vfx_sheet.png"
const CELL := 96
const COLUMNS := 6
const ROWS := 6

const IRON := Color(0.045, 0.036, 0.030, 1.0)
const IRON_SOFT := Color(0.080, 0.064, 0.050, 0.72)
const DUST_DARK := Color(0.210, 0.170, 0.125, 0.62)
const DUST := Color(0.360, 0.285, 0.200, 0.66)
const DUST_LIT := Color(0.520, 0.390, 0.235, 0.58)
const EMBER := Color(0.660, 0.335, 0.105, 0.74)
const EMBER_DIM := Color(0.405, 0.170, 0.060, 0.44)
const BONE := Color(0.760, 0.575, 0.315, 0.58)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var image := Image.create(CELL * COLUMNS, CELL * ROWS, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for frame in range(COLUMNS):
		_draw_muzzle_frame(image, Vector2(frame * CELL, 0), frame)
		_draw_projectile_frame(image, Vector2(frame * CELL, CELL), frame)
		_draw_impact_frame(image, Vector2(frame * CELL, CELL * 2), frame)
		_draw_dust_frame(image, Vector2(frame * CELL, CELL * 3), frame)
		_draw_slash_frame(image, Vector2(frame * CELL, CELL * 4), frame)
		_draw_tether_frame(image, Vector2(frame * CELL, CELL * 5), frame)
	var result := image.save_png(ProjectSettings.globalize_path(OUT_PATH))
	if result != OK:
		push_error("Failed to save %s" % OUT_PATH)
		quit(1)
		return
	quit(0)

func _draw_muzzle_frame(image: Image, origin: Vector2, frame: int) -> void:
	var t := float(mini(frame, 3)) / 3.0
	var center := origin + Vector2(48, 48)
	var length := lerpf(12.0, 34.0, t)
	var spread := lerpf(12.0, 24.0, t)
	var alpha := 1.0 - t * 0.52
	_line(image, center - Vector2(length * 0.30, 0), center + Vector2(length, 0), 8.0, Color(IRON.r, IRON.g, IRON.b, 0.78 * alpha))
	_line(image, center - Vector2(3, 0), center + Vector2(length * 0.72, 0), 3.4, Color(EMBER.r, EMBER.g, EMBER.b, 0.62 * alpha))
	_line(image, center - Vector2(2, 0), center + Vector2(length * 0.38, -spread * 0.45), 3.0, Color(DUST.r, DUST.g, DUST.b, 0.46 * alpha))
	_line(image, center - Vector2(2, 0), center + Vector2(length * 0.35, spread * 0.40), 3.0, Color(DUST_LIT.r, DUST_LIT.g, DUST_LIT.b, 0.40 * alpha))
	_circle(image, center - Vector2(7 + t * 5.0, -3), 5.5 + t * 5.5, Color(DUST_DARK.r, DUST_DARK.g, DUST_DARK.b, 0.18 * alpha), 8.0)

func _draw_projectile_frame(image: Image, origin: Vector2, frame: int) -> void:
	var t := float(mini(frame, 3)) / 3.0
	var center := origin + Vector2(48, 48)
	var phase := sin(t * PI)
	var drift := sin(t * TAU) * 1.4
	var dir := Vector2(1.0, -0.10).normalized()
	var normal := dir.rotated(PI * 0.5)
	for band in range(5):
		var k_band := float(band)
		var travel := fmod(t * 0.34 + k_band * 0.17, 1.0)
		var band_center := center - dir * (38.0 - travel * 58.0) + normal * ((k_band - 2.0) * 4.0 + drift)
		var half_len := 8.0 + phase * 2.5 - k_band * 0.45
		var split := 2.0 + k_band * 0.8
		var a := band_center - dir * (half_len + split)
		var b := band_center + dir * (half_len * 0.55)
		var under_alpha := 0.34 - k_band * 0.026
		var lit_alpha := 0.27 - k_band * 0.021
		_line(image, a, b, 4.0 - k_band * 0.24, Color(IRON.r, IRON.g, IRON.b, under_alpha))
		_line(image, a + normal * 0.8, b + normal * 0.8, 1.3, Color(DUST_LIT.r, DUST_LIT.g, DUST_LIT.b, lit_alpha))
		if band % 2 == 0:
			var chip_center := b + dir * (2.5 + phase * 2.0)
			_line(image, chip_center - normal * 2.8, chip_center + normal * 3.4, 1.4, Color(BONE.r, BONE.g, BONE.b, lit_alpha * 0.88))
	for i in range(3):
		var k := float(i)
		var spark_t := fmod(t * 0.50 + k * 0.31, 1.0)
		var start := center + Vector2(-30.0 + spark_t * 42.0, -9.0 + k * 8.0 + drift * 0.3)
		var end_pt := start + Vector2(10.0 + phase * 2.0, -1.2 + sin(k + t * TAU) * 1.1)
		var alpha := 0.29 - k * 0.040
		_line(image, start, end_pt, 2.8, Color(IRON.r, IRON.g, IRON.b, alpha))
		_line(image, start + Vector2(1, 0), end_pt + Vector2(1, 0), 1.0, Color(BONE.r, BONE.g, BONE.b, alpha * 0.70))
		_circle(image, end_pt + normal * (k - 1.0) * 1.8, 0.9 + phase * 0.25, Color(EMBER_DIM.r, EMBER_DIM.g, EMBER_DIM.b, 0.13), 1.6)

func _draw_impact_frame(image: Image, origin: Vector2, frame: int) -> void:
	var t := float(frame) / 5.0
	var center := origin + Vector2(48, 50)
	var burst := sin(t * PI)
	var radius := lerpf(7.0, 30.0, t)
	var alpha := 1.0 - t * 0.34
	_ellipse(image, center + Vector2(0, 4), Vector2(15.0 + burst * 9.0, 6.0 + burst * 3.0), Color(IRON.r, IRON.g, IRON.b, 0.20 * alpha), -0.08)
	for i in range(7):
		var angle := -0.72 * PI + float(i) * PI / 6.0
		var dir := Vector2(cos(angle), sin(angle))
		var inner := center + dir * radius * 0.18
		var outer := center + dir * (radius + float(i % 2) * 4.0)
		var width := 4.0 - t * 1.9
		_line(image, inner, outer, width + 1.6, Color(IRON.r, IRON.g, IRON.b, 0.56 * alpha))
		_line(image, inner, outer, maxf(0.9, width * 0.34), Color(EMBER.r, EMBER.g, EMBER.b, 0.44 * alpha))
		if i % 2 == 0:
			var chip := center + dir * (radius * 0.72)
			_circle(image, chip, 2.2 + burst * 0.9, Color(BONE.r, BONE.g, BONE.b, 0.18 * alpha), 2.4)
	_circle(image, center, 4.4 + 2.4 * burst, Color(EMBER.r, EMBER.g, EMBER.b, 0.34 * alpha), 4.2)

func _draw_dust_frame(image: Image, origin: Vector2, frame: int) -> void:
	var t := float(frame) / 5.0
	var center := origin + Vector2(48, 55)
	var alpha := 1.0 - t * 0.50
	_line(image, center + Vector2(-24 - t * 7.0, 6 + t * 2.0), center + Vector2(22 + t * 8.0, 1 - t * 1.0), 2.2, Color(IRON_SOFT.r, IRON_SOFT.g, IRON_SOFT.b, 0.16 * alpha))
	_line(image, center + Vector2(-16 - t * 5.0, -1 - t * 2.0), center + Vector2(15 + t * 6.0, -4 - t * 4.0), 1.6, Color(DUST.r, DUST.g, DUST.b, 0.16 * alpha))
	_line(image, center + Vector2(-8 - t * 3.0, 12 + t * 2.0), center + Vector2(17 + t * 5.0, 8 + t * 1.0), 1.4, Color(DUST_DARK.r, DUST_DARK.g, DUST_DARK.b, 0.14 * alpha))
	_circle(image, center + Vector2(-5, -6 - t * 5.0), 1.6, Color(EMBER_DIM.r, EMBER_DIM.g, EMBER_DIM.b, 0.18 * alpha), 2.0)

func _draw_slash_frame(image: Image, origin: Vector2, frame: int) -> void:
	var t := float(mini(frame, 4)) / 4.0
	var center := origin + Vector2(48, 48)
	var open := sin(t * PI)
	var a := center + Vector2(-31 + t * 8.0, 23 - open * 5.0)
	var b := center + Vector2(-12 + t * 5.0, 3 - open * 9.0)
	var c := center + Vector2(17 + t * 3.0, -14 - open * 4.0)
	var d := center + Vector2(34, -21 + t * 6.0)
	var alpha := 0.70 + open * 0.25
	_polyline(image, [a, b, c, d], 9.0 - t * 2.0, Color(IRON.r, IRON.g, IRON.b, 0.80 * alpha))
	_polyline(image, [a, b, c, d], 4.0 - t * 1.2, Color(DUST.r, DUST.g, DUST.b, 0.66 * alpha))
	_line(image, b + Vector2(2, -1), d - Vector2(8, -2), 1.7, Color(EMBER.r, EMBER.g, EMBER.b, 0.52 * alpha))
	if frame >= 2:
		_line(image, center + Vector2(-29, 18), center + Vector2(-20, 25), 2.0, Color(DUST_DARK.r, DUST_DARK.g, DUST_DARK.b, 0.42))

func _draw_tether_frame(image: Image, origin: Vector2, frame: int) -> void:
	var t := float(mini(frame, 3)) / 3.0
	var center := origin + Vector2(48, 48)
	var y := sin(t * PI * 2.0) * 2.0
	_line(image, center + Vector2(-38, y + 1), center + Vector2(38, y - 1), 6.0, Color(IRON.r, IRON.g, IRON.b, 0.74))
	_line(image, center + Vector2(-36, y), center + Vector2(36, y - 1), 2.1, Color(DUST.r, DUST.g, DUST.b, 0.56))
	for x in [-24, -8, 8, 24]:
		var lean := lerpf(-5.0, 5.0, fmod(t + float(x + 24) / 48.0, 1.0))
		_line(image, center + Vector2(x - 5, y + 6), center + Vector2(x + 5 + lean, y - 6), 3.0, Color(IRON_SOFT.r, IRON_SOFT.g, IRON_SOFT.b, 0.56))
		_line(image, center + Vector2(x - 2, y + 4), center + Vector2(x + 3 + lean * 0.5, y - 4), 1.1, Color(DUST_LIT.r, DUST_LIT.g, DUST_LIT.b, 0.35))

func _polyline(image: Image, points: Array, width: float, color: Color) -> void:
	for i in range(points.size() - 1):
		_line(image, points[i], points[i + 1], width, color)

func _line(image: Image, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var min_x := int(floor(minf(a.x, b.x) - width - 1.0))
	var max_x := int(ceil(maxf(a.x, b.x) + width + 1.0))
	var min_y := int(floor(minf(a.y, b.y) - width - 1.0))
	var max_y := int(ceil(maxf(a.y, b.y) + width + 1.0))
	var ab := b - a
	var len_sq := ab.length_squared()
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := 0.0
			if len_sq > 0.0001:
				t = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
			var closest := a + ab * t
			var dist := p.distance_to(closest)
			var edge := width * 0.5
			if dist <= edge + 1.0:
				var c := color
				c.a *= clampf(edge + 1.0 - dist, 0.0, 1.0)
				_blend_pixel(image, x, y, c)

func _arc(image: Image, center: Vector2, radius: Vector2, start_angle: float, end_angle: float, width: float, color: Color) -> void:
	var previous := center + Vector2(cos(start_angle) * radius.x, sin(start_angle) * radius.y)
	var steps := 30
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var angle := lerpf(start_angle, end_angle, t)
		var point := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		_line(image, previous, point, width, color)
		previous = point

func _circle(image: Image, center: Vector2, radius: float, color: Color, softness: float = 1.0) -> void:
	var min_x := int(floor(center.x - radius - softness))
	var max_x := int(ceil(center.x + radius + softness))
	var min_y := int(floor(center.y - radius - softness))
	var max_y := int(ceil(center.y + radius + softness))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if dist <= radius + softness:
				var c := color
				if softness > 0.0:
					c.a *= clampf((radius + softness - dist) / softness, 0.0, 1.0)
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
			var local := Vector2(
				p.x * cos_r - p.y * sin_r,
				p.x * sin_r + p.y * cos_r
			)
			var normalized := Vector2(local.x / maxf(0.001, radii.x), local.y / maxf(0.001, radii.y))
			var dist := normalized.length()
			if dist <= 1.0 + softness / maxf(1.0, minf(radii.x, radii.y)):
				var c := color
				if softness > 0.0:
					var edge := softness / maxf(1.0, minf(radii.x, radii.y))
					c.a *= clampf((1.0 + edge - dist) / edge, 0.0, 1.0)
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
