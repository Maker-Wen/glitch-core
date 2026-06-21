extends SceneTree
## Renders a board-only preview for battle prop profile review.
##
## Run with:
##   godot --path . --script tools/render_board_prop_preview.gd

const OUT_PATH := "res://tmp/board_prop_preview.png"
const CAPTURE_SIZE := Vector2i(1280, 720)

func _init() -> void:
	var viewport := SubViewport.new()
	viewport.size = CAPTURE_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var bg := ColorRect.new()
	bg.size = Vector2(CAPTURE_SIZE)
	bg.color = Color(0.035, 0.035, 0.034, 1.0)
	viewport.add_child(bg)

	var root := Node2D.new()
	root.position = Vector2(0, 10)
	viewport.add_child(root)

	var state := BattleState.new()
	state.phase = BattleState.Phase.PLAYER_ACTION
	state.grid.set_tile(Vector2i(2, 2), Grid.TileType.BUILDING, 2)
	state.grid.set_tile(Vector2i(4, 3), Grid.TileType.PILLAR)
	state.grid.set_tile(Vector2i(5, 5), Grid.TileType.RUIN)
	state.grid.set_tile(Vector2i(1, 5), Grid.TileType.BUILDING, 1)
	state.grid.set_tile(Vector2i(6, 2), Grid.TileType.PILLAR)
	state.grid.set_tile(Vector2i(3, 6), Grid.TileType.RUIN)

	var board := DiamondBoardView.new()
	board.bind_state(state)
	root.add_child(board)

	_capture(viewport)

func _capture(viewport: SubViewport) -> void:
	for i in range(8):
		await process_frame
	var image := viewport.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_PATH)
	var result := image.save_png(path)
	print("board prop preview: %s result=%s" % [path, str(result)])
	quit(0 if result == OK else 1)
