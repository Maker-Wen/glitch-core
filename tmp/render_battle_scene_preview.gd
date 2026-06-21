extends SceneTree

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const BattleActionScript := preload("res://scripts/battle/action.gd")

const OUT_PATH := "res://tmp/battle_scene_preview.png"
const CAPTURE_SIZE := Vector2i(1280, 720)

func _init() -> void:
	var root := get_root()
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var scene: Node = load("res://Scenes/battle/BattleScene.tscn").instantiate()
	if scene.has_method("configure_battle"):
		var run_wardens: Array[Dictionary] = []
		scene.configure_battle(_preview_battle_config(), run_wardens, 12, 12)
	viewport.add_child(scene)
	await _prepare_selected_warden_preview(scene)
	_capture(viewport)

func _preview_battle_config() -> Dictionary:
	var config := BattleConfigCatalogScript.get_config(BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD)
	return {
		"title": String(config.get("display_name", "战斗预览")),
		"node_id": String(config.get("node_id", "pillar_graveyard_03")),
		"node_type": "normal",
		"battle": {
			"config_id": String(config.get("config_id", BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD)),
			"variant": "pillar",
			"max_rounds": int(config.get("max_rounds", 5)),
		},
		"pressure_tags": config.get("pressure_tags", []),
	}

func _prepare_selected_warden_preview(scene: Node) -> void:
	for i in range(4):
		await process_frame
	var engine = scene.get("engine")
	if engine == null or engine.state == null:
		return
	var config := _preview_battle_config()
	var catalog_config: Dictionary = BattleConfigCatalogScript.get_config(String(config.get("battle", {}).get("config_id", BattleConfigCatalogScript.CONFIG_PILLAR_GRAVEYARD)))
	var deploy_cells: Array = catalog_config.get("warden_spawns", [])
	deploy_cells.append_array(BattleConfigCatalogScript.build_deploy_zone(catalog_config))
	while not engine.state.pending_warden_defs.is_empty():
		var placed := false
		for cell in deploy_cells:
			var deploy_cell: Vector2i = cell
			if not engine.state.deploy_zone.has(deploy_cell):
				continue
			if engine.state.grid.blocks_movement(deploy_cell):
				continue
			if engine.state.get_unit_at(deploy_cell) != null:
				continue
			engine.apply_action(BattleActionScript.deploy(deploy_cell))
			placed = true
			break
		if not placed:
			break
	engine.apply_action(BattleActionScript.confirm_deploy())
	for i in range(120):
		await process_frame
		if not bool(scene.get("_animating")):
			break
	var wardens: Array = engine.state.wardens()
	if wardens.is_empty():
		return
	var first = wardens[0]
	if scene.has_method("_on_warden_selected"):
		scene.call("_on_warden_selected", first.id)
	for i in range(6):
		await process_frame
	wardens = engine.state.wardens()
	if not wardens.is_empty() and int(scene.get("selected_warden_id")) == -1 and not bool(scene.get("_animating")) and scene.has_method("_on_warden_selected"):
		scene.call("_on_warden_selected", wardens[0].id)
	for i in range(2):
		await process_frame
	var hud = scene.get("hud")
	if scene.has_method("_refresh_ability_bar"):
		scene.call("_refresh_ability_bar")
	if hud != null and hud.has_method("_show_ability_detail") and hud.ability_stack != null and hud.ability_stack.get_child_count() > 0:
		hud.call("_show_ability_detail", {
			"id": "attack",
			"name": "链锤击",
			"desc": "近战 (1 格) 1 伤 + 推 1",
			"active": true,
			"is_default": true,
			"slot_index": 0,
		})
	if hud != null:
		print("preview hud state: phase=%s selected=%s ability_bar=%s detail=%s stack=%s" % [
			str(engine.state.phase),
			str(scene.get("selected_warden_id")),
			str(hud.ability_bar_bg.visible if hud.ability_bar_bg != null else false),
			str(hud.ability_detail_panel.visible if hud.ability_detail_panel != null else false),
			str(hud.ability_stack.get_child_count() if hud.ability_stack != null else -1),
		])
	for i in range(2):
		await process_frame

func _capture(viewport: SubViewport) -> void:
	for i in range(8):
		await process_frame
	var image := viewport.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_PATH)
	var result := image.save_png(path)
	print("battle scene preview: %s result=%s" % [path, str(result)])
	quit(0 if result == OK else 1)
