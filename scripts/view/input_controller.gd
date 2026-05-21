class_name InputController extends Node
## Translates mouse + keyboard input into BattleActions. Owned by BattleScene.

signal warden_selected(unit_id: int)
signal action_requested(action: BattleAction)
signal hover_changed(cell: Vector2i, has_cell: bool)

var _battle: Node = null  # BattleScene

func bind(battle: Node) -> void:
	_battle = battle

func _unhandled_input(event: InputEvent) -> void:
	if _battle == null:
		return
	if event is InputEventMouseMotion:
		var local: Vector2 = _battle.grid_view.to_local(_battle.grid_view.get_global_mouse_position())
		var cell := GridView.pixel_to_cell(local)
		var inside := cell.x >= 0 and cell.x < Grid.SIZE and cell.y >= 0 and cell.y < Grid.SIZE
		hover_changed.emit(cell, inside)
		return
	if event.is_action_pressed("select"):
		var local: Vector2 = _battle.grid_view.to_local(_battle.grid_view.get_global_mouse_position())
		var cell := GridView.pixel_to_cell(local)
		if cell.x < 0 or cell.x >= Grid.SIZE or cell.y < 0 or cell.y >= Grid.SIZE:
			return
		_on_cell_clicked(cell)
	elif event.is_action_pressed("cancel"):
		_battle.deselect()
	elif event.is_action_pressed("undo"):
		action_requested.emit(BattleAction.undo())
	elif event.is_action_pressed("end_turn"):
		var state: BattleState = _battle.engine.state
		if state.phase == BattleState.Phase.GARRISON:
			# Only confirm if all wardens placed.
			if state.pending_warden_defs.is_empty():
				action_requested.emit(BattleAction.confirm_deploy())
		else:
			action_requested.emit(BattleAction.end_turn())
	elif event.is_action_pressed("debug_toggle"):
		_battle.toggle_debug_mode()

func _on_cell_clicked(cell: Vector2i) -> void:
	var state: BattleState = _battle.engine.state
	# Garrison phase: clicking a valid deploy cell places the next warden.
	if state.phase == BattleState.Phase.GARRISON:
		if _battle.engine.can_deploy_at(cell):
			action_requested.emit(BattleAction.deploy(cell))
		return
	var selected_id: int = _battle.selected_warden_id
	if selected_id != -1:
		var armed: String = _battle._armed_ability_id
		var attack_targets: Array[Vector2i] = _battle.engine.get_legal_attack_targets(selected_id)
		var move_cells: Array[Vector2i] = _battle.engine.get_legal_moves(selected_id)
		# Armed ability mode: only the matching action type is valid.
		if armed == "attack":
			if cell in attack_targets:
				action_requested.emit(BattleAction.attack(selected_id, cell))
				return
			# Click outside attack range while armed -> cancel arming (let the
			# normal selection logic below run).
		elif armed == "move":
			if cell in move_cells:
				action_requested.emit(BattleAction.move(selected_id, cell))
				return
		else:
			# No ability armed: click an enemy in range -> attack; otherwise
			# click a move cell -> move. This keeps the fast "click target"
			# flow alongside the explicit "select skill -> click target" flow.
			if cell in attack_targets:
				action_requested.emit(BattleAction.attack(selected_id, cell))
				return
			if cell in move_cells:
				action_requested.emit(BattleAction.move(selected_id, cell))
				return
	# Click on another warden -> re-select that one (cancels armed mode via _on_warden_selected).
	var unit := state.get_alive_unit_at(cell)
	if unit != null and unit.is_warden() and not unit.has_acted and state.phase == BattleState.Phase.PLAYER_ACTION:
		warden_selected.emit(unit.id)
	else:
		_battle.deselect()
