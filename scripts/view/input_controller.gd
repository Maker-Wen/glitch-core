class_name InputController extends Node
## Translates mouse + keyboard input into BattleActions. Owned by BattleScene.

signal warden_selected(unit_id: int)
signal action_requested(action: BattleAction)
signal hover_changed(cell: Vector2i, has_cell: bool)

var _battle: Node = null  # BattleScene
var _left_mouse_down: bool = false
var _right_mouse_down: bool = false
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _hover_inside: bool = false

func bind(battle: Node) -> void:
	_battle = battle

func _process(_delta: float) -> void:
	if _battle == null:
		return
	var cell := _board_cell_under_mouse()
	var inside := _cell_in_bounds(cell)
	if cell != _hover_cell or inside != _hover_inside:
		_hover_cell = cell
		_hover_inside = inside
		hover_changed.emit(cell, inside)

	var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if left_down and not _left_mouse_down and inside:
		_on_cell_clicked(cell)
	_left_mouse_down = left_down

	var right_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if right_down and not _right_mouse_down:
		_battle.deselect()
	_right_mouse_down = right_down

func _input(event: InputEvent) -> void:
	if _battle == null:
		return
	if event is InputEventMouse:
		return
	_handle_global_action(event)

func handle_board_input(event: InputEvent, local_pos: Vector2) -> void:
	if _battle == null:
		return
	var cell := Vector2i(-1, -1)
	if _battle.has_method("board_cell_from_local"):
		cell = _battle.board_cell_from_local(local_pos)
	var inside := _cell_in_bounds(cell)
	if event is InputEventMouseMotion:
		hover_changed.emit(cell, inside)
		return
	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if inside:
			_on_cell_clicked(cell)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_battle.deselect()

func _handle_global_action(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
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

func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < Grid.SIZE and cell.y >= 0 and cell.y < Grid.SIZE

func _board_cell_under_mouse() -> Vector2i:
	if _battle.has_method("board_cell_under_mouse"):
		return _battle.board_cell_under_mouse()
	return Vector2i(-1, -1)

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
