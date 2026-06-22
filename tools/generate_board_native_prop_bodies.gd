extends SceneTree
## Generates board-native one-cell prop body sprites.
##
## This is the production-friendly prop path for the tactical board: deterministic
## dimetric stone bodies that share the board tile palette and footprint. The
## sprites are still body-only sources; placement and contact are controlled by
## BattleBoardPropProfile resources.
##
## Run with:
##   godot --path . --script tools/generate_board_native_prop_bodies.gd

const CANVAS := Vector2i(1024, 1024)
const RENDER_SCALE := 2

const OUT_BUILDING := "res://art/tiles/board_building_body_v2.png"
const OUT_PILLAR := "res://art/tiles/board_pillar_body_v2.png"
const OUT_RUIN := "res://art/tiles/board_ruin_body_v2.png"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _render("building", OUT_BUILDING)
	await _render("pillar", OUT_PILLAR)
	await _render("ruin", OUT_RUIN)
	quit(0)

func _render(kind: String, out_path: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = CANVAS * RENDER_SCALE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var sprite := PropBodyCanvas.new()
	sprite.kind = kind
	sprite.scale = Vector2(RENDER_SCALE, RENDER_SCALE)
	viewport.add_child(sprite)

	for i in range(8):
		await process_frame

	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(CANVAS.x, CANVAS.y, Image.INTERPOLATE_LANCZOS)
	var absolute := ProjectSettings.globalize_path(out_path)
	var result := image.save_png(absolute)
	var bbox := _alpha_bbox(image)
	print("%s board-native body: %s result=%s bbox=%s" % [kind, absolute, str(result), str(bbox)])
	viewport.queue_free()

func _alpha_bbox(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

class PropBodyCanvas:
	extends Node2D

	var kind := ""

	const LINE_DARK := Color(0.038, 0.041, 0.041, 1.0)
	const LINE_SOFT := Color(0.17, 0.18, 0.17, 0.90)
	const EDGE_LIT := Color(0.72, 0.70, 0.58, 0.82)
	const TOP := Color(0.405, 0.405, 0.370, 1.0)
	const TOP_LIT := Color(0.545, 0.535, 0.455, 1.0)
	const TOP_DARK := Color(0.285, 0.300, 0.290, 1.0)
	const LEFT := Color(0.335, 0.345, 0.325, 1.0)
	const RIGHT := Color(0.215, 0.225, 0.220, 1.0)
	const FRONT := Color(0.245, 0.255, 0.240, 1.0)
	const DEEP := Color(0.055, 0.058, 0.056, 1.0)
	const AMBER := Color(0.96, 0.45, 0.16, 1.0)
	const AMBER_DARK := Color(0.42, 0.16, 0.07, 1.0)
	const OLD_MOSS := Color(0.24, 0.30, 0.20, 0.36)

	func _draw() -> void:
		match kind:
			"building":
				_draw_building()
			"pillar":
				_draw_pillar()
			"ruin":
				_draw_ruin()

	func _draw_building() -> void:
		var base := _iso_box(Vector2(512, 326), 326, 152, 340, TOP, LEFT, RIGHT)
		_draw_face_panels(base, 5, 0.26)
		_draw_vertical_reveals(base, 4)

		_iso_box(Vector2(346, 386), 82, 40, 246, TOP_DARK.lightened(0.04), LEFT.darkened(0.02), RIGHT.darkened(0.04))
		_iso_box(Vector2(678, 386), 82, 40, 246, TOP_DARK.lightened(0.04), LEFT.darkened(0.02), RIGHT.darkened(0.04))
		_iso_box(Vector2(512, 280), 242, 112, 108, TOP_LIT, LEFT.lightened(0.05), RIGHT.lightened(0.04))
		_iso_box(Vector2(512, 238), 148, 68, 58, TOP_LIT.lightened(0.04), LEFT.lightened(0.07), RIGHT.lightened(0.05))

		_draw_top_inset(Vector2(512, 238), 108, 50, Color(0.23, 0.24, 0.23, 0.95))
		_draw_ambertile(Vector2(512, 612), 118, 38)
		_draw_small_blocks(Vector2(512, 269), 276, 6)
		_draw_stone_marks(Vector2(512, 402), 292, 170, 12)
		_draw_cracks(Vector2(512, 472), 288, 5)
		_draw_old_moss(Vector2(512, 360), 250, 2)
		_draw_attached_chips(Vector2(512, 818), 320, 6)

	func _draw_pillar() -> void:
		var base := _iso_box(Vector2(512, 565), 380, 172, 122, TOP_DARK.lightened(0.08), LEFT, RIGHT)
		_draw_face_panels(base, 4, 0.22)
		_draw_top_inset(Vector2(512, 565), 286, 128, Color(0.27, 0.28, 0.27, 0.72))

		_iso_box(Vector2(333, 522), 110, 50, 116, TOP_LIT, LEFT.lightened(0.05), RIGHT)
		_iso_box(Vector2(500, 477), 124, 58, 148, TOP_LIT.lightened(0.02), LEFT.lightened(0.04), RIGHT)
		_iso_box(Vector2(676, 530), 104, 47, 106, TOP, LEFT, RIGHT.darkened(0.04))
		_iso_box(Vector2(530, 602), 134, 54, 62, TOP_DARK.lightened(0.07), LEFT.darkened(0.04), RIGHT.darkened(0.02))
		_draw_broken_cap(Vector2(500, 477), 124, 58)

		_draw_stone_marks(Vector2(512, 574), 330, 130, 9)
		_draw_cracks(Vector2(518, 606), 250, 3)
		_draw_old_moss(Vector2(506, 586), 290, 1)
		_draw_attached_chips(Vector2(512, 814), 360, 5)

	func _draw_ruin() -> void:
		var base := _iso_box(Vector2(512, 586), 386, 166, 92, TOP_DARK.lightened(0.08), LEFT.darkened(0.02), RIGHT.darkened(0.03))
		_draw_top_inset(Vector2(512, 586), 304, 124, Color(0.24, 0.25, 0.24, 0.62))
		_draw_face_panels(base, 5, 0.20)

		_draw_wall_segment(Vector2(242, 532), 134, 58, 142)
		_draw_wall_segment(Vector2(382, 492), 136, 60, 196)
		_draw_wall_segment(Vector2(528, 526), 148, 62, 146)
		_draw_wall_segment(Vector2(678, 570), 136, 56, 92)

		_draw_broken_cap(Vector2(384, 489), 136, 60)
		_draw_broken_cap(Vector2(526, 520), 146, 62)
		_draw_stone_marks(Vector2(492, 598), 360, 126, 11)
		_draw_cracks(Vector2(506, 612), 330, 4)
		_draw_old_moss(Vector2(500, 610), 340, 2)
		_draw_attached_chips(Vector2(512, 805), 374, 7)

	func _iso_box(center: Vector2, half_w: float, half_h: float, height: float, top_color: Color, left_color: Color, right_color: Color) -> Dictionary:
		var top := center + Vector2(0, -half_h)
		var right := center + Vector2(half_w, 0)
		var bottom := center + Vector2(0, half_h)
		var left := center + Vector2(-half_w, 0)
		var right_down := right + Vector2(0, height)
		var bottom_down := bottom + Vector2(0, height)
		var left_down := left + Vector2(0, height)

		_poly([left, bottom, bottom_down, left_down], left_color)
		_poly([right, bottom, bottom_down, right_down], right_color)
		_poly([left_down, bottom_down, right_down, bottom + Vector2(0, height * 0.64)], FRONT)
		_poly([top, right, bottom, left], top_color)

		_line(left, top, EDGE_LIT, 3.0)
		_line(top, right, Color(0.58, 0.58, 0.50, 0.72), 2.2)
		_line(left, bottom, LINE_SOFT, 2.4)
		_line(right, bottom, LINE_DARK, 2.8)
		_line(left, left_down, LINE_DARK, 2.2)
		_line(right, right_down, LINE_DARK, 2.2)
		_line(left_down, bottom_down, LINE_DARK, 3.0)
		_line(bottom_down, right_down, LINE_DARK, 3.0)
		_line(bottom, bottom_down, Color(0.03, 0.045, 0.043, 0.70), 1.7)

		return {
			"left": left,
			"right": right,
			"bottom": bottom,
			"left_down": left_down,
			"right_down": right_down,
			"bottom_down": bottom_down,
			"height": height,
			"half_w": half_w,
			"half_h": half_h,
		}

	func _draw_wall_segment(center: Vector2, half_w: float, half_h: float, height: float) -> void:
		_iso_box(center, half_w, half_h, height, TOP, LEFT.lightened(0.02), RIGHT)

	func _draw_broken_cap(center: Vector2, half_w: float, half_h: float) -> void:
		var p0 := center + Vector2(-half_w * 0.92, -half_h * 0.05)
		var p1 := center + Vector2(-half_w * 0.30, -half_h * 0.58)
		var p2 := center + Vector2(half_w * 0.18, -half_h * 0.40)
		var p3 := center + Vector2(half_w * 0.84, half_h * 0.08)
		var p4 := center + Vector2(half_w * 0.18, half_h * 0.55)
		var p5 := center + Vector2(-half_w * 0.54, half_h * 0.38)
		_poly([p0, p1, p2, p3, p4, p5], TOP_LIT)
		_line(p0, p1, EDGE_LIT, 2.0)
		_line(p2, p3, LINE_SOFT, 1.6)
		_line(p4, p5, LINE_DARK, 1.8)

	func _draw_top_inset(center: Vector2, half_w: float, half_h: float, color: Color) -> void:
		var points := [
			center + Vector2(0, -half_h),
			center + Vector2(half_w, 0),
			center + Vector2(0, half_h),
			center + Vector2(-half_w, 0),
		]
		_poly(points, color)
		_line(points[3], points[0], Color(0.78, 0.76, 0.62, 0.42), 1.4)
		_line(points[1], points[2], Color(0.02, 0.03, 0.03, 0.38), 1.8)

	func _draw_ambertile(center: Vector2, width: float, height: float) -> void:
		var outer := Rect2(center - Vector2(width * 0.5, height * 0.5), Vector2(width, height))
		draw_rect(outer, DEEP, true)
		draw_rect(outer, LINE_DARK, false, 2.0)
		var inner := Rect2(center - Vector2(width * 0.34, height * 0.24), Vector2(width * 0.68, height * 0.48))
		draw_rect(inner, AMBER_DARK, true)
		draw_rect(inner.grow(-3), AMBER, true)

	func _draw_small_blocks(center: Vector2, span: float, count: int) -> void:
		for i in range(count):
			var t := 0.0 if count <= 1 else float(i) / float(count - 1)
			var x := center.x - span * 0.5 + span * t
			var y := center.y + 16.0 * sin(t * PI)
			_iso_box(Vector2(x, y), 28, 13, 34, TOP_LIT, LEFT, RIGHT)

	func _draw_face_panels(box: Dictionary, count: int, alpha: float) -> void:
		for i in range(count):
			var t := (float(i) + 0.5) / float(count)
			var left: Vector2 = box.left.lerp(box.bottom, t)
			var left_down: Vector2 = box.left_down.lerp(box.bottom_down, t)
			var right: Vector2 = box.bottom.lerp(box.right, t)
			var right_down: Vector2 = box.bottom_down.lerp(box.right_down, t)
			_line(left + Vector2(0, 10), left_down - Vector2(0, 18), Color(0.03, 0.045, 0.042, alpha), 1.8)
			_line(right + Vector2(0, 10), right_down - Vector2(0, 18), Color(0.03, 0.045, 0.042, alpha), 1.8)

	func _draw_vertical_reveals(box: Dictionary, count: int) -> void:
		for i in range(count):
			var t := (float(i) + 1.0) / float(count + 1)
			var x := lerpf(box.left.x + 48.0, box.right.x - 48.0, t)
			var y_top := lerpf(box.bottom.y + 30.0, box.bottom.y + 8.0, absf(t - 0.5) * 2.0)
			_line(Vector2(x, y_top), Vector2(x, y_top + box.height * 0.58), Color(0.02, 0.035, 0.034, 0.36), 2.0)
			_line(Vector2(x + 2, y_top), Vector2(x + 2, y_top + box.height * 0.45), Color(0.55, 0.61, 0.50, 0.20), 0.9)

	func _draw_stone_marks(center: Vector2, width: float, height: float, count: int) -> void:
		for i in range(count):
			var n0 := _noise(i, 13)
			var n1 := _noise(i, 29)
			var x := center.x - width * 0.5 + width * n0
			var y := center.y - height * 0.5 + height * n1
			var length := 18.0 + 36.0 * _noise(i, 47)
			var angle := -0.45 + 0.90 * _noise(i, 61)
			var a := Vector2(x, y)
			var b := a + Vector2(cos(angle), sin(angle)) * length
			_line(a, b, Color(0.78, 0.77, 0.64, 0.15), 1.0)
			_line(a + Vector2(0, 2), b + Vector2(0, 2), Color(0.03, 0.04, 0.04, 0.14), 1.0)

	func _draw_cracks(center: Vector2, width: float, count: int) -> void:
		for i in range(count):
			var start := center + Vector2(-width * 0.5 + width * _noise(i, 101), -20.0 + 42.0 * _noise(i, 109))
			var previous := start
			for j in range(3):
				var next := previous + Vector2(-18.0 + 36.0 * _noise(i * 7 + j, 127), 18.0 + 30.0 * _noise(i * 5 + j, 149))
				_line(previous, next, Color(0.025, 0.035, 0.034, 0.30), 1.6)
				previous = next

	func _draw_attached_chips(center: Vector2, span: float, count: int) -> void:
		for i in range(count):
			var t := (float(i) + 0.5) / float(count)
			var x := center.x - span * 0.5 + span * t + (-18.0 + 36.0 * _noise(i, 173))
			var y := center.y + (-20.0 + 34.0 * _noise(i, 181))
			var hw := 16.0 + 18.0 * _noise(i, 191)
			var hh := 8.0 + 9.0 * _noise(i, 199)
			var c := Vector2(x, y)
			var points := [c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)]
			_poly(points, Color(0.24, 0.30, 0.28, 0.96))
			_line(points[3], points[0], Color(0.70, 0.68, 0.56, 0.36), 0.9)
			_line(points[1], points[2], Color(0.02, 0.03, 0.03, 0.32), 1.0)

	func _draw_old_moss(center: Vector2, width: float, count: int) -> void:
		for i in range(count):
			var x := center.x - width * 0.5 + width * _noise(i, 211)
			var y := center.y + (-18.0 + 36.0 * _noise(i, 223))
			var a := Vector2(x - 26.0 * _noise(i, 227), y)
			var b := Vector2(x + 18.0 + 22.0 * _noise(i, 229), y + 3.0 + 8.0 * _noise(i, 233))
			_line(a, b, OLD_MOSS, 2.0)

	func _poly(points: Array, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array(points), color)

	func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
		draw_line(a, b, color, width, true)

	func _noise(i: int, salt: int) -> float:
		var value := (i * 928371 + salt * 689287 + (i ^ salt) * 97) & 0xffff
		return float(value % 1000) / 999.0
