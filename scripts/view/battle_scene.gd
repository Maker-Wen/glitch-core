class_name BattleScene extends Node2D
## Root of the battle vertical slice. Wires engine + view together.

signal battle_finished(summary: Dictionary)

@onready var diamond_board_view: DiamondBoardView = $DiamondBoardView
@onready var hud: HUD = $HUD
@onready var input_ctl: InputController = $InputController

const BattleConfigCatalogScript := preload("res://scripts/data/battle_config_catalog.gd")
const BattleEventAnimatorScript := preload("res://scripts/view/battle_event_animator.gd")
const AttackFxPresenterScript := preload("res://scripts/view/attack_fx_presenter.gd")

var engine: BattleEngine
var selected_warden_id: int = -1
## When non-empty, the player is in "ability targeting" mode: clicking a valid
## cell executes the armed ability. Right-click cancels back to normal selection.
## Slice currently executes the primary attack. The HUD already reserves the
## target 3 active skill slots; non-primary skills stay disabled until the
## data-driven ability system lands.
var _armed_ability_id: String = ""
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _animating: bool = false
var _focused_enemy_id: int = -1
var _executing_enemy_id: int = -1
var _defer_state_refresh_until_events: bool = false
var _defer_enemy_intent_refresh_until_events: bool = false
var _suppress_enemy_intents_until_events_done: bool = false
var _pending_player_attack_context: Dictionary = {}
var _event_unit_snapshots: Dictionary = {}
var _event_protected_damage_start: int = 0
var _event_protected_damage_pending: int = 0
var _event_tile_display_overrides: Dictionary = {}
var _event_unit_display_overrides: Dictionary = {}
var _battle_config: Dictionary = {}
var _run_wardens: Array[Dictionary] = []
var _sanctuary_integrity: int = 12
var _sanctuary_integrity_max: int = 12
var _finish_emitted: bool = false
## Debug mode: when ON, info panel shows planned actions, execution order,
## displacement state, etc. Toggle with F1. OFF by default so the panel
## stays clean (just HP / move / attack range).
var _debug_mode: bool = false
var _event_animator = null
var _attack_fx_presenter = null

func _ready() -> void:
	engine = BattleEngine.new()
	engine.events_produced.connect(_on_events)
	engine.state_changed.connect(_on_state_changed)
	_configure_board_presentation()
	_event_animator = BattleEventAnimatorScript.new()
	_event_animator.bind(self, diamond_board_view)
	_attack_fx_presenter = AttackFxPresenterScript.new()
	_attack_fx_presenter.bind(self, diamond_board_view)
	input_ctl.bind(self)
	input_ctl.warden_selected.connect(_on_warden_selected)
	input_ctl.action_requested.connect(_on_action_requested)
	input_ctl.hover_changed.connect(_on_hover_changed)
	hud.end_turn_pressed.connect(func(): _on_action_requested(BattleAction.end_turn()))
	hud.undo_pressed.connect(func(): _on_action_requested(BattleAction.undo()))
	hud.confirm_deploy_pressed.connect(func(): _on_action_requested(BattleAction.confirm_deploy()))
	hud.ability_selected.connect(_on_ability_selected)
	hud.enemy_stack_hovered.connect(_on_enemy_stack_hovered)
	hud.set_help("战斗准备中")
	_start_slice_battle()

func configure_battle(config: Dictionary, run_wardens: Array[Dictionary], sanctuary: int, sanctuary_max: int) -> void:
	_battle_config = config.duplicate(true)
	_run_wardens = run_wardens.duplicate(true)
	_sanctuary_integrity = sanctuary
	_sanctuary_integrity_max = sanctuary_max

func _start_slice_battle() -> void:
	var config := _battle_config
	if config.is_empty():
		config = {
			"title": "战斗演示",
			"node_type": "normal",
			"battle": {"variant": "pillars", "max_rounds": 5},
			"pressure_tags": ["基础防守", "远程线压", "裂隙压力"],
		}
	var bh: UnitDef = load("res://scripts/data/defs/warden_bountyhunter.tres")
	var gr: UnitDef = load("res://scripts/data/defs/warden_graverobber.tres")
	var mg: UnitDef = load("res://scripts/data/defs/warden_mage.tres")
	var carrion: UnitDef = load("res://scripts/data/defs/enemy_carrion_spawn.tres")
	var archer: UnitDef = load("res://scripts/data/defs/enemy_plague_archer.tres")

	var grid := Grid.new()
	var battle_ref: Dictionary = config.get("battle", {})
	var variant := String(battle_ref.get("variant", "pillars"))
	var catalog_config := _resolve_catalog_battle_config(config)
	var protected_targets := _build_grid_for_variant(grid, variant, catalog_config)
	for p in protected_targets:
		if grid.get_tile(p) != Grid.TileType.BUILDING:
			grid.set_tile(p, Grid.TileType.BUILDING, 2)

	# Wardens are deployed by the player during the Garrison phase (see §3.3).
	var def_by_id := {
		"warden_bountyhunter": bh,
		"warden_graverobber": gr,
		"warden_mage": mg,
	}
	var warden_defs: Array = []
	var warden_hp: Array[int] = []
	if _run_wardens.is_empty():
		warden_defs = [bh, gr, mg]
		warden_hp = [bh.max_hp, gr.max_hp, mg.max_hp]
	else:
		for w in _run_wardens:
			if not bool(w.get("alive", false)):
				continue
			var def: UnitDef = def_by_id.get(String(w.get("warden_id", "")), null)
			if def == null:
				continue
			var run_max_hp := int(w.get("hp_max", def.max_hp))
			var battle_def := _runtime_warden_def(def, run_max_hp)
			warden_defs.append(battle_def)
			warden_hp.append(int(w.get("hp", battle_def.max_hp)))
	var enemies := _build_enemies_for_variant(variant, carrion, archer, catalog_config)
	var deploy_zone := BattleConfigCatalogScript.build_deploy_zone(catalog_config)

	# Two rifts on the north half. Schedule (design §3.4): the golden "↑"
	# marker appears during round N (predicting round N+1 spawns), the
	# enemy appears at start of round N+1.
	#
	# Round 1 has NO rift activity at all -- player gets a clean first turn
	# to figure out initial positioning. Predictions only start in round 2.
	#
	# Round 2 player turn shows: rift_a + rift_b will spawn next round.
	# Round 3 player turn shows: rift_a will spawn next round.
	# Round 4+: no more rift activity (let player clean up before round 5).
	var rift_data := _build_rifts_for_variant(variant, carrion, catalog_config)
	var rift_positions: Array[Vector2i] = []
	for p in rift_data.positions:
		rift_positions.append(p)
	var rift_schedule: Array = rift_data.schedule
	var cracked_ground_schedule: Array = BattleConfigCatalogScript.build_cracked_ground_schedule(catalog_config, grid)
	var abyss_edges: Dictionary = BattleConfigCatalogScript.build_abyss_edges(catalog_config)
	var bell_wave_schedule: Array = BattleConfigCatalogScript.build_bell_wave_schedule(catalog_config, grid)
	var scripted_spawn_schedule := _scripted_spawns_for_variant(catalog_config)
	var max_rounds := int(catalog_config.get("max_rounds", battle_ref.get("max_rounds", 5)))
	var reward_tasks := _reward_tasks_for_variant(variant, catalog_config)
	var boss_config := _boss_config_for_variant(variant, battle_ref, catalog_config)

	engine.start_battle(
		grid,
		warden_defs,
		enemies,
		deploy_zone,
		rift_positions,
		rift_schedule,
		max_rounds,
		protected_targets,
		reward_tasks,
		warden_hp,
		boss_config,
		scripted_spawn_schedule,
		cracked_ground_schedule,
		abyss_edges,
		bell_wave_schedule,
	)
	diamond_board_view.bind_state(engine.state)
	hud.set_sanctuary(_sanctuary_integrity, _sanctuary_integrity_max)
	hud.set_help(_battle_help_text(config, variant))
	_on_state_changed()

func _runtime_warden_def(def: UnitDef, run_max_hp: int) -> UnitDef:
	if def == null:
		return null
	var result: UnitDef = def.duplicate(true)
	result.max_hp = maxi(1, run_max_hp)
	return result

func _resolve_catalog_battle_config(config: Dictionary) -> Dictionary:
	var battle_ref: Dictionary = config.get("battle", {})
	var node_id := String(config.get("node_id", ""))
	return BattleConfigCatalogScript.resolve_battle_config(node_id, battle_ref)

func _build_grid_for_variant(grid: Grid, variant: String, catalog_config: Dictionary = {}) -> Array[Vector2i]:
	if not catalog_config.is_empty():
		var grid_data := BattleConfigCatalogScript.build_grid(catalog_config)
		var built_grid: Grid = grid_data.get("grid", null)
		if built_grid != null:
			grid.tiles = built_grid.tiles.duplicate()
			grid.tile_hp = built_grid.tile_hp.duplicate()
			return grid_data.get("protected_targets", [])
	var protected_targets: Array[Vector2i] = []
	match variant:
		"intro":
			protected_targets = [Vector2i(2, 6), Vector2i(5, 6), Vector2i(4, 7)]
		"archer":
			grid.set_tile(Vector2i(3, 3), Grid.TileType.PILLAR)
			protected_targets = [Vector2i(1, 6), Vector2i(4, 6), Vector2i(6, 7)]
		"elite":
			grid.set_tile(Vector2i(2, 3), Grid.TileType.PILLAR)
			grid.set_tile(Vector2i(5, 3), Grid.TileType.PILLAR)
			grid.set_tile(Vector2i(3, 4), Grid.TileType.PILLAR)
			protected_targets = [Vector2i(1, 6), Vector2i(3, 6), Vector2i(6, 6), Vector2i(4, 7)]
		"preboss":
			grid.set_tile(Vector2i(2, 4), Grid.TileType.PILLAR)
			grid.set_tile(Vector2i(5, 4), Grid.TileType.PILLAR)
			protected_targets = [Vector2i(2, 6), Vector2i(5, 6), Vector2i(3, 7), Vector2i(6, 7)]
		"boss":
			grid.set_tile(Vector2i(2, 3), Grid.TileType.PILLAR)
			grid.set_tile(Vector2i(5, 3), Grid.TileType.PILLAR)
			grid.set_tile(Vector2i(3, 4), Grid.TileType.PILLAR)
			grid.set_tile(Vector2i(4, 4), Grid.TileType.PILLAR)
			protected_targets = [Vector2i(1, 6), Vector2i(3, 6), Vector2i(5, 6), Vector2i(4, 7)]
			grid.set_tile(Vector2i(4, 7), Grid.TileType.BUILDING, 3)
		_:
			grid.set_tile(Vector2i(3, 3), Grid.TileType.PILLAR)
			grid.set_tile(Vector2i(4, 4), Grid.TileType.PILLAR)
			protected_targets = [Vector2i(2, 6), Vector2i(5, 6), Vector2i(4, 7)]
	return protected_targets

func _build_enemies_for_variant(variant: String, carrion: UnitDef, archer: UnitDef, catalog_config: Dictionary = {}) -> Array:
	if not catalog_config.is_empty():
		return BattleConfigCatalogScript.build_initial_enemies(catalog_config)
	match variant:
		"intro":
			return [
				{"def": carrion, "pos": Vector2i(2, 0)},
				{"def": carrion, "pos": Vector2i(5, 0)},
			]
		"archer":
			return [
				{"def": carrion, "pos": Vector2i(1, 0)},
				{"def": archer, "pos": Vector2i(3, 0)},
				{"def": carrion, "pos": Vector2i(6, 0)},
			]
		"elite":
			return [
				{"def": carrion, "pos": Vector2i(1, 0)},
				{"def": archer, "pos": Vector2i(3, 0)},
				{"def": carrion, "pos": Vector2i(5, 0)},
				{"def": archer, "pos": Vector2i(6, 1)},
			]
		"preboss":
			return [
				{"def": carrion, "pos": Vector2i(0, 0)},
				{"def": archer, "pos": Vector2i(2, 0)},
				{"def": archer, "pos": Vector2i(5, 0)},
				{"def": carrion, "pos": Vector2i(7, 0)},
			]
		"boss":
			return [
				{"def": carrion, "pos": Vector2i(0, 0)},
				{"def": archer, "pos": Vector2i(2, 0)},
				{"def": carrion, "pos": Vector2i(5, 0)},
				{"def": archer, "pos": Vector2i(7, 1)},
			]
	return [
		{"def": carrion, "pos": Vector2i(1, 0)},
		{"def": archer, "pos": Vector2i(3, 0)},
		{"def": carrion, "pos": Vector2i(6, 0)},
	]

func _build_rifts_for_variant(variant: String, carrion: UnitDef, catalog_config: Dictionary = {}) -> Dictionary:
	if not catalog_config.is_empty():
		return BattleConfigCatalogScript.build_rifts(catalog_config)
	var rift_a := Vector2i(2, 1)
	var rift_b := Vector2i(5, 1)
	var rift_c := Vector2i(4, 2)
	var positions: Array[Vector2i] = []
	match variant:
		"intro":
			return {"positions": positions, "schedule": []}
		"elite":
			positions = [rift_a, rift_b, rift_c]
			return {
				"positions": positions,
				"schedule": [
					{"round": 1, "pos": rift_a, "def": carrion},
					{"round": 2, "pos": rift_b, "def": carrion},
					{"round": 3, "pos": rift_c, "def": carrion},
				],
			}
		"preboss":
			positions = [rift_a, rift_b]
			return {
				"positions": positions,
				"schedule": [
					{"round": 1, "pos": rift_a, "def": carrion},
					{"round": 2, "pos": rift_b, "def": carrion},
					{"round": 3, "pos": rift_a, "def": carrion},
				],
			}
		"boss":
			positions = [rift_a, rift_b, rift_c]
			return {
				"positions": positions,
				"schedule": [
					{"round": 1, "pos": rift_a, "def": carrion},
					{"round": 2, "pos": rift_b, "def": carrion},
					{"round": 3, "pos": rift_c, "def": carrion},
					{"round": 4, "pos": rift_a, "def": carrion},
				],
			}
	positions = [rift_a, rift_b]
	return {
		"positions": positions,
		"schedule": [
			{"round": 2, "pos": rift_a, "def": carrion},
			{"round": 2, "pos": rift_b, "def": carrion},
			{"round": 3, "pos": rift_a, "def": carrion},
		],
	}

func _scripted_spawns_for_variant(catalog_config: Dictionary = {}) -> Array:
	if catalog_config.is_empty():
		return []
	return BattleConfigCatalogScript.build_scripted_spawns(catalog_config)

func _boss_config_for_variant(variant: String, battle_ref: Dictionary, catalog_config: Dictionary = {}) -> Dictionary:
	if variant != "boss" and String(catalog_config.get("boss_config_id", "")).is_empty():
		return {}
	var source := catalog_config if not catalog_config.is_empty() else battle_ref
	var anchor_positions = source.get("anchor_positions", [Vector2i(1, 3), Vector2i(6, 3)])
	var anchor_hp := int(source.get("anchor_hp", 2))
	var heart_position = source.get("heart_position", Vector2i(4, 3))
	if not catalog_config.is_empty():
		var boss_objects := _boss_objects_to_runtime_config(catalog_config)
		if not boss_objects.anchor_positions.is_empty():
			anchor_positions = boss_objects.anchor_positions
		if int(boss_objects.anchor_hp) > 0:
			anchor_hp = int(boss_objects.anchor_hp)
		if boss_objects.heart_position != Vector2i(-1, -1):
			heart_position = boss_objects.heart_position
	return {
		"boss_config_id": String(source.get("boss_config_id", "knell_lord_demo_01")),
		"boss_script_id": String(source.get("boss_script_id", "knell_lord_demo_six_round")),
		"doom_count_initial": int(source.get("doom_count_initial", 0)),
		"doom_count_max": int(source.get("doom_count_max", 3)),
		"anchor_positions": anchor_positions,
		"anchor_hp": anchor_hp,
		"heart_position": heart_position,
		"heart_hit_cap": int(source.get("heart_hit_cap", 3)),
	}

func _boss_objects_to_runtime_config(config: Dictionary) -> Dictionary:
	var anchors: Array[Vector2i] = []
	var anchor_hp := -1
	var heart := Vector2i(-1, -1)
	var grid := Grid.new()
	for raw in config.get("boss_objects", []):
		var entry: Dictionary = raw
		var pos := _config_cell(entry.get("pos", Vector2i(-1, -1)))
		if not grid.in_bounds(pos):
			continue
		match String(entry.get("kind", "")):
			"anchor":
				if not (pos in anchors):
					anchors.append(pos)
				anchor_hp = maxi(anchor_hp, int(entry.get("hp", -1)))
			"heart_bell":
				heart = pos
	return {
		"anchor_positions": anchors,
		"anchor_hp": anchor_hp,
		"heart_position": heart,
	}

func _config_cell(value) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_VECTOR2:
		return Vector2i(int(value.x), int(value.y))
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))
	return Vector2i(-1, -1)

func _reward_tasks_for_variant(variant: String, catalog_config: Dictionary = {}) -> Array:
	if not catalog_config.is_empty():
		return BattleConfigCatalogScript.runtime_reward_tasks(catalog_config)
	match variant:
		"boss":
			return [
				BattleState.REWARD_PERFECT_DEFENSE,
				BattleState.REWARD_TERMINAL_CLEAR,
				BattleState.REWARD_PHYSICAL_KILLS_3,
			]
		_:
			return [
				BattleState.REWARD_PERFECT_DEFENSE,
				BattleState.REWARD_TERMINAL_CLEAR,
				BattleState.REWARD_PHYSICAL_KILLS_3,
			]

func _battle_help_text(config: Dictionary, variant: String) -> String:
	var title := String(config.get("title", "战斗"))
	var tags := ", ".join(config.get("pressure_tags", []))
	if variant == "boss":
		return "%s · Boss 节点 · 压力：%s" % [title, tags]
	return "%s · 压力：%s" % [title, tags]

# ---------- input handlers ----------

func _on_warden_selected(unit_id: int) -> void:
	if _animating:
		return
	if selected_warden_id != unit_id:
		_armed_ability_id = ""  # switching wardens cancels any armed ability
	selected_warden_id = unit_id
	_refresh_persistent_hud()
	_refresh_selection_highlights()
	_refresh_ability_bar()
	_refresh_hover_preview()
	_refresh_info_panel()

func _on_ability_selected(ability_id: String) -> void:
	## Player clicked an ability button on the HUD. Enter "armed" sub-mode:
	## the next click on a valid board cell will execute this ability.
	## Clicking the same ability again disarms it.
	if _animating or selected_warden_id == -1:
		return
	if ability_id == "wait":
		_on_action_requested(BattleAction.end_turn())
		return
	if _armed_ability_id == ability_id:
		_armed_ability_id = ""  # toggle off
	else:
		_armed_ability_id = ability_id
	_refresh_selection_highlights()
	_refresh_ability_bar()
	_refresh_hover_preview()

func _on_action_requested(action: BattleAction) -> void:
	if _animating and action.kind != BattleAction.Kind.UNDO:
		return
	if action.kind == BattleAction.Kind.UNDO:
		_pending_player_attack_context.clear()
		_event_unit_snapshots.clear()
		if _attack_fx_presenter != null:
			_attack_fx_presenter.clear()
		engine.apply_action(action)
		# After undo, do a full rebuild
		_full_rebuild()
		return
	_capture_player_attack_context(action)
	_capture_event_unit_snapshots()
	_defer_state_refresh_until_events = true
	_defer_enemy_intent_refresh_until_events = true
	var events := engine.apply_action(action)
	# Any move / attack clears the armed ability so the ability bar refreshes
	# to reflect the warden's new available actions.
	if action.kind == BattleAction.Kind.MOVE or action.kind == BattleAction.Kind.ATTACK:
		_armed_ability_id = ""
	# Attacking / ending turn fully deselects the warden.
	if action.kind == BattleAction.Kind.ATTACK or action.kind == BattleAction.Kind.END_TURN:
		deselect(not _animating)

func _on_hover_changed(cell: Vector2i, inside: bool) -> void:
	if not inside:
		_hover_cell = Vector2i(-1, -1)
		_set_diamond_board_hover(Vector2i(-1, -1))
		_clear_diamond_board_preview()
		_set_focused_enemy(-1)
		_refresh_info_panel()
		_refresh_enemy_intent_overlay()
		return
	_hover_cell = cell
	_set_diamond_board_hover(cell)
	_refresh_hover_preview()
	_refresh_info_panel()

# ---------- presentation ----------

func _on_state_changed() -> void:
	if _defer_state_refresh_until_events:
		return
	_refresh_state_presentation()
	_refresh_enemy_intent_overlay()
	_refresh_selection_highlights()
	_refresh_ability_bar()

func _refresh_state_presentation() -> void:
	hud.set_sanctuary(_effective_sanctuary_integrity(), _sanctuary_integrity_max)
	hud.update_status(engine.state)
	_refresh_diamond_board()
	_refresh_persistent_hud()
	if engine.state.outcome != BattleState.Outcome.UNDECIDED:
		hud.show_outcome(engine.state.outcome, _battle_outcome_reason(engine.state))

func _configure_board_presentation() -> void:
	if diamond_board_view != null:
		diamond_board_view.visible = true

func _refresh_diamond_board() -> void:
	if diamond_board_view != null:
		diamond_board_view.queue_redraw()

func _set_diamond_board_hover(cell: Vector2i) -> void:
	if diamond_board_view != null:
		diamond_board_view.set_hover_cell(cell)

func _clear_diamond_board_preview() -> void:
	if diamond_board_view != null:
		diamond_board_view.clear_preview()
	if hud != null:
		hud.set_sanctuary_preview_loss(0)

func _set_diamond_board_selection_ranges(move_cells: Array, attack_cells: Array) -> void:
	if diamond_board_view != null:
		diamond_board_view.set_selection_ranges(move_cells, attack_cells)

func _set_diamond_board_enemy_intents(rows: Array) -> void:
	if diamond_board_view != null:
		diamond_board_view.set_enemy_intents(rows)

func _set_diamond_board_predicted_rifts(cells: Array) -> void:
	if diamond_board_view != null:
		diamond_board_view.set_predicted_rifts(cells)

func _set_diamond_board_predicted_cracked_ground(cells: Array) -> void:
	if diamond_board_view != null:
		diamond_board_view.set_predicted_cracked_ground(cells)

func _set_diamond_board_predicted_bell_wave(cells: Array) -> void:
	if diamond_board_view != null:
		diamond_board_view.set_predicted_bell_wave(cells)

func _set_diamond_board_preview_markers(markers: Array, paths: Array, protected_damage: Dictionary = {}) -> void:
	if diamond_board_view != null:
		diamond_board_view.set_preview_markers(markers, paths, protected_damage)
	_set_sanctuary_preview_from_damage(protected_damage)

func _set_diamond_board_focus(enemy_id: int) -> void:
	if diamond_board_view != null:
		diamond_board_view.set_focused_enemy(enemy_id)

func board_cell_under_mouse() -> Vector2i:
	if diamond_board_view != null:
		return diamond_board_view.pixel_to_cell(diamond_board_view.get_local_mouse_position())
	return Vector2i(-1, -1)

func board_cell_from_local(local_pos: Vector2) -> Vector2i:
	if diamond_board_view == null:
		return Vector2i(-1, -1)
	return diamond_board_view.pixel_to_cell(local_pos)

func _on_events(events: Array) -> void:
	_defer_enemy_intent_refresh_until_events = false
	_defer_state_refresh_until_events = false
	if events.is_empty():
		# Nothing to play; just refresh overlays.
		_refresh_state_presentation()
		_refresh_enemy_intent_overlay()
		_refresh_selection_highlights()
		_refresh_ability_bar()
		_refresh_info_panel()
		return
	_animating = true
	_begin_event_damage_playback(events)
	_executing_enemy_id = -1
	_clear_diamond_board_preview()
	_set_diamond_board_selection_ranges([], [])
	_set_diamond_board_predicted_rifts([])
	_set_diamond_board_predicted_cracked_ground([])
	_set_diamond_board_predicted_bell_wave([])
	_suppress_enemy_intents_until_events_done = _events_include_enemy_displacement(events)
	if _suppress_enemy_intents_until_events_done:
		_set_diamond_board_enemy_intents([])
		hud.set_enemy_action_stack([])
		_set_focused_enemy(-1)
	await _play_events(events)
	_animating = false
	_end_event_damage_playback()
	_suppress_enemy_intents_until_events_done = false
	_executing_enemy_id = -1
	hud.set_enemy_stack_executing(-1)
	_refresh_state_presentation()
	_refresh_enemy_intent_overlay()
	_refresh_selection_highlights()
	# After state changes (push, kill, etc.), re-render the info panel for the
	# cell currently under the cursor.
	_refresh_persistent_hud()
	_refresh_info_panel()
	_refresh_hover_preview()
	_emit_finish_if_ready()

func _emit_finish_if_ready() -> void:
	if _finish_emitted:
		return
	if engine == null or engine.state == null:
		return
	if engine.state.outcome == BattleState.Outcome.UNDECIDED:
		return
	_finish_emitted = true
	await get_tree().create_timer(0.55).timeout
	battle_finished.emit(_build_battle_summary())

func _build_battle_summary() -> Dictionary:
	var state := engine.state
	var wardens: Array[Dictionary] = []
	for unit in state.units:
		if unit.def == null or not unit.is_warden():
			continue
		wardens.append({
			"def_id": String(unit.def.def_id),
			"name": unit.def.display_name,
			"hp": maxi(0, unit.hp),
			"hp_max": unit.def.max_hp,
			"alive": unit.alive,
		})
	var completed := 0
	for task in state.reward_tasks:
		if bool(state.reward_completed.get(task, false)):
			completed += 1
	return {
		"outcome": state.outcome,
		"victory": state.outcome == BattleState.Outcome.VICTORY,
		"line_breached": state.outcome == BattleState.Outcome.DEFEAT \
			and state.has_protected_targets() and state.alive_protected_targets().is_empty(),
		"boss_config_id": state.boss_config_id,
		"boss_doom_count": state.doom_count,
		"boss_doom_count_max": state.doom_count_max,
		"boss_breached": state.boss_breached,
		"boss_anchor_destroyed_count": state.boss_destroyed_anchor_count(),
		"boss_anchor_count": state.boss_anchor_positions.size(),
		"boss_heart_hits": state.heart_hits,
		"destroyed_protected_count": state.destroyed_protected_count,
		"protected_damage_taken": state.protected_damage_taken,
		"completed_reward_count": completed,
		"reward_tasks": state.reward_tasks.duplicate(),
		"reward_completed": state.reward_completed.duplicate(true),
		"reward_failed": state.reward_failed.duplicate(true),
		"wardens": wardens,
		"round": state.current_round,
		"max_rounds": state.max_rounds,
	}

func _play_events(events: Array) -> void:
	if _event_animator == null:
		_event_animator = BattleEventAnimatorScript.new()
	_event_animator.bind(self, diamond_board_view)
	_event_animator.set_unit_snapshots(_event_unit_snapshots)
	await _event_animator.play_events(events)
	_event_unit_snapshots.clear()

# ---------- per-event animations ----------

func _update_boss_event_feedback(e: BattleEvent) -> void:
	if hud == null or engine == null or engine.state == null:
		return
	var text := ""
	if e.extra.get("boss_doom", false):
		text = "Boss Doom +1：当前 %d / %d" % [
			engine.state.doom_count,
			engine.state.doom_count_max,
		]
	elif e.extra.get("boss_heart_doom_reduction", false):
		text = "心脏钟压制生效：Boss Doom -1，当前 %d / %d" % [
			engine.state.doom_count,
			engine.state.doom_count_max,
		]
	elif e.extra.get("boss_heart_hit", false):
		text = "心脏钟命中：%d / %d" % [
			engine.state.heart_hits,
			engine.state.heart_hit_cap,
		]
	elif e.extra.get("boss_anchor_destroyed", false):
		text = "Boss 锚石破坏：剩余 %d / %d" % [
			engine.state.boss_alive_anchor_count(),
			engine.state.boss_anchor_positions.size(),
		]
	elif e.extra.get("boss_anchor", false):
		text = "Boss 锚石受损：剩余 %d / %d" % [
			engine.state.boss_alive_anchor_count(),
			engine.state.boss_anchor_positions.size(),
		]
	if text == "":
		return
	hud.set_help(text)
	hud.set_boss_status(engine.state)

func _anim_unit_spawned(e: BattleEvent) -> void:
	_refresh_diamond_board()
	if e.extra.get("from_rift", false):
		await get_tree().create_timer(0.12).timeout

func _capture_player_attack_context(action: BattleAction) -> void:
	_pending_player_attack_context.clear()
	if action.kind != BattleAction.Kind.ATTACK:
		return
	if engine == null or engine.state == null:
		return
	var attacker := engine.state.find_unit(action.actor_id)
	if attacker == null or not attacker.is_warden():
		return
	_pending_player_attack_context = _build_attack_fx_request(attacker, action.target_pos, true)

func _capture_event_unit_snapshots() -> void:
	_event_unit_snapshots.clear()
	if engine == null or engine.state == null:
		return
	for unit in engine.state.units:
		_event_unit_snapshots[unit.id] = unit.clone()

func _play_pending_player_attack_fx(e: BattleEvent, events: Array = []) -> void:
	if _pending_player_attack_context.is_empty():
		return
	var target_pos: Vector2i = _pending_player_attack_context.get("to_cell", Vector2i(-1, -1))
	if _event_has_target_pos(e) and e.to_pos != target_pos:
		return
	var request := _pending_player_attack_context.duplicate(true)
	await _play_attack_fx(request)
	_pending_player_attack_context.clear()

func _play_enemy_attack_fx(e: BattleEvent) -> void:
	var attacker := engine.state.find_unit(e.unit_id) if engine != null and engine.state != null else null
	if attacker == null:
		attacker = _event_unit_snapshots.get(e.unit_id, null)
	var request := _build_attack_fx_request(attacker, e.to_pos, false, e.unit_id, e.from_pos)
	await _play_attack_fx(request)

func _build_attack_fx_request(attacker: Unit, to_cell: Vector2i, is_player_attack: bool, fallback_id: int = -1, fallback_from_cell: Vector2i = DiamondBoardView.INVALID_CELL) -> Dictionary:
	var from_cell := fallback_from_cell
	var attacker_id := fallback_id
	var attack_kind := UnitDef.AttackKind.MELEE_BUMP
	if attacker != null:
		if from_cell == DiamondBoardView.INVALID_CELL:
			from_cell = attacker.position
		if attacker_id < 0:
			attacker_id = attacker.id
		if attacker.def != null:
			attack_kind = attacker.def.attack_kind
	return {
		"attacker_id": attacker_id,
		"from_cell": from_cell,
		"to_cell": to_cell,
		"attack_kind": attack_kind,
		"direction": Direction.from_cells(from_cell, to_cell),
		"is_player_attack": is_player_attack,
	}

func _play_attack_fx(request: Dictionary) -> void:
	if _attack_fx_presenter == null:
		_attack_fx_presenter = AttackFxPresenterScript.new()
	_attack_fx_presenter.bind(self, diamond_board_view)
	await _attack_fx_presenter.play_attack(request)

func _event_has_target_pos(e: BattleEvent) -> bool:
	return e.type == BattleEvent.Type.UNIT_DAMAGED \
		or e.type == BattleEvent.Type.UNIT_PUSHED \
		or e.type == BattleEvent.Type.UNIT_FELL \
		or e.type == BattleEvent.Type.TILE_DAMAGED \
		or e.type == BattleEvent.Type.TILE_DESTROYED \
		or e.type == BattleEvent.Type.BUMP_WALL \
		or e.type == BattleEvent.Type.BUMP_UNIT

func _event_is_attack_fx_trigger(e: BattleEvent) -> bool:
	return e.type == BattleEvent.Type.UNIT_DAMAGED \
		or e.type == BattleEvent.Type.UNIT_PUSHED \
		or e.type == BattleEvent.Type.UNIT_FELL \
		or e.type == BattleEvent.Type.TILE_DAMAGED \
		or e.type == BattleEvent.Type.TILE_DESTROYED \
		or e.type == BattleEvent.Type.BUMP_WALL \
		or e.type == BattleEvent.Type.BUMP_UNIT

func _event_starts_player_attack_fx(e: BattleEvent) -> bool:
	if _pending_player_attack_context.is_empty() or not _event_is_attack_fx_trigger(e):
		return false
	var target_pos: Vector2i = _pending_player_attack_context.get("to_cell", Vector2i(-1, -1))
	return _event_has_target_pos(e) and e.to_pos == target_pos

func _anim_unit_moved(_e: BattleEvent) -> void:
	_refresh_diamond_board()

func _anim_unit_pushed(_e: BattleEvent) -> void:
	_refresh_diamond_board()

func _anim_unit_damaged(_e: BattleEvent) -> void:
	_consume_presented_unit_damage(_e)
	_refresh_live_damage_presentation()
	await get_tree().create_timer(0.10).timeout

func _anim_unit_died(_e: BattleEvent) -> void:
	_refresh_diamond_board()
	await get_tree().create_timer(0.08).timeout

func _anim_unit_removed(_e: BattleEvent) -> void:
	_refresh_diamond_board()

func _anim_bump(_e: BattleEvent) -> void:
	_refresh_diamond_board()
	await get_tree().create_timer(0.08).timeout

func _anim_enemy_attack_missed(e: BattleEvent) -> void:
	## Keep a visible beat for a locked attack slot that the player neutralized.
	_set_executing_enemy(e.unit_id)
	await get_tree().create_timer(0.16).timeout

func _anim_tile_changed(_e: BattleEvent) -> void:
	_consume_presented_protected_damage(_e)
	_refresh_live_damage_presentation()

func _refresh_selection_highlights() -> void:
	_refresh_action_state_presentation()
	if engine.state.phase == BattleState.Phase.GARRISON:
		_set_diamond_board_selection_ranges([], [])
		return
	if selected_warden_id == -1 or engine.state.phase != BattleState.Phase.PLAYER_ACTION:
		_set_diamond_board_selection_ranges([], [])
		return
	# Range display depends on whether an ability is armed:
	#   - "attack" armed: only attack targets (red).
	#   - "move"   armed: only move cells (green).
	#   - none    armed: both, so the player can click whatever they want.
	var move_cells: Array[Vector2i] = []
	var attack_cells: Array[Vector2i] = []
	match _armed_ability_id:
		"attack":
			attack_cells = engine.get_legal_attack_targets(selected_warden_id)
		"move":
			move_cells = engine.get_legal_moves(selected_warden_id)
		_:
			move_cells = engine.get_legal_moves(selected_warden_id)
			attack_cells = engine.get_legal_attack_targets(selected_warden_id)
	_set_diamond_board_selection_ranges(move_cells, attack_cells)

func _refresh_action_state_presentation() -> void:
	_refresh_diamond_board()
	_refresh_persistent_hud()

func _refresh_persistent_hud() -> void:
	if hud == null or engine == null or engine.state == null:
		return
	hud.set_sanctuary(_effective_sanctuary_integrity(), _sanctuary_integrity_max)
	hud.set_squad_status(engine.state.wardens(), selected_warden_id)
	hud.set_reward_tasks(engine.state)
	hud.set_battle_status_summary(engine.state)

func _effective_sanctuary_integrity() -> int:
	if engine == null or engine.state == null:
		return _sanctuary_integrity
	return maxi(0, _sanctuary_integrity - _presented_protected_damage_taken())

func _presented_protected_damage_taken() -> int:
	if engine == null or engine.state == null:
		return 0
	if _animating:
		return maxi(0, _event_protected_damage_start + _event_protected_damage_pending)
	return maxi(0, engine.state.protected_damage_taken)

func _begin_event_damage_playback(events: Array) -> void:
	if engine == null or engine.state == null:
		_event_protected_damage_start = 0
		_event_protected_damage_pending = 0
		_event_tile_display_overrides.clear()
		_event_unit_display_overrides.clear()
		return
	var batch_damage := _total_protected_damage_in_events(events)
	_event_protected_damage_start = maxi(0, engine.state.protected_damage_taken - batch_damage)
	_event_protected_damage_pending = 0
	_event_tile_display_overrides = _initial_tile_display_overrides(events)
	_event_unit_display_overrides = _initial_unit_display_overrides(events)
	_apply_tile_display_overrides()
	_apply_unit_display_overrides()

func _end_event_damage_playback() -> void:
	_event_protected_damage_start = 0
	_event_protected_damage_pending = 0
	_event_tile_display_overrides.clear()
	_event_unit_display_overrides.clear()
	if diamond_board_view != null:
		diamond_board_view.clear_tile_display_overrides()
		diamond_board_view.clear_unit_display_overrides()

func _consume_presented_protected_damage(e: BattleEvent) -> void:
	if e.type == BattleEvent.Type.TILE_DAMAGED:
		_consume_tile_display_damage(e)
		if engine != null and engine.state != null and engine.state.is_protected_target(e.to_pos):
			_event_protected_damage_pending += maxi(0, e.amount)
	elif e.type == BattleEvent.Type.TILE_DESTROYED:
		_event_tile_display_overrides.erase(e.to_pos)
	_apply_tile_display_overrides()

func _consume_presented_unit_damage(e: BattleEvent) -> void:
	if e.type != BattleEvent.Type.UNIT_DAMAGED:
		return
	if not _event_unit_display_overrides.has(e.unit_id):
		return
	var display: Dictionary = _event_unit_display_overrides.get(e.unit_id, {})
	var hp := int(display.get("hp", 0)) - maxi(0, e.amount)
	display["hp"] = hp
	display["alive"] = hp > 0
	_event_unit_display_overrides[e.unit_id] = display
	_apply_unit_display_overrides()

func _total_protected_damage_in_events(events: Array) -> int:
	var total := 0
	if engine == null or engine.state == null:
		return total
	for raw in events:
		var e: BattleEvent = raw
		if e.type == BattleEvent.Type.TILE_DAMAGED and engine.state.is_protected_target(e.to_pos):
			total += maxi(0, e.amount)
	return total

func _initial_tile_display_overrides(events: Array) -> Dictionary:
	var pending_by_pos: Dictionary = {}
	if engine == null or engine.state == null:
		return pending_by_pos
	for raw in events:
		var e: BattleEvent = raw
		if e.type == BattleEvent.Type.TILE_DAMAGED and engine.state.is_protected_target(e.to_pos):
			_add_preview_protected_damage(pending_by_pos, e.to_pos, maxi(0, e.amount))
	var overrides: Dictionary = {}
	for pos in pending_by_pos.keys():
		var cell: Vector2i = pos
		var final_tile := engine.state.grid.get_tile(cell)
		var final_hp := int(engine.state.grid.tile_hp.get(cell, 0))
		var display_hp := final_hp + int(pending_by_pos.get(cell, 0))
		if display_hp <= 0:
			continue
		overrides[cell] = {
			"tile": Grid.TileType.BUILDING,
			"hp": display_hp,
		}
	return overrides

func _initial_unit_display_overrides(events: Array) -> Dictionary:
	var pending_by_unit: Dictionary = {}
	if engine == null or engine.state == null:
		return pending_by_unit
	for raw in events:
		var e: BattleEvent = raw
		if e.type == BattleEvent.Type.UNIT_DAMAGED:
			pending_by_unit[e.unit_id] = int(pending_by_unit.get(e.unit_id, 0)) + maxi(0, e.amount)
	var overrides: Dictionary = {}
	for unit_id in pending_by_unit.keys():
		var unit := _unit_for_event_display(int(unit_id))
		if unit == null:
			continue
		var final_hp := maxi(0, unit.hp)
		var display_hp := final_hp + int(pending_by_unit.get(unit_id, 0))
		overrides[int(unit_id)] = {
			"hp": display_hp,
			"alive": display_hp > 0,
		}
	return overrides

func _unit_for_event_display(unit_id: int) -> Unit:
	if engine != null and engine.state != null:
		var unit := engine.state.find_unit(unit_id)
		if unit != null:
			return unit
	return _event_unit_snapshots.get(unit_id, null)

func _consume_tile_display_damage(e: BattleEvent) -> void:
	if not _event_tile_display_overrides.has(e.to_pos):
		return
	var display: Dictionary = _event_tile_display_overrides.get(e.to_pos, {})
	var hp := int(display.get("hp", 0)) - maxi(0, e.amount)
	if hp > 0:
		display["hp"] = hp
		_event_tile_display_overrides[e.to_pos] = display
	else:
		_event_tile_display_overrides.erase(e.to_pos)

func _apply_tile_display_overrides() -> void:
	if diamond_board_view != null:
		diamond_board_view.set_tile_display_overrides(_event_tile_display_overrides)

func _apply_unit_display_overrides() -> void:
	if diamond_board_view != null:
		diamond_board_view.set_unit_display_overrides(_event_unit_display_overrides)

func _refresh_live_damage_presentation() -> void:
	_refresh_diamond_board()
	if hud == null or engine == null or engine.state == null:
		return
	hud.set_sanctuary(_effective_sanctuary_integrity(), _sanctuary_integrity_max)
	hud.set_squad_status(_display_wardens_for_live_damage(), selected_warden_id)

func _display_wardens_for_live_damage() -> Array:
	var wardens: Array = []
	if engine == null or engine.state == null:
		return wardens
	var listed: Dictionary = {}
	for unit_id in _event_unit_snapshots.keys():
		var snapshot: Unit = _event_unit_snapshots.get(int(unit_id), null)
		if snapshot == null or not snapshot.is_warden() or not snapshot.alive:
			continue
		var display: Dictionary = _event_unit_display_overrides.get(int(unit_id), {})
		if int(display.get("hp", snapshot.hp)) <= 0:
			continue
		wardens.append(_display_unit_for_live_damage(snapshot))
		listed[snapshot.id] = true
	for unit in engine.state.wardens():
		if listed.has(unit.id):
			continue
		wardens.append(_display_unit_for_live_damage(unit))
		listed[unit.id] = true
	return wardens

func _display_unit_for_live_damage(unit: Unit) -> Unit:
	if unit == null:
		return Unit.new()
	var display_unit := unit.clone()
	var display: Dictionary = _event_unit_display_overrides.get(unit.id, {})
	if display.has("hp"):
		display_unit.hp = int(display.get("hp", display_unit.hp))
	if display.has("alive"):
		display_unit.alive = bool(display.get("alive", display_unit.alive))
	return display_unit

func _battle_outcome_reason(state: BattleState) -> String:
	if state.outcome == BattleState.Outcome.VICTORY:
		return "守住第 %d 轮" % state.max_rounds
	if state.has_boss() and (state.boss_breached or state.is_boss_doom_breached()):
		return "Boss Doom 满"
	if state.wardens().is_empty():
		return "守卫者全灭"
	if state.has_protected_targets() and state.alive_protected_targets().is_empty():
		return "防线溃败"
	return "战斗失败"

func _refresh_enemy_intent_overlay(rows_override: Array = [], preview_mode: bool = false) -> void:
	if _suppress_enemy_intents_until_events_done and rows_override.is_empty():
		_set_diamond_board_enemy_intents([])
		if diamond_board_view != null:
			diamond_board_view.set_preview_protected_damage({})
		_set_sanctuary_preview_from_damage({})
		hud.set_enemy_action_stack([])
		return
	var rows: Array = rows_override if not rows_override.is_empty() else engine.get_enemy_intent_ui_state()
	var attack_rows: Array = []
	for row in rows:
		if row.get("has_attack", false) or row.get("status", BattleEngine.INTENT_STATUS_NO_ATTACK) == BattleEngine.INTENT_STATUS_REMOVED:
			attack_rows.append(row)
	_set_diamond_board_enemy_intents(attack_rows)
	var intent_damage := _preview_protected_damage_from_intent_rows(attack_rows)
	if diamond_board_view != null:
		diamond_board_view.set_preview_protected_damage(intent_damage)
	_set_sanctuary_preview_from_damage(intent_damage)
	hud.set_enemy_action_stack(
		rows,
		preview_mode,
		_focused_enemy_id,
		_executing_enemy_id,
	)
	# Predicted rift spawns (1 round ahead).
	var predicted: Array[Vector2i] = []
	for entry in engine.state.pending_rift_spawns:
		predicted.append(entry.pos)
	_set_diamond_board_predicted_rifts(predicted)
	_set_diamond_board_predicted_cracked_ground(engine.state.pending_cracked_ground)
	_set_diamond_board_predicted_bell_wave(engine.state.pending_bell_wave)

func _preview_protected_damage_from_events(events: Array) -> Dictionary:
	var damage: Dictionary = {}
	if engine == null or engine.state == null:
		return damage
	for raw in events:
		var e: BattleEvent = raw
		if e.type != BattleEvent.Type.TILE_DAMAGED:
			continue
		if not engine.state.is_protected_target(e.to_pos):
			continue
		_add_preview_protected_damage(damage, e.to_pos, e.amount)
	return damage

func _preview_protected_damage_from_intent_rows(rows: Array) -> Dictionary:
	var damage: Dictionary = {}
	var remaining_by_pos: Dictionary = {}
	for row in rows:
		if row.get("target_kind", "") != BattleEngine.TARGET_KIND_BUILDING:
			continue
		if row.get("status", "") != BattleEngine.INTENT_STATUS_HIT:
			continue
		if not bool(row.get("attack_fires", false)):
			continue
		var pos: Vector2i = row.get("target_pos", Vector2i(-1, -1))
		if pos == Vector2i(-1, -1):
			continue
		if not remaining_by_pos.has(pos):
			remaining_by_pos[pos] = maxi(0, int(row.get("target_hp", 0)))
		var remaining := int(remaining_by_pos.get(pos, 0))
		var amount := mini(remaining, maxi(0, int(row.get("target_damage", 0))))
		if amount <= 0:
			continue
		remaining_by_pos[pos] = remaining - amount
		_add_preview_protected_damage(damage, pos, amount)
	return damage

func _merge_preview_protected_damage(first: Dictionary, second: Dictionary) -> Dictionary:
	var merged := first.duplicate(true)
	for pos in second.keys():
		_add_preview_protected_damage(merged, pos, int(second.get(pos, 0)))
	return merged

func _add_preview_protected_damage(damage: Dictionary, pos: Vector2i, amount: int) -> void:
	if amount <= 0:
		return
	damage[pos] = int(damage.get(pos, 0)) + amount

func _set_sanctuary_preview_from_damage(damage: Dictionary) -> void:
	if hud == null:
		return
	var total := 0
	for amount in damage.values():
		total += maxi(0, int(amount))
	hud.set_sanctuary_preview_loss(total)

func _refresh_info_panel() -> void:
	_set_focused_enemy(-1)
	_show_selected_unit_info_or_hide()

func _show_selected_unit_info_or_hide() -> void:
	hud.hide_info_panel()

func _show_unit_info(unit: Unit) -> void:
	if unit.is_warden() and unit.id == selected_warden_id and _hover_cell == Vector2i(-1, -1):
		hud.hide_info_panel()
		return
	## Default info panel: only HP / 移动 / 攻击范围.
	## Debug-mode info panel: + 出手顺序、意图、伤害预算 等.
	var faction_tag: String = "守卫者" if unit.is_warden() else "敌方"
	var title: String = "%s [%s]" % [unit.def.display_name, faction_tag]
	var lines: Array[String] = []
	lines.append("HP: %d / %d" % [unit.hp, unit.def.max_hp])
	lines.append("移动: %d 格" % unit.def.move)
	lines.append("攻击: " + _attack_kind_text(unit.def))
	if _debug_mode:
		_append_debug_info(unit, lines)
	else:
		# Footer hint about toggle.
		lines.append("")
		lines.append("[按 F1 查看调试详情]")
	hud.show_info_panel(title, "\n".join(lines))

## Appends planning/intent/damage details to the info panel. Only called when
## debug mode is on. Player-facing UI stays clean.
func _append_debug_info(unit: Unit, lines: Array[String]) -> void:
	lines.append("")
	lines.append("─ DEBUG ─")
	if unit.is_enemy():
		var order_ids: Array[int] = engine.enemy_execution_order()
		var idx: int = order_ids.find(unit.id)
		if idx >= 0:
			lines.append("出手顺序: 第 %d 个" % (idx + 1))
		var plan = engine.state.enemy_warnings.get(unit.id, null)
		if plan == null:
			lines.append("意图: 未知")
		else:
			var actionable: bool = engine.is_plan_actionable(unit.id)
			if not actionable:
				lines.append("[本回合行动落空]")
				lines.append("（失去攻击方向 / 目标）")
			elif plan.has_attack():
				var attack_pos := engine.current_enemy_attack_pos(unit.id)
				lines.append("攻击格: (%d, %d)" % [attack_pos.x, attack_pos.y])
				var target := engine.state.get_alive_unit_at(attack_pos)
				if target != null:
					lines.append("目标: %s (HP %d → %d)" % [
						target.def.display_name,
						target.hp,
						max(0, target.hp - unit.def.attack_damage),
					])
			else:
				lines.append("[本回合仅靠近，不攻击]")
	else:
		if unit.has_acted:
			lines.append("状态: 本回合已结束")
		elif unit.has_moved:
			lines.append("状态: 已移动，剩 1 次攻击")
		else:
			lines.append("状态: 未行动")
	# Damage preview when warden is selected and hovering enemy in range.
	if unit.is_enemy() and selected_warden_id != -1:
		var targets: Array[Vector2i] = engine.get_legal_attack_targets(selected_warden_id)
		if unit.position in targets:
			var attacker := engine.state.find_unit(selected_warden_id)
			if attacker != null:
				lines.append("")
				lines.append("─ 攻击预算 ─")
				lines.append("伤害: %d" % attacker.def.attack_damage)
				if attacker.def.attack_force > 0:
					var fkind := "推" if attacker.def.attack_kind != UnitDef.AttackKind.RANGED_PULL else "拉"
					lines.append("%s: %d 格" % [fkind, attacker.def.attack_force])
				lines.append("击杀后剩余 HP: %d" % max(0, unit.hp - attacker.def.attack_damage))

func _attack_kind_text(def: UnitDef) -> String:
	match def.attack_kind:
		UnitDef.AttackKind.MELEE_BUMP:
			return "近战 (1 格) %d 伤" % def.attack_damage
		UnitDef.AttackKind.MELEE_PUSH:
			return "近战 (1 格) %d 伤 + 推 %d" % [def.attack_damage, def.attack_force]
		UnitDef.AttackKind.RANGED_PULL:
			return "远程直线 %d 格 %d 伤 + 拉 %d" % [def.attack_range, def.attack_damage, def.attack_force]
		UnitDef.AttackKind.RANGED_PUSH:
			return "远程直线 %d 格 %d 伤 + 推 %d" % [def.attack_range, def.attack_damage, def.attack_force]
	return "?"

func _refresh_ability_bar() -> void:
	if selected_warden_id == -1:
		hud.hide_ability_bar()
		return
	var warden := engine.state.find_unit(selected_warden_id)
	if warden == null or not warden.is_warden():
		hud.hide_ability_bar()
		return
	var subtitle: String = ""
	if _armed_ability_id == "attack":
		subtitle = " ▸ 选择目标"
	var warden_data := {
		"name": "%s%s" % [warden.def.display_name, subtitle],
		"hp": warden.hp,
		"max_hp": warden.def.max_hp,
		"move": warden.def.move,
		"attack": _attack_kind_text(warden.def),
		"token": warden.def.token_texture,
	}
	var abilities: Array = []
	var skill_defs := _warden_skill_slots(warden)
	for i in range(skill_defs.size()):
		var skill: Dictionary = skill_defs[i]
		abilities.append({
			"id": skill.get("id", ""),
			"name": skill.get("name", "?"),
			"icon": skill.get("icon", ""),
			"desc": skill.get("desc", ""),
			"active": bool(skill.get("active", false)),
			"is_default": i == 0,
			"is_armed": _armed_ability_id == skill.get("id", ""),
		})
	hud.show_ability_bar(warden_data, abilities)

func _warden_skill_slots(warden: Unit) -> Array:
	var primary_desc := _attack_kind_text(warden.def)
	var primary := {
		"id": "attack",
		"name": _primary_skill_name(warden),
		"icon": "⚔",
		"desc": primary_desc,
		"active": not warden.has_acted,
	}
	match String(warden.def.def_id):
		"warden_bountyhunter":
			return [
				primary,
				{"id": "guard_shoulder", "name": "护卫肩撞", "icon": "⛨", "desc": "换位 · 护建筑", "active": false},
				{"id": "bounty_execute", "name": "悬赏处决", "icon": "◆", "desc": "击杀收益", "active": false},
			]
		"warden_graverobber":
			return [
				primary,
				{"id": "rift_wedge", "name": "裂隙楔", "icon": "▰", "desc": "延迟地裂", "active": false},
				{"id": "backhand_throw", "name": "反手抛", "icon": "↶", "desc": "拉近侧推", "active": false},
			]
		"warden_mage":
			return [
				primary,
				{"id": "ward_fire", "name": "护火", "icon": "✚", "desc": "修复建筑", "active": false},
				{"id": "sigil", "name": "法阵", "icon": "◇", "desc": "区域减速", "active": false},
			]
	return [
		primary,
		{"id": "skill_2", "name": "技能 2", "icon": "◆", "desc": "未接入", "active": false},
		{"id": "skill_3", "name": "技能 3", "icon": "◇", "desc": "未接入", "active": false},
	]

func _primary_skill_name(warden: Unit) -> String:
	match String(warden.def.def_id):
		"warden_bountyhunter":
			return "链锤击"
		"warden_graverobber":
			return "倒钩索"
		"warden_mage":
			return "斥力弹"
	return "攻击"

func _refresh_hover_preview() -> void:
	_clear_diamond_board_preview()
	if selected_warden_id == -1 or _hover_cell == Vector2i(-1, -1):
		_refresh_enemy_intent_overlay()
		return
	if engine.state.phase != BattleState.Phase.PLAYER_ACTION:
		_refresh_enemy_intent_overlay()
		return
	var attack_targets: Array[Vector2i] = engine.get_legal_attack_targets(selected_warden_id)
	var move_cells: Array[Vector2i] = engine.get_legal_moves(selected_warden_id)
	var action: BattleAction = null
	if _hover_cell in attack_targets:
		action = BattleAction.attack(selected_warden_id, _hover_cell)
	elif _hover_cell in move_cells:
		action = BattleAction.move(selected_warden_id, _hover_cell)
	if action == null:
		_refresh_enemy_intent_overlay()
		return
	var events := engine.preview_action(action)
	var preview_rows := engine.preview_enemy_intent_ui_state(action)
	_refresh_enemy_intent_overlay(preview_rows, true)
	var protected_damage := _merge_preview_protected_damage(
		_preview_protected_damage_from_events(events),
		_preview_protected_damage_from_intent_rows(preview_rows)
	)
	# Build per-unit projection:
	#   start_pos = position when the chain began
	#   end_pos   = final landing cell (or original if never moved)
	#   fate      = "ok" | "dead" | "fell"
	# Only show MOVED units that actually changed cell OR units whose fate changed.
	var start_positions: Dictionary = {}  # uid -> first from_pos seen
	var end_positions: Dictionary = {}    # uid -> last to_pos seen
	var fates: Dictionary = {}            # uid -> "dead" | "fell"
	for raw in events:
		var e: BattleEvent = raw
		match e.type:
			BattleEvent.Type.UNIT_MOVED, BattleEvent.Type.UNIT_PUSHED:
				if not start_positions.has(e.unit_id):
					start_positions[e.unit_id] = e.from_pos
				end_positions[e.unit_id] = e.to_pos
			BattleEvent.Type.UNIT_FELL:
				if not start_positions.has(e.unit_id):
					start_positions[e.unit_id] = e.from_pos
				fates[e.unit_id] = "fell"
			BattleEvent.Type.UNIT_REMOVED:
				if not fates.has(e.unit_id):
					fates[e.unit_id] = "dead"
	# Compose preview markers.
	# We send the overlay 2 sorts of info:
	#   - markers: list of {pos, kind} where kind ∈ {"ghost_enemy", "ghost_warden", "skull", "fall"}
	#   - paths: list of {from, to} for arrow rendering on pushed enemies
	var markers: Array = []
	var paths: Array = []
	# Iterate the union of affected units, but skip the attacker itself if they
	# didn't move (their position is already shown by their live token).
	var affected_ids: Dictionary = {}
	for k in end_positions.keys(): affected_ids[k] = true
	for k in fates.keys(): affected_ids[k] = true
	for uid in affected_ids.keys():
		var u := engine.state.find_unit(uid)
		if u == null:
			continue
		# Skip the acting warden -- they don't change cells in our slice.
		if uid == selected_warden_id and not end_positions.has(uid):
			continue
		var end_pos: Vector2i = end_positions.get(uid, u.position)
		var start_pos: Vector2i = start_positions.get(uid, u.position)
		var fate: String = fates.get(uid, "")
		if fate == "fell":
			markers.append({"pos": start_pos, "kind": "fall"})
		elif fate == "dead":
			# Show skull at where the unit actually lands (or its current pos if no move).
			markers.append({"pos": end_pos, "kind": "skull"})
		else:
			# Alive after action. Show a faint ghost at the final cell ONLY if it
			# actually moved -- avoids putting a dot under the live token.
			if end_pos != start_pos:
				var kind: String = "ghost_warden" if u.is_warden() else "ghost_enemy"
				markers.append({"pos": end_pos, "kind": kind})
		# Draw an arrow from start to end if the unit was displaced.
		if end_pos != start_pos:
			paths.append({"from": start_pos, "to": end_pos, "enemy": u.is_enemy()})
	_set_diamond_board_preview_markers(markers, paths, protected_damage)

# ---------- helpers exposed to children ----------

## F1 toggle: swaps the info panel between "player view" (HP/move/attack) and
## "debug view" (+ planning details, displacement state, damage preview).
func toggle_debug_mode() -> void:
	_debug_mode = not _debug_mode
	# If the info panel is open, re-render with new mode.
	_refresh_info_panel()
	# Also flash a brief HUD hint about the mode change.
	hud.set_help("调试模式：%s   ·   F1 切换" % ("开启" if _debug_mode else "关闭"))

func deselect(refresh_now: bool = true) -> void:
	selected_warden_id = -1
	_armed_ability_id = ""
	if refresh_now:
		_refresh_persistent_hud()
		_refresh_selection_highlights()
	_clear_diamond_board_preview()
	hud.hide_ability_bar()
	if refresh_now and not _defer_enemy_intent_refresh_until_events and not _animating:
		_refresh_enemy_intent_overlay()

func _full_rebuild() -> void:
	diamond_board_view.bind_state(engine.state)
	if _event_animator != null:
		_event_animator.bind(self, diamond_board_view)
	if _attack_fx_presenter != null:
		_attack_fx_presenter.bind(self, diamond_board_view)
	deselect()
	_on_state_changed()

func _on_enemy_stack_hovered(enemy_id: int) -> void:
	_set_focused_enemy(enemy_id)

func _set_focused_enemy(enemy_id: int) -> void:
	if _focused_enemy_id == enemy_id:
		return
	_focused_enemy_id = enemy_id
	_set_diamond_board_focus(enemy_id)
	hud.set_enemy_stack_focus(enemy_id)

func _set_executing_enemy(enemy_id: int) -> void:
	if _executing_enemy_id == enemy_id:
		return
	_executing_enemy_id = enemy_id
	hud.set_enemy_stack_executing(enemy_id)
	_set_focused_enemy(enemy_id)

func _events_include_enemy_displacement(events: Array) -> bool:
	for raw in events:
		var e: BattleEvent = raw
		if (
			e.type == BattleEvent.Type.UNIT_MOVED
			or e.type == BattleEvent.Type.UNIT_PUSHED
			or e.type == BattleEvent.Type.UNIT_FELL
		) and _event_unit_is_enemy(e):
			return true
	return false

func _event_unit_is_enemy(e: BattleEvent) -> bool:
	var u := engine.state.find_unit(e.unit_id)
	if u == null:
		u = _event_unit_snapshots.get(e.unit_id, null)
	return u != null and u.is_enemy()
