class_name BattleBoardAssetProfiles extends RefCounted
## Runtime helpers for board-rendered battle prop profiles.
##
## Authoring data lives in BattleBoardPropProfile `.tres` resources. The atlas
## builder validates those resources against source PNGs and serializes this
## compact JSON so the board renderer can stay data-driven.

const PROFILE_JSON_PATH := "res://art/atlases/battle/battle_board_asset_profiles.json"
const DEFAULT_ALPHA_THRESHOLD := 0.05
const DEFAULT_EDGE_MARGIN := 4
const DEFAULT_PROP_FOOT_OFFSET := Vector2(0, 10)

const PROFILE_VERSION := 2
const KIND_PROP_BODY := "prop_body"

const ID_BUILDING_BODY := "board_building_body"
const ID_PILLAR_BODY := "board_pillar_body"
const ID_RUIN_BODY := "board_ruin_body"

const PROFILE_RESOURCE_PATHS := {
	ID_BUILDING_BODY: "res://art/tiles/profiles/board_building_body_profile.tres",
	ID_PILLAR_BODY: "res://art/tiles/profiles/board_pillar_body_profile.tres",
	ID_RUIN_BODY: "res://art/tiles/profiles/board_ruin_body_profile.tres",
}

static func profile(id: String) -> Dictionary:
	var path := String(PROFILE_RESOURCE_PATHS.get(id, ""))
	if path.is_empty():
		return {}
	var resource := load(path)
	if not (resource is BattleBoardPropProfile):
		return {}
	return profile_resource_to_dict(resource)

static func all_profiles() -> Dictionary:
	var result := {}
	for id in PROFILE_RESOURCE_PATHS.keys():
		var profile_data := profile(String(id))
		if not profile_data.is_empty():
			result[id] = profile_data
	return result

static func profile_resource_to_dict(resource: BattleBoardPropProfile) -> Dictionary:
	return {
		"id": String(resource.id),
		"kind": KIND_PROP_BODY,
		"profile_resource": resource.resource_path,
		"source": resource.source,
		"texture": resource.texture,
		"crop": resource.body_crop,
		"anchor_px": resource.body_anchor_px,
		"foot_offset": resource.board_foot_offset,
		"hp_offset": resource.hp_offset,
		"target_height": resource.target_height,
		"footprint_scale": resource.footprint_scale,
		"foundation_scale": resource.foundation_scale,
		"foundation_offset": resource.foundation_offset,
		"floor_occlusion_strength": resource.floor_occlusion_strength,
		"contact_shadow_strength": resource.contact_shadow_strength,
		"sort_bias": resource.sort_bias,
		"max_draw_width": resource.max_draw_width,
		"tint": resource.tint,
		"min_edge_margin": resource.min_edge_margin,
		"min_horizontal_margin": resource.min_horizontal_margin,
		"max_alpha_width_ratio": resource.max_alpha_width_ratio,
	}

static func prop_profile_id_for_tile(tile: int) -> String:
	match tile:
		Grid.TileType.BUILDING:
			return ID_BUILDING_BODY
		Grid.TileType.PILLAR:
			return ID_PILLAR_BODY
		Grid.TileType.RUIN:
			return ID_RUIN_BODY
	return ""

static func prop_profile_for_tile(tile: int, runtime_profiles: Dictionary = {}) -> Dictionary:
	var id := prop_profile_id_for_tile(tile)
	if id.is_empty():
		return {}
	if runtime_profiles.has(id):
		return runtime_profiles[id].duplicate(true)
	return profile(id)

static func load_runtime_profiles() -> Dictionary:
	var result := {}
	for id in PROFILE_RESOURCE_PATHS.keys():
		var base: Dictionary = profile(String(id))
		if base.is_empty():
			continue
		base["alpha_bbox"] = base.get("crop", Rect2())
		result[id] = base

	if not FileAccess.file_exists(PROFILE_JSON_PATH):
		return result
	var file := FileAccess.open(PROFILE_JSON_PATH, FileAccess.READ)
	if file == null:
		return result
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return result
	var serialized_profiles: Dictionary = parsed.get("profiles", {})
	for id in serialized_profiles.keys():
		var base := profile(String(id))
		if base.is_empty():
			continue
		var serialized: Dictionary = serialized_profiles[id]
		base["profile_resource"] = String(serialized.get("profile_resource", base.get("profile_resource", "")))
		base["source"] = String(serialized.get("source", base.get("source", "")))
		base["texture"] = String(serialized.get("texture", base.get("texture", "")))
		base["crop"] = rect2_from_dict(serialized.get("crop", {}), base.get("crop", Rect2()))
		base["anchor_px"] = vector2_from_dict(serialized.get("anchor_px", {}), base.get("anchor_px", _fallback_anchor(base)))
		base["alpha_bbox"] = rect2_from_dict(serialized.get("alpha_bbox", {}), base["crop"])
		base["atlas_region"] = rect2_from_dict(serialized.get("atlas_region", {}), Rect2())
		for key in ["target_height", "foot_offset", "hp_offset", "footprint_scale", "foundation_scale", "foundation_offset", "floor_occlusion_strength", "contact_shadow_strength", "sort_bias", "max_draw_width", "tint"]:
			if not serialized.has(key):
				continue
			match key:
				"foot_offset", "hp_offset", "foundation_scale", "foundation_offset":
					base[key] = vector2_from_dict(serialized.get(key, {}), base.get(key, Vector2.ZERO))
				"tint":
					base[key] = color_from_dict(serialized.get(key, {}), base.get(key, Color.WHITE))
				_:
					base[key] = serialized[key]
		result[id] = base
	return result

static func alpha_bbox_for_image(image: Image, alpha_threshold: float = DEFAULT_ALPHA_THRESHOLD) -> Rect2i:
	if image == null:
		return Rect2i()
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= alpha_threshold:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

static func validated_serialized_profile(profile_data: Dictionary, image: Image) -> Dictionary:
	var alpha_bbox := alpha_bbox_for_image(image)
	var issues := validate_profile_image(profile_data, image.get_size() if image != null else Vector2i.ZERO, alpha_bbox)
	return serialized_profile(profile_data, alpha_bbox, issues)

static func serialized_profile(profile_data: Dictionary, alpha_bbox: Rect2i = Rect2i(), issues: Array[String] = []) -> Dictionary:
	return {
		"id": String(profile_data.get("id", "")),
		"kind": String(profile_data.get("kind", KIND_PROP_BODY)),
		"profile_resource": String(profile_data.get("profile_resource", "")),
		"source": String(profile_data.get("source", "")),
		"texture": String(profile_data.get("texture", "")),
		"alpha_bbox": rect2_to_dict(Rect2(alpha_bbox.position, alpha_bbox.size)),
		"crop": rect2_to_dict(profile_data.get("crop", Rect2())),
		"anchor_px": vector2_to_dict(profile_data.get("anchor_px", _fallback_anchor(profile_data))),
		"target_height": float(profile_data.get("target_height", 0.0)),
		"foot_offset": vector2_to_dict(profile_data.get("foot_offset", Vector2.ZERO)),
		"hp_offset": vector2_to_dict(profile_data.get("hp_offset", Vector2.ZERO)),
		"footprint_scale": float(profile_data.get("footprint_scale", 1.0)),
		"foundation_scale": vector2_to_dict(profile_data.get("foundation_scale", Vector2.ONE)),
		"foundation_offset": vector2_to_dict(profile_data.get("foundation_offset", Vector2.ZERO)),
		"floor_occlusion_strength": float(profile_data.get("floor_occlusion_strength", 0.0)),
		"contact_shadow_strength": float(profile_data.get("contact_shadow_strength", 0.0)),
		"sort_bias": float(profile_data.get("sort_bias", 0.0)),
		"max_draw_width": float(profile_data.get("max_draw_width", 0.0)),
		"tint": color_to_dict(profile_data.get("tint", Color.WHITE)),
		"issues": issues,
	}

static func validate_profile_image(profile_data: Dictionary, image_size: Vector2i, alpha_bbox: Rect2i) -> Array[String]:
	var issues: Array[String] = []
	var id := String(profile_data.get("id", ""))
	if image_size.x <= 0 or image_size.y <= 0:
		issues.append("%s image is missing or empty" % id)
		return issues
	if alpha_bbox.size.x <= 0 or alpha_bbox.size.y <= 0:
		issues.append("%s has no visible alpha pixels" % id)
		return issues
	var crop: Rect2 = profile_data.get("crop", Rect2())
	var anchor: Vector2 = profile_data.get("anchor_px", _fallback_anchor(profile_data))
	if crop.size.x <= 0.0 or crop.size.y <= 0.0:
		issues.append("%s body_crop must be positive" % id)
		return issues
	if not _rect_inside_image(crop, image_size):
		issues.append("%s body_crop must stay inside the source image" % id)
	if not crop.has_point(anchor) and not _point_on_crop_bottom(anchor, crop):
		issues.append("%s body_anchor_px must be inside body_crop or on its bottom edge" % id)
	var alpha_rect := Rect2(alpha_bbox.position, alpha_bbox.size)
	if not alpha_rect.encloses(crop):
		issues.append("%s body_crop must be inside visible alpha bounds" % id)
	var margin := int(profile_data.get("min_edge_margin", DEFAULT_EDGE_MARGIN))
	var left := alpha_bbox.position.x
	var top := alpha_bbox.position.y
	var right := image_size.x - (alpha_bbox.position.x + alpha_bbox.size.x)
	var bottom := image_size.y - (alpha_bbox.position.y + alpha_bbox.size.y)
	if mini(mini(left, top), mini(right, bottom)) < margin:
		issues.append("%s alpha touches source edge; leave at least %d px transparent padding" % [id, margin])
	var horizontal_margin := int(profile_data.get("min_horizontal_margin", 0))
	if horizontal_margin > 0 and mini(left, right) < horizontal_margin:
		issues.append("%s looks like a baked board tile or platform; leave at least %d px horizontal body-only padding" % [id, horizontal_margin])
	var max_alpha_width_ratio := float(profile_data.get("max_alpha_width_ratio", 1.0))
	if max_alpha_width_ratio > 0.0 and max_alpha_width_ratio < 1.0:
		var alpha_width_ratio := float(alpha_bbox.size.x) / maxf(1.0, float(image_size.x))
		if alpha_width_ratio > max_alpha_width_ratio:
			issues.append("%s visible body is %.2f of source width, over %.2f; remove baked tile/base art" % [id, alpha_width_ratio, max_alpha_width_ratio])
	if not _rects_nearly_equal(crop, alpha_rect, 2.0):
		issues.append("%s body_crop must cover the full visible body alpha; fix source art instead of hiding pixels with crop" % id)
	var target_height := float(profile_data.get("target_height", 0.0))
	if target_height <= 0.0:
		issues.append("%s target_height must be positive" % id)
	var drawn_size := profile_draw_size_for_crop(crop, profile_data)
	if drawn_size.x <= 0.0 or drawn_size.y <= 0.0:
		issues.append("%s draw size must be positive" % id)
	var max_draw_width := float(profile_data.get("max_draw_width", 0.0))
	if max_draw_width > 0.0 and drawn_size.x > max_draw_width + 0.01:
		issues.append("%s draws %.1f px wide, over max %.1f px" % [id, drawn_size.x, max_draw_width])
	var foot_offset: Vector2 = profile_data.get("foot_offset", Vector2.ZERO)
	if foot_offset.y < 0.0 or foot_offset.y >= 26.0:
		issues.append("%s board_foot_offset.y must sit on the lower diamond face" % id)
	return issues

static func profile_draw_size_for_crop(crop: Rect2, profile_data: Dictionary) -> Vector2:
	var target_height := float(profile_data.get("target_height", crop.size.y))
	var scale := target_height / maxf(1.0, crop.size.y)
	var max_draw_width := float(profile_data.get("max_draw_width", 0.0))
	if max_draw_width > 0.0 and crop.size.x * scale > max_draw_width:
		scale = max_draw_width / maxf(1.0, crop.size.x)
	return crop.size * scale

static func profile_draw_rect(anchor_screen: Vector2, profile_data: Dictionary) -> Rect2:
	var crop: Rect2 = profile_data.get("crop", Rect2())
	var anchor_px: Vector2 = profile_data.get("anchor_px", _fallback_anchor(profile_data))
	var drawn_size := profile_draw_size_for_crop(crop, profile_data)
	var scale := drawn_size.y / maxf(1.0, crop.size.y)
	var anchor_in_crop := (anchor_px - crop.position) * scale
	return Rect2(anchor_screen - anchor_in_crop, drawn_size)

static func _rect_inside_image(rect: Rect2, image_size: Vector2i) -> bool:
	return rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.position.x + rect.size.x <= float(image_size.x) and rect.position.y + rect.size.y <= float(image_size.y)

static func _rects_nearly_equal(a: Rect2, b: Rect2, tolerance: float) -> bool:
	return absf(a.position.x - b.position.x) <= tolerance \
		and absf(a.position.y - b.position.y) <= tolerance \
		and absf(a.size.x - b.size.x) <= tolerance \
		and absf(a.size.y - b.size.y) <= tolerance

static func _point_on_crop_bottom(point: Vector2, crop: Rect2) -> bool:
	return point.x >= crop.position.x and point.x <= crop.position.x + crop.size.x and is_equal_approx(point.y, crop.position.y + crop.size.y)

static func _fallback_anchor(profile_data: Dictionary) -> Vector2:
	var crop: Rect2 = profile_data.get("crop", Rect2())
	return Vector2(crop.position.x + crop.size.x * 0.5, crop.position.y + crop.size.y)

static func rect2_to_dict(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y}

static func vector2_to_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}

static func color_to_dict(c: Color) -> Dictionary:
	return {"r": c.r, "g": c.g, "b": c.b, "a": c.a}

static func rect2_from_dict(data: Variant, fallback: Rect2 = Rect2()) -> Rect2:
	if not (data is Dictionary):
		return fallback
	return Rect2(
		float(data.get("x", fallback.position.x)),
		float(data.get("y", fallback.position.y)),
		float(data.get("w", fallback.size.x)),
		float(data.get("h", fallback.size.y))
	)

static func vector2_from_dict(data: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if not (data is Dictionary):
		return fallback
	return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))

static func color_from_dict(data: Variant, fallback: Color = Color.WHITE) -> Color:
	if not (data is Dictionary):
		return fallback
	return Color(
		float(data.get("r", fallback.r)),
		float(data.get("g", fallback.g)),
		float(data.get("b", fallback.b)),
		float(data.get("a", fallback.a))
	)
