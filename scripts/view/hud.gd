class_name HUD extends CanvasLayer
## Top-bar status + end-turn / undo controls.

signal end_turn_pressed
signal undo_pressed
signal confirm_deploy_pressed
signal ability_selected(ability_id: String)
signal enemy_stack_hovered(enemy_id: int)

@onready var round_label: Label = $Root/TopRow/RoundLabel
@onready var phase_label: Label = $Root/TopRow/PhaseLabel
@onready var help_label: Label = $Root/HelpLabel
@onready var end_turn_button: Button = $Root/TopRow/EndTurnButton
@onready var undo_button: Button = $Root/TopRow/UndoButton
@onready var confirm_deploy_button: Button = $Root/TopRow/ConfirmDeployButton
@onready var banner: Label = $Root/Banner
@onready var info_panel_bg: ColorRect = $Root/InfoPanelBg
@onready var info_title: Label = $Root/InfoPanelBg/InfoTitle
@onready var info_body: Label = $Root/InfoPanelBg/InfoBody
@onready var ability_bar_bg: ColorRect = $Root/AbilityBarBg
@onready var ability_title: Label = $Root/AbilityBarBg/AbilityTitle
@onready var ability_row: HBoxContainer = $Root/AbilityBarBg/AbilityRow
@onready var enemy_stack_bg: ColorRect = $Root/EnemyStackBg
@onready var enemy_stack_title: Label = $Root/EnemyStackBg/EnemyStackTitle
@onready var enemy_stack_mode: Label = $Root/EnemyStackBg/EnemyStackMode
@onready var enemy_stack_row: VBoxContainer = $Root/EnemyStackBg/EnemyStackRow

var _enemy_stack_rows: Array = []
var _enemy_stack_signature: String = ""
var _enemy_stack_preview_mode: bool = false
var _focused_enemy_id: int = -1
var _executing_enemy_id: int = -1
var _enemy_row_controls: Dictionary = {}

func _ready() -> void:
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	undo_button.pressed.connect(func(): undo_pressed.emit())
	confirm_deploy_button.pressed.connect(func(): confirm_deploy_pressed.emit())
	banner.visible = false
	confirm_deploy_button.visible = false
	if enemy_stack_bg != null:
		enemy_stack_bg.visible = false

func update_status(state: BattleState) -> void:
	if state.phase == BattleState.Phase.GARRISON:
		round_label.text = "布防阶段"
	else:
		round_label.text = "第 %d / %d 轮" % [state.current_round, state.max_rounds]
	var phase_name: String = "?"
	match state.phase:
		BattleState.Phase.GARRISON:
			var remaining: int = state.pending_warden_defs.size()
			if remaining > 0:
				var next_def: UnitDef = state.pending_warden_defs[0]
				phase_name = "请部署：%s（还剩 %d 个）" % [next_def.display_name, remaining]
			else:
				phase_name = "部署完成，按「确认部署」"
		BattleState.Phase.ENEMY_WARNING: phase_name = "敌方预警"
		BattleState.Phase.PLAYER_ACTION: phase_name = "玩家回合"
		BattleState.Phase.ENEMY_EXECUTE: phase_name = "敌方执行"
		BattleState.Phase.BATTLE_END: phase_name = "战斗结束"
	phase_label.text = phase_name
	end_turn_button.disabled = state.phase != BattleState.Phase.PLAYER_ACTION
	end_turn_button.visible = state.phase != BattleState.Phase.GARRISON
	# Confirm-deploy is visible only in garrison, enabled when all wardens placed.
	confirm_deploy_button.visible = state.phase == BattleState.Phase.GARRISON
	confirm_deploy_button.disabled = not state.pending_warden_defs.is_empty()
	# Undo is always available unless battle is over.
	undo_button.disabled = state.phase == BattleState.Phase.BATTLE_END

func set_help(text: String) -> void:
	help_label.text = text

## Show / hide / update the side info panel (ITB-style).
##   title: header string (unit name + faction badge)
##   body:  multi-line description (planned action, damage, etc.)
func show_info_panel(title: String, body: String) -> void:
	if info_panel_bg == null:
		return
	info_panel_bg.visible = true
	info_title.text = title
	info_body.text = body

func hide_info_panel() -> void:
	if info_panel_bg == null:
		return
	info_panel_bg.visible = false

## Show / hide the ability bar shown when a warden is selected.
##   warden_label: e.g. "赏金猎人 — 选择行动"
##   abilities:    Array of {id, name, desc, active, is_default, is_armed}
##     is_armed=true: ability is currently in "targeting mode" -- highlight the button.
func show_ability_bar(warden_label: String, abilities: Array) -> void:
	if ability_bar_bg == null:
		return
	ability_bar_bg.visible = true
	ability_title.text = warden_label
	# Clear previous buttons
	for child in ability_row.get_children():
		child.queue_free()
	for ab in abilities:
		var slot := VBoxContainer.new()
		slot.custom_minimum_size = Vector2(140, 48)
		ability_row.add_child(slot)
		var btn := Button.new()
		btn.text = ab.get("name", "?")
		btn.custom_minimum_size = Vector2(140, 28)
		btn.disabled = not ab.get("active", true)
		# Visual states:
		#  - armed (currently selected for targeting): bright amber
		#  - default attack (suggestion to click first): soft green
		#  - other: neutral
		if ab.get("is_armed", false):
			btn.modulate = Color(1.0, 0.85, 0.4, 1)
		elif ab.get("is_default", false):
			btn.modulate = Color(0.75, 1.0, 0.8, 1)
		# Capture ability id for the signal.
		var ab_id: String = ab.get("id", "")
		if not btn.disabled and ab_id != "":
			btn.pressed.connect(func(): ability_selected.emit(ab_id))
		slot.add_child(btn)
		var desc := Label.new()
		desc.text = ab.get("desc", "")
		desc.add_theme_font_size_override("font_size", 11)
		desc.modulate = Color(0.78, 0.78, 0.85, 1)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(desc)

func hide_ability_bar() -> void:
	if ability_bar_bg == null:
		return
	ability_bar_bg.visible = false

func set_enemy_action_stack(rows: Array, preview_mode: bool = false, focused_enemy_id: int = -1, executing_enemy_id: int = -1) -> void:
	if enemy_stack_bg == null:
		return
	if rows.is_empty():
		_enemy_stack_rows.clear()
		_enemy_stack_signature = ""
		_enemy_row_controls.clear()
		for child in enemy_stack_row.get_children():
			child.queue_free()
		enemy_stack_bg.visible = false
		return
	var signature := _enemy_stack_signature_for(rows, preview_mode)
	_enemy_stack_preview_mode = preview_mode
	_focused_enemy_id = focused_enemy_id
	_executing_enemy_id = executing_enemy_id
	if signature != _enemy_stack_signature:
		_enemy_stack_rows = rows.duplicate(true)
		_enemy_stack_signature = signature
		_rebuild_enemy_stack_rows()
	enemy_stack_bg.visible = not rows.is_empty()
	enemy_stack_mode.text = "预演后" if preview_mode else "锁定"
	_update_enemy_stack_styles()

func set_enemy_stack_focus(enemy_id: int) -> void:
	if _focused_enemy_id == enemy_id:
		return
	_focused_enemy_id = enemy_id
	_update_enemy_stack_styles()

func set_enemy_stack_executing(enemy_id: int) -> void:
	if _executing_enemy_id == enemy_id:
		return
	_executing_enemy_id = enemy_id
	_update_enemy_stack_styles()

func _rebuild_enemy_stack_rows() -> void:
	_enemy_row_controls.clear()
	for child in enemy_stack_row.get_children():
		child.queue_free()
	for row in _enemy_stack_rows:
		var enemy_id: int = row.get("enemy_id", -1)
		var panel := ColorRect.new()
		panel.name = "EnemyIntent_%d" % enemy_id
		panel.custom_minimum_size = Vector2(250, 54)
		panel.color = Color(0.11, 0.09, 0.13, 0.90)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_entered.connect(func(): enemy_stack_hovered.emit(enemy_id))
		panel.mouse_exited.connect(func(): enemy_stack_hovered.emit(-1))
		enemy_stack_row.add_child(panel)

		var border := ReferenceRect.new()
		border.anchor_right = 1.0
		border.anchor_bottom = 1.0
		border.offset_right = 0.0
		border.offset_bottom = 0.0
		border.border_width = 2.0
		border.editor_only = false
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(border)

		var order_label := Label.new()
		order_label.offset_left = 8.0
		order_label.offset_top = 7.0
		order_label.offset_right = 36.0
		order_label.offset_bottom = 34.0
		order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		order_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		order_label.add_theme_font_size_override("font_size", 18)
		order_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(order_label)

		var name_label := Label.new()
		name_label.offset_left = 42.0
		name_label.offset_top = 6.0
		name_label.offset_right = 170.0
		name_label.offset_bottom = 27.0
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(name_label)

		var status_label := Label.new()
		status_label.offset_left = 172.0
		status_label.offset_top = 6.0
		status_label.offset_right = 242.0
		status_label.offset_bottom = 27.0
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_label.add_theme_font_size_override("font_size", 14)
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(status_label)

		var summary_label := Label.new()
		summary_label.offset_left = 42.0
		summary_label.offset_top = 29.0
		summary_label.offset_right = 242.0
		summary_label.offset_bottom = 50.0
		summary_label.add_theme_font_size_override("font_size", 12)
		summary_label.modulate = Color(0.78, 0.78, 0.86, 1)
		summary_label.clip_text = true
		summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(summary_label)

		order_label.text = str(row.get("order", "?"))
		name_label.text = row.get("enemy_name", "敌人")
		status_label.text = _enemy_status_text(row.get("status", BattleEngine.INTENT_STATUS_NO_ATTACK))
		summary_label.text = _enemy_intent_summary(row)
		_enemy_row_controls[enemy_id] = {
			"panel": panel,
			"border": border,
			"order": order_label,
			"name": name_label,
			"status": status_label,
			"summary": summary_label,
		}

func _update_enemy_stack_styles() -> void:
	for row in _enemy_stack_rows:
		var enemy_id: int = row.get("enemy_id", -1)
		var controls: Dictionary = _enemy_row_controls.get(enemy_id, {})
		if controls.is_empty():
			continue
		var panel: ColorRect = controls.panel
		var border: ReferenceRect = controls.border
		var order_label: Label = controls.order
		var name_label: Label = controls.name
		var status_label: Label = controls.status
		var summary_label: Label = controls.summary
		var status: String = row.get("status", BattleEngine.INTENT_STATUS_NO_ATTACK)
		var is_focused := _focused_enemy_id == enemy_id
		var is_dimmed := _focused_enemy_id != -1 and not is_focused
		var is_executing := _executing_enemy_id == enemy_id
		var palette := _enemy_stack_palette(status)
		var base_panel: Color = palette.panel
		var border_color: Color = palette.border
		var status_color: Color = palette.status
		if is_executing:
			base_panel = Color(0.20, 0.13, 0.08, 0.96)
			border_color = Color(1.0, 0.82, 0.34, 1.0)
		elif is_focused:
			base_panel = base_panel.lightened(0.12)
			border_color = border_color.lightened(0.20)
		elif is_dimmed:
			base_panel.a = 0.55
			border_color.a = 0.38
		if _enemy_stack_preview_mode:
			border_color = border_color.lightened(0.10)
		panel.color = base_panel
		border.border_color = border_color
		order_label.modulate = Color(1.0, 0.90, 0.56, 1.0 if not is_dimmed else 0.60)
		name_label.modulate = Color(0.95, 0.92, 0.88, 1.0 if not is_dimmed else 0.58)
		status_label.modulate = status_color if not is_dimmed else Color(status_color.r, status_color.g, status_color.b, 0.58)
		summary_label.modulate = Color(0.78, 0.78, 0.86, 1.0 if not is_dimmed else 0.50)

func _enemy_stack_signature_for(rows: Array, preview_mode: bool) -> String:
	var parts: Array[String] = [str(preview_mode)]
	for row in rows:
		parts.append("%s:%s:%s:%s:%s:%s:%s" % [
			row.get("enemy_id", -1),
			row.get("order", 0),
			row.get("enemy_name", ""),
			row.get("status", ""),
			row.get("target_kind", ""),
			row.get("target_id", -1),
			row.get("target_hp", 0),
		])
	return "|".join(parts)

func _enemy_intent_summary(row: Dictionary) -> String:
	var status: String = row.get("status", BattleEngine.INTENT_STATUS_NO_ATTACK)
	if status == BattleEngine.INTENT_STATUS_REMOVED:
		return "已被击杀 / 推出，不再攻击"
	if status == BattleEngine.INTENT_STATUS_NO_ATTACK:
		return "本轮只移动，不攻击"
	var damage: int = row.get("target_damage", 0)
	var target_kind: String = row.get("target_kind", BattleEngine.TARGET_KIND_NONE)
	var target_name: String = row.get("target_name", "")
	if target_kind == BattleEngine.TARGET_KIND_BUILDING:
		return "攻击建筑，预计 %d 伤" % damage
	if target_kind == BattleEngine.TARGET_KIND_UNIT:
		return "攻击 %s，预计 %d 伤" % [target_name, damage]
	return "攻击原锁定格，当前会落空"

func _enemy_status_text(status: String) -> String:
	match status:
		BattleEngine.INTENT_STATUS_HIT:
			return "命中"
		BattleEngine.INTENT_STATUS_MISS:
			return "落空"
		BattleEngine.INTENT_STATUS_REMOVED:
			return "已移除"
		_:
			return "无攻击"

func _enemy_stack_palette(status: String) -> Dictionary:
	match status:
		BattleEngine.INTENT_STATUS_HIT:
			return {
				"panel": Color(0.16, 0.07, 0.08, 0.92),
				"border": Color(0.92, 0.28, 0.34, 0.90),
				"status": Color(1.0, 0.45, 0.46, 1.0),
			}
		BattleEngine.INTENT_STATUS_MISS:
			return {
				"panel": Color(0.10, 0.12, 0.15, 0.82),
				"border": Color(0.52, 0.62, 0.72, 0.72),
				"status": Color(0.66, 0.75, 0.84, 1.0),
			}
		BattleEngine.INTENT_STATUS_REMOVED:
			return {
				"panel": Color(0.08, 0.08, 0.09, 0.72),
				"border": Color(0.44, 0.44, 0.48, 0.58),
				"status": Color(0.70, 0.70, 0.74, 1.0),
			}
		_:
			return {
				"panel": Color(0.09, 0.08, 0.11, 0.70),
				"border": Color(0.36, 0.34, 0.42, 0.50),
				"status": Color(0.72, 0.68, 0.78, 1.0),
			}

func show_outcome(outcome: int) -> void:
	if outcome == BattleState.Outcome.VICTORY:
		banner.text = "胜 利"
		banner.modulate = Color(0.7, 1.0, 0.8)
	elif outcome == BattleState.Outcome.DEFEAT:
		banner.text = "失 败"
		banner.modulate = Color(1.0, 0.5, 0.5)
	banner.visible = true
