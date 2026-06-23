extends SceneTree
## Rebuilds battle texture atlases from source PNG assets.
##
## Run with:
##   godot --headless --path . --script tools/build_battle_atlases.gd

const OUT_DIR := "res://art/atlases/battle"
const PADDING := 4
const PROP_PROFILE_PREVIEW_PATH := "res://art/atlases/battle/battle_prop_profile_preview.png"
const BattleBoardAssetProfilesScript := preload("res://scripts/data/battle_board_asset_profiles.gd")

const ATLASES := {
	"battle_units": {
		"cell_size": Vector2i(1024, 1024),
		"columns": 3,
		"items": [
			{"id": "warden_bountyhunter_token", "source": "res://art/units/wardens/warden_bountyhunter_token.png"},
			{"id": "warden_graverobber_token", "source": "res://art/units/wardens/warden_graverobber_token.png"},
			{"id": "warden_mage_token", "source": "res://art/units/wardens/warden_mage_token.png"},
			{"id": "enemy_carrion_spawn_token", "source": "res://art/units/enemies/enemy_carrion_spawn_token.png"},
			{"id": "enemy_plague_archer_token", "source": "res://art/units/enemies/enemy_plague_archer_token.png"},
			{"id": "warden_bountyhunter_body", "source": "res://art/units/board_body/wardens/warden_bountyhunter_body.png"},
			{"id": "warden_graverobber_body", "source": "res://art/units/board_body/wardens/warden_graverobber_body.png"},
			{"id": "warden_mage_body", "source": "res://art/units/board_body/wardens/warden_mage_body.png"},
			{"id": "enemy_carrion_spawn_body", "source": "res://art/units/board_body/enemies/enemy_carrion_spawn_body.png"},
			{"id": "enemy_plague_archer_body", "source": "res://art/units/board_body/enemies/enemy_plague_archer_body.png"},
			{"id": "enemy_bone_grub_token", "source": "res://art/units/enemies/enemy_bone_grub_token.png"},
			{"id": "enemy_ironhorn_token", "source": "res://art/units/enemies/enemy_ironhorn_token.png"},
			{"id": "enemy_shell_beetle_token", "source": "res://art/units/enemies/enemy_shell_beetle_token.png"},
			{"id": "enemy_bell_thrall_token", "source": "res://art/units/enemies/enemy_bell_thrall_token.png"},
		],
	},
	"battle_props": {
		"cell_size": Vector2i(1024, 1024),
		"columns": 3,
		"items": [
			{"id": "board_floor_tile", "source": "res://art/tiles/board_floor_tile.png"},
			{"id": "board_deploy_floor_tile", "source": "res://art/tiles/board_deploy_floor_tile.png"},
			{"id": "board_rift_floor_tile", "source": "res://art/tiles/board_rift_floor_tile.png"},
			{"id": "board_base_tile", "source": "res://art/tiles/board_base_tile.png"},
			{"id": "board_deploy_tile", "source": "res://art/tiles/board_deploy_tile.png"},
			{"id": "board_building_tile", "source": "res://art/tiles/board_building_tile.png"},
			{"id": "board_pillar_tile", "source": "res://art/tiles/board_pillar_tile.png"},
			{"id": "board_rift_tile", "source": "res://art/tiles/board_rift_tile.png"},
			{"id": "board_ruin_tile", "source": "res://art/tiles/board_ruin_tile.png"},
		],
	},
	"battle_ui": {
		"cell_size": Vector2i(64, 64),
		"columns": 4,
		"items": [
			{"id": "attack_icon", "source": "res://art/ui/battle_hud/icons/attack_icon_gpt-image-2.png"},
			{"id": "move_icon", "source": "res://art/ui/battle_hud/icons/move_icon_gpt-image-2.png"},
			{"id": "relic_icon", "source": "res://art/ui/battle_hud/icons/relic_icon_gpt-image-2.png"},
			{"id": "wait_icon", "source": "res://art/ui/battle_hud/icons/wait_icon_gpt-image-2.png"},
			{"id": "cooldown_ring", "source": "res://art/ui/battle_hud/icons/cooldown_ring_gpt.png"},
			{"id": "cooldown_ring_muted", "source": "res://art/ui/battle_hud/icons/cooldown_ring_muted_gpt.png"},
		],
	},
}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var manifest := {}
	var board_profiles := {}
	var validation_issues: Array[String] = []
	var atlas_configs := ATLASES.duplicate(true)
	_append_prop_profile_items(atlas_configs)
	for atlas_name in ATLASES.keys():
		var result := _build_atlas(atlas_name, atlas_configs[atlas_name])
		manifest[atlas_name] = result.manifest
		board_profiles.merge(result.board_profiles, true)
		validation_issues.append_array(result.validation_issues)
	_write_manifest(manifest)
	_write_board_asset_profiles(board_profiles)
	_write_prop_profile_preview(board_profiles)
	if not validation_issues.is_empty():
		for issue in validation_issues:
			push_error(issue)
		quit(1)
		return
	print("battle atlases rebuilt in %s" % OUT_DIR)
	quit(0)

func _append_prop_profile_items(atlas_configs: Dictionary) -> void:
	var props_config: Dictionary = atlas_configs["battle_props"]
	var items: Array = props_config.items
	for id in BattleBoardAssetProfilesScript.PROFILE_RESOURCE_PATHS.keys():
		var profile := BattleBoardAssetProfilesScript.profile(String(id))
		if profile.is_empty():
			continue
		items.append({"id": id, "source": String(profile.source)})
	props_config.items = items
	atlas_configs["battle_props"] = props_config

func _build_atlas(atlas_name: String, config: Dictionary) -> Dictionary:
	var cell_size: Vector2i = config.cell_size
	var columns := int(config.columns)
	var items: Array = config.items
	var rows := ceili(float(items.size()) / float(columns))
	var atlas_size := Vector2i(
		columns * cell_size.x + maxi(0, columns - 1) * PADDING,
		rows * cell_size.y + maxi(0, rows - 1) * PADDING
	)
	var atlas := Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))

	var entries := {}
	var board_profiles := {}
	var validation_issues: Array[String] = []
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var source := String(item.source)
		var image := Image.load_from_file(source)
		if image == null:
			push_error("Failed to load %s" % source)
			continue
		image.convert(Image.FORMAT_RGBA8)
		if image.get_size() != cell_size:
			image.resize(cell_size.x, cell_size.y, Image.INTERPOLATE_LANCZOS)
		var col := i % columns
		var row := i / columns
		var pos := Vector2i(col * (cell_size.x + PADDING), row * (cell_size.y + PADDING))
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, cell_size), pos)
		var id := String(item.id)
		var region := Rect2i(pos, cell_size)
		entries[id] = _entry(atlas_name, id, source, region)
		var profile := BattleBoardAssetProfilesScript.profile(id)
		if not profile.is_empty():
			profile["texture"] = String(entries[id].texture)
			var serialized: Dictionary = BattleBoardAssetProfilesScript.validated_serialized_profile(profile, image)
			serialized["atlas_region"] = BattleBoardAssetProfilesScript.rect2_to_dict(Rect2(region.position, region.size))
			board_profiles[id] = serialized
			for issue in serialized.get("issues", []):
				validation_issues.append(issue)

	var atlas_path := "%s/%s.png" % [OUT_DIR, atlas_name]
	atlas.save_png(atlas_path)
	if not FileAccess.file_exists("%s.import" % atlas_path):
		_write_png_import_stub(atlas_path)
	for id in entries.keys():
		_write_atlas_texture(entries[id])
	return {
		"manifest": {
			"texture": atlas_path,
			"cell_size": _vec2i_dict(cell_size),
			"padding": PADDING,
			"items": entries,
		},
		"board_profiles": board_profiles,
		"validation_issues": validation_issues,
	}

func _entry(atlas_name: String, id: String, source: String, region: Rect2i) -> Dictionary:
	return {
		"id": id,
		"source": source,
		"atlas": "%s/%s.png" % [OUT_DIR, atlas_name],
		"texture": "%s/%s.%s.tres" % [OUT_DIR, atlas_name, id],
		"region": {
			"x": region.position.x,
			"y": region.position.y,
			"w": region.size.x,
			"h": region.size.y,
		},
	}

func _write_atlas_texture(entry: Dictionary) -> void:
	var text := "\n".join([
		"[gd_resource type=\"AtlasTexture\" load_steps=2 format=3]",
		"",
		"[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1_atlas\"]" % String(entry.atlas),
		"",
		"[resource]",
		"atlas = ExtResource(\"1_atlas\")",
		"region = Rect2(%d, %d, %d, %d)" % [
			int(entry.region.x),
			int(entry.region.y),
			int(entry.region.w),
			int(entry.region.h),
		],
		"",
	])
	var file := FileAccess.open(String(entry.texture), FileAccess.WRITE)
	file.store_string(text)

func _write_manifest(manifest: Dictionary) -> void:
	var file := FileAccess.open("%s/battle_atlases_manifest.json" % OUT_DIR, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t", false))

func _write_board_asset_profiles(profiles: Dictionary) -> void:
	var payload := {
		"version": BattleBoardAssetProfilesScript.PROFILE_VERSION,
		"profiles": profiles,
	}
	var file := FileAccess.open(BattleBoardAssetProfilesScript.PROFILE_JSON_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "\t", false))

func _write_prop_profile_preview(profiles: Dictionary) -> void:
	if profiles.is_empty():
		return
	var tile_w := 102.0
	var tile_h := 52.0
	var cell_w := 180
	var cell_h := 156
	var ids := profiles.keys()
	ids.sort()
	var image := Image.create(cell_w * ids.size(), cell_h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.05, 0.055, 0.052, 1.0))
	for i in range(ids.size()):
		var id := String(ids[i])
		var profile: Dictionary = profiles[id]
		var source := String(profile.get("source", ""))
		var prop_image := Image.load_from_file(source)
		if prop_image == null:
			continue
		prop_image.convert(Image.FORMAT_RGBA8)
		var crop := BattleBoardAssetProfilesScript.rect2_from_dict(profile.get("crop", {}), Rect2())
		var anchor_px := BattleBoardAssetProfilesScript.vector2_from_dict(profile.get("anchor_px", {}), Vector2.ZERO)
		var draw_size := BattleBoardAssetProfilesScript.profile_draw_size_for_crop(crop, profile)
		var scale := draw_size.y / maxf(1.0, crop.size.y)
		var anchor_in_crop := (anchor_px - crop.position) * scale
		var prop_scaled := _crop_and_scale(prop_image, crop, Vector2i(maxi(1, roundi(draw_size.x)), maxi(1, roundi(draw_size.y))))
		var foot := Vector2(float(i * cell_w) + cell_w * 0.5, 92.0)
		_draw_preview_diamond(image, foot, tile_w, tile_h)
		var dest := Vector2i(roundi(foot.x - anchor_in_crop.x), roundi(foot.y - anchor_in_crop.y))
		image.blend_rect(prop_scaled, Rect2i(Vector2i.ZERO, prop_scaled.get_size()), dest)
	image.save_png(PROP_PROFILE_PREVIEW_PATH)

func _crop_and_scale(source: Image, crop: Rect2, size: Vector2i) -> Image:
	var cropped := Image.create(int(crop.size.x), int(crop.size.y), false, Image.FORMAT_RGBA8)
	cropped.fill(Color(0, 0, 0, 0))
	cropped.blit_rect(source, Rect2i(Vector2i(int(crop.position.x), int(crop.position.y)), Vector2i(int(crop.size.x), int(crop.size.y))), Vector2i.ZERO)
	cropped.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return cropped

func _draw_preview_diamond(image: Image, foot: Vector2, tile_w: float, tile_h: float) -> void:
	var top := foot + Vector2(0, -tile_h * 0.5)
	var right := foot + Vector2(tile_w * 0.5, 0)
	var bottom := foot + Vector2(0, tile_h * 0.5)
	var left := foot + Vector2(-tile_w * 0.5, 0)
	_fill_triangle(image, top, right, bottom, Color(0.25, 0.28, 0.26, 1))
	_fill_triangle(image, top, bottom, left, Color(0.22, 0.25, 0.23, 1))
	_draw_line(image, left, top, Color(0.66, 0.78, 0.70, 0.42))
	_draw_line(image, top, right, Color(0.66, 0.78, 0.70, 0.42))
	_draw_line(image, right, bottom, Color(0, 0, 0, 0.50))
	_draw_line(image, bottom, left, Color(0, 0, 0, 0.50))

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

func _draw_line(image: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var steps := maxi(1, ceili(a.distance_to(b)))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := a.lerp(b, t)
		var x := roundi(p.x)
		var y := roundi(p.y)
		if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
			image.set_pixel(x, y, color)

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
		"process/channel_remap/alpha=3",
		"process/fix_alpha_border=true",
		"process/premult_alpha=false",
		"process/normal_map_invert_y=false",
		"process/hdr_as_srgb=false",
		"process/hdr_clamp_exposure=false",
		"process/size_limit=0",
		"detect_3d/compress_to=1",
		"",
	]))

func _vec2i_dict(v: Vector2i) -> Dictionary:
	return {"x": v.x, "y": v.y}
