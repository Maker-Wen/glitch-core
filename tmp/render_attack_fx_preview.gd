extends SceneTree

const OUT_DIR := "/private/tmp/glitch_core_attack_fx_preview"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await _render_case(
		"ranged_push_action",
		_action_layers({
			"from_cell": Vector2i(2, 5),
			"to_cell": Vector2i(5, 2),
			"attack_kind": UnitDef.AttackKind.RANGED_PUSH,
			"direction": Vector2i(1, -1),
		}, 0.55)
	)
	await _render_case(
		"ranged_pull_action",
		_action_layers({
			"from_cell": Vector2i(5, 5),
			"to_cell": Vector2i(2, 3),
			"attack_kind": UnitDef.AttackKind.RANGED_PULL,
			"direction": Vector2i(1, 1),
		}, 0.72)
	)
	await _render_case(
		"melee_push_action",
		_action_layers({
			"from_cell": Vector2i(3, 5),
			"to_cell": Vector2i(3, 4),
			"attack_kind": UnitDef.AttackKind.MELEE_PUSH,
			"direction": Vector2i(0, -1),
		}, 0.74)
	)
	await _render_case(
		"impact_confirm",
		_impact_layers({
			"from_cell": Vector2i(3, 5),
			"to_cell": Vector2i(3, 4),
			"attack_kind": UnitDef.AttackKind.MELEE_PUSH,
			"direction": Vector2i(0, -1),
		}, 0.60)
	)
	quit(0)

func _render_case(case_name: String, layers: Array) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var board := DiamondBoardView.new()
	viewport.add_child(board)
	board.bind_state(_make_state())
	board._pulse_t = 0.42
	board.set_enemy_intents([
		{
			"enemy_id": 2,
			"enemy_pos": Vector2i(5, 2),
			"attack_pos": Vector2i(3, 4),
			"status": BattleEngine.INTENT_STATUS_HIT,
		}
	])
	board.set_attack_fx_suppresses_intents(true)
	board.set_attack_fx_layers(layers)

	await process_frame
	await process_frame
	RenderingServer.force_sync()

	var image := viewport.get_texture().get_image()
	var output_path := "%s/%s.png" % [OUT_DIR, case_name]
	var result := image.save_png(output_path)
	if result != OK:
		push_error("Failed to save preview: %s" % output_path)
	viewport.queue_free()
	await process_frame

func _action_layers(request: Dictionary, progress: float) -> Array:
	var presenter := AttackFxPresenter.new()
	return presenter._action_layers(request, progress)

func _impact_layers(request: Dictionary, progress: float) -> Array:
	var presenter := AttackFxPresenter.new()
	return presenter._impact_layers(request, progress)

func _make_state() -> BattleState:
	var state := BattleState.new()
	state.grid = Grid.new()
	state.phase = BattleState.Phase.PLAYER_ACTION
	state.units.append(Unit.new(1, _make_def(&"bh", UnitDef.Faction.WARDEN, UnitDef.AttackKind.MELEE_PUSH), Vector2i(3, 5)))
	state.units.append(Unit.new(2, _make_def(&"carrion", UnitDef.Faction.ENEMY, UnitDef.AttackKind.MELEE_BUMP), Vector2i(3, 4)))
	state.units.append(Unit.new(3, _make_def(&"archer", UnitDef.Faction.ENEMY, UnitDef.AttackKind.RANGED_PUSH), Vector2i(5, 2)))
	return state

func _make_def(def_id: StringName, faction: int, attack_kind: int) -> UnitDef:
	var def := UnitDef.new()
	def.def_id = def_id
	def.display_name = String(def_id)
	def.faction = faction
	def.max_hp = 2
	def.attack_kind = attack_kind
	def.attack_range = 3
	def.attack_damage = 1
	def.attack_force = 1
	return def
