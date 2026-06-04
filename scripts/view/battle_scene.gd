class_name BattleScene extends Node2D
## Root of the battle vertical slice. Wires engine + view together.

@onready var grid_view: GridView = $Board/GridView
@onready var preview: PreviewOverlay = $Board/PreviewOverlay
@onready var units_root: Node2D = $Board/Units
@onready var hud: HUD = $HUD
@onready var input_ctl: InputController = $InputController

const UNIT_VIEW_SCENE := preload("res://Scenes/battle/UnitView.tscn")

var engine: BattleEngine
var unit_views: Dictionary = {}  # unit_id: int -> UnitView
var selected_warden_id: int = -1
## When non-empty, the player is in "ability targeting" mode: clicking a valid
## cell executes the armed ability. Right-click cancels back to normal selection.
## Slice supports "attack" and "move"; future relics will add more ids.
var _armed_ability_id: String = ""
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _animating: bool = false
var _focused_enemy_id: int = -1
var _executing_enemy_id: int = -1
var _defer_enemy_intent_refresh_until_events: bool = false
var _suppress_enemy_intents_until_events_done: bool = false
## Debug mode: when ON, info panel shows planned actions, execution order,
## displacement state, etc. Toggle with F1. OFF by default so the panel
## stays clean (just HP / move / attack range).
var _debug_mode: bool = false

func _ready() -> void:
	engine = BattleEngine.new()
	engine.events_produced.connect(_on_events)
	engine.state_changed.connect(_on_state_changed)
	input_ctl.bind(self)
	input_ctl.warden_selected.connect(_on_warden_selected)
	input_ctl.action_requested.connect(_on_action_requested)
	input_ctl.hover_changed.connect(_on_hover_changed)
	hud.end_turn_pressed.connect(func(): _on_action_requested(BattleAction.end_turn()))
	hud.undo_pressed.connect(func(): _on_action_requested(BattleAction.undo()))
	hud.confirm_deploy_pressed.connect(func(): _on_action_requested(BattleAction.confirm_deploy()))
	hud.ability_selected.connect(_on_ability_selected)
	hud.enemy_stack_hovered.connect(_on_enemy_stack_hovered)
	hud.set_help("操作：点击守卫者后，点绿格移动 / 红格攻击   ·   空格 = 结束回合   ·   Cmd/Ctrl+Z = 撤回   ·   右键 = 取消   ·   F1 = 调试详情")
	_start_slice_battle()

func _start_slice_battle() -> void:
	var bh: UnitDef = load("res://scripts/data/defs/warden_bountyhunter.tres")
	var gr: UnitDef = load("res://scripts/data/defs/warden_graverobber.tres")
	var mg: UnitDef = load("res://scripts/data/defs/warden_mage.tres")
	var carrion: UnitDef = load("res://scripts/data/defs/enemy_carrion_spawn.tres")
	var archer: UnitDef = load("res://scripts/data/defs/enemy_plague_archer.tres")

	var grid := Grid.new()
	# A couple of pillars for tactical interest.
	grid.set_tile(Vector2i(3, 3), Grid.TileType.PILLAR)
	grid.set_tile(Vector2i(4, 4), Grid.TileType.PILLAR)
	# Protected buildings: the battle now follows the stable defense rule.
	# Clearing enemies is useful, but victory waits until max_rounds.
	var protected_targets: Array[Vector2i] = [
		Vector2i(2, 6),
		Vector2i(5, 6),
		Vector2i(4, 7),
	]
	for p in protected_targets:
		grid.set_tile(p, Grid.TileType.BUILDING, 2)

	# Wardens are deployed by the player during the Garrison phase (see §3.3).
	var warden_defs: Array = [bh, gr, mg]
	# Starting wave: 2 carrions + 1 plague archer. Archer's ranged threat
	# forces the player to engage / push enemies into LOS-breaking positions.
	var enemies: Array = [
		{"def": carrion, "pos": Vector2i(1, 0)},
		{"def": archer, "pos": Vector2i(3, 0)},
		{"def": carrion, "pos": Vector2i(6, 0)},
	]
	# Deploy zone: bottom 2 rows (y >= 6 in 0-indexed 8x8).
	var deploy_zone: Array[Vector2i] = []
	for y in [6, 7]:
		for x in range(Grid.SIZE):
			deploy_zone.append(Vector2i(x, y))

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
	var rift_a := Vector2i(2, 1)
	var rift_b := Vector2i(5, 1)
	var rift_positions: Array[Vector2i] = [rift_a, rift_b]
	var rift_schedule: Array = [
		{"round": 2, "pos": rift_a, "def": carrion},
		{"round": 2, "pos": rift_b, "def": carrion},
		{"round": 3, "pos": rift_a, "def": carrion},
	]

	engine.start_battle(
		grid,
		warden_defs,
		enemies,
		deploy_zone,
		rift_positions,
		rift_schedule,
		5,
		protected_targets,
		[
			BattleState.REWARD_PERFECT_DEFENSE,
			BattleState.REWARD_TERMINAL_CLEAR,
			BattleState.REWARD_PHYSICAL_KILLS_3,
		],
	)
	grid_view.bind(engine.state.grid)
	_rebuild_unit_views()
	_on_state_changed()

func _rebuild_unit_views() -> void:
	for child in units_root.get_children():
		child.queue_free()
	unit_views.clear()
	for u in engine.state.units:
		_spawn_unit_view(u)

func _spawn_unit_view(u: Unit, at_cell: Vector2i = Vector2i(-99, -99)) -> void:
	## Create a view for unit `u`. By default the view appears at u.position,
	## but callers can override `at_cell` to place it at a specific spawn
	## location -- needed when the engine has already mutated u.position
	## (e.g. rift spawn + immediate move in the same event batch).
	var view: UnitView = UNIT_VIEW_SCENE.instantiate()
	units_root.add_child(view)
	view.configure(u)
	if at_cell == Vector2i(-99, -99):
		view.snap_to_cell(u.position)
	else:
		view.snap_to_cell(at_cell)
	unit_views[u.id] = view

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

func _on_action_requested(action: BattleAction) -> void:
	if _animating and action.kind != BattleAction.Kind.UNDO:
		return
	if action.kind == BattleAction.Kind.UNDO:
		engine.apply_action(action)
		# After undo, do a full rebuild
		_full_rebuild()
		return
	_defer_enemy_intent_refresh_until_events = true
	var events := engine.apply_action(action)
	# Any move / attack clears the armed ability so the ability bar refreshes
	# to reflect the warden's new available actions.
	if action.kind == BattleAction.Kind.MOVE or action.kind == BattleAction.Kind.ATTACK:
		_armed_ability_id = ""
	# Attacking / ending turn fully deselects the warden.
	if action.kind == BattleAction.Kind.ATTACK or action.kind == BattleAction.Kind.END_TURN:
		deselect()

func _on_hover_changed(cell: Vector2i, inside: bool) -> void:
	if not inside:
		_hover_cell = Vector2i(-1, -1)
		preview.clear_preview()
		_set_focused_enemy(-1)
		hud.hide_info_panel()
		_refresh_enemy_intent_overlay()
		return
	_hover_cell = cell
	_refresh_hover_preview()
	_refresh_info_panel()

# ---------- presentation ----------

func _on_state_changed() -> void:
	hud.set_sanctuary(7, 7)
	hud.update_status(engine.state)
	_refresh_persistent_hud()
	if engine.state.outcome != BattleState.Outcome.UNDECIDED:
		hud.show_outcome(engine.state.outcome)
	if _defer_enemy_intent_refresh_until_events:
		return
	_refresh_enemy_intent_overlay()
	_refresh_selection_highlights()
	_refresh_ability_bar()

func _on_events(events: Array) -> void:
	_defer_enemy_intent_refresh_until_events = false
	if events.is_empty():
		# Nothing to play; just refresh overlays.
		_refresh_enemy_intent_overlay()
		_refresh_selection_highlights()
		_refresh_info_panel()
		return
	_animating = true
	_executing_enemy_id = -1
	preview.clear_preview()
	preview.clear_all_ranges()
	_suppress_enemy_intents_until_events_done = _events_include_enemy_displacement(events)
	if _suppress_enemy_intents_until_events_done:
		hud.set_enemy_action_stack([])
		_set_focused_enemy(-1)
	await _play_events(events)
	_animating = false
	_suppress_enemy_intents_until_events_done = false
	_executing_enemy_id = -1
	hud.set_enemy_stack_executing(-1)
	_refresh_enemy_intent_overlay()
	_refresh_selection_highlights()
	# After state changes (push, kill, etc.), re-render the info panel for the
	# cell currently under the cursor.
	_refresh_persistent_hud()
	_refresh_info_panel()
	_refresh_hover_preview()

func _play_events(events: Array) -> void:
	## Plays each event from the engine sequentially, awaiting animations.
	## Adding a new event type? Add a case here + handler below.
	for raw in events:
		var e: BattleEvent = raw
		match e.type:
			BattleEvent.Type.UNIT_SPAWNED: await _anim_unit_spawned(e)
			BattleEvent.Type.UNIT_MOVED:
				if _suppress_enemy_intents_until_events_done and _event_unit_is_enemy(e):
					preview.set_enemy_intents([])
					hud.set_enemy_action_stack([])
					_set_focused_enemy(-1)
				await _anim_unit_moved(e)
			BattleEvent.Type.UNIT_PUSHED:
				if _suppress_enemy_intents_until_events_done and _event_unit_is_enemy(e):
					preview.set_enemy_intents([])
					hud.set_enemy_action_stack([])
					_set_focused_enemy(-1)
				await _anim_unit_pushed(e)
			BattleEvent.Type.UNIT_DAMAGED: await _anim_unit_damaged(e)
			BattleEvent.Type.UNIT_DIED, BattleEvent.Type.UNIT_FELL:
				await _anim_unit_died(e)
			BattleEvent.Type.UNIT_REMOVED: _anim_unit_removed(e)
			BattleEvent.Type.TILE_DAMAGED, BattleEvent.Type.TILE_DESTROYED:
				_anim_tile_changed(e)
			BattleEvent.Type.BUMP_WALL, BattleEvent.Type.BUMP_UNIT:
				await _anim_bump(e)
			BattleEvent.Type.ENEMY_ATTACK_STARTED:
				_set_executing_enemy(e.unit_id)
				await get_tree().create_timer(0.10).timeout
			BattleEvent.Type.ENEMY_ATTACK_MISSED:
				await _anim_enemy_attack_missed(e)
			BattleEvent.Type.ROUND_STARTED:
				if _suppress_enemy_intents_until_events_done:
					preview.set_enemy_intents([])
					hud.set_enemy_action_stack([])
					_set_focused_enemy(-1)
			# Phase / round / battle-end events are state changes; no animation.
			_:
				pass

# ---------- per-event animations ----------

func _anim_unit_spawned(e: BattleEvent) -> void:
	var u := engine.state.find_unit(e.unit_id)
	if u == null or unit_views.has(u.id):
		return
	# Place at the SPAWN cell (e.to_pos), not u.position -- u.position may
	# have already been mutated by a later move event in the same batch.
	_spawn_unit_view(u, e.to_pos)
	if not e.extra.get("from_rift", false):
		return
	var view: UnitView = unit_views.get(u.id)
	if view == null:
		return
	# Rising-from-rift animation: fade in + scale up.
	view.modulate.a = 0.0
	view.scale = Vector2(0.5, 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(view, "modulate:a", 1.0, 0.35)
	tw.tween_property(view, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

func _anim_unit_moved(e: BattleEvent) -> void:
	var view: UnitView = unit_views.get(e.unit_id, null)
	if view != null:
		await view.move_to_cell(e.to_pos, 0.18)

func _anim_unit_pushed(e: BattleEvent) -> void:
	var view: UnitView = unit_views.get(e.unit_id, null)
	if view != null:
		await view.push_to_cell(e.to_pos, 0.30)

func _anim_unit_damaged(e: BattleEvent) -> void:
	## Impact flash + tiny shake so attacks feel weighty.
	var u := engine.state.find_unit(e.unit_id)
	var view: UnitView = unit_views.get(e.unit_id, null)
	if view == null or u == null:
		return
	view.configure(u)  # redraw HP pips
	var orig_color: Color = view.modulate
	var orig_pos: Vector2 = view.position
	view.modulate = Color(1.6, 0.8, 0.8)
	create_tween().tween_property(view, "modulate", orig_color, 0.14)
	var shake := create_tween()
	shake.tween_property(view, "position", orig_pos + Vector2(3, 0), 0.04)
	shake.tween_property(view, "position", orig_pos + Vector2(-3, 0), 0.04)
	shake.tween_property(view, "position", orig_pos, 0.04)
	await get_tree().create_timer(0.10).timeout

func _anim_unit_died(e: BattleEvent) -> void:
	var view: UnitView = unit_views.get(e.unit_id, null)
	if view != null:
		var tw := create_tween()
		tw.tween_property(view, "modulate:a", 0.0, 0.18)
		await tw.finished

func _anim_unit_removed(e: BattleEvent) -> void:
	var view: UnitView = unit_views.get(e.unit_id, null)
	if view != null:
		view.queue_free()
		unit_views.erase(e.unit_id)

func _anim_bump(e: BattleEvent) -> void:
	## Quick vertical shake on the impacted unit.
	var view: UnitView = unit_views.get(e.unit_id, null)
	if view != null:
		var orig: Vector2 = view.position
		var shake := create_tween()
		shake.tween_property(view, "position", orig + Vector2(0, -4), 0.04)
		shake.tween_property(view, "position", orig, 0.06)
	await get_tree().create_timer(0.08).timeout

func _anim_enemy_attack_missed(e: BattleEvent) -> void:
	## Keep a visible beat for a locked attack slot that the player neutralized.
	_set_executing_enemy(e.unit_id)
	await get_tree().create_timer(0.16).timeout

func _anim_tile_changed(_e: BattleEvent) -> void:
	grid_view.queue_redraw()

func _refresh_selection_highlights() -> void:
	_sync_unit_view_action_states()
	# Garrison phase: show deploy zone as the "move range" highlight.
	if engine.state.phase == BattleState.Phase.GARRISON:
		preview.set_move_range(engine.get_deploy_zone())
		preview.set_attack_targets([])
		return
	if selected_warden_id == -1 or engine.state.phase != BattleState.Phase.PLAYER_ACTION:
		preview.set_move_range([])
		preview.set_attack_targets([])
		return
	# Range display depends on whether an ability is armed:
	#   - "attack" armed: only attack targets (red).
	#   - "move"   armed: only move cells (green).
	#   - none    armed: both, so the player can click whatever they want.
	match _armed_ability_id:
		"attack":
			preview.set_move_range([])
			preview.set_attack_targets(engine.get_legal_attack_targets(selected_warden_id))
		"move":
			preview.set_move_range(engine.get_legal_moves(selected_warden_id))
			preview.set_attack_targets([])
		_:
			preview.set_move_range(engine.get_legal_moves(selected_warden_id))
			preview.set_attack_targets(engine.get_legal_attack_targets(selected_warden_id))

func _sync_unit_view_action_states() -> void:
	for u in engine.state.units:
		var v: UnitView = unit_views.get(u.id, null)
		if v != null:
			v.set_acted(u.has_acted, u.has_moved)
	_refresh_persistent_hud()

func _refresh_persistent_hud() -> void:
	if hud == null or engine == null or engine.state == null:
		return
	hud.set_squad_status(engine.state.wardens(), selected_warden_id)
	hud.set_reward_tasks(engine.state)

func _refresh_enemy_intent_overlay(rows_override: Array = [], preview_mode: bool = false) -> void:
	if _suppress_enemy_intents_until_events_done and rows_override.is_empty():
		preview.set_enemy_intents([])
		hud.set_enemy_action_stack([])
		return
	var rows: Array = rows_override if not rows_override.is_empty() else engine.get_enemy_intent_ui_state()
	var attack_rows: Array = []
	for row in rows:
		if row.get("has_attack", false) or row.get("status", BattleEngine.INTENT_STATUS_NO_ATTACK) == BattleEngine.INTENT_STATUS_REMOVED:
			attack_rows.append(row)
	preview.set_enemy_intents(attack_rows, preview_mode)
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
	preview.set_predicted_rifts(predicted)
	# Refresh execution-order labels on each enemy view.
	_refresh_enemy_order_labels(engine.enemy_execution_order())

func _refresh_info_panel() -> void:
	if _hover_cell == Vector2i(-1, -1):
		hud.hide_info_panel()
		_set_focused_enemy(-1)
		return
	# Priority 1: a unit at the hovered cell.
	var unit := engine.state.get_alive_unit_at(_hover_cell)
	if unit != null:
		_show_unit_info(unit)
		if unit.is_enemy():
			_set_focused_enemy(unit.id)
		else:
			_set_focused_enemy(-1)
		return
	# Priority 2: a tile feature.
	var tile: int = engine.state.grid.get_tile(_hover_cell)
	if tile == Grid.TileType.PILLAR:
		hud.show_info_panel("石柱", "  · 阻挡寻路 / 阻挡推动\n  · 可被攻击或撞击\n  · HP: 2 (后续阶段实装)")
		_set_focused_enemy(-1)
		return
	if tile == Grid.TileType.BUILDING:
		var hp: int = engine.state.grid.tile_hp.get(_hover_cell, Grid.DEFAULT_BUILDING_HP)
		var protected := "是" if engine.state.is_protected_target(_hover_cell) else "否"
		hud.show_info_panel(
			"建筑",
			"  · 保护目标: %s\n  · HP: %d\n  · 所有保护目标被毁则失败" % [protected, hp],
		)
		_set_focused_enemy(-1)
		return
	if tile == Grid.TileType.RUIN:
		hud.show_info_panel("废墟", "  · 建筑被毁后的残骸\n  · 可通行，不再提供保护")
		_set_focused_enemy(-1)
		return
	if tile == Grid.TileType.RIFT:
		var about_to_spawn: bool = false
		for entry in engine.state.pending_rift_spawns:
			if entry.pos == _hover_cell:
				about_to_spawn = true
				break
		var body := "  · 敌人出生点\n  · 单位站上可延迟 1 回合（但受 1 伤）"
		if about_to_spawn:
			body = "  · ⚠ 下回合将冒出敌人\n" + body
		hud.show_info_panel("地裂", body)
		_set_focused_enemy(-1)
		return
	# Otherwise: empty cell. Hide the panel.
	hud.hide_info_panel()
	_set_focused_enemy(-1)

func _show_unit_info(unit: Unit) -> void:
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
	elif _armed_ability_id == "move":
		subtitle = " ▸ 选择移动落点"
	var warden_data := {
		"name": "%s%s" % [warden.def.display_name, subtitle],
		"hp": warden.hp,
		"max_hp": warden.def.max_hp,
		"move": warden.def.move,
		"attack": _attack_kind_text(warden.def),
		"token": warden.def.token_texture,
	}
	var abilities: Array = []
	abilities.append({
		"id": "attack",
		"name": "攻击",
		"icon": "⚔",
		"desc": _attack_kind_text(warden.def),
		"active": not warden.has_acted,
		"is_default": true,
		"is_armed": _armed_ability_id == "attack",
	})
	abilities.append({
		"id": "move",
		"name": "移动",
		"icon": "✣",
		"desc": "%d 格" % warden.def.move,
		"active": not warden.has_moved and not warden.has_acted,
		"is_default": false,
		"is_armed": _armed_ability_id == "move",
	})
	abilities.append({
		"id": "relic",
		"name": "遗物",
		"icon": "✦",
		"desc": "未装备",
		"active": false,
		"is_default": false,
		"is_armed": false,
	})
	abilities.append({
		"id": "wait",
		"name": "待命",
		"icon": "⌛",
		"desc": "结束",
		"active": true,
		"is_default": false,
		"is_armed": false,
	})
	hud.show_ability_bar(warden_data, abilities)

func _refresh_enemy_order_labels(order_ids: Array[int]) -> void:
	# Clear badges first.
	for u in engine.state.units:
		var v: UnitView = unit_views.get(u.id, null)
		if v != null:
			v.set_order_badge(0)
	# Assign 1-indexed badges to alive enemies in actionable order.
	for i in range(order_ids.size()):
		var v: UnitView = unit_views.get(order_ids[i], null)
		if v != null:
			v.set_order_badge(i + 1)

func _refresh_hover_preview() -> void:
	preview.clear_preview()
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
			markers.append({"pos": end_pos, "kind": "fall"})
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
	preview.set_preview_markers(markers, paths)

# ---------- helpers exposed to children ----------

## F1 toggle: swaps the info panel between "player view" (HP/move/attack) and
## "debug view" (+ planning details, displacement state, damage preview).
func toggle_debug_mode() -> void:
	_debug_mode = not _debug_mode
	# If the info panel is open, re-render with new mode.
	_refresh_info_panel()
	# Also flash a brief HUD hint about the mode change.
	hud.set_help("调试模式：%s   ·   F1 切换" % ("开启" if _debug_mode else "关闭"))

func deselect() -> void:
	selected_warden_id = -1
	_armed_ability_id = ""
	_refresh_persistent_hud()
	_refresh_selection_highlights()
	preview.clear_preview()
	hud.hide_ability_bar()
	if not _defer_enemy_intent_refresh_until_events and not _animating:
		_refresh_enemy_intent_overlay()

func _full_rebuild() -> void:
	grid_view.bind(engine.state.grid)
	_rebuild_unit_views()
	deselect()
	_on_state_changed()

func _on_enemy_stack_hovered(enemy_id: int) -> void:
	_set_focused_enemy(enemy_id)

func _set_focused_enemy(enemy_id: int) -> void:
	if _focused_enemy_id == enemy_id:
		return
	_focused_enemy_id = enemy_id
	preview.set_focused_enemy(enemy_id)
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
	return u != null and u.is_enemy()
