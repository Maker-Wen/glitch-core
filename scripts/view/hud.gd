class_name HUD extends CanvasLayer
## Top-bar status + end-turn / undo controls.

signal end_turn_pressed
signal undo_pressed
signal confirm_deploy_pressed
signal ability_selected(ability_id: String)
signal enemy_stack_hovered(enemy_id: int)

const ENEMY_STACK_ROW_SIZE := Vector2(284, 46)
const ABILITY_SLOT_SIZE := Vector2(58, 76)
const SQUAD_CARD_SIZE := Vector2(170, 74)
const ITEM_SLOT_SIZE := Vector2(38, 48)
const UI_BG := Color(0.025, 0.027, 0.034, 0.96)
const UI_BG_RAISED := Color(0.045, 0.047, 0.056, 0.96)
const UI_BG_INSET := Color(0.014, 0.016, 0.020, 0.92)
const UI_BORDER := Color(0.42, 0.34, 0.24, 0.54)
const UI_BORDER_SOFT := Color(0.24, 0.29, 0.34, 0.46)
const UI_AMBER := Color(0.95, 0.64, 0.24, 1.0)
const UI_GOLD_TEXT := Color(1.0, 0.80, 0.44, 1.0)
const UI_TEXT := Color(0.90, 0.90, 0.93, 1.0)
const UI_TEXT_DIM := Color(0.60, 0.65, 0.70, 1.0)
const UI_DANGER := Color(0.92, 0.24, 0.30, 1.0)
const UI_SAFE := Color(0.36, 0.82, 0.96, 1.0)

const ICON_ATTACK := preload("res://art/ui/battle_hud/icons/attack_icon_gpt-image-2.png")
const ICON_MOVE := preload("res://art/ui/battle_hud/icons/move_icon_gpt-image-2.png")
const ICON_RELIC := preload("res://art/ui/battle_hud/icons/relic_icon_gpt-image-2.png")
const ICON_WAIT := preload("res://art/ui/battle_hud/icons/wait_icon_gpt-image-2.png")
const BattleStatusPresenter := preload("res://scripts/view/battle_status_presenter.gd")

@onready var round_label: Label = $Root/TopRow/RoundLabel
@onready var phase_label: Label = $Root/TopRow/PhaseLabel
@onready var sanctuary_label: Label = $Root/TopRow/SanctuaryLabel
@onready var objective_label: Label = $Root/TopRow/ObjectiveLabel
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
@onready var ability_portrait: TextureRect = $Root/AbilityBarBg/AbilityPortraitFrame/AbilityPortrait
@onready var ability_hp_label: Label = $Root/AbilityBarBg/AbilityHpLabel
@onready var ability_info_label: Label = $Root/AbilityBarBg/AbilityInfoLabel
@onready var ability_row: HBoxContainer = $Root/AbilityBarBg/AbilityRow
@onready var item_slot_row: HBoxContainer = $Root/AbilityBarBg/ItemSlotRow
@onready var squad_strip_bg: ColorRect = $Root/SquadStripBg
@onready var squad_strip_row: BoxContainer = $Root/SquadStripBg/SquadStripRow
@onready var reward_panel_bg: ColorRect = $Root/RewardPanelBg
@onready var reward_task_row: VBoxContainer = $Root/RewardPanelBg/RewardTaskRow
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
var sanctuary_integrity: int = 7
var sanctuary_integrity_max: int = 7

func _ready() -> void:
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	undo_button.pressed.connect(func(): undo_pressed.emit())
	confirm_deploy_button.pressed.connect(func(): confirm_deploy_pressed.emit())
	banner.visible = false
	confirm_deploy_button.visible = false
	if enemy_stack_bg != null:
		enemy_stack_bg.visible = false
	_install_static_ui_styles()
	_build_item_slots()

func update_status(state: BattleState) -> void:
	if state.phase == BattleState.Phase.GARRISON:
		round_label.text = "布防阶段"
	else:
		round_label.text = "第 %d/%d 轮" % [state.current_round, state.max_rounds]
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
	sanctuary_label.text = "守护值 %d/%d" % [sanctuary_integrity, sanctuary_integrity_max]
	set_battle_status_summary(state)
	end_turn_button.disabled = state.phase != BattleState.Phase.PLAYER_ACTION
	end_turn_button.visible = state.phase != BattleState.Phase.GARRISON
	# Confirm-deploy is visible only in garrison, enabled when all wardens placed.
	confirm_deploy_button.visible = state.phase == BattleState.Phase.GARRISON
	confirm_deploy_button.disabled = not state.pending_warden_defs.is_empty()
	# Undo is always available unless battle is over.
	undo_button.disabled = state.phase == BattleState.Phase.BATTLE_END

func set_battle_status_summary(state: BattleState) -> void:
	if objective_label == null or state == null:
		return
	objective_label.text = _battle_status_summary_text(state)

func set_boss_status(state: BattleState) -> void:
	set_battle_status_summary(state)

func _battle_status_summary_text(state: BattleState) -> String:
	return BattleStatusPresenter.battle_status_summary_text(state)

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
##   warden_data: e.g. {name, hp, max_hp, move, attack, token}
##   abilities:    Array of {id, name, desc, active, is_default, is_armed}
##     is_armed=true: ability is currently in "targeting mode" -- highlight the button.
func show_ability_bar(warden_data, abilities: Array) -> void:
	if ability_bar_bg == null:
		return
	ability_bar_bg.visible = true
	var data: Dictionary = warden_data if warden_data is Dictionary else {"name": str(warden_data)}
	ability_title.text = data.get("name", "守卫者")
	ability_hp_label.text = "♥ %d/%d" % [int(data.get("hp", 0)), int(data.get("max_hp", 0))]
	ability_info_label.text = "移动 %d   %s" % [int(data.get("move", 0)), data.get("attack", "")]
	ability_portrait.texture = data.get("token", null)
	# Clear previous buttons
	_clear_children(ability_row)
	for ab in abilities:
		var slot := ColorRect.new()
		slot.custom_minimum_size = ABILITY_SLOT_SIZE
		ability_row.add_child(slot)
		var slot_border := _apply_panel_frame(slot, UI_BG_RAISED, UI_BORDER_SOFT, 4, 1)
		_add_top_sheen(slot, Color(1.0, 0.78, 0.42, 0.08))

		var btn := Button.new()
		btn.anchor_right = 1.0
		btn.anchor_bottom = 1.0
		btn.offset_left = 0.0
		btn.offset_top = 0.0
		btn.offset_right = 0.0
		btn.offset_bottom = 0.0
		btn.flat = true
		btn.text = ""
		btn.custom_minimum_size = ABILITY_SLOT_SIZE
		btn.disabled = not ab.get("active", true)
		slot.add_child(btn)

		var icon := TextureRect.new()
		icon.offset_left = 0.0
		icon.offset_top = 5.0
		icon.offset_right = ABILITY_SLOT_SIZE.x
		icon.offset_bottom = 29.0
		icon.texture = _ability_icon_texture(ab.get("id", ""))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		var name := Label.new()
		name.offset_left = 4.0
		name.offset_top = 28.0
		name.offset_right = ABILITY_SLOT_SIZE.x - 4.0
		name.offset_bottom = 47.0
		name.text = ab.get("name", "?")
		name.add_theme_font_size_override("font_size", 15)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.clip_text = true
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(name)

		var desc := Label.new()
		desc.offset_left = 4.0
		desc.offset_top = 52.0
		desc.offset_right = ABILITY_SLOT_SIZE.x - 4.0
		desc.offset_bottom = 70.0
		desc.text = _short_ability_desc(ab.get("desc", ""))
		desc.add_theme_font_size_override("font_size", 10)
		desc.modulate = UI_TEXT_DIM
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		desc.clip_text = true
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(desc)
		# Visual states:
		#  - armed (currently selected for targeting): bright amber
		#  - default attack (suggestion to click first): soft green
		#  - other: neutral
		if ab.get("is_armed", false):
			icon.modulate = Color(1.0, 0.88, 0.48, 1)
			name.modulate = Color(1.0, 0.88, 0.48, 1)
			slot.color = Color(0.11, 0.07, 0.035, 0.98)
			slot_border.border_color = Color(1.0, 0.75, 0.28, 1.0)
		elif ab.get("is_default", false):
			icon.modulate = Color(0.78, 1.0, 0.86, 1)
			name.modulate = Color(0.78, 1.0, 0.86, 1)
			slot.color = Color(0.035, 0.075, 0.060, 0.98)
			slot_border.border_color = Color(0.36, 0.74, 0.56, 0.82)
		else:
			slot.color = UI_BG_RAISED
			icon.modulate = Color(0.84, 0.84, 0.88, 1)
			name.modulate = Color(0.84, 0.84, 0.88, 1)
			slot_border.border_color = UI_BORDER_SOFT
		if btn.disabled:
			slot.color = Color(0.030, 0.032, 0.038, 0.82)
			icon.modulate = Color(0.38, 0.38, 0.42, 0.82)
			name.modulate = Color(0.38, 0.38, 0.42, 0.82)
			desc.modulate = Color(0.32, 0.34, 0.38, 0.82)
			slot_border.border_color = Color(0.18, 0.20, 0.23, 0.62)
		# Capture ability id for the signal.
		var ab_id: String = ab.get("id", "")
		if not btn.disabled and ab_id != "":
			btn.pressed.connect(func(): ability_selected.emit(ab_id))
		slot_border.move_to_front()
	_build_item_slots()

func hide_ability_bar() -> void:
	if ability_bar_bg == null:
		return
	ability_bar_bg.visible = false
	ability_portrait.texture = null

func set_sanctuary(value: int, max_value: int) -> void:
	sanctuary_integrity = value
	sanctuary_integrity_max = max_value
	if sanctuary_label != null:
		sanctuary_label.text = "守护值 %d/%d" % [sanctuary_integrity, sanctuary_integrity_max]

func set_squad_status(wardens: Array, selected_id: int = -1) -> void:
	if squad_strip_bg == null:
		return
	_clear_children(squad_strip_row)
	if wardens.is_empty():
		squad_strip_bg.visible = false
		return
	squad_strip_bg.visible = true
	for raw in wardens:
		var unit: Unit = raw
		var card := ColorRect.new()
		card.custom_minimum_size = SQUAD_CARD_SIZE
		squad_strip_row.add_child(card)
		var selected := unit.id == selected_id
		var border := _apply_panel_frame(
			card,
			Color(0.08, 0.058, 0.035, 0.97) if selected else UI_BG_RAISED,
			Color(1.0, 0.65, 0.24, 0.96) if selected else UI_BORDER_SOFT,
			4,
			2 if selected else 1,
		)
		_add_top_sheen(card, Color(1.0, 0.74, 0.30, 0.12 if selected else 0.05))

		var portrait := TextureRect.new()
		portrait.offset_left = 7.0
		portrait.offset_top = 5.0
		portrait.offset_right = 61.0
		portrait.offset_bottom = 61.0
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = unit.def.token_texture if unit.def != null else null
		portrait.modulate = Color(0.42, 0.42, 0.42, 0.88) if unit.has_acted else Color.WHITE
		card.add_child(portrait)

		var name := Label.new()
		name.offset_left = 68.0
		name.offset_top = 9.0
		name.offset_right = SQUAD_CARD_SIZE.x - 10.0
		name.offset_bottom = 33.0
		name.add_theme_font_size_override("font_size", 16)
		name.clip_text = true
		name.modulate = Color(1.0, 0.82, 0.48, 1.0) if selected else UI_TEXT
		name.text = unit.def.display_name if unit.def != null else "守卫者"
		card.add_child(name)

		var state := Label.new()
		state.offset_left = 68.0
		state.offset_top = 34.0
		state.offset_right = SQUAD_CARD_SIZE.x - 10.0
		state.offset_bottom = 54.0
		state.add_theme_font_size_override("font_size", 12)
		state.modulate = UI_TEXT_DIM
		state.text = "已行动" if unit.has_acted else "已移动" if unit.has_moved else "待命"
		card.add_child(state)

		var hp := Label.new()
		hp.offset_left = 68.0
		hp.offset_top = 55.0
		hp.offset_right = SQUAD_CARD_SIZE.x - 10.0
		hp.offset_bottom = 72.0
		hp.add_theme_font_size_override("font_size", 12)
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hp.modulate = Color(1.0, 0.42, 0.38, 1.0) if unit.hp <= 1 else Color(1.0, 0.72, 0.58, 1.0)
		hp.text = _hp_pips(unit.hp, unit.def.max_hp if unit.def != null else unit.hp)
		card.add_child(hp)

		var state_bar := ColorRect.new()
		state_bar.offset_left = 8.0
		state_bar.offset_top = 68.0
		state_bar.offset_right = SQUAD_CARD_SIZE.x - 8.0
		state_bar.offset_bottom = 71.0
		if unit.has_acted:
			state_bar.color = Color(0.42, 0.42, 0.45, 0.75)
		elif unit.has_moved:
			state_bar.color = Color(0.78, 0.58, 0.26, 0.85)
		else:
			state_bar.color = Color(0.36, 0.82, 1.0, 0.85)
		card.add_child(state_bar)
		border.move_to_front()

func set_reward_tasks(state: BattleState) -> void:
	if reward_panel_bg == null:
		return
	_clear_children(reward_task_row)
	if state.reward_tasks.is_empty():
		reward_panel_bg.visible = false
		return
	reward_panel_bg.visible = true
	for task in state.reward_tasks:
		var row := ColorRect.new()
		row.custom_minimum_size = Vector2(604, 42)
		reward_task_row.add_child(row)
		_apply_panel_frame(row, Color(0.036, 0.038, 0.046, 0.90), Color(0.20, 0.24, 0.28, 0.76), 3, 1)

		var mark := Label.new()
		mark.offset_left = 6.0
		mark.offset_top = 7.0
		mark.offset_right = 28.0
		mark.offset_bottom = 31.0
		mark.add_theme_font_size_override("font_size", 16)
		var failed := bool(state.reward_failed.get(task, false))
		var completed := bool(state.reward_completed.get(task, false))
		mark.text = "✓" if completed else ("×" if failed else "◆")
		mark.modulate = Color(0.55, 0.95, 0.60, 1.0) if completed else (Color(1.0, 0.35, 0.35, 1.0) if failed else Color(1.0, 0.78, 0.38, 1.0))
		row.add_child(mark)

		var label := Label.new()
		label.offset_left = 32.0
		label.offset_top = 5.0
		label.offset_right = 596.0
		label.offset_bottom = 35.0
		label.add_theme_font_size_override("font_size", 12)
		label.modulate = Color(0.95, 0.88, 0.74, 0.62 if failed else 1.0)
		label.text = _reward_task_text(task, state)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)

func _reward_task_text(task: StringName, state: BattleState) -> String:
	match task:
		BattleState.REWARD_PERFECT_DEFENSE:
			return "完美防守：建筑未毁"
		BattleState.REWARD_TERMINAL_CLEAR:
			return "终局清场：剩余 %d" % int(state.reward_progress.get(task, state.enemies().size()))
		BattleState.REWARD_PHYSICAL_KILLS_3:
			return "物理击杀：%d / 3" % int(state.reward_progress.get(task, 0))
	return str(task)

func _hp_pips(hp: int, max_hp: int) -> String:
	var parts: Array[String] = []
	for i in range(max_hp):
		parts.append("♥" if i < hp else "♡")
	return "".join(parts)

func _short_ability_desc(desc: String) -> String:
	if desc.find("远程") != -1:
		return "远程"
	if desc.find("近战") != -1:
		return "近战"
	if desc.find("未装备") != -1:
		return "未装备"
	if desc.find("结束") != -1:
		return "结束"
	return desc

func _ability_icon_texture(ability_id: String) -> Texture2D:
	match ability_id:
		"attack":
			return ICON_ATTACK
		"move":
			return ICON_MOVE
		"relic":
			return ICON_RELIC
		"wait":
			return ICON_WAIT
	return null

func _build_item_slots() -> void:
	if item_slot_row == null:
		return
	_clear_children(item_slot_row)
	var slots := [
		{"icon": "♜", "count": "1", "active": true},
		{"icon": "✚", "count": "1", "active": true},
		{"icon": "◌", "count": "", "active": false},
	]
	for slot_data in slots:
		var slot := ColorRect.new()
		slot.custom_minimum_size = ITEM_SLOT_SIZE
		item_slot_row.add_child(slot)
		_apply_panel_frame(
			slot,
			Color(0.065, 0.052, 0.035, 0.96) if slot_data.active else Color(0.030, 0.032, 0.038, 0.82),
			Color(0.72, 0.52, 0.28, 0.82) if slot_data.active else Color(0.22, 0.24, 0.28, 0.58),
			4,
			1,
		)

		var icon := Label.new()
		icon.offset_left = 0.0
		icon.offset_top = 5.0
		icon.offset_right = ITEM_SLOT_SIZE.x
		icon.offset_bottom = 32.0
		icon.add_theme_font_size_override("font_size", 22)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.modulate = Color(1.0, 0.80, 0.48, 1.0) if slot_data.active else Color(0.38, 0.38, 0.42, 1.0)
		icon.text = slot_data.icon
		slot.add_child(icon)

		var count := Label.new()
		count.offset_left = 0.0
		count.offset_top = 31.0
		count.offset_right = ITEM_SLOT_SIZE.x - 5.0
		count.offset_bottom = 46.0
		count.add_theme_font_size_override("font_size", 11)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.modulate = Color(0.92, 0.86, 0.74, 1.0)
		count.text = slot_data.count
		slot.add_child(count)

func set_enemy_action_stack(rows: Array, preview_mode: bool = false, focused_enemy_id: int = -1, executing_enemy_id: int = -1) -> void:
	if enemy_stack_bg == null:
		return
	if rows.is_empty():
		_enemy_stack_rows.clear()
		_enemy_stack_signature = ""
		_enemy_row_controls.clear()
		_clear_children(enemy_stack_row)
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
	enemy_stack_mode.modulate = Color(1.0, 0.78, 0.40, 1.0) if preview_mode else Color(0.72, 0.82, 1.0, 1.0)
	if enemy_stack_title != null:
		enemy_stack_title.modulate = Color(1.0, 0.82, 0.48, 1.0) if not preview_mode else Color(1.0, 0.92, 0.64, 1.0)
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
	_clear_children(enemy_stack_row)
	for row in _enemy_stack_rows:
		var enemy_id: int = row.get("enemy_id", -1)
		var panel := ColorRect.new()
		panel.name = "EnemyIntent_%d" % enemy_id
		panel.custom_minimum_size = ENEMY_STACK_ROW_SIZE
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_entered.connect(func(): enemy_stack_hovered.emit(enemy_id))
		panel.mouse_exited.connect(func(): enemy_stack_hovered.emit(-1))
		enemy_stack_row.add_child(panel)
		var row_art := _add_top_sheen(panel, Color(1.0, 0.78, 0.44, 0.06))

		var wash := ColorRect.new()
		wash.name = "PreviewWash"
		wash.offset_left = 0.0
		wash.offset_top = 0.0
		wash.offset_right = ENEMY_STACK_ROW_SIZE.x
		wash.offset_bottom = ENEMY_STACK_ROW_SIZE.y
		wash.color = Color(1.0, 0.72, 0.28, 0.0)
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(wash)

		var rail := ColorRect.new()
		rail.name = "StatusRail"
		rail.offset_left = 0.0
		rail.offset_top = 0.0
		rail.offset_right = 5.0
		rail.offset_bottom = ENEMY_STACK_ROW_SIZE.y
		rail.color = Color(0.42, 0.34, 0.48, 0.85)
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(rail)

		var border := ReferenceRect.new()
		border.anchor_right = 1.0
		border.anchor_bottom = 1.0
		border.offset_right = 0.0
		border.offset_bottom = 0.0
		border.border_width = 2.0
		border.editor_only = false
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(border)

		var order_badge := Panel.new()
		order_badge.name = "OrderBadge"
		order_badge.offset_left = 13.0
		order_badge.offset_top = 10.0
		order_badge.offset_right = 39.0
		order_badge.offset_bottom = 36.0
		order_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(order_badge)

		var order_label := Label.new()
		order_label.offset_left = 13.0
		order_label.offset_top = 10.0
		order_label.offset_right = 39.0
		order_label.offset_bottom = 36.0
		order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		order_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		order_label.add_theme_font_size_override("font_size", 16)
		order_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(order_label)

		var name_label := Label.new()
		name_label.offset_left = 84.0
		name_label.offset_top = 7.0
		name_label.offset_right = 224.0
		name_label.offset_bottom = 29.0
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(name_label)

		var icon_frame := Panel.new()
		icon_frame.name = "EnemyIconFrame"
		icon_frame.offset_left = 50.0
		icon_frame.offset_top = 8.0
		icon_frame.offset_right = 78.0
		icon_frame.offset_bottom = 34.0
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon_frame)

		var enemy_icon := TextureRect.new()
		enemy_icon.name = "EnemyIcon"
		enemy_icon.offset_left = 49.0
		enemy_icon.offset_top = 3.0
		enemy_icon.offset_right = 81.0
		enemy_icon.offset_bottom = 39.0
		enemy_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		enemy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		enemy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(enemy_icon)

		var intent_line := ColorRect.new()
		intent_line.name = "IntentLine"
		intent_line.offset_left = 84.0
		intent_line.offset_top = 34.0
		intent_line.offset_right = 224.0
		intent_line.offset_bottom = 37.0
		intent_line.color = Color(0.50, 0.38, 0.46, 0.62)
		intent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(intent_line)

		var status_back := Panel.new()
		status_back.name = "StatusBack"
		status_back.offset_left = 238.0
		status_back.offset_top = 10.0
		status_back.offset_right = 272.0
		status_back.offset_bottom = 36.0
		status_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(status_back)

		var status_mark := Panel.new()
		status_mark.name = "StatusMark"
		status_mark.offset_left = 244.0
		status_mark.offset_top = 14.0
		status_mark.offset_right = 266.0
		status_mark.offset_bottom = 32.0
		status_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(status_mark)

		order_label.text = str(row.get("order", "?"))
		name_label.text = row.get("enemy_name", "敌人")
		enemy_icon.texture = _enemy_row_texture(row)
		_enemy_row_controls[enemy_id] = {
			"panel": panel,
			"row_art": row_art,
			"wash": wash,
			"rail": rail,
			"border": border,
			"order_badge": order_badge,
			"order": order_label,
			"name": name_label,
			"icon_frame": icon_frame,
			"enemy_icon": enemy_icon,
			"intent_line": intent_line,
			"status_back": status_back,
			"status": status_mark,
		}

func _update_enemy_stack_styles() -> void:
	for row in _enemy_stack_rows:
		var enemy_id: int = row.get("enemy_id", -1)
		var controls: Dictionary = _enemy_row_controls.get(enemy_id, {})
		if controls.is_empty():
			continue
		var panel: ColorRect = controls.panel
		var row_art: ColorRect = controls.row_art
		var wash: ColorRect = controls.wash
		var rail: ColorRect = controls.rail
		var border: ReferenceRect = controls.border
		var order_badge: Panel = controls.order_badge
		var order_label: Label = controls.order
		var name_label: Label = controls.name
		var icon_frame: Panel = controls.icon_frame
		var enemy_icon: TextureRect = controls.enemy_icon
		var intent_line: ColorRect = controls.intent_line
		var status_back: Panel = controls.status_back
		var status_mark: Panel = controls.status
		var status: String = row.get("status", BattleEngine.INTENT_STATUS_NO_ATTACK)
		var is_focused := _focused_enemy_id == enemy_id
		var is_dimmed := _focused_enemy_id != -1 and not is_focused
		var is_executing := _executing_enemy_id == enemy_id
		var palette := _enemy_stack_palette(status)
		var base_panel: Color = palette.panel
		var border_color: Color = palette.border
		var status_color: Color = palette.status
		var rail_color: Color = palette.rail
		var line_color: Color = palette.line
		if is_executing:
			base_panel = Color(0.22, 0.14, 0.08, 0.97)
			border_color = Color(1.0, 0.82, 0.34, 1.0)
			rail_color = Color(1.0, 0.78, 0.26, 1.0)
			line_color = Color(1.0, 0.70, 0.26, 0.90)
		elif is_focused:
			base_panel = base_panel.lightened(0.12)
			border_color = border_color.lightened(0.20)
			rail_color = rail_color.lightened(0.15)
		elif is_dimmed:
			base_panel.a = 0.55
			border_color.a = 0.38
			rail_color.a *= 0.48
			line_color.a *= 0.45
		if _enemy_stack_preview_mode:
			border_color = border_color.lightened(0.10)
			base_panel = base_panel.lightened(0.04)
		panel.color = base_panel
		row_art.color = Color(1.0, 0.78, 0.44, 0.07 if not is_dimmed else 0.03)
		if is_executing:
			row_art.color = Color(1.0, 0.68, 0.20, 0.15)
		elif _enemy_stack_preview_mode:
			row_art.color = Color(1.0, 0.84, 0.36, 0.12 if not is_dimmed else 0.05)
		wash.color = Color(1.0, 0.70, 0.24, 0.10 if _enemy_stack_preview_mode else 0.0)
		rail.color = rail_color
		border.border_color = border_color
		border.border_width = 3.0 if is_executing else 2.0
		intent_line.color = line_color
		order_label.modulate = Color(1.0, 0.90, 0.56, 1.0 if not is_dimmed else 0.60)
		name_label.modulate = Color(0.95, 0.92, 0.88, 1.0 if not is_dimmed else 0.58)
		enemy_icon.modulate = Color(1, 1, 1, 1.0 if not is_dimmed else 0.52)
		_apply_enemy_order_badge(order_badge, status_color, border_color, is_dimmed, is_executing)
		_apply_enemy_icon_frame(icon_frame, status_color, is_dimmed)
		_apply_enemy_status_back(status_back, status_color, is_dimmed, is_executing)
		_apply_enemy_status_mark(status_mark, status, status_color, is_dimmed, is_executing)

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

func _enemy_row_texture(row: Dictionary) -> Texture2D:
	var enemy_def = row.get("enemy_def", null)
	if enemy_def is UnitDef:
		return enemy_def.token_texture
	return null

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.free()

func _install_static_ui_styles() -> void:
	var root := get_node_or_null("Root")
	if root == null:
		return
	var top_bar := root.get_node_or_null("TopBarBg")
	if top_bar is ColorRect:
		_apply_panel_frame(top_bar, Color(0.022, 0.023, 0.029, 0.95), Color(0.24, 0.20, 0.16, 0.42), 0, 0)
		_add_bottom_rule(top_bar, Color(0.72, 0.48, 0.22, 0.45), 2.0)
	if ability_bar_bg != null:
		_apply_panel_frame(ability_bar_bg, UI_BG, Color(0.68, 0.43, 0.18, 0.62), 0, 2)
		_add_top_sheen(ability_bar_bg, Color(1.0, 0.70, 0.28, 0.08))
	if enemy_stack_bg != null:
		_apply_panel_frame(enemy_stack_bg, Color(0.026, 0.027, 0.033, 0.92), Color(0.68, 0.43, 0.18, 0.54), 0, 1)
		_add_top_sheen(enemy_stack_bg, Color(1.0, 0.70, 0.26, 0.05))
	if squad_strip_bg != null:
		_apply_panel_frame(squad_strip_bg, Color(0.030, 0.031, 0.038, 0.90), Color(0.62, 0.42, 0.22, 0.46), 0, 1)
	if reward_panel_bg != null:
		_apply_panel_frame(reward_panel_bg, Color(0.030, 0.031, 0.038, 0.90), Color(0.62, 0.42, 0.22, 0.46), 0, 1)
		_add_top_sheen(reward_panel_bg, Color(1.0, 0.70, 0.26, 0.05))
	if info_panel_bg != null:
		_apply_panel_frame(info_panel_bg, Color(0.030, 0.031, 0.038, 0.90), Color(0.44, 0.34, 0.48, 0.50), 0, 1)

func _apply_panel_frame(parent: Control, bg: Color, border: Color, radius: int = 0, width: int = 1) -> ReferenceRect:
	if parent is ColorRect:
		parent.color = bg
	for child in parent.get_children():
		if child is ReferenceRect:
			var existing := child as ReferenceRect
			existing.border_color = Color(existing.border_color.r, existing.border_color.g, existing.border_color.b, existing.border_color.a * 0.55)
			existing.border_width = max(1.0, existing.border_width * 0.5)
	var frame := ReferenceRect.new()
	frame.name = "HUDFrame"
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_right = 0.0
	frame.offset_bottom = 0.0
	frame.border_width = width
	frame.border_color = border
	frame.editor_only = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	if radius > 0:
		var inset := ColorRect.new()
		inset.name = "HUDInnerTone"
		inset.anchor_right = 1.0
		inset.anchor_bottom = 1.0
		inset.offset_left = 1.0
		inset.offset_top = 1.0
		inset.offset_right = -1.0
		inset.offset_bottom = -1.0
		inset.color = Color(bg.r, bg.g, bg.b, bg.a * 0.52)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(inset)
		parent.move_child(inset, 0)
	return frame

func _add_top_sheen(parent: Control, color: Color) -> ColorRect:
	var sheen := ColorRect.new()
	sheen.name = "HUDTopSheen"
	sheen.anchor_right = 1.0
	sheen.offset_left = 1.0
	sheen.offset_top = 1.0
	sheen.offset_right = -1.0
	sheen.offset_bottom = 3.0
	sheen.color = color
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sheen)
	parent.move_child(sheen, 0)
	return sheen

func _add_bottom_rule(parent: Control, color: Color, height: float = 1.0) -> ColorRect:
	var rule := ColorRect.new()
	rule.name = "HUDBottomRule"
	rule.anchor_top = 1.0
	rule.anchor_right = 1.0
	rule.anchor_bottom = 1.0
	rule.offset_left = 0.0
	rule.offset_top = -height
	rule.offset_right = 0.0
	rule.offset_bottom = 0.0
	rule.color = color
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)
	return rule

func _apply_enemy_icon_frame(frame: Panel, base_color: Color, dimmed: bool) -> void:
	var alpha_scale := 0.50 if dimmed else 1.0
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.bg_color = Color(0.04, 0.035, 0.04, 0.86 * alpha_scale)
	style.border_color = Color(base_color.r, base_color.g, base_color.b, 0.42 * alpha_scale)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	frame.add_theme_stylebox_override("panel", style)

func _apply_enemy_order_badge(badge: Panel, fill_color: Color, border_color: Color, dimmed: bool, executing: bool) -> void:
	var alpha_scale := 0.58 if dimmed else 1.0
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.bg_color = Color(0.06, 0.045, 0.05, 0.92 * alpha_scale)
	if executing:
		style.bg_color = Color(0.24, 0.14, 0.06, 0.98 * alpha_scale)
	style.border_color = Color(border_color.r, border_color.g, border_color.b, 0.88 * alpha_scale)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	badge.add_theme_stylebox_override("panel", style)

func _apply_enemy_status_back(back: Panel, base_color: Color, dimmed: bool, executing: bool) -> void:
	var alpha_scale := 0.50 if dimmed else 1.0
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.bg_color = Color(base_color.r, base_color.g, base_color.b, (0.12 if not executing else 0.18) * alpha_scale)
	style.border_color = Color(base_color.r, base_color.g, base_color.b, (0.34 if not executing else 0.58) * alpha_scale)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	back.add_theme_stylebox_override("panel", style)

func _apply_enemy_status_mark(mark: Panel, status: String, base_color: Color, dimmed: bool, executing: bool) -> void:
	var alpha_scale := 0.58 if dimmed else 1.0
	if executing:
		alpha_scale = minf(1.0, alpha_scale + 0.12)
	var fill := Color(base_color.r, base_color.g, base_color.b, base_color.a * alpha_scale)
	var border := Color(base_color.r, base_color.g, base_color.b, 0.72 * alpha_scale)
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	match status:
		BattleEngine.INTENT_STATUS_HIT:
			mark.offset_left = 244.0
			mark.offset_top = 14.0
			mark.offset_right = 266.0
			mark.offset_bottom = 32.0
			style.bg_color = fill
			style.border_color = border.lightened(0.25)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
		BattleEngine.INTENT_STATUS_MISS:
			mark.offset_left = 244.0
			mark.offset_top = 15.0
			mark.offset_right = 266.0
			mark.offset_bottom = 31.0
			style.bg_color = Color(fill.r, fill.g, fill.b, 0.16 * alpha_scale)
			style.border_color = border
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
		BattleEngine.INTENT_STATUS_REMOVED:
			mark.offset_left = 243.0
			mark.offset_top = 22.0
			mark.offset_right = 267.0
			mark.offset_bottom = 26.0
			style.bg_color = Color(fill.r, fill.g, fill.b, 0.64 * alpha_scale)
			style.border_color = Color(border.r, border.g, border.b, 0.34 * alpha_scale)
		_:
			mark.offset_left = 247.0
			mark.offset_top = 22.0
			mark.offset_right = 263.0
			mark.offset_bottom = 26.0
			style.bg_color = Color(fill.r, fill.g, fill.b, 0.54 * alpha_scale)
			style.border_color = Color(border.r, border.g, border.b, 0.28 * alpha_scale)
	mark.add_theme_stylebox_override("panel", style)

func _enemy_stack_palette(status: String) -> Dictionary:
	match status:
		BattleEngine.INTENT_STATUS_HIT:
			return {
				"panel": Color(0.16, 0.07, 0.08, 0.92),
				"border": Color(0.92, 0.28, 0.34, 0.90),
				"status": Color(1.0, 0.45, 0.46, 1.0),
				"rail": Color(1.0, 0.30, 0.34, 0.95),
				"line": Color(1.0, 0.36, 0.40, 0.80),
			}
		BattleEngine.INTENT_STATUS_MISS:
			return {
				"panel": Color(0.10, 0.12, 0.15, 0.82),
				"border": Color(0.52, 0.62, 0.72, 0.72),
				"status": Color(0.66, 0.75, 0.84, 1.0),
				"rail": Color(0.58, 0.69, 0.80, 0.78),
				"line": Color(0.58, 0.68, 0.78, 0.52),
			}
		BattleEngine.INTENT_STATUS_REMOVED:
			return {
				"panel": Color(0.08, 0.08, 0.09, 0.72),
				"border": Color(0.44, 0.44, 0.48, 0.58),
				"status": Color(0.70, 0.70, 0.74, 1.0),
				"rail": Color(0.46, 0.46, 0.50, 0.58),
				"line": Color(0.50, 0.50, 0.54, 0.36),
			}
		_:
			return {
				"panel": Color(0.09, 0.08, 0.11, 0.70),
				"border": Color(0.36, 0.34, 0.42, 0.50),
				"status": Color(0.72, 0.68, 0.78, 1.0),
				"rail": Color(0.58, 0.46, 0.30, 0.50),
				"line": Color(0.58, 0.46, 0.30, 0.30),
			}

func show_outcome(outcome: int, reason: String = "") -> void:
	if outcome == BattleState.Outcome.VICTORY:
		banner.text = "胜 利" if reason == "" else "胜 利\n%s" % reason
		banner.modulate = Color(0.7, 1.0, 0.8)
	elif outcome == BattleState.Outcome.DEFEAT:
		banner.text = "失 败" if reason == "" else "失 败\n%s" % reason
		banner.modulate = Color(1.0, 0.5, 0.5)
	banner.offset_top = -56.0 if reason != "" else -40.0
	banner.offset_bottom = 56.0 if reason != "" else 40.0
	banner.add_theme_font_size_override("font_size", 36 if reason != "" else 64)
	banner.visible = true
