class_name HUD extends CanvasLayer
## Top-bar status + end-turn / undo controls.

signal end_turn_pressed
signal undo_pressed
signal confirm_deploy_pressed
signal ability_selected(ability_id: String)

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

func _ready() -> void:
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	undo_button.pressed.connect(func(): undo_pressed.emit())
	confirm_deploy_button.pressed.connect(func(): confirm_deploy_pressed.emit())
	banner.visible = false
	confirm_deploy_button.visible = false

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

func show_outcome(outcome: int) -> void:
	if outcome == BattleState.Outcome.VICTORY:
		banner.text = "胜 利"
		banner.modulate = Color(0.7, 1.0, 0.8)
	elif outcome == BattleState.Outcome.DEFEAT:
		banner.text = "失 败"
		banner.modulate = Color(1.0, 0.5, 0.5)
	banner.visible = true
