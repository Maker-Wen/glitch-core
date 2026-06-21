extends RefCounted
## Verifies generated battle atlas slices load as runtime textures.

const BattleBoardAssetProfilesScript := preload("res://scripts/data/battle_board_asset_profiles.gd")

const EXPECTED := {
	"res://art/atlases/battle/battle_units.warden_bountyhunter_token.tres": Rect2(0, 0, 1024, 1024),
	"res://art/atlases/battle/battle_units.enemy_carrion_spawn_token.tres": Rect2(0, 1028, 1024, 1024),
	"res://art/atlases/battle/battle_units.warden_bountyhunter_body.tres": Rect2(2056, 1028, 1024, 1024),
	"res://art/atlases/battle/battle_units.enemy_plague_archer_body.tres": Rect2(0, 3084, 1024, 1024),
	"res://art/atlases/battle/battle_props.board_floor_tile.tres": Rect2(0, 0, 1024, 1024),
	"res://art/atlases/battle/battle_props.board_deploy_floor_tile.tres": Rect2(1028, 0, 1024, 1024),
	"res://art/atlases/battle/battle_props.board_rift_floor_tile.tres": Rect2(2056, 0, 1024, 1024),
	"res://art/atlases/battle/battle_props.board_base_tile.tres": Rect2(0, 1028, 1024, 1024),
	"res://art/atlases/battle/battle_props.board_deploy_tile.tres": Rect2(1028, 1028, 1024, 1024),
	"res://art/atlases/battle/battle_props.board_building_tile.tres": Rect2(2056, 1028, 1024, 1024),
	"res://art/atlases/battle/battle_props.board_ruin_tile.tres": Rect2(2056, 2056, 1024, 1024),
	"res://art/atlases/battle/battle_props.board_building_body.tres": Rect2(0, 3084, 1024, 1024),
	"res://art/atlases/battle/battle_props.board_pillar_body.tres": Rect2(1028, 3084, 1024, 1024),
	"res://art/atlases/battle/battle_props.board_ruin_body.tres": Rect2(2056, 3084, 1024, 1024),
	"res://art/atlases/battle/battle_ui.attack_icon.tres": Rect2(0, 0, 64, 64),
	"res://art/atlases/battle/battle_ui.wait_icon.tres": Rect2(204, 0, 64, 64),
}

static func run(tr) -> void:
	_test_atlas_slices_load(tr)
	_test_board_asset_profiles(tr)
	_test_board_profile_preview(tr)
	_test_unit_defs_use_atlas_textures(tr)

static func _test_atlas_slices_load(tr) -> void:
	for path in EXPECTED.keys():
		var texture := load(path)
		tr.assert_true("%s loads" % path.get_file(), texture is AtlasTexture)
		if texture is AtlasTexture:
			tr.assert_eq("%s region" % path.get_file(), texture.region, EXPECTED[path])
			tr.assert_true("%s atlas exists" % path.get_file(), texture.atlas != null)

static func _test_unit_defs_use_atlas_textures(tr) -> void:
	var defs := [
		"res://scripts/data/defs/warden_bountyhunter.tres",
		"res://scripts/data/defs/warden_graverobber.tres",
		"res://scripts/data/defs/warden_mage.tres",
		"res://scripts/data/defs/enemy_carrion_spawn.tres",
		"res://scripts/data/defs/enemy_plague_archer.tres",
	]
	for path in defs:
		var def: UnitDef = load(path)
		tr.assert_true("%s has atlas token" % path.get_file(), def.token_texture is AtlasTexture)

static func _test_board_asset_profiles(tr) -> void:
	var profiles: Dictionary = BattleBoardAssetProfilesScript.load_runtime_profiles()
	for id in [
		BattleBoardAssetProfilesScript.ID_BUILDING_BODY,
		BattleBoardAssetProfilesScript.ID_PILLAR_BODY,
		BattleBoardAssetProfilesScript.ID_RUIN_BODY,
	]:
		var profile: Dictionary = profiles.get(id, {})
		tr.assert_true("%s board profile exists" % id, not profile.is_empty())
		tr.assert_true("%s profile crop is visible" % id, profile.get("crop", Rect2()).size.x > 0.0 and profile.get("crop", Rect2()).size.y > 0.0)
		var crop: Rect2 = profile.get("crop", Rect2())
		var alpha_bbox: Rect2 = profile.get("alpha_bbox", crop)
		var anchor: Vector2 = profile.get("anchor_px", Vector2.ZERO)
		tr.assert_true("%s profile is authored as a Resource" % id, ResourceLoader.exists(String(profile.get("profile_resource", ""))))
		tr.assert_true("%s profile anchor is inside or at crop bottom" % id, anchor.x >= crop.position.x and anchor.x <= crop.position.x + crop.size.x and anchor.y >= crop.position.y and anchor.y <= crop.position.y + crop.size.y)
		tr.assert_true("%s profile crop renders full body alpha" % id, crop.is_equal_approx(alpha_bbox))
		tr.assert_true("%s source stays body-only, not a baked full tile" % id, alpha_bbox.size.x < 1024.0 * 0.84)
		tr.assert_true("%s source keeps horizontal transparent padding" % id, alpha_bbox.position.x >= 64.0 and alpha_bbox.position.x + alpha_bbox.size.x <= 1024.0 - 64.0)
		tr.assert_true("%s profile carries hp anchor" % id, profile.has("hp_offset"))
		tr.assert_true("%s profile serializes foundation footprint" % id, profile.get("foundation_scale", Vector2.ZERO).x > 0.0 and profile.get("foundation_scale", Vector2.ZERO).y > 0.0)
		tr.assert_true("%s profile serializes floor occlusion" % id, float(profile.get("floor_occlusion_strength", 0.0)) > 0.0)
		tr.assert_true("%s profile serializes contact shadow" % id, float(profile.get("contact_shadow_strength", 0.0)) > 0.0)
		tr.assert_true("%s profile avoids legacy crop trim" % id, not profile.has("crop_bottom_trim"))
		tr.assert_true("%s profile validates source art" % id, _source_profile_issues(profile).is_empty())

static func _test_board_profile_preview(tr) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://art/atlases/battle/battle_prop_profile_preview.png"))
	tr.assert_true("battle prop profile preview exists", image != null)
	if image == null:
		return
	tr.assert_true("battle prop profile preview has content", image.get_width() >= 3 * 120 and image.get_height() >= 120)

static func _source_profile_issues(profile: Dictionary) -> Array[String]:
	var source := String(profile.get("source", ""))
	var image := Image.load_from_file(ProjectSettings.globalize_path(source))
	if image == null:
		return ["missing source"]
	image.convert(Image.FORMAT_RGBA8)
	var bbox := BattleBoardAssetProfilesScript.alpha_bbox_for_image(image)
	return BattleBoardAssetProfilesScript.validate_profile_image(profile, image.get_size(), bbox)
