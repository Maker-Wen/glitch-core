extends SceneTree
## Renders deployment-phase screenshots for fixed battle maps and checks that
## deploy overlays are visually detectable.

const BattleSceneScript := preload("res://scripts/view/battle_scene.gd")
const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")

const CONFIG_IDS := [
	BattleConfigCatalogScript.CONFIG_OUTER_WALL,
	BattleConfigCatalogScript.CONFIG_RIFT_COURTYARD,
	BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD,
	BattleConfigCatalogScript.CONFIG_IRON_GATE,
	BattleConfigCatalogScript.CONFIG_OUTER_BELL,
]

const OUT_DIR := "res://tmp/deploy_overlay_shots"
const MIN_TEAL_PIXELS := 5000

var _failures: Array[String] = []

func _init() -> void:
	print("=== deploy overlay screenshot preview ===")
	var dir := DirAccess.open("res://")
	if dir != null:
		dir.make_dir_recursive("tmp/deploy_overlay_shots")
	root.size = Vector2i(1280, 720)
	await process_frame
	for config_id in CONFIG_IDS:
		await _render_config(config_id)
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)

func _render_config(config_id: String) -> void:
	var scene: BattleSceneScript = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	scene.configure_battle(
		{
			"node_id": "",
			"title": config_id,
			"battle": {"config_id": config_id},
		},
		[],
		12,
		12
	)
	root.add_child(scene)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var file_path := "%s/%s.png" % [OUT_DIR, config_id]
	var err := image.save_png(file_path)
	var stats := _image_stats(image)
	print("[%s] saved=%s err=%d teal=%d bright=%d dark=%d size=%dx%d" % [
		config_id,
		ProjectSettings.globalize_path(file_path),
		err,
		int(stats.teal_pixels),
		int(stats.bright_pixels),
		int(stats.dark_pixels),
		image.get_width(),
		image.get_height(),
	])
	if err != OK:
		_failures.append("%s failed to save deployment screenshot" % config_id)
	if int(stats.teal_pixels) < MIN_TEAL_PIXELS:
		_failures.append("%s deployment overlay is not visually detectable: teal=%d" % [config_id, int(stats.teal_pixels)])
	scene.queue_free()
	await process_frame

func _image_stats(image: Image) -> Dictionary:
	var stats := {
		"teal_pixels": 0,
		"bright_pixels": 0,
		"dark_pixels": 0,
	}
	if image == null:
		return stats
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.05:
				continue
			if color.g > 0.34 and color.b > 0.28 and color.g >= color.r * 1.30 and color.b >= color.r * 1.10:
				stats.teal_pixels += 1
			if maxf(color.r, maxf(color.g, color.b)) > 0.62:
				stats.bright_pixels += 1
			if color.r < 0.05 and color.g < 0.05 and color.b < 0.05 and color.a > 0.50:
				stats.dark_pixels += 1
	return stats
