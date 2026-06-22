extends RefCounted

const BattleBoardAssetProfilesScript := preload("res://scripts/data/battle_board_asset_profiles.gd")

static func run(tr) -> void:
	var view := DiamondBoardView.new()
	_assert_floor_variant_atlas_size(tr)
	_assert_floor_map_size(tr)
	_assert_attack_vfx_sheet(tr, view)
	_assert_attack_fx_anchor_height(tr, view)
	_assert_attack_fx_action_anchors(tr, view)
	_assert_attack_fx_palette(tr)
	_assert_attack_fx_intent_suppression(tr, view)
	_assert_readability_palette(tr)
	_assert_deploy_overlay_visibility_rules(tr, view)
	_assert_prop_profiles(tr, view)
	_assert_prop_draw_rects(tr, view)
	_assert_entity_draw_order(tr, view)
	_assert_unit_hp_pips_disabled(tr)
	_assert_unit_overhead_hp_bar_config(tr)
	_assert_building_hp_bar_config(tr)
	_assert_building_hp_preview_damage_state(tr, view)
	_assert_hazard_decal_atlas(tr, view)
	_assert_hazard_visual_profiles(tr, view)
	_assert_rift_warning_keeps_fallback_glyph(tr, view)
	_assert_hazard_intent_redraw_rules(tr, view)
	_assert_environment_decal_variants(tr, view)
	_assert_void_tile_rendering_rules(tr, view)
	_assert_predicted_rift_state(tr, view)
	_assert_predicted_bell_wave_state(tr, view)
	_assert_abyss_edge_geometry(tr, view)
	_assert_tile_display_overrides(tr, view)
	_assert_unit_visual_position_overrides(tr, view)
	_assert_unit_visual_override_draw_cell(tr, view)
	_assert_roundtrip(tr, view, Vector2i(0, 0))
	_assert_roundtrip(tr, view, Vector2i(3, 2))
	_assert_roundtrip(tr, view, Vector2i(7, 0))
	_assert_roundtrip(tr, view, Vector2i(0, 7))
	_assert_roundtrip(tr, view, Vector2i(7, 7))

	var center := view.cell_to_pixel(Vector2i(4, 4))
	tr.assert_eq(
		"projected cell picks inside lower half",
		view.pixel_to_cell(center + Vector2(0, DiamondBoardView.TILE_HALF.y * 0.45)),
		Vector2i(4, 4)
	)
	tr.assert_eq(
		"projected cell picks inside right half",
		view.pixel_to_cell(center + Vector2(DiamondBoardView.TILE_HALF.x * 0.45, 0)),
		Vector2i(4, 4)
	)
	tr.assert_eq(
		"projected pick outside board top-left",
		view.pixel_to_cell(view.cell_to_pixel(Vector2i(0, 0)) + Vector2(-DiamondBoardView.TILE_HALF.x - 4.0, 0)),
		Vector2i(-1, -1)
	)
	tr.assert_eq(
		"projected pick far outside board",
		view.pixel_to_cell(Vector2(-1000, -1000)),
		Vector2i(-1, -1)
	)
	view.free()

static func _assert_floor_variant_atlas_size(tr) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DiamondBoardView.FLOOR_VARIANTS_PATH))
	tr.assert_true("battle board floor variant atlas exists", image != null)
	if image == null:
		return
	tr.assert_eq("battle board floor variant atlas width matches columns", image.get_width(), int(DiamondBoardView.TILE_W * DiamondBoardView.FLOOR_VARIANT_COLUMNS))
	tr.assert_eq("battle board floor variant atlas height matches rows", image.get_height(), int(DiamondBoardView.TILE_H * DiamondBoardView.FLOOR_VARIANT_ROWS))
	tr.assert_eq("battle board floor variant count fills atlas", DiamondBoardView.FLOOR_VARIANT_COUNT, DiamondBoardView.FLOOR_VARIANT_COLUMNS * DiamondBoardView.FLOOR_VARIANT_ROWS)

static func _assert_floor_map_size(tr) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DiamondBoardView.FLOOR_MAP_PATH))
	tr.assert_true("battle board floor map exists", image != null)
	if image == null:
		return
	tr.assert_eq("battle board floor map width matches logical grid", image.get_width(), int(DiamondBoardView.TILE_W * Grid.SIZE))
	tr.assert_eq("battle board floor map height matches logical grid", image.get_height(), int(DiamondBoardView.TILE_H * Grid.SIZE))

static func _assert_predicted_bell_wave_state(tr, view: DiamondBoardView) -> void:
	var cells := [Vector2i(3, 3), Vector2i(4, 3)]
	view.set_predicted_bell_wave(cells)
	tr.assert_eq("predicted bell wave cells stored", view.get_predicted_bell_wave(), cells)

static func _assert_predicted_rift_state(tr, view: DiamondBoardView) -> void:
	var cells := [Vector2i(3, 1), Vector2i(4, 2)]
	view.set_predicted_rifts(cells)
	tr.assert_eq("predicted rift cells stored", view.get_predicted_rifts(), cells)

static func _assert_abyss_edge_geometry(tr, view: DiamondBoardView) -> void:
	var west_edge: Array = view._diamond_edge_for_direction(Vector2i(0, 3), Vector2i(-1, 0))
	var east_edge: Array = view._diamond_edge_for_direction(Vector2i(7, 4), Vector2i(1, 0))
	tr.assert_eq("west abyss edge uses left diamond side", west_edge.size(), 2)
	tr.assert_eq("east abyss edge uses right diamond side", east_edge.size(), 2)
	tr.assert_true("west abyss normal points left on screen", view._screen_normal_for_direction(Vector2i(-1, 0)).x < 0.0)
	tr.assert_true("east abyss normal points right on screen", view._screen_normal_for_direction(Vector2i(1, 0)).x > 0.0)

static func _assert_attack_vfx_sheet(tr, view: DiamondBoardView) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DiamondBoardView.ATTACK_VFX_SHEET_PATH))
	tr.assert_true("battle attack vfx sheet exists", image != null)
	if image == null:
		return
	tr.assert_eq("battle attack vfx sheet width matches columns", image.get_width(), int(DiamondBoardView.ATTACK_VFX_FRAME_SIZE.x * DiamondBoardView.ATTACK_VFX_COLUMNS))
	tr.assert_eq("battle attack vfx sheet height matches sequence rows", image.get_height(), int(DiamondBoardView.ATTACK_VFX_FRAME_SIZE.y * DiamondBoardView.ATTACK_VFX_ROWS))
	var muzzle := view._attack_vfx_frame_region(DiamondBoardView.FX_SEQUENCE_MUZZLE, 0.0)
	var projectile := view._attack_vfx_frame_region(DiamondBoardView.FX_SEQUENCE_PROJECTILE, 0.5)
	var impact := view._attack_vfx_frame_region(DiamondBoardView.FX_SEQUENCE_IMPACT, 0.999)
	var dust := view._attack_vfx_frame_region(DiamondBoardView.FX_SEQUENCE_DUST, 0.5)
	tr.assert_eq("attack vfx muzzle row starts first row", muzzle, Rect2(Vector2.ZERO, DiamondBoardView.ATTACK_VFX_FRAME_SIZE))
	tr.assert_eq("attack vfx projectile uses second row", projectile.position.y, DiamondBoardView.ATTACK_VFX_FRAME_SIZE.y)
	tr.assert_eq("attack vfx impact can address final active frame", impact.position.x, DiamondBoardView.ATTACK_VFX_FRAME_SIZE.x * float(DiamondBoardView.FX_IMPACT_FRAMES - 1))
	tr.assert_eq("attack vfx dust uses fourth row", dust.position.y, DiamondBoardView.ATTACK_VFX_FRAME_SIZE.y * 3.0)
	tr.assert_true("attack vfx muzzle first frame has visible alpha", _region_stats(image, muzzle).visible_pixels > 80)
	_assert_attack_vfx_sheet_style(tr, image, view)

static func _assert_attack_fx_anchor_height(tr, view: DiamondBoardView) -> void:
	var cell := Vector2i(3, 4)
	tr.assert_true("attack fx anchor floats above tile center", view._attack_fx_anchor(cell).y < view.cell_to_pixel(cell).y)
	tr.assert_eq("attack fx anchor uses configured height", view._attack_fx_anchor(cell), view.cell_to_pixel(cell, DiamondBoardView.ATTACK_FX_HEIGHT))
	tr.assert_true("attack fx height stays below token body midpoint", DiamondBoardView.ATTACK_FX_HEIGHT > DiamondBoardView.TILE_HALF.y and DiamondBoardView.ATTACK_FX_HEIGHT < DiamondBoardView.UNIT_TOKEN_HEIGHT * 0.5)

static func _assert_attack_fx_action_anchors(tr, view: DiamondBoardView) -> void:
	var cell := Vector2i(3, 4)
	tr.assert_true("attack muzzle anchor starts higher than target hit anchor", view._attack_fx_muzzle_anchor(cell).y < view._attack_fx_target_anchor(cell).y)
	tr.assert_true("attack target anchor stays higher than impact confirm anchor", view._attack_fx_target_anchor(cell).y < view._attack_fx_anchor(cell).y)
	tr.assert_true("attack muzzle height remains inside token body", DiamondBoardView.ATTACK_FX_MUZZLE_HEIGHT < DiamondBoardView.UNIT_TOKEN_HEIGHT * 0.5)

static func _assert_attack_fx_palette(tr) -> void:
	tr.assert_true("attack fx primary color is amber, not cyan", DiamondBoardView.COLOR_ATTACK_AMBER.r > DiamondBoardView.COLOR_ATTACK_AMBER.g and DiamondBoardView.COLOR_ATTACK_AMBER.g > DiamondBoardView.COLOR_ATTACK_AMBER.b)
	tr.assert_true("attack fx primary color is subdued, not bright gold", DiamondBoardView.COLOR_ATTACK_AMBER.r < 0.82 and DiamondBoardView.COLOR_ATTACK_AMBER.g < 0.48 and DiamondBoardView.COLOR_ATTACK_AMBER.b < 0.22)
	tr.assert_true("attack fx dust color stays subdued", DiamondBoardView.COLOR_ATTACK_DUST.r < 0.50 and DiamondBoardView.COLOR_ATTACK_DUST.g < 0.38 and DiamondBoardView.COLOR_ATTACK_DUST.b < 0.26)
	tr.assert_true("attack fx iron outline stays dark", DiamondBoardView.COLOR_ATTACK_IRON.r < 0.08 and DiamondBoardView.COLOR_ATTACK_IRON.g < 0.06 and DiamondBoardView.COLOR_ATTACK_IRON.b < 0.04)

static func _assert_attack_vfx_sheet_style(tr, image: Image, view: DiamondBoardView) -> void:
	var muzzle := _sequence_stats(image, view, DiamondBoardView.FX_SEQUENCE_MUZZLE, DiamondBoardView.FX_MUZZLE_FRAMES)
	var projectile := _sequence_stats(image, view, DiamondBoardView.FX_SEQUENCE_PROJECTILE, DiamondBoardView.FX_PROJECTILE_FRAMES)
	var impact := _sequence_stats(image, view, DiamondBoardView.FX_SEQUENCE_IMPACT, DiamondBoardView.FX_IMPACT_FRAMES)
	var dust := _sequence_stats(image, view, DiamondBoardView.FX_SEQUENCE_DUST, DiamondBoardView.FX_DUST_FRAMES)
	var slash := _sequence_stats(image, view, DiamondBoardView.FX_SEQUENCE_SLASH, DiamondBoardView.FX_SLASH_FRAMES)
	var tether := _sequence_stats(image, view, DiamondBoardView.FX_SEQUENCE_TETHER, DiamondBoardView.FX_TETHER_FRAMES)
	tr.assert_true("attack vfx muzzle is animated over multiple visible frames", muzzle.frame_count >= 4 and muzzle.min_visible_pixels > 60)
	tr.assert_true("attack vfx projectile is animated over multiple visible frames", projectile.frame_count >= 4 and projectile.min_visible_pixels > 140)
	tr.assert_true("attack vfx impact uses six readable frames", impact.frame_count == 6 and impact.min_visible_pixels > 110)
	tr.assert_true("attack vfx dust uses six low-energy frames", dust.frame_count == 6 and dust.min_visible_pixels > 170 and dust.max_alpha < 0.55)
	tr.assert_true("attack vfx slash uses rough subdued frames", slash.frame_count >= 5 and slash.max_value < 0.78 and slash.avg_value < 0.34)
	tr.assert_true("attack vfx tether uses muted chain frames", tether.frame_count >= 4 and tether.min_visible_pixels > 150 and tether.avg_value < 0.34)
	tr.assert_true("attack vfx sheet avoids blue/cyan cast", muzzle.max_cyan < 0.10 and projectile.max_cyan < 0.10 and impact.max_cyan < 0.10 and dust.max_cyan < 0.10 and slash.max_cyan < 0.10 and tether.max_cyan < 0.10)

static func _sequence_stats(image: Image, view: DiamondBoardView, sequence_id: StringName, frame_count: int) -> Dictionary:
	var stats := {
		"frame_count": frame_count,
		"min_visible_pixels": 999999,
		"avg_value": 0.0,
		"max_value": 0.0,
		"max_cyan": 0.0,
		"max_alpha": 0.0,
	}
	var avg_total := 0.0
	for frame in range(frame_count):
		var progress := (float(frame) + 0.01) / float(frame_count)
		var frame_stats := _region_stats(image, view._attack_vfx_frame_region(sequence_id, progress))
		stats.min_visible_pixels = mini(stats.min_visible_pixels, frame_stats.visible_pixels)
		stats.max_value = maxf(stats.max_value, frame_stats.max_value)
		stats.max_cyan = maxf(stats.max_cyan, frame_stats.max_cyan)
		stats.max_alpha = maxf(stats.max_alpha, frame_stats.max_alpha)
		avg_total += frame_stats.avg_value
	stats.avg_value = avg_total / float(maxi(1, frame_count))
	return stats

static func _region_stats(image: Image, region: Rect2) -> Dictionary:
	var stats := {
		"visible_pixels": 0,
		"avg_value": 0.0,
		"max_value": 0.0,
		"max_blue": 0.0,
		"max_cyan": 0.0,
		"avg_energy": 0.0,
		"max_alpha": 0.0,
	}
	var weighted_value := 0.0
	var alpha_total := 0.0
	var energy_total := 0.0
	for y in range(int(region.position.y), int(region.position.y + region.size.y)):
		for x in range(int(region.position.x), int(region.position.x + region.size.x)):
			var color := image.get_pixel(x, y)
			if color.a <= 0.05:
				continue
			var value := maxf(color.r, maxf(color.g, color.b))
			stats.visible_pixels += 1
			stats.max_value = maxf(stats.max_value, value)
			stats.max_blue = maxf(stats.max_blue, color.b)
			stats.max_cyan = maxf(stats.max_cyan, minf(color.g, color.b) - color.r * 0.35)
			stats.max_alpha = maxf(stats.max_alpha, color.a)
			weighted_value += value * color.a
			energy_total += value * color.a
			alpha_total += color.a
	if alpha_total > 0.0:
		stats.avg_value = weighted_value / alpha_total
	stats.avg_energy = energy_total / (region.size.x * region.size.y)
	return stats

static func _assert_attack_fx_intent_suppression(tr, view: DiamondBoardView) -> void:
	view.set_attack_fx_suppresses_intents(true)
	tr.assert_true("attack fx can suppress tactical intent overlays", view._attack_fx_suppresses_intents)
	view.set_attack_fx_suppresses_intents(false)
	tr.assert_true("attack fx intent suppression can be restored", not view._attack_fx_suppresses_intents)

static func _assert_readability_palette(tr) -> void:
	tr.assert_true("move overlay is calmer than attack overlay", DiamondBoardView.COLOR_MOVE.a < DiamondBoardView.COLOR_ATTACK.a)
	tr.assert_true("deploy overlay stays below move overlay salience", DiamondBoardView.COLOR_DEPLOY.a < DiamondBoardView.COLOR_MOVE.a)
	tr.assert_true("deploy frame is visible enough to read", DiamondBoardView.COLOR_DEPLOY_FRAME.a > 0.60)
	tr.assert_true("deploy frame uses calm teal, not attack red", DiamondBoardView.COLOR_DEPLOY_FRAME.g > DiamondBoardView.COLOR_DEPLOY_FRAME.r and DiamondBoardView.COLOR_DEPLOY_FRAME.g >= DiamondBoardView.COLOR_DEPLOY_FRAME.b)
	tr.assert_true("enemy order marker uses non-yellow red/orange threat border", DiamondBoardView.COLOR_ENEMY_ORDER_BORDER.r > DiamondBoardView.COLOR_ENEMY_ORDER_BORDER.g and DiamondBoardView.COLOR_ENEMY_ORDER_BORDER.g > DiamondBoardView.COLOR_ENEMY_ORDER_BORDER.b)
	tr.assert_true("enemy order marker has dark backing", DiamondBoardView.COLOR_ENEMY_ORDER_BACK.r < 0.10 and DiamondBoardView.COLOR_ENEMY_ORDER_BACK.g < 0.10 and DiamondBoardView.COLOR_ENEMY_ORDER_BACK.b < 0.10)
	tr.assert_true("ruin cell base reads as a full grid cell", DiamondBoardView.RUIN_CELL_FILL.a > DiamondBoardView.COLOR_GRID_GROUT.a * 6.0 and DiamondBoardView.RUIN_CELL_LIT.a > DiamondBoardView.COLOR_GRID_LINE.a * 8.0)
	tr.assert_true("ruin cell base avoids a black platform", DiamondBoardView.RUIN_CELL_FILL.a < 0.38 and DiamondBoardView.RUIN_CELL_DARK.a < 0.36)

static func _assert_deploy_overlay_visibility_rules(tr, view: DiamondBoardView) -> void:
	var state := BattleState.new()
	state.phase = BattleState.Phase.GARRISON
	var free_cell := Vector2i(2, 5)
	var occupied_cell := Vector2i(3, 5)
	var blocked_cell := Vector2i(4, 5)
	state.deploy_zone[free_cell] = true
	state.deploy_zone[occupied_cell] = true
	state.deploy_zone[blocked_cell] = true
	state.units.append(Unit.new(7, null, occupied_cell))
	state.grid.set_tile(blocked_cell, Grid.TileType.BUILDING, 2)
	view.bind_state(state)
	tr.assert_true("garrison deploy overlay is visible when a legal cell exists", view._has_visible_deploy_overlay())
	tr.assert_true("free deploy cell is visible", view._is_available_deploy_cell(free_cell))
	tr.assert_true("occupied deploy cell is hidden", not view._is_available_deploy_cell(occupied_cell))
	tr.assert_true("blocked deploy cell is hidden", not view._is_available_deploy_cell(blocked_cell))
	tr.assert_eq("normal deploy cells use deploy floor texture", view._tile_texture(Grid.TileType.EMPTY, true), DiamondBoardView.TEX_DEPLOY_FLOOR)
	tr.assert_true("deploy floor tint is readable on normal floor", view._tile_texture_tint(free_cell, Grid.TileType.EMPTY, true).a >= 0.20)
	state.phase = BattleState.Phase.PLAYER_ACTION
	tr.assert_true("deploy overlay hides outside garrison", not view._has_visible_deploy_overlay())

static func _assert_prop_profiles(tr, view: DiamondBoardView) -> void:
	var profiles: Dictionary = BattleBoardAssetProfilesScript.load_runtime_profiles()
	for id in [
		BattleBoardAssetProfilesScript.ID_BUILDING_BODY,
		BattleBoardAssetProfilesScript.ID_PILLAR_BODY,
		BattleBoardAssetProfilesScript.ID_RUIN_BODY,
	]:
		var profile: Dictionary = profiles.get(id, {})
		tr.assert_true("%s profile exists" % id, not profile.is_empty())
		tr.assert_true("%s profile has crop" % id, profile.get("crop", Rect2()).size.x > 0.0 and profile.get("crop", Rect2()).size.y > 0.0)
		var crop: Rect2 = profile.get("crop", Rect2())
		var alpha_bbox: Rect2 = profile.get("alpha_bbox", crop)
		var anchor: Vector2 = profile.get("anchor_px", Vector2.ZERO)
		tr.assert_true("%s profile comes from an authored resource" % id, String(profile.get("profile_resource", "")).ends_with("_profile.tres"))
		tr.assert_true("%s profile anchor is inside or at crop bottom" % id, anchor.x >= crop.position.x and anchor.x <= crop.position.x + crop.size.x and anchor.y >= crop.position.y and anchor.y <= crop.position.y + crop.size.y)
		var target_height := float(profile.get("target_height", 0.0))
		if id == BattleBoardAssetProfilesScript.ID_BUILDING_BODY:
			tr.assert_true("%s profile target height is ITB-style compact objective scale" % id, target_height >= DiamondBoardView.UNIT_TOKEN_HEIGHT * 0.55 and target_height <= DiamondBoardView.UNIT_TOKEN_HEIGHT * 0.70)
		elif id == BattleBoardAssetProfilesScript.ID_RUIN_BODY:
			tr.assert_true("%s profile target height is low rubble scale" % id, target_height >= 32.0 and target_height <= DiamondBoardView.UNIT_TOKEN_HEIGHT * 0.45)
		else:
			tr.assert_true("%s profile target height is gameplay-scale" % id, target_height >= 40.0 and target_height <= DiamondBoardView.UNIT_TOKEN_HEIGHT)
		tr.assert_true("%s profile crop renders full body alpha" % id, crop.is_equal_approx(alpha_bbox))
		tr.assert_true("%s source is body-only, not a baked full tile" % id, alpha_bbox.size.x < 1024.0 * 0.84)
		tr.assert_true("%s source keeps horizontal transparent padding" % id, alpha_bbox.position.x >= 64.0 and alpha_bbox.position.x + alpha_bbox.size.x <= 1024.0 - 64.0)
		tr.assert_true("%s profile exposes hp anchor" % id, profile.has("hp_offset"))
		tr.assert_true("%s profile exposes foundation footprint" % id, profile.get("foundation_scale", Vector2.ZERO).x > 0.0 and profile.get("foundation_scale", Vector2.ZERO).y > 0.0)
		tr.assert_true("%s profile darkens floor contact" % id, float(profile.get("floor_occlusion_strength", 0.0)) > 0.0)
		tr.assert_true("%s profile has contact shadow" % id, float(profile.get("contact_shadow_strength", 0.0)) > 0.0)
		var expected_min_width := 56.0
		if id == BattleBoardAssetProfilesScript.ID_PILLAR_BODY:
			expected_min_width = 74.0
		elif id == BattleBoardAssetProfilesScript.ID_RUIN_BODY:
			expected_min_width = 96.0
		tr.assert_true("%s profile draws as a one-cell prop, not a tiny object" % id, float(profile.get("min_draw_width", 0.0)) >= expected_min_width)
		tr.assert_true("%s profile does not rely on legacy crop trim" % id, not profile.has("crop_bottom_trim"))
	var building: Dictionary = BattleBoardAssetProfilesScript.prop_profile_for_tile(Grid.TileType.BUILDING, profiles)
	var building_crop: Rect2 = building.get("crop", Rect2())
	var building_anchor: Vector2 = building.get("anchor_px", Vector2.ZERO)
	var building_offset: Vector2 = building.get("foot_offset", Vector2.ZERO)
	tr.assert_true("building profile anchors near bottom of crop", building_anchor.y >= building_crop.position.y + building_crop.size.y - 1.0)
	tr.assert_true("prop foot offset sits near the lower diamond edge", building_offset.y >= DiamondBoardView.TILE_HALF.y - 4.0 and building_offset.y < DiamondBoardView.TILE_HALF.y)
	tr.assert_eq("prop renderer fallback offset matches shared profile offset", DiamondBoardView.PROP_TILE_ANCHOR_OFFSET, BattleBoardAssetProfilesScript.DEFAULT_PROP_FOOT_OFFSET)
	tr.assert_true("runtime view has profile cache after ready fallback or load", view != null)

static func _assert_prop_draw_rects(tr, view: DiamondBoardView) -> void:
	var profiles: Dictionary = BattleBoardAssetProfilesScript.load_runtime_profiles()
	var cell := Vector2i(3, 3)
	var building_profile: Dictionary = profiles[BattleBoardAssetProfilesScript.ID_BUILDING_BODY]
	var building_offset: Vector2 = building_profile.get("foot_offset", Vector2.ZERO)
	var anchor: Vector2 = view.cell_to_pixel(cell) + building_offset
	var rect: Rect2 = BattleBoardAssetProfilesScript.profile_draw_rect(anchor, building_profile)
	tr.assert_true("building draw rect bottom aligns to board anchor", is_equal_approx(rect.position.y + rect.size.y, anchor.y))
	tr.assert_true("building draw rect fills one-cell footprint", rect.size.x >= float(building_profile.get("min_draw_width", 0.0)) - 0.5)
	tr.assert_true("building draw rect is no wider than profile max", rect.size.x <= float(building_profile.get("max_draw_width", DiamondBoardView.TILE_W)) + 0.5)
	tr.assert_true("building draw rect stays near tile width", rect.size.x <= DiamondBoardView.TILE_W + 4.0)
	var atlas_region: Rect2 = building_profile.get("atlas_region", Rect2())
	tr.assert_true("prop crop is offset inside atlas region", atlas_region.size.x > 0.0 and atlas_region.position.y >= 0.0)
	var state := BattleState.new()
	state.grid.set_tile(cell, Grid.TileType.BUILDING, Grid.DEFAULT_BUILDING_HP)
	view.bind_state(state)
	tr.assert_eq("building hp origin uses profile offset", view._prop_drawable(cell).get("hp_origin", Vector2.ZERO), view.cell_to_pixel(cell) + building_profile.get("hp_offset", DiamondBoardView.BUILDING_HP_BAR_OFFSET))
	var ruin_profile: Dictionary = profiles[BattleBoardAssetProfilesScript.ID_RUIN_BODY]
	var ruin_offset: Vector2 = ruin_profile.get("foot_offset", Vector2.ZERO)
	var ruin_anchor: Vector2 = view.cell_to_pixel(cell) + ruin_offset
	var ruin_rect: Rect2 = BattleBoardAssetProfilesScript.profile_draw_rect(ruin_anchor, ruin_profile)
	tr.assert_true("ruin draw rect stays low but fills one-cell width", ruin_rect.size.y < DiamondBoardView.UNIT_TOKEN_HEIGHT * 0.75 and ruin_rect.size.x >= float(ruin_profile.get("min_draw_width", 0.0)) - 0.5)

static func _assert_entity_draw_order(tr, view: DiamondBoardView) -> void:
	var a := {"sort_y": 10.0, "cell": Vector2i(4, 4), "sequence": 1}
	var b := {"sort_y": 20.0, "cell": Vector2i(1, 1), "sequence": 1}
	var c := {"sort_y": 10.0, "cell": Vector2i(5, 4), "sequence": 1}
	tr.assert_true("entity sorter draws smaller foot y first", view._sort_entity_drawables(a, b))
	tr.assert_true("entity sorter tie-breaks by projected cell depth", view._sort_entity_drawables(a, c))

static func _assert_unit_hp_pips_disabled(tr) -> void:
	tr.assert_true("unit HP pips are disabled on the battlefield", not DiamondBoardView.DRAW_UNIT_HP_PIPS)

static func _assert_unit_overhead_hp_bar_config(tr) -> void:
	tr.assert_true("unit body HP bars are disabled on tokens", not DiamondBoardView.DRAW_UNIT_BODY_HP_BARS)
	tr.assert_true("unit overhead HP bars are enabled above tokens", DiamondBoardView.DRAW_UNIT_OVERHEAD_HP_BARS)
	tr.assert_true("unit overhead HP bar is short horizontal ITB-style plate", DiamondBoardView.UNIT_OVERHEAD_HP_BAR_SIZE.x > DiamondBoardView.UNIT_OVERHEAD_HP_BAR_SIZE.y * 3.0)
	tr.assert_true("unit overhead HP bar stays compact", DiamondBoardView.UNIT_OVERHEAD_HP_BAR_SIZE.x <= 38.0 and DiamondBoardView.UNIT_OVERHEAD_HP_BAR_SIZE.y <= 8.0)
	tr.assert_true("unit overhead HP bar sits above the token body without floating too high", absf(DiamondBoardView.UNIT_OVERHEAD_HP_OFFSET.x) <= 20.0 and DiamondBoardView.UNIT_OVERHEAD_HP_OFFSET.y < -DiamondBoardView.UNIT_TOKEN_HEIGHT * 0.75 and DiamondBoardView.UNIT_OVERHEAD_HP_OFFSET.y > -DiamondBoardView.UNIT_TOKEN_HEIGHT)
	tr.assert_true("warden overhead HP fill stays amber/orange", DiamondBoardView.COLOR_WARDEN_HP_FILL.r > DiamondBoardView.COLOR_WARDEN_HP_FILL.g and DiamondBoardView.COLOR_WARDEN_HP_FILL.g > DiamondBoardView.COLOR_WARDEN_HP_FILL.b)
	tr.assert_true("enemy overhead HP fill stays red/orange", DiamondBoardView.COLOR_ENEMY_HP_FILL.r > DiamondBoardView.COLOR_ENEMY_HP_FILL.g and DiamondBoardView.COLOR_ENEMY_HP_FILL.g >= DiamondBoardView.COLOR_ENEMY_HP_FILL.b)

static func _assert_building_hp_bar_config(tr) -> void:
	tr.assert_eq("building HP bar uses default building HP as segment count", DiamondBoardView.BUILDING_HP_MAX_SEGMENTS, Grid.DEFAULT_BUILDING_HP)
	tr.assert_true("building HP bar is anchored near the prop footprint", DiamondBoardView.BUILDING_HP_BAR_OFFSET.y > -DiamondBoardView.TILE_HALF.y and DiamondBoardView.BUILDING_HP_BAR_OFFSET.y < 0.0)
	tr.assert_true("building HP bar stays lightweight", DiamondBoardView.BUILDING_HP_SEGMENT_SIZE.y <= 4.0)
	tr.assert_true("building HP bar fill is amber, not badge yellow", DiamondBoardView.COLOR_BUILDING_HP_FILL.r > DiamondBoardView.COLOR_BUILDING_HP_FILL.g and DiamondBoardView.COLOR_BUILDING_HP_FILL.g > DiamondBoardView.COLOR_BUILDING_HP_FILL.b)
	tr.assert_true("building HP bar uses dark empty segments", DiamondBoardView.COLOR_BUILDING_HP_EMPTY.r < 0.12 and DiamondBoardView.COLOR_BUILDING_HP_EMPTY.g < 0.10 and DiamondBoardView.COLOR_BUILDING_HP_EMPTY.b < 0.08)
	tr.assert_true("building HP preview uses red threat fill", DiamondBoardView.COLOR_BUILDING_HP_PREVIEW.r > 0.9 and DiamondBoardView.COLOR_BUILDING_HP_PREVIEW.g < 0.3)

static func _assert_building_hp_preview_damage_state(tr, view: DiamondBoardView) -> void:
	var pos := Vector2i(1, 6)
	view.set_preview_protected_damage({pos: 2})
	tr.assert_eq("building preview damage can be queried", view.get_preview_protected_damage().get(pos, 0), 2)
	view.clear_preview()
	tr.assert_true("building preview damage clears with preview", view.get_preview_protected_damage().is_empty())

static func _assert_hazard_decal_atlas(tr, view: DiamondBoardView) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DiamondBoardView.HAZARD_DECAL_ATLAS_PATH))
	tr.assert_true("hazard decal atlas exists", image != null)
	if image == null:
		return
	tr.assert_eq("hazard decal atlas width has three frames", image.get_width(), int(DiamondBoardView.HAZARD_DECAL_FRAME_SIZE.x) * 3)
	tr.assert_eq("hazard decal atlas height matches tile", image.get_height(), int(DiamondBoardView.HAZARD_DECAL_FRAME_SIZE.y))
	var expected := {
		DiamondBoardView.HAZARD_RIFT_WARNING: DiamondBoardView.HAZARD_DECAL_RIFT,
		BattleEngine.HAZARD_BELL_WAVE: DiamondBoardView.HAZARD_DECAL_BELL,
		BattleEngine.HAZARD_CHARGE_LANE: DiamondBoardView.HAZARD_DECAL_CHARGE,
	}
	for hazard_type in expected.keys():
		var frame_index := int(expected[hazard_type])
		tr.assert_eq("%s hazard maps to expected decal frame" % hazard_type, view._hazard_decal_index(hazard_type), frame_index)
		var region := view._hazard_decal_region(frame_index)
		tr.assert_eq("%s hazard decal region size" % hazard_type, region.size, DiamondBoardView.HAZARD_DECAL_FRAME_SIZE)
		tr.assert_true("%s hazard decal frame has visible art" % hazard_type, _region_visible_pixels(image, region) > 80)
	tr.assert_eq("unknown hazard has no decal frame", view._hazard_decal_index("unknown_hazard"), -1)

static func _assert_hazard_visual_profiles(tr, view: DiamondBoardView) -> void:
	var hazard_types := [
		DiamondBoardView.HAZARD_RIFT_WARNING,
		BattleEngine.HAZARD_BELL_WAVE,
		BattleEngine.HAZARD_CHARGE_LANE,
	]
	for hazard_type in hazard_types:
		var profile: Dictionary = view._hazard_visual_profile(hazard_type)
		var fill: Color = profile.get("fill", Color.TRANSPARENT)
		var frame: Color = profile.get("frame", Color.TRANSPARENT)
		var max_fill_alpha := 0.32 if hazard_type == DiamondBoardView.HAZARD_RIFT_WARNING else 0.26
		tr.assert_true("%s hazard profile uses readable terrain fill" % hazard_type, fill.a >= 0.20 and fill.a <= max_fill_alpha)
		tr.assert_true("%s hazard profile keeps readable frame" % hazard_type, frame.a >= 0.80)
		tr.assert_true("%s hazard profile pulses with shared schema" % hazard_type, profile.has("base_pulse") and profile.has("pulse_amp") and profile.has("pulse_rate"))
	tr.assert_true("rift warning keeps warm danger family", DiamondBoardView.COLOR_HAZARD_RIFT_FRAME.r >= DiamondBoardView.COLOR_HAZARD_RIFT_FRAME.g)
	tr.assert_true("bell wave keeps distinct cool hazard accent", DiamondBoardView.COLOR_HAZARD_BELL_FRAME.b >= DiamondBoardView.COLOR_HAZARD_BELL_FRAME.r)

static func _assert_rift_warning_keeps_fallback_glyph(tr, view: DiamondBoardView) -> void:
	tr.assert_true("rift warning uses decal frame", view._hazard_decal_index(DiamondBoardView.HAZARD_RIFT_WARNING) >= 0)
	tr.assert_true("rift warning always overlays core glyph", view._hazard_always_draws_glyph(DiamondBoardView.HAZARD_RIFT_WARNING))
	tr.assert_true("bell wave relies on decal without duplicate glyph", not view._hazard_always_draws_glyph(BattleEngine.HAZARD_BELL_WAVE))
	tr.assert_true("charge lane relies on decal without duplicate glyph", not view._hazard_always_draws_glyph(BattleEngine.HAZARD_CHARGE_LANE))

static func _assert_hazard_intent_redraw_rules(tr, view: DiamondBoardView) -> void:
	view.set_enemy_intents([{
		"enemy_id": 3,
		"enemy_pos": Vector2i(2, 1),
		"attack_pos": Vector2i(2, 3),
		"status": BattleEngine.INTENT_STATUS_HIT,
		"hazard_type": BattleEngine.HAZARD_CHARGE_LANE,
		"hazard_cells": [Vector2i(2, 2), Vector2i(2, 3)],
	}])
	tr.assert_true("charge lane hazard intents keep board pulse redraw active", view._has_visible_hazard_intents())
	view.set_attack_fx_suppresses_intents(true)
	tr.assert_true("suppressed intents do not keep board pulse redraw active", not view._has_visible_hazard_intents())
	view.set_attack_fx_suppresses_intents(false)
	view.set_enemy_intents([{
		"status": BattleEngine.INTENT_STATUS_REMOVED,
		"hazard_type": BattleEngine.HAZARD_CHARGE_LANE,
		"hazard_cells": [Vector2i(2, 2)],
	}])
	tr.assert_true("removed hazard intent does not keep board pulse redraw active", not view._has_visible_hazard_intents())

static func _assert_environment_decal_variants(tr, view: DiamondBoardView) -> void:
	tr.assert_eq("empty tile environment decal pool has six stable variants", DiamondBoardView.EMPTY_TILE_ENV_DECAL_VARIANTS, 6)
	tr.assert_eq("board edge detail pool has five stable variants", DiamondBoardView.EDGE_DETAIL_VARIANTS, 5)
	var empty_variants := {}
	var right_edge_variants := {}
	var front_edge_variants := {}
	for y in Grid.SIZE:
		for x in Grid.SIZE:
			var cell := Vector2i(x, y)
			var variant := view._empty_tile_env_decal_variant_for_cell(cell)
			tr.assert_true("empty tile environment variant is in range", variant >= 0 and variant < DiamondBoardView.EMPTY_TILE_ENV_DECAL_VARIANTS)
			empty_variants[variant] = true
			if x == Grid.SIZE - 1:
				var right_variant := view._edge_detail_variant_for_cell(cell, true)
				tr.assert_true("right edge detail variant is in range", right_variant >= 0 and right_variant < DiamondBoardView.EDGE_DETAIL_VARIANTS)
				right_edge_variants[right_variant] = true
			if y == Grid.SIZE - 1:
				var front_variant := view._edge_detail_variant_for_cell(cell, false)
				tr.assert_true("front edge detail variant is in range", front_variant >= 0 and front_variant < DiamondBoardView.EDGE_DETAIL_VARIANTS)
				front_edge_variants[front_variant] = true
	tr.assert_true("empty tile environment decals cover several styles", empty_variants.size() >= 4)
	tr.assert_true("right edge details cover several styles", right_edge_variants.size() >= 3)
	tr.assert_true("front edge details cover several styles", front_edge_variants.size() >= 3)

static func _assert_void_tile_rendering_rules(tr, view: DiamondBoardView) -> void:
	tr.assert_eq("void tile has no ordinary floor texture", view._tile_texture(Grid.TileType.VOID, false), null)
	var pos := Vector2i(3, 3)
	view.set_tile_display_overrides({pos: {"tile": Grid.TileType.VOID}})
	tr.assert_eq("void display override exposes void tile", view._display_tile(pos), Grid.TileType.VOID)
	view.clear_tile_display_overrides()

static func _region_visible_pixels(image: Image, region: Rect2) -> int:
	var count := 0
	for y in range(int(region.position.y), int(region.position.y + region.size.y)):
		for x in range(int(region.position.x), int(region.position.x + region.size.x)):
			if image.get_pixel(x, y).a > 0.05:
				count += 1
	return count

static func _assert_tile_display_overrides(tr, view: DiamondBoardView) -> void:
	var pos := Vector2i(2, 6)
	view.set_tile_display_overrides({pos: {"tile": Grid.TileType.BUILDING, "hp": 2}})
	tr.assert_eq("tile display override exposes tile", view.get_tile_display_override(pos).tile, Grid.TileType.BUILDING)
	tr.assert_eq("tile display override exposes hp", view.get_tile_display_override(pos).hp, 2)
	view.clear_tile_display_overrides()
	tr.assert_true("tile display override clears", view.get_tile_display_override(pos).is_empty())
	view.set_unit_display_overrides({77: {"hp": 1, "alive": true}})
	tr.assert_eq("unit display override exposes hp", view.get_unit_display_override(77).hp, 1)
	tr.assert_eq("unit display override exposes alive", view.get_unit_display_override(77).alive, true)
	view.clear_unit_display_overrides()
	tr.assert_true("unit display override clears", view.get_unit_display_override(77).is_empty())

static func _assert_unit_visual_position_overrides(tr, view: DiamondBoardView) -> void:
	var unit_id := 42
	var visual_pos := view.cell_to_pixel(Vector2i(2, 3)) + Vector2(7.0, -5.0)
	tr.assert_true("unit visual override starts absent", not view.has_unit_visual_position(unit_id))
	view.set_unit_visual_position(unit_id, visual_pos)
	tr.assert_true("unit visual override can be set", view.has_unit_visual_position(unit_id))
	tr.assert_eq("unit visual override returns pixel position", view.get_unit_visual_position(unit_id), visual_pos)
	view.clear_unit_visual_position(unit_id)
	tr.assert_true("unit visual override clears one unit", not view.has_unit_visual_position(unit_id))
	view.set_unit_visual_position(unit_id, visual_pos)
	view.set_unit_visual_position(unit_id + 1, visual_pos + Vector2.ONE)
	view.clear_unit_visual_positions()
	tr.assert_true("unit visual override clears all units", not view.has_unit_visual_position(unit_id) and not view.has_unit_visual_position(unit_id + 1))

static func _assert_unit_visual_override_draw_cell(tr, view: DiamondBoardView) -> void:
	var unit := Unit.new(77, null, Vector2i(5, 5))
	tr.assert_eq("unit draw cell starts at logical position", view._unit_draw_cell(unit), Vector2i(5, 5))
	view.set_unit_visual_position(unit.id, view.cell_to_pixel(Vector2i(2, 3)))
	tr.assert_eq("unit draw cell follows visual override", view._unit_draw_cell(unit), Vector2i(2, 3))
	view.set_unit_visual_position(unit.id, Vector2(-1000.0, -1000.0))
	tr.assert_eq("invalid visual override falls back to logical position", view._unit_draw_cell(unit), Vector2i(5, 5))
	view.clear_unit_visual_position(unit.id)
	tr.assert_eq("cleared visual override restores logical draw cell", view._unit_draw_cell(unit), Vector2i(5, 5))

static func _assert_roundtrip(tr, view: DiamondBoardView, cell: Vector2i) -> void:
	tr.assert_eq(
		"projected center roundtrip %s" % cell,
		view.pixel_to_cell(view.cell_to_pixel(cell)),
		cell
	)
