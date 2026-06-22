extends RefCounted
## Verifies generated battle atlas slices load as runtime textures.

const BattleBoardAssetProfilesScript := preload("res://scripts/data/battle_board_asset_profiles.gd")

const EXPECTED := {
	"res://art/atlases/battle/battle_units.warden_bountyhunter_token.tres": Rect2(0, 0, 1024, 1024),
	"res://art/atlases/battle/battle_units.enemy_carrion_spawn_token.tres": Rect2(0, 1028, 1024, 1024),
	"res://art/atlases/battle/battle_units.warden_bountyhunter_body.tres": Rect2(2056, 1028, 1024, 1024),
	"res://art/atlases/battle/battle_units.enemy_plague_archer_body.tres": Rect2(0, 3084, 1024, 1024),
	"res://art/atlases/battle/battle_units.enemy_bone_grub_token.tres": Rect2(1028, 3084, 1024, 1024),
	"res://art/atlases/battle/battle_units.enemy_ironhorn_token.tres": Rect2(2056, 3084, 1024, 1024),
	"res://art/atlases/battle/battle_units.enemy_shell_beetle_token.tres": Rect2(0, 4112, 1024, 1024),
	"res://art/atlases/battle/battle_units.enemy_bell_thrall_token.tres": Rect2(1028, 4112, 1024, 1024),
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

const ENEMY_TOKEN_SOURCE_PATHS := [
	"res://art/units/enemies/enemy_carrion_spawn_token.png",
	"res://art/units/enemies/enemy_plague_archer_token.png",
	"res://art/units/enemies/enemy_bone_grub_token.png",
	"res://art/units/enemies/enemy_ironhorn_token.png",
	"res://art/units/enemies/enemy_shell_beetle_token.png",
	"res://art/units/enemies/enemy_bell_thrall_token.png",
]
const ENEMY_TOKEN_MIN_BOTTOM_MARGIN := 48
const ENEMY_TOKEN_MAX_BOTTOM_MARGIN := 112
const ENEMY_TOKEN_MAX_CENTER_DRIFT := 36
const ENEMY_TOKEN_RENDERED_HEIGHT := 104.0
const ENEMY_TOKEN_MAX_RENDERED_WIDTH := 72.0
const ENEMY_TOKEN_MIN_VISIBLE_BOTTOM_FROM_CELL_CENTER := 5.0
const ENEMY_TOKEN_MAX_VISIBLE_BOTTOM_FROM_CELL_CENTER := 14.0
const ENEMY_TOKEN_MAX_VISIBLE_CENTER_X_FROM_CELL_CENTER := 5.0

const ENEMY_TOKEN_DEF_SOURCE_PATHS := [
	{"def": "res://scripts/data/defs/enemy_carrion_spawn.tres", "source": "res://art/units/enemies/enemy_carrion_spawn_token.png"},
	{"def": "res://scripts/data/defs/enemy_plague_archer.tres", "source": "res://art/units/enemies/enemy_plague_archer_token.png"},
	{"def": "res://scripts/data/defs/enemy_bone_grub.tres", "source": "res://art/units/enemies/enemy_bone_grub_token.png"},
	{"def": "res://scripts/data/defs/enemy_ironhorn.tres", "source": "res://art/units/enemies/enemy_ironhorn_token.png"},
	{"def": "res://scripts/data/defs/enemy_shell_beetle.tres", "source": "res://art/units/enemies/enemy_shell_beetle_token.png"},
	{"def": "res://scripts/data/defs/enemy_bell_thrall.tres", "source": "res://art/units/enemies/enemy_bell_thrall_token.png"},
]

static func run(tr) -> void:
	_test_atlas_slices_load(tr)
	_test_enemy_token_source_anchors(tr)
	_test_board_asset_profiles(tr)
	_test_board_profile_preview(tr)
	_test_unit_defs_use_atlas_textures(tr)
	_test_enemy_token_board_alignment(tr)

static func _test_atlas_slices_load(tr) -> void:
	for path in EXPECTED.keys():
		var texture := load(path)
		tr.assert_true("%s loads" % path.get_file(), texture is AtlasTexture)
		if texture is AtlasTexture:
			tr.assert_eq("%s region" % path.get_file(), texture.region, EXPECTED[path])
			tr.assert_true("%s atlas exists" % path.get_file(), texture.atlas != null)

static func _test_enemy_token_source_anchors(tr) -> void:
	for path in ENEMY_TOKEN_SOURCE_PATHS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		tr.assert_true("%s source loads" % path.get_file(), image != null)
		if image == null:
			continue
		image.convert(Image.FORMAT_RGBA8)
		var bbox := BattleBoardAssetProfilesScript.alpha_bbox_for_image(image)
		tr.assert_true("%s has visible alpha" % path.get_file(), bbox.size.x > 0 and bbox.size.y > 0)
		if bbox.size.x <= 0 or bbox.size.y <= 0:
			continue
		var bottom_margin := image.get_height() - (bbox.position.y + bbox.size.y)
		var center_x := bbox.position.x + bbox.size.x * 0.5
		var canvas_center_x := image.get_width() * 0.5
		var rendered_width := float(bbox.size.x) / float(image.get_height()) * ENEMY_TOKEN_RENDERED_HEIGHT
		tr.assert_true("%s alpha bottom stays near token foot anchor" % path.get_file(), bottom_margin >= ENEMY_TOKEN_MIN_BOTTOM_MARGIN and bottom_margin <= ENEMY_TOKEN_MAX_BOTTOM_MARGIN)
		tr.assert_true("%s alpha center stays near token canvas center" % path.get_file(), absf(center_x - canvas_center_x) <= ENEMY_TOKEN_MAX_CENTER_DRIFT)
		tr.assert_true("%s alpha width fits one board cell" % path.get_file(), rendered_width <= ENEMY_TOKEN_MAX_RENDERED_WIDTH)

static func _test_unit_defs_use_atlas_textures(tr) -> void:
	var defs := [
		"res://scripts/data/defs/warden_bountyhunter.tres",
		"res://scripts/data/defs/warden_graverobber.tres",
		"res://scripts/data/defs/warden_mage.tres",
		"res://scripts/data/defs/enemy_carrion_spawn.tres",
		"res://scripts/data/defs/enemy_plague_archer.tres",
		"res://scripts/data/defs/enemy_bone_grub.tres",
		"res://scripts/data/defs/enemy_ironhorn.tres",
		"res://scripts/data/defs/enemy_shell_beetle.tres",
		"res://scripts/data/defs/enemy_bell_thrall.tres",
	]
	for path in defs:
		var def: UnitDef = load(path)
		tr.assert_true("%s has atlas token" % path.get_file(), def.token_texture is AtlasTexture)

static func _test_enemy_token_board_alignment(tr) -> void:
	for entry in ENEMY_TOKEN_DEF_SOURCE_PATHS:
		var def_path := String(entry.def)
		var source_path := String(entry.source)
		var def: UnitDef = load(def_path)
		tr.assert_true("%s alignment def loads" % def_path.get_file(), def != null)
		if def == null:
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		tr.assert_true("%s alignment source loads" % source_path.get_file(), image != null)
		if image == null:
			continue
		image.convert(Image.FORMAT_RGBA8)
		var bbox := BattleBoardAssetProfilesScript.alpha_bbox_for_image(image)
		tr.assert_true("%s alignment source has visible alpha" % source_path.get_file(), bbox.size.x > 0 and bbox.size.y > 0)
		if bbox.size.x <= 0 or bbox.size.y <= 0:
			continue
		var source_to_board := DiamondBoardView.UNIT_TOKEN_HEIGHT / float(image.get_height())
		var bottom_margin := float(image.get_height() - (bbox.position.y + bbox.size.y))
		var visible_bottom_y := DiamondBoardView.UNIT_GROUND_Y + DiamondBoardView.UNIT_TOKEN_OFFSET.y + def.token_board_offset.y - bottom_margin * source_to_board
		var visible_center_x := def.token_board_offset.x + (float(bbox.position.x) + float(bbox.size.x) * 0.5 - float(image.get_width()) * 0.5) * source_to_board
		tr.assert_true(
			"%s visible token bottom y %.2f stays near board center" % [def_path.get_file(), visible_bottom_y],
			visible_bottom_y >= ENEMY_TOKEN_MIN_VISIBLE_BOTTOM_FROM_CELL_CENTER and visible_bottom_y <= ENEMY_TOKEN_MAX_VISIBLE_BOTTOM_FROM_CELL_CENTER
		)
		tr.assert_true(
			"%s visible token center x %.2f stays near board center" % [def_path.get_file(), visible_center_x],
			absf(visible_center_x) <= ENEMY_TOKEN_MAX_VISIBLE_CENTER_X_FROM_CELL_CENTER
		)

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
		var expected_min_width := 56.0
		if id == BattleBoardAssetProfilesScript.ID_PILLAR_BODY:
			expected_min_width = 74.0
		elif id == BattleBoardAssetProfilesScript.ID_RUIN_BODY:
			expected_min_width = 96.0
		tr.assert_true("%s profile enforces one-cell minimum width" % id, float(profile.get("min_draw_width", 0.0)) >= expected_min_width)
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
