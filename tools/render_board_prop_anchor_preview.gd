extends SceneTree
## Renders prop sprite bounds, board foot anchors, and one-cell footprint guides.
##
## This tool composites from source PNG pixels directly. It intentionally avoids
## Texture2D drawing so atlas coordinates or imported texture state cannot hide
## the real source alpha during review.

const OUT_PATH := "res://tmp/board_prop_anchor_preview.png"
const CAPTURE_SIZE := Vector2i(960, 420)
const TILE_W := 102.0
const TILE_H := 52.0
const TILE_HALF := Vector2(TILE_W * 0.5, TILE_H * 0.5)
const BattleBoardAssetProfilesScript := preload("res://scripts/data/battle_board_asset_profiles.gd")

func _init() -> void:
	var image := Image.create(CAPTURE_SIZE.x, CAPTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.035, 0.035, 0.034, 1.0))

	var profiles := BattleBoardAssetProfilesScript.load_runtime_profiles()
	var ids := [
		BattleBoardAssetProfilesScript.ID_BUILDING_BODY,
		BattleBoardAssetProfilesScript.ID_PILLAR_BODY,
		BattleBoardAssetProfilesScript.ID_RUIN_BODY,
	]
	for i in range(ids.size()):
		var id := String(ids[i])
		var profile: Dictionary = profiles.get(id, {})
		if profile.is_empty():
			continue
		var center := Vector2(170.0 + i * 300.0, 260.0)
		_draw_diamond(image, center)
		_draw_anchor_guides(image, center, profile)
		_draw_prop(image, center, profile)

	var path := ProjectSettings.globalize_path(OUT_PATH)
	var result := image.save_png(path)
	print("board prop anchor preview: %s result=%s" % [path, str(result)])
	quit(0 if result == OK else 1)

func _draw_diamond(image: Image, center: Vector2) -> void:
	var top := center + Vector2(0, -TILE_HALF.y)
	var right := center + Vector2(TILE_HALF.x, 0)
	var bottom := center + Vector2(0, TILE_HALF.y)
	var left := center + Vector2(-TILE_HALF.x, 0)
	_fill_triangle(image, top, right, bottom, Color(0.25, 0.28, 0.26, 1))
	_fill_triangle(image, top, bottom, left, Color(0.22, 0.25, 0.23, 1))
	_draw_line(image, left, top, Color(0.82, 0.94, 0.78, 0.72), 2)
	_draw_line(image, top, right, Color(0.82, 0.94, 0.78, 0.72), 2)
	_draw_line(image, right, bottom, Color(0.82, 0.94, 0.78, 0.72), 2)
	_draw_line(image, bottom, left, Color(0.82, 0.94, 0.78, 0.72), 2)

func _draw_anchor_guides(image: Image, center: Vector2, profile: Dictionary) -> void:
	var foot: Vector2 = center + profile.get("foot_offset", Vector2.ZERO)
	var foundation_scale: Vector2 = profile.get("foundation_scale", Vector2.ONE)
	var foundation_offset: Vector2 = profile.get("foundation_offset", Vector2.ZERO)
	var foundation_center := foot + foundation_offset
	var span_x := TILE_HALF.x * foundation_scale.x
	var span_y := TILE_HALF.y * foundation_scale.y
	var guide := [
		foundation_center + Vector2(0, -span_y),
		foundation_center + Vector2(span_x, 0),
		foundation_center + Vector2(0, span_y),
		foundation_center + Vector2(-span_x, 0),
	]
	for i in range(guide.size()):
		_draw_line(image, guide[i], guide[(i + 1) % guide.size()], Color(1.0, 0.72, 0.22, 0.86), 2)
	_draw_line(image, foot + Vector2(-10, 0), foot + Vector2(10, 0), Color(1, 0.2, 0.2, 1), 2)
	_draw_line(image, foot + Vector2(0, -10), foot + Vector2(0, 10), Color(1, 0.2, 0.2, 1), 2)

func _draw_prop(image: Image, center: Vector2, profile: Dictionary) -> void:
	var source := String(profile.get("source", ""))
	if source.is_empty():
		return
	var prop_image := Image.load_from_file(source)
	if prop_image == null:
		return
	prop_image.convert(Image.FORMAT_RGBA8)
	var foot: Vector2 = center + profile.get("foot_offset", Vector2.ZERO)
	var crop: Rect2 = profile.get("crop", Rect2())
	var rect := BattleBoardAssetProfilesScript.profile_draw_rect(foot, profile)
	var prop_scaled := _crop_and_scale(prop_image, crop, Vector2i(maxi(1, roundi(rect.size.x)), maxi(1, roundi(rect.size.y))))
	image.blend_rect(prop_scaled, Rect2i(Vector2i.ZERO, prop_scaled.get_size()), Vector2i(roundi(rect.position.x), roundi(rect.position.y)))
	_draw_rect_outline(image, rect, Color(0.1, 0.75, 1.0, 0.80), 2)

func _crop_and_scale(source: Image, crop: Rect2, size: Vector2i) -> Image:
	var cropped := Image.create(int(crop.size.x), int(crop.size.y), false, Image.FORMAT_RGBA8)
	cropped.fill(Color(0, 0, 0, 0))
	cropped.blit_rect(
		source,
		Rect2i(Vector2i(int(crop.position.x), int(crop.position.y)), Vector2i(int(crop.size.x), int(crop.size.y))),
		Vector2i.ZERO
	)
	cropped.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return cropped

func _draw_rect_outline(image: Image, rect: Rect2, color: Color, width: int) -> void:
	var top_left := rect.position
	var top_right := rect.position + Vector2(rect.size.x, 0)
	var bottom_right := rect.position + rect.size
	var bottom_left := rect.position + Vector2(0, rect.size.y)
	_draw_line(image, top_left, top_right, color, width)
	_draw_line(image, top_right, bottom_right, color, width)
	_draw_line(image, bottom_right, bottom_left, color, width)
	_draw_line(image, bottom_left, top_left, color, width)

func _fill_triangle(image: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x := maxi(0, floori(minf(a.x, minf(b.x, c.x))))
	var max_x := mini(image.get_width() - 1, ceili(maxf(a.x, maxf(b.x, c.x))))
	var min_y := maxi(0, floori(minf(a.y, minf(b.y, c.y))))
	var max_y := mini(image.get_height() - 1, ceili(maxf(a.y, maxf(b.y, c.y))))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if _point_in_triangle(p, a, b, c):
				image.set_pixel(x, y, color)

func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _sign(p, a, b)
	var d2 := _sign(p, b, c)
	var d3 := _sign(p, c, a)
	var has_neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_neg and has_pos)

func _sign(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)

func _draw_line(image: Image, a: Vector2, b: Vector2, color: Color, width: int = 1) -> void:
	var steps := maxi(1, ceili(a.distance_to(b)))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := a.lerp(b, t)
		var radius := maxi(0, width / 2)
		for oy in range(-radius, radius + 1):
			for ox in range(-radius, radius + 1):
				var x := roundi(p.x) + ox
				var y := roundi(p.y) + oy
				if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
					image.blend_rect(_solid_pixel(color), Rect2i(Vector2i.ZERO, Vector2i.ONE), Vector2i(x, y))

func _solid_pixel(color: Color) -> Image:
	var pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	pixel.set_pixel(0, 0, color)
	return pixel
