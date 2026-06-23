class_name HUD extends CanvasLayer
## Top-bar status + end-turn / undo controls.

signal end_turn_pressed
signal undo_pressed
signal confirm_deploy_pressed
signal ability_selected(ability_id: String)
signal ability_unavailable(ability_id: String, reason: String)
signal enemy_stack_hovered(enemy_id: int)

const ENEMY_STACK_ROW_SIZE := Vector2(208, 42)
const ABILITY_SLOT_SIZE := Vector2(206, 76)
const LEFT_ACTION_SLOT_SIZE := Vector2(202, 76)
const ABILITY_DETAIL_PANEL_SIZE := Vector2(300, 96)
const SQUAD_CARD_SIZE := Vector2(156, 66)
const SQUAD_HP_BAR_SIZE := Vector2(48, 7)
const SELECTED_UNIT_HP_BAR_SIZE := Vector2(132, 8)
const ENEMY_HP_BAR_SIZE := Vector2(94, 5)
const HP_BAR_MAX_VISIBLE_SEGMENTS := 12
const TOP_STATUS_CLUSTER_SIZE := Vector2(626, 54)
const TOP_STATUS_SANCTUARY_SIZE := Vector2(252, 50)
const TOP_STATUS_ROUND_SIZE := Vector2(126, 50)
const TOP_STATUS_OBJECTIVE_SIZE := Vector2(244, 50)
const SANCTUARY_BAR_SIZE := Vector2(202, 8)
const HP_SEGMENT_GAP := 2.0
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
const UI_HP_EMPTY := Color(0.10, 0.075, 0.060, 0.96)
const UI_HP_FILL := Color(1.0, 0.58, 0.20, 0.96)
const UI_HP_CRITICAL := Color(1.0, 0.30, 0.24, 0.96)
const UI_HP_PREVIEW := Color(1.0, 0.18, 0.12, 0.84)
const UI_HP_PREVIEW_GLOW := Color(1.0, 0.54, 0.22, 0.34)
const UI_ENEMY_HP_FILL := Color(0.82, 0.30, 0.22, 0.92)
const UI_ENEMY_HP_CRITICAL := Color(1.0, 0.18, 0.14, 0.96)
const UI_ART_PASSIVE := Color(0.58, 0.63, 0.70, 0.68)
const UI_ART_SELECTED := Color(0.76, 0.78, 0.80, 0.86)
const UI_ART_DISABLED := Color(0.48, 0.52, 0.58, 0.68)

const ICON_ATTACK := preload("res://art/atlases/battle/battle_ui.attack_icon.tres")
const ICON_MOVE := preload("res://art/atlases/battle/battle_ui.move_icon.tres")
const ICON_RELIC := preload("res://art/atlases/battle/battle_ui.relic_icon.tres")
const ICON_WAIT := preload("res://art/atlases/battle/battle_ui.wait_icon.tres")
const ICON_COOLDOWN_RING := preload("res://art/atlases/battle/battle_ui.cooldown_ring.tres")
const ICON_COOLDOWN_RING_MUTED := preload("res://art/atlases/battle/battle_ui.cooldown_ring_muted.tres")
const SHADER_COOLDOWN_RADIAL_CLIP := preload("res://shaders/ui/cooldown_radial_clip.gdshader")
const BattleStatusPresenter := preload("res://scripts/view/battle_status_presenter.gd")

@onready var round_label: Label = $Root/TopRow/RoundLabel
@onready var phase_label: Label = $Root/TopRow/PhaseLabel
@onready var sanctuary_label: Label = $Root/TopRow/SanctuaryLabel
@onready var objective_label: Label = $Root/TopRow/ObjectiveLabel
@onready var top_row: HBoxContainer = $Root/TopRow
@onready var top_bar_bg: ColorRect = $Root/TopBarBg
@onready var command_deck_bg: ColorRect = $Root/CommandDeckBg
@onready var help_label: Label = $Root/HelpLabel
@onready var end_turn_button: Button = $Root/TopRow/EndTurnButton
@onready var undo_button: Button = $Root/TopRow/UndoButton
@onready var confirm_deploy_button: Button = $Root/TopRow/ConfirmDeployButton
@onready var settings_button: Button = null
@onready var banner: Label = $Root/Banner
@onready var info_panel_bg: ColorRect = $Root/InfoPanelBg
@onready var info_title: Label = $Root/InfoPanelBg/InfoTitle
@onready var info_body: Label = $Root/InfoPanelBg/InfoBody
@onready var boss_status_bg: ColorRect = $Root/BossStatusBg
@onready var boss_status_title: Label = $Root/BossStatusBg/BossStatusTitle
@onready var boss_status_body: Label = $Root/BossStatusBg/BossStatusBody
@onready var ability_bar_bg: ColorRect = $Root/AbilityBarBg
@onready var ability_portrait_frame: ColorRect = $Root/SelectedUnitPanelBg/AbilityPortraitFrame
@onready var ability_title: Label = $Root/SelectedUnitPanelBg/AbilityTitle
@onready var ability_portrait: TextureRect = $Root/SelectedUnitPanelBg/AbilityPortraitFrame/AbilityPortrait
@onready var ability_hp_label: Label = $Root/SelectedUnitPanelBg/AbilityHpLabel
@onready var ability_info_label: Label = $Root/SelectedUnitPanelBg/AbilityInfoLabel
@onready var ability_row: HBoxContainer = $Root/AbilityBarBg/AbilityRow
@onready var item_slot_title: Label = $Root/AbilityBarBg/ItemSlotTitle
@onready var item_slot_row: HBoxContainer = $Root/AbilityBarBg/ItemSlotRow
@onready var squad_strip_bg: ColorRect = $Root/SquadStripBg
@onready var squad_strip_row: BoxContainer = $Root/SquadStripBg/SquadStripRow
@onready var reward_panel_bg: ColorRect = $Root/RewardPanelBg
@onready var reward_task_row: VBoxContainer = $Root/RewardPanelBg/RewardTaskRow
@onready var enemy_stack_bg: ColorRect = $Root/EnemyStackBg
@onready var enemy_stack_title: Label = $Root/EnemyStackBg/EnemyStackTitle
@onready var enemy_stack_mode: Label = $Root/EnemyStackBg/EnemyStackMode
@onready var enemy_stack_row: VBoxContainer = $Root/EnemyStackBg/EnemyStackRow

var selected_unit_panel_bg: ColorRect = null
var selected_unit_card_bg: ColorRect = null
var selected_unit_card_frame: ReferenceRect = null
var selected_unit_hp_bar: Control = null
var command_divider: ColorRect = null
var ability_stack: HBoxContainer = null
var ability_console_frame: Panel = null
var ability_detail_panel: Panel = null
var ability_detail_accent: ColorRect = null
var ability_detail_title: Label = null
var ability_detail_badges: HBoxContainer = null
var ability_detail_body: Label = null
var ability_detail_footer: Label = null
var enemy_stack_scroll: ScrollContainer = null
var top_status_cluster: Panel = null
var _enemy_stack_rows: Array = []
var _enemy_stack_signature: String = ""
var _enemy_stack_preview_mode: bool = false
var _hovered_ability: Dictionary = {}
var _armed_ability_detail: Dictionary = {}
var _focused_enemy_id: int = -1
var _executing_enemy_id: int = -1
var _enemy_row_controls: Dictionary = {}
var _enemy_stack_dragging: bool = false
var _enemy_stack_drag_last_y: float = 0.0
var sanctuary_integrity: int = 12
var sanctuary_integrity_max: int = 12
var sanctuary_preview_loss: int = 0
var sanctuary_panel: Control = null
var sanctuary_bar: Control = null
var sanctuary_title_label: Label = null
var sanctuary_value_label: Label = null
var sanctuary_bar_back: Panel = null
var round_title_label: Label = null
var round_number_plate: Panel = null
var round_current_label: Label = null
var round_total_label: Label = null
var round_accent_rule: ColorRect = null
var round_progress_bar: Control = null
var top_status_divider_a: ColorRect = null
var top_status_divider_b: ColorRect = null
var _sanctuary_pulse_t: float = 0.0

const ENEMY_STACK_WHEEL_STEP := 48

func _ready() -> void:
	_ensure_settings_button()
	_ensure_top_status_cluster()
	_ensure_sanctuary_panel()
	_ensure_round_status_panel()
	_ensure_selected_unit_panel()
	_ensure_ability_detail_panel()
	_ensure_enemy_stack_scroll()
	_apply_layout_metrics()
	end_turn_button.pressed.connect(func(): end_turn_pressed.emit())
	undo_button.pressed.connect(func(): undo_pressed.emit())
	confirm_deploy_button.pressed.connect(func(): confirm_deploy_pressed.emit())
	if settings_button != null:
		settings_button.pressed.connect(func(): set_help("设置暂未接入"))
	banner.visible = false
	confirm_deploy_button.visible = false
	if enemy_stack_bg != null:
		enemy_stack_bg.visible = false
	_install_static_ui_styles()
	if item_slot_title != null:
		item_slot_title.visible = false
	if item_slot_row != null:
		item_slot_row.visible = false
	_refresh_sanctuary_display()
	set_process(true)

func _process(delta: float) -> void:
	if sanctuary_preview_loss <= 0 or sanctuary_bar == null:
		return
	_sanctuary_pulse_t += delta
	_apply_sanctuary_preview_pulse()

func _input(event: InputEvent) -> void:
	_handle_enemy_stack_scroll_input(event)

func _ensure_top_status_cluster() -> void:
	var root := get_node_or_null("Root")
	if root == null:
		return
	var existing := root.get_node_or_null("TopStatusCluster")
	if existing is Panel:
		top_status_cluster = existing
	else:
		if existing != null:
			root.remove_child(existing)
			existing.free()
		top_status_cluster = Panel.new()
		top_status_cluster.name = "TopStatusCluster"
		top_status_cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(top_status_cluster)
		root.move_child(top_status_cluster, 1)
	var existing_divider_a := top_status_cluster.get_node_or_null("DividerSanctuaryRound")
	if existing_divider_a is ColorRect:
		top_status_divider_a = existing_divider_a
	else:
		top_status_divider_a = ColorRect.new()
		top_status_divider_a.name = "DividerSanctuaryRound"
		top_status_divider_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_status_cluster.add_child(top_status_divider_a)
	var existing_divider_b := top_status_cluster.get_node_or_null("DividerRoundObjective")
	if existing_divider_b is ColorRect:
		top_status_divider_b = existing_divider_b
	else:
		top_status_divider_b = ColorRect.new()
		top_status_divider_b.name = "DividerRoundObjective"
		top_status_divider_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_status_cluster.add_child(top_status_divider_b)
	_apply_top_status_cluster_style()

func _ensure_round_status_panel() -> void:
	if round_label == null:
		return
	round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_label.clip_text = false
	round_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var existing_title := round_label.get_node_or_null("RoundTitle")
	if existing_title is Label:
		round_title_label = existing_title
	else:
		round_title_label = Label.new()
		round_title_label.name = "RoundTitle"
		round_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		round_label.add_child(round_title_label)
	var existing_current := round_label.get_node_or_null("RoundCurrent")
	if existing_current is Label:
		round_current_label = existing_current
	else:
		round_current_label = Label.new()
		round_current_label.name = "RoundCurrent"
		round_current_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		round_label.add_child(round_current_label)
	var existing_plate := round_label.get_node_or_null("RoundNumberPlate")
	if existing_plate is Panel:
		round_number_plate = existing_plate
	else:
		round_number_plate = Panel.new()
		round_number_plate.name = "RoundNumberPlate"
		round_number_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		round_label.add_child(round_number_plate)
		round_label.move_child(round_number_plate, max(0, round_current_label.get_index()))
	var existing_total := round_label.get_node_or_null("RoundTotal")
	if existing_total is Label:
		round_total_label = existing_total
	else:
		round_total_label = Label.new()
		round_total_label.name = "RoundTotal"
		round_total_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		round_label.add_child(round_total_label)
	var existing_rule := round_label.get_node_or_null("RoundAccentRule")
	if existing_rule is ColorRect:
		round_accent_rule = existing_rule
	else:
		round_accent_rule = ColorRect.new()
		round_accent_rule.name = "RoundAccentRule"
		round_accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		round_label.add_child(round_accent_rule)
	var existing_progress := round_label.get_node_or_null("RoundProgressBar")
	if existing_progress is Control:
		round_progress_bar = existing_progress
	else:
		round_progress_bar = Control.new()
		round_progress_bar.name = "RoundProgressBar"
		round_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		round_label.add_child(round_progress_bar)
	_layout_round_status_panel()

func _ensure_sanctuary_panel() -> void:
	if sanctuary_label == null:
		return
	sanctuary_panel = sanctuary_label
	sanctuary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sanctuary_label.clip_text = false
	sanctuary_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var existing_title := sanctuary_label.get_node_or_null("SanctuaryTitle")
	if existing_title is Label:
		sanctuary_title_label = existing_title
	else:
		sanctuary_title_label = Label.new()
		sanctuary_title_label.name = "SanctuaryTitle"
		sanctuary_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sanctuary_label.add_child(sanctuary_title_label)
	var existing_value := sanctuary_label.get_node_or_null("SanctuaryValue")
	if existing_value is Label:
		sanctuary_value_label = existing_value
	else:
		sanctuary_value_label = Label.new()
		sanctuary_value_label.name = "SanctuaryValue"
		sanctuary_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sanctuary_label.add_child(sanctuary_value_label)
	var existing_back := sanctuary_label.get_node_or_null("SanctuaryBarBack")
	if existing_back is Panel:
		sanctuary_bar_back = existing_back
	else:
		sanctuary_bar_back = Panel.new()
		sanctuary_bar_back.name = "SanctuaryBarBack"
		sanctuary_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sanctuary_label.add_child(sanctuary_bar_back)
	var existing := sanctuary_label.get_node_or_null("SanctuaryBar")
	if existing is Control:
		sanctuary_bar = existing
	else:
		if existing != null:
			sanctuary_label.remove_child(existing)
			existing.free()
		sanctuary_bar = Control.new()
		sanctuary_bar.name = "SanctuaryBar"
		sanctuary_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sanctuary_label.add_child(sanctuary_bar)
	sanctuary_label.move_child(sanctuary_bar, sanctuary_label.get_child_count() - 1)
	_layout_sanctuary_text()
	_layout_sanctuary_bar()

func _layout_sanctuary_text() -> void:
	if sanctuary_title_label != null:
		sanctuary_title_label.offset_left = 16.0
		sanctuary_title_label.offset_top = 7.0
		sanctuary_title_label.offset_right = 120.0
		sanctuary_title_label.offset_bottom = 25.0
		sanctuary_title_label.text = "守护值"
		sanctuary_title_label.add_theme_font_size_override("font_size", 13)
		sanctuary_title_label.modulate = UI_GOLD_TEXT
	if sanctuary_value_label != null:
		sanctuary_value_label.offset_left = 174.0
		sanctuary_value_label.offset_top = 7.0
		sanctuary_value_label.offset_right = 232.0
		sanctuary_value_label.offset_bottom = 25.0
		sanctuary_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sanctuary_value_label.add_theme_font_size_override("font_size", 13)
		sanctuary_value_label.modulate = Color(0.88, 0.92, 0.92, 0.86)

func _layout_sanctuary_bar() -> void:
	if sanctuary_bar == null:
		return
	if sanctuary_bar_back != null:
		sanctuary_bar_back.offset_left = 14.0
		sanctuary_bar_back.offset_top = 30.0
		sanctuary_bar_back.offset_right = sanctuary_bar_back.offset_left + SANCTUARY_BAR_SIZE.x + 8.0
		sanctuary_bar_back.offset_bottom = sanctuary_bar_back.offset_top + SANCTUARY_BAR_SIZE.y + 8.0
		_apply_bar_back_style(sanctuary_bar_back)
	sanctuary_bar.offset_left = 18.0
	sanctuary_bar.offset_top = 34.0
	sanctuary_bar.offset_right = sanctuary_bar.offset_left + SANCTUARY_BAR_SIZE.x
	sanctuary_bar.offset_bottom = sanctuary_bar.offset_top + SANCTUARY_BAR_SIZE.y

func _layout_round_status_panel() -> void:
	if round_label == null:
		return
	if round_title_label != null:
		round_title_label.offset_left = 12.0
		round_title_label.offset_top = 10.0
		round_title_label.offset_right = 108.0
		round_title_label.offset_bottom = 40.0
		round_title_label.text = "回合"
		round_title_label.add_theme_font_size_override("font_size", 13)
		round_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		round_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		round_title_label.modulate = Color(1.0, 0.80, 0.44, 0.86)
	if round_number_plate != null:
		round_number_plate.visible = false
	if round_current_label != null:
		round_current_label.offset_left = 53.0
		round_current_label.offset_top = 10.0
		round_current_label.offset_right = 74.0
		round_current_label.offset_bottom = 40.0
		round_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		round_current_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		round_current_label.add_theme_font_size_override("font_size", 16)
		round_current_label.modulate = Color(1.0, 0.86, 0.48, 1.0)
	if round_total_label != null:
		round_total_label.offset_left = 69.0
		round_total_label.offset_top = 10.0
		round_total_label.offset_right = 112.0
		round_total_label.offset_bottom = 40.0
		round_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		round_total_label.add_theme_font_size_override("font_size", 14)
		round_total_label.modulate = Color(0.76, 0.76, 0.70, 0.82)
	if round_accent_rule != null:
		round_accent_rule.offset_left = 12.0
		round_accent_rule.offset_top = 40.0
		round_accent_rule.offset_right = 112.0
		round_accent_rule.offset_bottom = 41.0
		round_accent_rule.color = Color(0.95, 0.58, 0.18, 0.24)
	if round_progress_bar != null:
		round_progress_bar.visible = false

func _ensure_selected_unit_panel() -> void:
	var root := get_node_or_null("Root")
	if root == null:
		return
	var legacy_panel := root.get_node_or_null("SelectedUnitPanelBg")
	if ability_bar_bg == null:
		return
	selected_unit_panel_bg = ability_bar_bg
	_ensure_selected_unit_card()
	_ensure_left_command_frame()
	_ensure_ability_stack()
	_reparent_to_selected_card(ability_portrait_frame)
	_reparent_to_selected_card(ability_title)
	_reparent_to_selected_card(ability_hp_label)
	_reparent_to_selected_card(ability_info_label)
	_ensure_selected_unit_hp_bar()
	if legacy_panel is ColorRect and legacy_panel != ability_bar_bg:
		legacy_panel.visible = false
		legacy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legacy_panel.color = Color(0, 0, 0, 0)
	_ensure_command_divider()

func _ensure_left_command_frame() -> void:
	if ability_bar_bg == null:
		return
	var legacy_generated_art := ability_bar_bg.get_node_or_null("CommandConsoleArt")
	if legacy_generated_art != null:
		legacy_generated_art.queue_free()
	var existing := ability_bar_bg.get_node_or_null("CommandConsoleFrame")
	if existing is Panel:
		ability_console_frame = existing
	else:
		ability_console_frame = Panel.new()
		ability_console_frame.name = "CommandConsoleFrame"
		ability_console_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_bar_bg.add_child(ability_console_frame)
	ability_bar_bg.move_child(ability_console_frame, 0)

func _ensure_ability_stack() -> void:
	if ability_bar_bg == null:
		return
	if ability_row != null:
		ability_row.visible = false
	var existing := ability_bar_bg.get_node_or_null("AbilityStack")
	if existing is HBoxContainer:
		ability_stack = existing
	else:
		if existing != null:
			ability_bar_bg.remove_child(existing)
			existing.free()
		ability_stack = HBoxContainer.new()
		ability_stack.name = "AbilityStack"
		ability_bar_bg.add_child(ability_stack)
	ability_stack.add_theme_constant_override("separation", 10)

func _ensure_selected_unit_card() -> void:
	if ability_bar_bg == null:
		return
	var existing := ability_bar_bg.get_node_or_null("SelectedUnitCardBg")
	if existing is ColorRect:
		selected_unit_card_bg = existing
	else:
		selected_unit_card_bg = ColorRect.new()
		selected_unit_card_bg.name = "SelectedUnitCardBg"
		selected_unit_card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_bar_bg.add_child(selected_unit_card_bg)
	var existing_frame := selected_unit_card_bg.get_node_or_null("SelectedUnitCardFrame")
	if existing_frame is ReferenceRect:
		selected_unit_card_frame = existing_frame
	else:
		selected_unit_card_frame = ReferenceRect.new()
		selected_unit_card_frame.name = "SelectedUnitCardFrame"
		selected_unit_card_frame.anchor_right = 1.0
		selected_unit_card_frame.anchor_bottom = 1.0
		selected_unit_card_frame.offset_right = 0.0
		selected_unit_card_frame.offset_bottom = 0.0
		selected_unit_card_frame.editor_only = false
		selected_unit_card_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selected_unit_card_bg.add_child(selected_unit_card_frame)
	var existing_rail := selected_unit_card_bg.get_node_or_null("SelectedUnitAccentRail")
	if not existing_rail is ColorRect:
		if existing_rail != null:
			selected_unit_card_bg.remove_child(existing_rail)
			existing_rail.free()
		var rail := ColorRect.new()
		rail.name = "SelectedUnitAccentRail"
		rail.offset_left = 0.0
		rail.offset_top = 0.0
		rail.offset_right = 3.0
		rail.offset_bottom = 92.0
		rail.color = Color(0.88, 0.54, 0.22, 0.72)
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selected_unit_card_bg.add_child(rail)
	ability_bar_bg.move_child(selected_unit_card_bg, 1)

func _reparent_to_selected_card(node: Control) -> void:
	if selected_unit_card_bg == null or node == null or node.get_parent() == selected_unit_card_bg:
		return
	var old_parent := node.get_parent()
	if old_parent != null:
		old_parent.remove_child(node)
	_clear_owner_recursive(node)
	selected_unit_card_bg.add_child(node)

func _ensure_selected_unit_hp_bar() -> void:
	if selected_unit_card_bg == null:
		return
	var existing := selected_unit_card_bg.get_node_or_null("SelectedUnitHpBar")
	if existing is Control:
		selected_unit_hp_bar = existing
	else:
		if existing != null:
			selected_unit_card_bg.remove_child(existing)
			existing.free()
		selected_unit_hp_bar = Control.new()
		selected_unit_hp_bar.name = "SelectedUnitHpBar"
		selected_unit_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selected_unit_card_bg.add_child(selected_unit_hp_bar)
	selected_unit_card_bg.move_child(selected_unit_hp_bar, selected_unit_card_bg.get_child_count() - 1)

func _clear_owner_recursive(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owner_recursive(child)

func _ensure_command_divider() -> void:
	if ability_bar_bg == null:
		return
	var existing := ability_bar_bg.get_node_or_null("CommandDivider")
	if existing is ColorRect:
		command_divider = existing
		return
	command_divider = ColorRect.new()
	command_divider.name = "CommandDivider"
	command_divider.color = Color(0.46, 0.56, 0.58, 0.34)
	command_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_bar_bg.add_child(command_divider)

func _ensure_ability_detail_panel() -> void:
	var root := get_node_or_null("Root")
	if root == null:
		return
	var existing := root.get_node_or_null("AbilityDetailPanel")
	if existing is Panel:
		ability_detail_panel = existing
	else:
		if existing != null:
			root.remove_child(existing)
			existing.free()
		ability_detail_panel = Panel.new()
		ability_detail_panel.name = "AbilityDetailPanel"
		ability_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ability_detail_panel)
	ability_detail_panel.visible = false
	var backdrop_node := ability_detail_panel.get_node_or_null("Backdrop")
	if backdrop_node != null:
		ability_detail_panel.remove_child(backdrop_node)
		backdrop_node.free()
	var accent_node := ability_detail_panel.get_node_or_null("AccentRule")
	if accent_node is ColorRect:
		ability_detail_accent = accent_node
	else:
		if accent_node != null:
			ability_detail_panel.remove_child(accent_node)
			accent_node.free()
		ability_detail_accent = ColorRect.new()
		ability_detail_accent.name = "AccentRule"
		ability_detail_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_detail_panel.add_child(ability_detail_accent)
	var title_node := ability_detail_panel.get_node_or_null("Title")
	if title_node is Label:
		ability_detail_title = title_node
	else:
		ability_detail_title = Label.new()
		ability_detail_title.name = "Title"
		ability_detail_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_detail_panel.add_child(ability_detail_title)
	var badges_node := ability_detail_panel.get_node_or_null("Badges")
	if badges_node is HBoxContainer:
		ability_detail_badges = badges_node
	else:
		ability_detail_badges = HBoxContainer.new()
		ability_detail_badges.name = "Badges"
		ability_detail_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_detail_panel.add_child(ability_detail_badges)
	var body_node := ability_detail_panel.get_node_or_null("Body")
	if body_node is Label:
		ability_detail_body = body_node
	else:
		ability_detail_body = Label.new()
		ability_detail_body.name = "Body"
		ability_detail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_detail_panel.add_child(ability_detail_body)
	var footer_node := ability_detail_panel.get_node_or_null("Footer")
	if footer_node is Label:
		ability_detail_footer = footer_node
	else:
		ability_detail_footer = Label.new()
		ability_detail_footer.name = "Footer"
		ability_detail_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_detail_panel.add_child(ability_detail_footer)
	_layout_ability_detail_panel(Vector2.ZERO)
	_apply_ability_detail_panel_style()

func _ensure_settings_button() -> void:
	if top_row == null:
		top_row = get_node_or_null("Root/TopRow")
	if top_row == null:
		return
	var existing := top_row.get_node_or_null("SettingsButton")
	if existing is Button:
		settings_button = existing
		return
	var btn := Button.new()
	btn.name = "SettingsButton"
	btn.text = "⚙"
	btn.custom_minimum_size = Vector2(42, 36)
	top_row.add_child(btn)
	settings_button = btn

func _ensure_enemy_stack_scroll() -> void:
	if enemy_stack_bg == null or enemy_stack_row == null:
		return
	var existing := enemy_stack_bg.get_node_or_null("EnemyStackScroll")
	if existing is ScrollContainer:
		enemy_stack_scroll = existing
	else:
		if existing != null:
			enemy_stack_bg.remove_child(existing)
			existing.free()
		enemy_stack_scroll = ScrollContainer.new()
		enemy_stack_scroll.name = "EnemyStackScroll"
		enemy_stack_bg.add_child(enemy_stack_scroll)
	enemy_stack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	enemy_stack_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	enemy_stack_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	if not enemy_stack_scroll.gui_input.is_connected(_handle_enemy_stack_scroll_input):
		enemy_stack_scroll.gui_input.connect(_handle_enemy_stack_scroll_input)
	if enemy_stack_row.get_parent() != enemy_stack_scroll:
		var old_parent := enemy_stack_row.get_parent()
		if old_parent != null:
			old_parent.remove_child(enemy_stack_row)
		_clear_owner_recursive(enemy_stack_row)
		enemy_stack_scroll.add_child(enemy_stack_row)

func _handle_enemy_stack_scroll_input(event: InputEvent) -> void:
	if enemy_stack_scroll == null or enemy_stack_bg == null or not enemy_stack_bg.visible:
		return
	if event is InputEventMouseMotion:
		_handle_enemy_stack_drag_motion(event as InputEventMouseMotion)
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_handle_enemy_stack_drag_button(mouse_event)
		return
	if not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_WHEEL_UP and mouse_event.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	if not _enemy_stack_contains_screen_point(mouse_event.position):
		return
	var direction := -1 if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
	enemy_stack_scroll.scroll_vertical = maxi(0, enemy_stack_scroll.scroll_vertical + direction * ENEMY_STACK_WHEEL_STEP)
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func _handle_enemy_stack_drag_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		if not _enemy_stack_contains_screen_point(event.position):
			return
		_enemy_stack_dragging = true
		_enemy_stack_drag_last_y = event.position.y
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if _enemy_stack_dragging:
		_enemy_stack_dragging = false
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _handle_enemy_stack_drag_motion(event: InputEventMouseMotion) -> void:
	if not _enemy_stack_dragging:
		return
	var delta_y := event.position.y - _enemy_stack_drag_last_y
	_enemy_stack_drag_last_y = event.position.y
	enemy_stack_scroll.scroll_vertical = maxi(0, enemy_stack_scroll.scroll_vertical - int(delta_y))
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func _enemy_stack_contains_screen_point(point: Vector2) -> bool:
	if enemy_stack_scroll == null:
		return false
	return enemy_stack_scroll.get_global_rect().has_point(point)

func _apply_command_console_style() -> void:
	if ability_console_frame == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	ability_console_frame.add_theme_stylebox_override("panel", style)

func _apply_action_button_style(panel: Panel, ability: Dictionary) -> void:
	var disabled := not bool(ability.get("active", true))
	var armed := bool(ability.get("is_armed", false))
	var defaulted := bool(ability.get("is_default", false))
	var is_attack := String(ability.get("id", "")) == "attack"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.013, 0.016, 0.78)
	style.border_color = Color(0.24, 0.23, 0.22, 0.46)
	if armed:
		style.bg_color = Color(0.020, 0.041, 0.046, 0.90)
		style.border_color = Color(0.25, 0.78, 0.86, 0.76)
	elif defaulted:
		style.bg_color = Color(0.020, 0.019, 0.017, 0.82)
		style.border_color = Color(0.58, 0.44, 0.24, 0.56)
	elif is_attack:
		style.bg_color = Color(0.040, 0.022, 0.020, 0.74)
		style.border_color = Color(0.52, 0.22, 0.18, 0.56)
	elif disabled:
		style.bg_color = Color(0.008, 0.009, 0.012, 0.66)
		style.border_color = Color(0.14, 0.15, 0.17, 0.46)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0, 0, 0, 0.34)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", style)

func _apply_ability_detail_panel_style() -> void:
	if ability_detail_panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.011, 0.012, 0.015, 0.94)
	style.border_color = Color(0.34, 0.30, 0.24, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0, 0, 0, 0.44)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
	ability_detail_panel.add_theme_stylebox_override("panel", style)

func _layout_ability_detail_panel(anchor: Vector2) -> void:
	if ability_detail_panel == null:
		return
	var left := clampf(anchor.x - ABILITY_DETAIL_PANEL_SIZE.x * 0.5, 204.0, 1280.0 - ABILITY_DETAIL_PANEL_SIZE.x - 24.0)
	var top := maxf(92.0, anchor.y - ABILITY_DETAIL_PANEL_SIZE.y - 10.0)
	ability_detail_panel.offset_left = left
	ability_detail_panel.offset_top = top
	ability_detail_panel.offset_right = left + ABILITY_DETAIL_PANEL_SIZE.x
	ability_detail_panel.offset_bottom = top + ABILITY_DETAIL_PANEL_SIZE.y
	if ability_detail_accent != null:
		ability_detail_accent.offset_left = 12.0
		ability_detail_accent.offset_top = 8.0
		ability_detail_accent.offset_right = 66.0
		ability_detail_accent.offset_bottom = 10.0
		ability_detail_accent.color = Color(0.88, 0.58, 0.24, 0.82)
	if ability_detail_title != null:
		ability_detail_title.offset_left = 14.0
		ability_detail_title.offset_top = 14.0
		ability_detail_title.offset_right = 154.0
		ability_detail_title.offset_bottom = 31.0
		ability_detail_title.add_theme_font_size_override("font_size", 14)
		ability_detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ability_detail_title.modulate = UI_GOLD_TEXT
		ability_detail_title.clip_text = true
	if ability_detail_badges != null:
		ability_detail_badges.offset_left = 158.0
		ability_detail_badges.offset_top = 14.0
		ability_detail_badges.offset_right = ABILITY_DETAIL_PANEL_SIZE.x - 12.0
		ability_detail_badges.offset_bottom = 32.0
		ability_detail_badges.add_theme_constant_override("separation", 4)
	if ability_detail_body != null:
		ability_detail_body.offset_left = 14.0
		ability_detail_body.offset_top = 38.0
		ability_detail_body.offset_right = ABILITY_DETAIL_PANEL_SIZE.x - 14.0
		ability_detail_body.offset_bottom = 68.0
		ability_detail_body.add_theme_font_size_override("font_size", 11)
		ability_detail_body.add_theme_constant_override("line_spacing", 0)
		ability_detail_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ability_detail_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		ability_detail_body.modulate = Color(0.80, 0.83, 0.84, 0.94)
		ability_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ability_detail_body.clip_text = true
	if ability_detail_footer != null:
		ability_detail_footer.offset_left = 14.0
		ability_detail_footer.offset_top = 75.0
		ability_detail_footer.offset_right = ABILITY_DETAIL_PANEL_SIZE.x - 14.0
		ability_detail_footer.offset_bottom = 89.0
		ability_detail_footer.add_theme_font_size_override("font_size", 10)
		ability_detail_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ability_detail_footer.modulate = Color(0.58, 0.63, 0.66, 0.82)
		ability_detail_footer.clip_text = true

func _layout_boss_status_panel() -> void:
	if boss_status_title != null:
		boss_status_title.offset_left = 12.0
		boss_status_title.offset_top = 10.0
		boss_status_title.offset_right = 210.0
		boss_status_title.offset_bottom = 32.0
		boss_status_title.clip_text = true
	if boss_status_body != null:
		boss_status_body.offset_left = 12.0
		boss_status_body.offset_top = 42.0
		boss_status_body.offset_right = 210.0
		boss_status_body.offset_bottom = 160.0
		boss_status_body.add_theme_font_size_override("font_size", 13)
		boss_status_body.add_theme_constant_override("line_spacing", 0)
		boss_status_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		boss_status_body.clip_text = true

func _apply_selected_unit_card_style() -> void:
	if selected_unit_card_bg == null:
		return
	selected_unit_card_bg.color = Color(0.010, 0.011, 0.014, 0.78)
	if selected_unit_card_frame != null:
		selected_unit_card_frame.border_color = Color(0.30, 0.27, 0.22, 0.44)
		selected_unit_card_frame.border_width = 1.0

func _apply_squad_card_style(panel: Panel, selected: bool, acted: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.017, 0.022, 0.78)
	style.border_color = Color(0.22, 0.30, 0.32, 0.44)
	if selected:
		style.bg_color = Color(0.022, 0.034, 0.038, 0.88)
		style.border_color = Color(0.34, 0.88, 0.94, 0.72)
	elif acted:
		style.bg_color = Color(0.010, 0.012, 0.016, 0.66)
		style.border_color = Color(0.14, 0.16, 0.18, 0.42)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.shadow_color = Color(0, 0, 0, 0.26)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	panel.add_theme_stylebox_override("panel", style)

func _apply_top_label_panel_style(label: Label, border_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.019, 0.017, 0.76)
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	label.add_theme_stylebox_override("normal", style)

func _apply_top_status_cluster_style() -> void:
	if top_status_cluster == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.013, 0.011, 0.88)
	style.border_color = Color(0.64, 0.47, 0.25, 0.46)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	top_status_cluster.add_theme_stylebox_override("panel", style)

func _apply_top_status_panel_style(label: Label, accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.018, accent.g * 0.018, accent.b * 0.018, 0.0)
	style.border_color = Color(0, 0, 0, 0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	label.add_theme_stylebox_override("normal", style)

func _apply_bar_back_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.006, 0.007, 0.84)
	style.border_color = Color(0.42, 0.34, 0.24, 0.48)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", style)

func _apply_round_number_plate_style(panel: Panel) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.040, 0.034, 0.024, 0.92)
	style.border_color = Color(0.90, 0.62, 0.24, 0.70)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", style)

func _apply_layout_metrics() -> void:
	if top_bar_bg != null:
		top_bar_bg.offset_left = 0.0
		top_bar_bg.offset_top = 0.0
		top_bar_bg.offset_right = 1280.0
		top_bar_bg.offset_bottom = 64.0
	if top_status_cluster != null:
		top_status_cluster.offset_left = 16.0
		top_status_cluster.offset_top = 7.0
		top_status_cluster.offset_right = top_status_cluster.offset_left + TOP_STATUS_CLUSTER_SIZE.x
		top_status_cluster.offset_bottom = top_status_cluster.offset_top + TOP_STATUS_CLUSTER_SIZE.y
		_apply_top_status_cluster_style()
	if top_row != null:
		if sanctuary_label != null:
			top_row.move_child(sanctuary_label, 0)
		if round_label != null:
			top_row.move_child(round_label, 1)
		if objective_label != null:
			top_row.move_child(objective_label, 2)
		if phase_label != null:
			top_row.move_child(phase_label, 3)
		if undo_button != null:
			top_row.move_child(undo_button, top_row.get_child_count() - 2)
		if end_turn_button != null:
			top_row.move_child(end_turn_button, top_row.get_child_count() - 2)
		if settings_button != null:
			top_row.move_child(settings_button, top_row.get_child_count() - 1)
		top_row.offset_left = 16.0
		top_row.offset_top = 9.0
		top_row.offset_right = 1264.0
		top_row.offset_bottom = 59.0
		top_row.add_theme_constant_override("separation", 0)
	if sanctuary_label != null:
		sanctuary_label.custom_minimum_size = TOP_STATUS_SANCTUARY_SIZE
		sanctuary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		sanctuary_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		sanctuary_label.add_theme_font_size_override("font_size", 1)
		_apply_top_status_panel_style(sanctuary_label, Color(0.92, 0.58, 0.22, 1.0))
		_layout_sanctuary_text()
		_layout_sanctuary_bar()
	if round_label != null:
		round_label.custom_minimum_size = TOP_STATUS_ROUND_SIZE
		round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		round_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		round_label.add_theme_font_size_override("font_size", 1)
		_apply_top_status_panel_style(round_label, Color(0.76, 0.64, 0.36, 1.0))
		_layout_round_status_panel()
	if phase_label != null:
		phase_label.custom_minimum_size = Vector2(0, 0)
		phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		phase_label.visible = true
		phase_label.text = ""
	if objective_label != null:
		objective_label.visible = true
		objective_label.custom_minimum_size = TOP_STATUS_OBJECTIVE_SIZE
		objective_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		objective_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		objective_label.clip_text = true
		objective_label.add_theme_font_size_override("font_size", 13)
		objective_label.modulate = Color(0.74, 0.70, 0.62, 0.88)
		objective_label.add_theme_constant_override("line_spacing", 0)
		_apply_top_status_panel_style(objective_label, Color(0.72, 0.62, 0.42, 1.0))
	if top_status_divider_a != null:
		top_status_divider_a.offset_left = TOP_STATUS_SANCTUARY_SIZE.x
		top_status_divider_a.offset_top = 10.0
		top_status_divider_a.offset_right = top_status_divider_a.offset_left + 1.0
		top_status_divider_a.offset_bottom = TOP_STATUS_CLUSTER_SIZE.y - 10.0
		top_status_divider_a.color = Color(0.72, 0.48, 0.22, 0.34)
	if top_status_divider_b != null:
		top_status_divider_b.offset_left = TOP_STATUS_SANCTUARY_SIZE.x + TOP_STATUS_ROUND_SIZE.x
		top_status_divider_b.offset_top = 10.0
		top_status_divider_b.offset_right = top_status_divider_b.offset_left + 1.0
		top_status_divider_b.offset_bottom = TOP_STATUS_CLUSTER_SIZE.y - 10.0
		top_status_divider_b.color = Color(0.72, 0.48, 0.22, 0.26)
	if undo_button != null:
		undo_button.custom_minimum_size = Vector2(84, 36)
	if end_turn_button != null:
		end_turn_button.custom_minimum_size = Vector2(104, 36)
		end_turn_button.text = "结束回合"
	if confirm_deploy_button != null:
		confirm_deploy_button.custom_minimum_size = Vector2(104, 36)
	if settings_button != null:
		settings_button.custom_minimum_size = Vector2(40, 36)
	if help_label != null:
		help_label.offset_left = 16.0
		help_label.offset_top = 62.0
		help_label.offset_right = 584.0
		help_label.offset_bottom = 92.0
		help_label.visible = false
	if command_deck_bg != null:
		command_deck_bg.visible = false
	if squad_strip_bg != null:
		squad_strip_bg.offset_left = 16.0
		squad_strip_bg.offset_top = 74.0
		squad_strip_bg.offset_right = 182.0
		squad_strip_bg.offset_bottom = 318.0
		_clear_generated_panel_art(squad_strip_bg)
		squad_strip_bg.color = Color(0, 0, 0, 0)
		squad_strip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if squad_strip_row != null:
		squad_strip_row.offset_left = 0.0
		squad_strip_row.offset_top = 0.0
		squad_strip_row.offset_right = SQUAD_CARD_SIZE.x
		squad_strip_row.offset_bottom = 236.0
		squad_strip_row.add_theme_constant_override("separation", 8)
	if enemy_stack_bg != null:
		enemy_stack_bg.offset_left = 1040.0
		enemy_stack_bg.offset_top = 74.0
		enemy_stack_bg.offset_right = 1264.0
		enemy_stack_bg.offset_bottom = 288.0
	if enemy_stack_title != null:
		enemy_stack_title.text = "敌方顺序"
		enemy_stack_title.offset_right = 172.0
	if enemy_stack_mode != null:
		enemy_stack_mode.visible = false
	if enemy_stack_scroll != null:
		enemy_stack_scroll.offset_left = 8.0
		enemy_stack_scroll.offset_top = 42.0
		enemy_stack_scroll.offset_right = 216.0
		enemy_stack_scroll.offset_bottom = 184.0
	if enemy_stack_row != null:
		enemy_stack_row.offset_left = 0.0
		enemy_stack_row.offset_top = 0.0
		enemy_stack_row.offset_right = ENEMY_STACK_ROW_SIZE.x
		enemy_stack_row.offset_bottom = 0.0
		enemy_stack_row.add_theme_constant_override("separation", 6)
	if reward_panel_bg != null:
		reward_panel_bg.offset_left = 1040.0
		reward_panel_bg.offset_top = 298.0
		reward_panel_bg.offset_right = 1264.0
		reward_panel_bg.offset_bottom = 464.0
	if reward_task_row != null:
		reward_task_row.offset_left = 8.0
		reward_task_row.offset_top = 38.0
		reward_task_row.offset_right = 216.0
		reward_task_row.offset_bottom = 158.0
		reward_task_row.add_theme_constant_override("separation", 4)
	if boss_status_bg != null:
		boss_status_bg.offset_left = 1040.0
		boss_status_bg.offset_top = 434.0
		boss_status_bg.offset_right = 1264.0
		boss_status_bg.offset_bottom = 604.0
	_layout_boss_status_panel()
	if info_panel_bg != null:
		info_panel_bg.offset_left = 1040.0
		info_panel_bg.offset_top = 434.0
		info_panel_bg.offset_right = 1264.0
		info_panel_bg.offset_bottom = 604.0
	if ability_bar_bg != null:
		ability_bar_bg.offset_left = 190.0
		ability_bar_bg.offset_top = 616.0
		ability_bar_bg.offset_right = 1090.0
		ability_bar_bg.offset_bottom = 708.0
		_apply_command_bar_frame_style()
		var legacy_ability_border := ability_bar_bg.get_node_or_null("AbilityBarBorder")
		if legacy_ability_border is ReferenceRect:
			legacy_ability_border.visible = false
	if selected_unit_panel_bg != null:
		selected_unit_panel_bg.offset_left = 190.0
		selected_unit_panel_bg.offset_top = 616.0
		selected_unit_panel_bg.offset_right = 1090.0
		selected_unit_panel_bg.offset_bottom = 708.0
	if command_divider != null:
		command_divider.visible = false
	if selected_unit_card_bg != null:
		selected_unit_card_bg.offset_left = 0.0
		selected_unit_card_bg.offset_top = 0.0
		selected_unit_card_bg.offset_right = 252.0
		selected_unit_card_bg.offset_bottom = 92.0
		_apply_selected_unit_card_style()
	if ability_console_frame != null:
		ability_console_frame.offset_left = 262.0
		ability_console_frame.offset_top = 0.0
		ability_console_frame.offset_right = 900.0
		ability_console_frame.offset_bottom = 92.0
		_apply_command_console_style()
	if ability_title != null:
		ability_title.offset_left = 86.0
		ability_title.offset_top = 12.0
		ability_title.offset_right = 238.0
		ability_title.offset_bottom = 34.0
		ability_title.add_theme_font_size_override("font_size", 17)
		ability_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if ability_hp_label != null:
		ability_hp_label.offset_left = 86.0
		ability_hp_label.offset_top = 44.0
		ability_hp_label.offset_right = 238.0
		ability_hp_label.offset_bottom = 60.0
		ability_hp_label.add_theme_font_size_override("font_size", 11)
		ability_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if selected_unit_hp_bar != null:
		selected_unit_hp_bar.offset_left = 86.0
		selected_unit_hp_bar.offset_top = 35.0
		selected_unit_hp_bar.offset_right = selected_unit_hp_bar.offset_left + SELECTED_UNIT_HP_BAR_SIZE.x
		selected_unit_hp_bar.offset_bottom = selected_unit_hp_bar.offset_top + SELECTED_UNIT_HP_BAR_SIZE.y
	if ability_info_label != null:
		ability_info_label.offset_left = 86.0
		ability_info_label.offset_top = 64.0
		ability_info_label.offset_right = 238.0
		ability_info_label.offset_bottom = 82.0
		ability_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if ability_row != null:
		ability_row.visible = false
	if ability_stack != null:
		ability_stack.offset_left = 276.0
		ability_stack.offset_top = 8.0
		ability_stack.offset_right = 900.0
		ability_stack.offset_bottom = 84.0
		ability_stack.add_theme_constant_override("separation", 9)
	if ability_detail_panel != null and ability_bar_bg != null:
		_layout_ability_detail_panel(Vector2(ability_bar_bg.offset_left + 276.0, ability_bar_bg.offset_top))
	if item_slot_title != null:
		item_slot_title.visible = false
	if item_slot_row != null:
		item_slot_row.visible = false

func update_status(state: BattleState, can_undo: bool = false) -> void:
	_refresh_round_display(state)
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
	if phase_label != null:
		phase_label.text = ""
	_refresh_sanctuary_display()
	set_battle_status_summary(state)
	if end_turn_button != null:
		end_turn_button.disabled = state.phase != BattleState.Phase.PLAYER_ACTION
		end_turn_button.visible = state.phase != BattleState.Phase.GARRISON
	# Confirm-deploy is visible only in garrison, enabled when all wardens placed.
	if confirm_deploy_button != null:
		confirm_deploy_button.visible = state.phase == BattleState.Phase.GARRISON
		confirm_deploy_button.disabled = not state.pending_warden_defs.is_empty()
	if undo_button != null:
		undo_button.disabled = not can_undo

func _refresh_round_display(state: BattleState) -> void:
	if round_label == null:
		return
	_ensure_round_status_panel()
	_layout_round_status_panel()
	round_label.text = ""
	if state == null:
		if round_current_label != null:
			round_current_label.text = "-"
		if round_total_label != null:
			round_total_label.text = "/ -"
		_populate_round_progress(0, 1)
		return
	if state.phase == BattleState.Phase.GARRISON:
		if round_title_label != null:
			round_title_label.text = "阶段"
		if round_current_label != null:
			round_current_label.offset_left = 51.0
			round_current_label.offset_right = 112.0
			round_current_label.add_theme_font_size_override("font_size", 13)
			round_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			round_current_label.text = "布防"
		if round_total_label != null:
			round_total_label.text = ""
		_populate_round_progress(0, maxi(1, state.max_rounds))
		return
	if round_title_label != null:
		round_title_label.text = "回合"
	if round_current_label != null:
		round_current_label.offset_left = 53.0
		round_current_label.offset_right = 74.0
		round_current_label.add_theme_font_size_override("font_size", 16)
		round_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		round_current_label.text = str(state.current_round)
	if round_total_label != null:
		round_total_label.text = "/ %d" % state.max_rounds
	_populate_round_progress(state.current_round, state.max_rounds)

func _populate_round_progress(current_round: int, max_rounds: int) -> void:
	if round_progress_bar == null:
		return
	_clear_children(round_progress_bar)
	var count := maxi(1, max_rounds)
	var filled := clampi(current_round, 0, count)
	var gap := 2.0
	var width := round_progress_bar.offset_right - round_progress_bar.offset_left
	var segment_width := maxf(2.0, (width - float(count - 1) * gap) / float(count))
	for i in range(count):
		var segment := ColorRect.new()
		segment.name = "RoundProgress_%d" % i
		segment.offset_left = float(i) * (segment_width + gap)
		segment.offset_top = 0.0
		segment.offset_right = minf(width, segment.offset_left + segment_width)
		segment.offset_bottom = 4.0
		segment.color = Color(0.90, 0.58, 0.20, 0.88) if i < filled else Color(0.18, 0.16, 0.13, 0.86)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		round_progress_bar.add_child(segment)

func set_battle_status_summary(state: BattleState) -> void:
	if objective_label == null or state == null:
		return
	objective_label.text = _top_objective_text(state)
	_refresh_boss_status_panel(state)

func set_boss_status(state: BattleState) -> void:
	_refresh_boss_status_panel(state)

func _battle_status_summary_text(state: BattleState) -> String:
	return BattleStatusPresenter.battle_status_summary_text(state)

func _top_objective_text(state: BattleState) -> String:
	var summary := _battle_status_summary_text(state)
	var parts := summary.split("   ", false)
	return String(parts[0]) if not parts.is_empty() else summary

func _refresh_boss_status_panel(state: BattleState) -> void:
	if boss_status_bg == null:
		return
	if state == null or not state.has_boss():
		boss_status_bg.visible = false
		if boss_status_title != null:
			boss_status_title.text = ""
		if boss_status_body != null:
			boss_status_body.text = ""
		return
	boss_status_bg.visible = true
	_layout_boss_status_panel()
	if boss_status_title != null:
		boss_status_title.text = BattleStatusPresenter.boss_status_title_text(state)
	if boss_status_body != null:
		boss_status_body.text = "\n".join(BattleStatusPresenter.boss_status_lines(state))

func set_help(text: String) -> void:
	if help_label == null:
		help_label = get_node_or_null("Root/HelpLabel")
	if help_label == null:
		return
	help_label.text = text
	help_label.visible = false

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
	if selected_unit_panel_bg != null and selected_unit_panel_bg != ability_bar_bg:
		selected_unit_panel_bg.visible = false
	if command_divider != null:
		command_divider.visible = false
	var data: Dictionary = warden_data if warden_data is Dictionary else {"name": str(warden_data)}
	var hp := int(data.get("hp", 0))
	var max_hp := int(data.get("max_hp", hp))
	ability_title.text = data.get("name", "守卫者")
	ability_hp_label.text = _hp_text(hp, max_hp)
	ability_info_label.text = "移 %d" % int(data.get("move", 0))
	ability_portrait.texture = data.get("token", null)
	_layout_selected_unit_panel()
	_populate_selected_unit_hp_bar(hp, max_hp)
	if ability_row != null:
		_clear_children(ability_row)
		ability_row.visible = false
	if ability_stack == null:
		return
	_clear_children(ability_stack)
	var displayed_abilities := abilities.slice(0, min(3, abilities.size()))
	_armed_ability_detail.clear()
	for i in range(displayed_abilities.size()):
		var ab: Dictionary = displayed_abilities[i]
		ab["slot_index"] = i
		var cooldown_rounds := int(ab.get("cooldown_rounds", 0))
		var cooldown_remaining := int(ab.get("cooldown_remaining", 0))
		var is_cooling_down := cooldown_remaining > 0
		if bool(ab.get("is_armed", false)):
			_armed_ability_detail = ab.duplicate(true)
		var slot := Control.new()
		slot.custom_minimum_size = LEFT_ACTION_SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		ability_stack.add_child(slot)

		var plate := Panel.new()
		plate.anchor_right = 1.0
		plate.anchor_bottom = 1.0
		plate.offset_right = 0.0
		plate.offset_bottom = 0.0
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_action_button_style(plate, ab)
		slot.add_child(plate)

		var top_glint := ColorRect.new()
		top_glint.offset_left = 8.0
		top_glint.offset_top = 1.0
		top_glint.offset_right = LEFT_ACTION_SLOT_SIZE.x - 8.0
		top_glint.offset_bottom = 2.0
		top_glint.color = Color(1.0, 0.72, 0.34, 0.10 if bool(ab.get("active", true)) else 0.035)
		top_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(top_glint)

		var btn := Button.new()
		btn.anchor_right = 1.0
		btn.anchor_bottom = 1.0
		btn.offset_right = 0.0
		btn.offset_bottom = 0.0
		btn.flat = true
		btn.text = ""
		btn.disabled = false
		slot.add_child(btn)

		var key := Label.new()
		key.offset_left = LEFT_ACTION_SLOT_SIZE.x - 28.0
		key.offset_top = 5.0
		key.offset_right = LEFT_ACTION_SLOT_SIZE.x - 8.0
		key.offset_bottom = 22.0
		key.text = str(i + 1)
		key.add_theme_font_size_override("font_size", 10)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key.modulate = Color(0.48, 0.44, 0.38, 0.90)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(key)

		var icon_frame := Panel.new()
		icon_frame.offset_left = 10.0
		icon_frame.offset_top = 14.0
		icon_frame.offset_right = 48.0
		icon_frame.offset_bottom = 52.0
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon_style := StyleBoxFlat.new()
		icon_style.bg_color = Color(0.018, 0.017, 0.015, 0.82)
		icon_style.border_color = Color(0.54, 0.44, 0.30, 0.52)
		icon_style.border_width_left = 1
		icon_style.border_width_top = 1
		icon_style.border_width_right = 1
		icon_style.border_width_bottom = 1
		icon_frame.add_theme_stylebox_override("panel", icon_style)
		slot.add_child(icon_frame)

		var icon := TextureRect.new()
		icon.offset_left = 15.0
		icon.offset_top = 19.0
		icon.offset_right = 43.0
		icon.offset_bottom = 47.0
		icon.texture = _ability_icon_texture(ab.get("id", ""))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		var icon_text := Label.new()
		icon_text.offset_left = 10.0
		icon_text.offset_top = 14.0
		icon_text.offset_right = 48.0
		icon_text.offset_bottom = 52.0
		icon_text.text = str(ab.get("icon", ""))
		icon_text.add_theme_font_size_override("font_size", 22)
		icon_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_text.visible = icon.texture == null
		slot.add_child(icon_text)

		if is_cooling_down:
			var icon_scrim := ColorRect.new()
			icon_scrim.name = "CooldownIconScrim"
			icon_scrim.offset_left = icon_frame.offset_left + 1.0
			icon_scrim.offset_top = icon_frame.offset_top + 1.0
			icon_scrim.offset_right = icon_frame.offset_right - 1.0
			icon_scrim.offset_bottom = icon_frame.offset_bottom - 1.0
			icon_scrim.color = Color(0.010, 0.013, 0.024, 0.70)
			icon_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon_scrim)

		if is_cooling_down:
			var cooldown_ring_bg := TextureRect.new()
			cooldown_ring_bg.name = "CooldownRingMuted"
			_layout_cooldown_ring(cooldown_ring_bg, icon_frame)
			cooldown_ring_bg.texture = ICON_COOLDOWN_RING_MUTED
			slot.add_child(cooldown_ring_bg)

			var cooldown_ring := TextureRect.new()
			cooldown_ring.name = "CooldownRing"
			_layout_cooldown_ring(cooldown_ring, icon_frame)
			cooldown_ring.texture = ICON_COOLDOWN_RING
			var cooldown_material := ShaderMaterial.new()
			cooldown_material.shader = SHADER_COOLDOWN_RADIAL_CLIP
			cooldown_material.set_shader_parameter("progress", float(cooldown_remaining) / float(maxi(1, cooldown_rounds)))
			cooldown_ring.material = cooldown_material
			slot.add_child(cooldown_ring)

			var cooldown_badge := _make_cooldown_count_badge(cooldown_remaining, icon_frame)
			slot.add_child(cooldown_badge)

		var name := Label.new()
		name.offset_left = 58.0
		name.offset_top = 13.0
		name.offset_right = LEFT_ACTION_SLOT_SIZE.x - 18.0
		name.offset_bottom = 33.0
		name.text = ab.get("name", "?")
		name.add_theme_font_size_override("font_size", 15)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.clip_text = true
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(name)

		var desc := Label.new()
		desc.offset_left = 58.0
		desc.offset_top = 35.0
		desc.offset_right = LEFT_ACTION_SLOT_SIZE.x - 18.0
		desc.offset_bottom = 65.0
		desc.text = _ability_slot_meta(ab)
		desc.add_theme_font_size_override("font_size", 10)
		desc.add_theme_constant_override("line_spacing", -1)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.clip_text = true
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc.visible = desc.text != ""
		slot.add_child(desc)

		if is_cooling_down:
			var card_scrim := ColorRect.new()
			card_scrim.name = "CooldownCardScrim"
			card_scrim.anchor_right = 1.0
			card_scrim.anchor_bottom = 1.0
			card_scrim.offset_right = 0.0
			card_scrim.offset_bottom = 0.0
			card_scrim.color = Color(0.005, 0.007, 0.012, 0.32)
			card_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(card_scrim)
			if slot.has_node("CooldownRingMuted"):
				slot.move_child(slot.get_node("CooldownRingMuted"), slot.get_child_count() - 1)
			if slot.has_node("CooldownRing"):
				slot.move_child(slot.get_node("CooldownRing"), slot.get_child_count() - 1)
			if slot.has_node("CooldownCountBadge"):
				slot.move_child(slot.get_node("CooldownCountBadge"), slot.get_child_count() - 1)

		var tint := Color(0.86, 0.86, 0.88, 1.0)
		var desc_tint := UI_TEXT_DIM
		if ab.get("is_armed", false):
			tint = Color(1.0, 0.88, 0.48, 1.0)
			desc_tint = Color(1.0, 0.78, 0.36, 0.92)
		elif ab.get("is_default", false):
			tint = Color(1.0, 0.84, 0.48, 1.0)
			desc_tint = Color(0.90, 0.73, 0.40, 0.94)
		if not bool(ab.get("active", true)):
			tint = Color(0.50, 0.52, 0.56, 0.86)
			desc_tint = Color(0.50, 0.54, 0.58, 0.84)
		icon.modulate = tint
		icon_text.modulate = tint
		name.modulate = tint
		desc.modulate = desc_tint
		var ab_id: String = ab.get("id", "")
		if ab_id != "":
			btn.pressed.connect(func():
				if bool(ab.get("active", true)):
					ability_selected.emit(ab_id)
				else:
					ability_unavailable.emit(ab_id, _ability_unavailable_reason(ab))
					_show_ability_detail(ab, true)
			)
		slot.mouse_entered.connect(func(): _show_ability_detail(ab))
		slot.mouse_exited.connect(_on_ability_slot_exited)
	if not _armed_ability_detail.is_empty():
		_show_ability_detail(_armed_ability_detail, true)
	elif ability_detail_panel != null:
		_hide_ability_detail()

func hide_ability_bar() -> void:
	if ability_bar_bg == null:
		return
	ability_bar_bg.visible = false
	if selected_unit_panel_bg != null and selected_unit_panel_bg != ability_bar_bg:
		selected_unit_panel_bg.visible = false
	if command_divider != null:
		command_divider.visible = false
	ability_portrait.texture = null
	_hovered_ability.clear()
	_armed_ability_detail.clear()
	_hide_ability_detail()

func _layout_cooldown_ring(ring: TextureRect, icon_frame: Control) -> void:
	ring.offset_left = icon_frame.offset_left - 7.0
	ring.offset_top = icon_frame.offset_top - 7.0
	ring.offset_right = icon_frame.offset_right + 7.0
	ring.offset_bottom = icon_frame.offset_bottom + 7.0
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _make_cooldown_count_badge(cooldown_remaining: int, icon_frame: Control) -> Label:
	var badge := Label.new()
	badge.name = "CooldownCountBadge"
	var badge_size := 18.0 if cooldown_remaining < 10 else 22.0
	badge.offset_left = icon_frame.offset_right - 9.0
	badge.offset_top = icon_frame.offset_top - 8.0
	badge.offset_right = badge.offset_left + badge_size
	badge.offset_bottom = badge.offset_top + 18.0
	badge.text = str(cooldown_remaining)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52, 1.0))
	badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	badge.add_theme_constant_override("shadow_offset_x", 0)
	badge.add_theme_constant_override("shadow_offset_y", 1)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.070, 0.048, 0.030, 0.96)
	style.border_color = Color(1.0, 0.55, 0.16, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	badge.add_theme_stylebox_override("normal", style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge

func _layout_selected_unit_panel() -> void:
	if ability_bar_bg == null:
		return
	if command_divider != null:
		command_divider.visible = false
	if ability_console_frame != null:
		ability_console_frame.offset_left = 262.0
		ability_console_frame.offset_top = 0.0
		ability_console_frame.offset_right = 900.0
		ability_console_frame.offset_bottom = 92.0
		_apply_command_console_style()
	if selected_unit_card_bg != null:
		selected_unit_card_bg.offset_left = 0.0
		selected_unit_card_bg.offset_top = 0.0
		selected_unit_card_bg.offset_right = 252.0
		selected_unit_card_bg.offset_bottom = 92.0
		_apply_selected_unit_card_style()
	if ability_portrait_frame != null:
		ability_portrait_frame.offset_left = 10.0
		ability_portrait_frame.offset_top = 8.0
		ability_portrait_frame.offset_right = 76.0
		ability_portrait_frame.offset_bottom = 82.0
	if ability_title != null:
		ability_title.offset_left = 86.0
		ability_title.offset_top = 12.0
		ability_title.offset_right = 238.0
		ability_title.offset_bottom = 34.0
		ability_title.add_theme_font_size_override("font_size", 17)
		ability_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if ability_hp_label != null:
		ability_hp_label.offset_left = 86.0
		ability_hp_label.offset_top = 44.0
		ability_hp_label.offset_right = 238.0
		ability_hp_label.offset_bottom = 60.0
		ability_hp_label.add_theme_font_size_override("font_size", 11)
		ability_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if selected_unit_hp_bar != null:
		selected_unit_hp_bar.offset_left = 86.0
		selected_unit_hp_bar.offset_top = 35.0
		selected_unit_hp_bar.offset_right = selected_unit_hp_bar.offset_left + SELECTED_UNIT_HP_BAR_SIZE.x
		selected_unit_hp_bar.offset_bottom = selected_unit_hp_bar.offset_top + SELECTED_UNIT_HP_BAR_SIZE.y
	if ability_info_label != null:
		ability_info_label.offset_left = 86.0
		ability_info_label.offset_top = 64.0
		ability_info_label.offset_right = 238.0
		ability_info_label.offset_bottom = 82.0
		ability_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if ability_stack != null:
		ability_stack.offset_left = 276.0
		ability_stack.offset_top = 8.0
		ability_stack.offset_right = 900.0
		ability_stack.offset_bottom = 84.0
		ability_stack.add_theme_constant_override("separation", 9)
	if ability_detail_panel != null and ability_bar_bg != null:
		_layout_ability_detail_panel(Vector2(ability_bar_bg.offset_left + 276.0, ability_bar_bg.offset_top))

func set_sanctuary(value: int, max_value: int) -> void:
	sanctuary_integrity = value
	sanctuary_integrity_max = max_value
	_refresh_sanctuary_display()

func set_sanctuary_preview_loss(loss: int) -> void:
	var next_loss := maxi(0, loss)
	if sanctuary_preview_loss == next_loss:
		return
	sanctuary_preview_loss = next_loss
	_refresh_sanctuary_display()

func get_sanctuary_preview_loss() -> int:
	return sanctuary_preview_loss

func _refresh_sanctuary_display() -> void:
	if sanctuary_label == null:
		return
	_ensure_sanctuary_panel()
	sanctuary_label.text = ""
	if sanctuary_value_label != null:
		sanctuary_value_label.text = "%d/%d" % [maxi(0, sanctuary_integrity), maxi(1, sanctuary_integrity_max)]
		var ratio := float(maxi(0, sanctuary_integrity)) / float(maxi(1, sanctuary_integrity_max))
		sanctuary_value_label.modulate = UI_DANGER if ratio <= 0.25 else Color(0.88, 0.92, 0.92, 0.86)
	_populate_sanctuary_bar()

func _populate_sanctuary_bar() -> void:
	if sanctuary_bar == null:
		return
	_clear_children(sanctuary_bar)
	var segment_count := maxi(1, sanctuary_integrity_max)
	var filled_count := clampi(sanctuary_integrity, 0, segment_count)
	var preview_count := clampi(sanctuary_preview_loss, 0, filled_count)
	var preview_start := filled_count - preview_count
	var gap := 1.0 if segment_count > 10 else HP_SEGMENT_GAP
	var segment_width := maxf(2.0, (SANCTUARY_BAR_SIZE.x - float(segment_count - 1) * gap) / float(segment_count))
	for i in range(segment_count):
		var segment := ColorRect.new()
		segment.name = "SanctuarySegment_%d" % i
		segment.offset_left = float(i) * (segment_width + gap)
		segment.offset_top = 0.0
		segment.offset_right = minf(SANCTUARY_BAR_SIZE.x, segment.offset_left + segment_width)
		segment.offset_bottom = SANCTUARY_BAR_SIZE.y
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < filled_count:
			segment.color = UI_HP_PREVIEW if i >= preview_start else UI_HP_FILL
		else:
			segment.color = UI_HP_EMPTY
		sanctuary_bar.add_child(segment)
		var sheen := ColorRect.new()
		sheen.name = "Sheen"
		sheen.anchor_right = 1.0
		sheen.offset_left = 0.0
		sheen.offset_top = 0.0
		sheen.offset_right = 0.0
		sheen.offset_bottom = 2.0
		sheen.color = Color(1.0, 0.84, 0.42, 0.16) if i < filled_count else Color(0, 0, 0, 0)
		sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.add_child(sheen)
		if i < filled_count and i >= preview_start:
			_add_sanctuary_preview_crack(segment)
	_apply_sanctuary_preview_pulse()

func _add_sanctuary_preview_crack(segment: Control) -> void:
	var crack := ColorRect.new()
	crack.name = "PreviewCrack"
	crack.offset_left = maxf(1.0, (segment.offset_right - segment.offset_left) * 0.42)
	crack.offset_top = 1.0
	crack.offset_right = crack.offset_left + 1.0
	crack.offset_bottom = SANCTUARY_BAR_SIZE.y - 1.0
	crack.rotation = 0.45
	crack.color = Color(1.0, 0.82, 0.45, 0.92)
	crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segment.add_child(crack)

func _apply_sanctuary_preview_pulse() -> void:
	if sanctuary_bar == null:
		return
	var pulse := 0.72 + 0.28 * (0.5 + 0.5 * sin(_sanctuary_pulse_t * 7.0))
	for child in sanctuary_bar.get_children():
		if not child is ColorRect:
			continue
		var segment: ColorRect = child
		var idx := int(String(segment.name).trim_prefix("SanctuarySegment_"))
		var filled_count := clampi(sanctuary_integrity, 0, maxi(1, sanctuary_integrity_max))
		var preview_count := clampi(sanctuary_preview_loss, 0, filled_count)
		if preview_count > 0 and idx >= filled_count - preview_count and idx < filled_count:
			var color := UI_HP_PREVIEW
			color.a *= pulse
			segment.color = color
			for nested in segment.get_children():
				if nested is ColorRect:
					var crack: ColorRect = nested
					crack.color = Color(1.0, 0.82, 0.45, 0.70 + 0.22 * pulse)
		elif idx < filled_count:
			segment.color = UI_HP_FILL
		else:
			segment.color = UI_HP_EMPTY

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
		var card := Control.new()
		card.custom_minimum_size = SQUAD_CARD_SIZE
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		squad_strip_row.add_child(card)
		var selected := unit.id == selected_id

		var card_art := Panel.new()
		card_art.anchor_right = 1.0
		card_art.anchor_bottom = 1.0
		card_art.offset_right = 0.0
		card_art.offset_bottom = 0.0
		card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_squad_card_style(card_art, selected, unit.has_acted)
		card.add_child(card_art)

		var status_rail := ColorRect.new()
		status_rail.offset_left = 0.0
		status_rail.offset_top = 0.0
		status_rail.offset_right = 4.0
		status_rail.offset_bottom = SQUAD_CARD_SIZE.y
		status_rail.color = _squad_state_color(unit, selected)
		status_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(status_rail)

		var portrait_well := Panel.new()
		portrait_well.offset_left = 9.0
		portrait_well.offset_top = 7.0
		portrait_well.offset_right = 55.0
		portrait_well.offset_bottom = 57.0
		portrait_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_squad_portrait_well_style(portrait_well, selected, unit.has_acted)
		card.add_child(portrait_well)

		var portrait_glow := ColorRect.new()
		portrait_glow.offset_left = 13.0
		portrait_glow.offset_top = 11.0
		portrait_glow.offset_right = 51.0
		portrait_glow.offset_bottom = 25.0
		portrait_glow.color = Color(0.34, 0.82, 0.92, 0.08 if selected else 0.025)
		portrait_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait_glow)

		var portrait := TextureRect.new()
		portrait.name = "SquadPortrait"
		portrait.offset_left = 5.0
		portrait.offset_top = -4.0
		portrait.offset_right = 62.0
		portrait.offset_bottom = 64.0
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = _unit_hud_portrait(unit)
		portrait.modulate = Color(0.42, 0.42, 0.42, 0.88) if unit.has_acted else Color.WHITE
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)

		var name := Label.new()
		name.offset_left = 63.0
		name.offset_top = 8.0
		name.offset_right = SQUAD_CARD_SIZE.x - 8.0
		name.offset_bottom = 27.0
		name.add_theme_font_size_override("font_size", 15)
		name.clip_text = true
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.modulate = Color(0.76, 1.0, 1.0, 1.0) if selected else Color(0.88, 0.90, 0.92, 0.94)
		name.text = _short_unit_name(unit)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name)

		var state := Label.new()
		state.offset_left = 63.0
		state.offset_top = 28.0
		state.offset_right = SQUAD_CARD_SIZE.x - 8.0
		state.offset_bottom = 44.0
		state.add_theme_font_size_override("font_size", 10)
		state.clip_text = true
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state.modulate = Color(0.52, 0.90, 0.96, 0.86) if selected else Color(0.62, 0.66, 0.68, 0.78)
		state.text = _squad_state_text(unit)
		state.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(state)

		_add_squad_hp_bar(card, unit.hp, unit.def.max_hp if unit.def != null else unit.hp)

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
		row.custom_minimum_size = Vector2(208, 36)
		reward_task_row.add_child(row)
		_apply_panel_frame(row, Color(0.030, 0.032, 0.038, 0.78), Color(0.18, 0.21, 0.24, 0.54), 3, 1)

		var mark := Label.new()
		mark.offset_left = 4.0
		mark.offset_top = 7.0
		mark.offset_right = 22.0
		mark.offset_bottom = 29.0
		mark.add_theme_font_size_override("font_size", 12)
		var failed := bool(state.reward_failed.get(task, false))
		var completed := bool(state.reward_completed.get(task, false))
		mark.text = "✓" if completed else ("×" if failed else "◆")
		mark.modulate = Color(0.55, 0.95, 0.60, 1.0) if completed else (Color(1.0, 0.35, 0.35, 1.0) if failed else Color(1.0, 0.78, 0.38, 1.0))
		row.add_child(mark)

		var label := Label.new()
		label.offset_left = 24.0
		label.offset_top = 6.0
		label.offset_right = 202.0
		label.offset_bottom = 30.0
		label.add_theme_font_size_override("font_size", 13)
		label.modulate = Color(0.95, 0.88, 0.74, 0.62 if failed else 1.0)
		label.text = _reward_task_text(task, state)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)

func _reward_task_text(task: StringName, state: BattleState) -> String:
	match task:
		BattleState.REWARD_PERFECT_DEFENSE:
			return "完美防守   未毁"
		BattleState.REWARD_TERMINAL_CLEAR:
			return "终局清场   %d" % int(state.reward_progress.get(task, state.enemies().size()))
		BattleState.REWARD_PHYSICAL_KILLS_3:
			return "物理击杀   %d/3" % int(state.reward_progress.get(task, 0))
		BattleState.REWARD_PUSH_THREAT:
			return "推离威胁   %d/1" % int(state.reward_progress.get(task, 0))
		BattleState.REWARD_ALL_WARDENS_SURVIVE:
			return "全员存活   阵亡 %d" % int(state.reward_progress.get(task, 0))
		BattleState.REWARD_RIFT_SUPPRESSION:
			return "裂隙压制   %d/1" % int(state.reward_progress.get(task, 0))
		BattleState.REWARD_LOW_LOSS_LINE:
			return "低损防线   受损 %d/1" % int(state.reward_progress.get(task, 0))
		BattleState.REWARD_ELITE_HUNT:
			return "精英猎杀   %d/1" % int(state.reward_progress.get(task, 0))
		BattleState.REWARD_KEY_TARGET_UNDAMAGED:
			return "关键无伤   受损 %d" % int(state.reward_progress.get(task, 0))
		BattleState.REWARD_ANCHOR_DESTROY:
			return "锚石破坏   %d/%d" % [
				int(state.reward_progress.get(task, 0)),
			state.boss_anchor_positions.size(),
			]
		BattleState.REWARD_PERFECT_WATCH:
			return "完美守夜   未毁"
		BattleState.REWARD_HEART_WINDOW:
			return "暴露窗口   %d/%d" % [
				int(state.reward_progress.get(task, 0)),
			state.heart_hit_cap,
			]
	return str(task)

func _hp_text(hp: int, max_hp: int) -> String:
	return "生命 %d/%d" % [clampi(hp, 0, maxi(1, max_hp)), maxi(1, max_hp)]

func _show_ability_detail(ability: Dictionary, force: bool = false) -> void:
	if ability_detail_panel == null:
		return
	_hovered_ability = ability.duplicate(true)
	var slot_index := int(ability.get("slot_index", 0))
	var slot_center := ability_bar_bg.offset_left + ability_stack.offset_left + float(slot_index) * (LEFT_ACTION_SLOT_SIZE.x + 9.0) + LEFT_ACTION_SLOT_SIZE.x * 0.5
	var anchor := Vector2(slot_center, ability_bar_bg.offset_top)
	_layout_ability_detail_panel(anchor)
	_populate_ability_detail(ability, force)
	ability_detail_panel.visible = true

func _on_ability_slot_exited() -> void:
	if not _armed_ability_detail.is_empty():
		_show_ability_detail(_armed_ability_detail, true)
		return
	_hovered_ability.clear()
	_hide_ability_detail()

func _hide_ability_detail() -> void:
	if ability_detail_panel != null:
		ability_detail_panel.visible = false

func _populate_ability_detail(ability: Dictionary, force: bool = false) -> void:
	if ability_detail_title == null or ability_detail_body == null or ability_detail_footer == null or ability_detail_badges == null:
		return
	ability_detail_title.text = str(ability.get("name", "技能"))
	_clear_children(ability_detail_badges)
	for badge in _ability_detail_badges(ability):
		ability_detail_badges.add_child(_make_ability_detail_badge(badge))
	ability_detail_body.text = _ability_detail_body_text(ability, force)
	ability_detail_footer.text = _ability_detail_footer_text(ability, force)

func _ability_detail_badges(ability: Dictionary) -> Array[String]:
	var desc := String(ability.get("desc", ""))
	var target_rule := String(ability.get("target_rule", ""))
	var badges: Array[String] = []
	var cooldown_remaining := int(ability.get("cooldown_remaining", 0))
	if cooldown_remaining > 0:
		_append_unique_badge(badges, "冷却 %d" % cooldown_remaining)
	if bool(ability.get("upgraded", false)):
		_append_unique_badge(badges, "强化")
	if target_rule.find("adjacent") != -1 or desc.find("近战") != -1:
		_append_unique_badge(badges, "近战")
	if target_rule.find("line") != -1 or desc.find("远程") != -1 or desc.find("直线") != -1:
		_append_unique_badge(badges, "直线")
	if target_rule.find("protected_building") != -1:
		_append_unique_badge(badges, "建筑")
	if target_rule.find("rift") != -1:
		_append_unique_badge(badges, "裂隙")
	if target_rule.find("empty") != -1:
		_append_unique_badge(badges, "区域")
	if desc.find("伤") != -1:
		var parts := desc.split(" ", false)
		for p in parts:
			if String(p).find("伤") != -1:
				_append_unique_badge(badges, p)
				break
	if desc.find("推") != -1:
		_append_unique_badge(badges, "推动")
	if desc.find("拉") != -1:
		_append_unique_badge(badges, "拉近")
	if desc.find("换位") != -1:
		_append_unique_badge(badges, "换位")
	if desc.find("修复") != -1 or desc.find("护盾") != -1:
		_append_unique_badge(badges, "守护")
	if badges.is_empty():
		badges.append("技能")
	return badges.slice(0, min(3, badges.size()))

func _append_unique_badge(badges: Array[String], text: String) -> void:
	if text == "":
		return
	if not badges.has(text):
		badges.append(text)

func _make_ability_detail_badge(text: String) -> Control:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(maxf(38.0, float(text.length()) * 11.0 + 14.0), 17.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.038, 0.034, 0.028, 0.64)
	style.border_color = Color(0.54, 0.42, 0.28, 0.34)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 6.0
	label.offset_right = -6.0
	label.offset_bottom = 0.0
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(0.88, 0.72, 0.46, 0.88)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge

func _ability_detail_body_text(ability: Dictionary, force: bool) -> String:
	var id := String(ability.get("id", ""))
	var desc := String(ability.get("desc", "")).strip_edges()
	match id:
		"attack", "bounty_chain_strike", "mage_repulsion_bolt":
			if desc.find("推") != -1:
				return "造成伤害并推动目标；碰撞、坠落按棋盘规则结算。"
			if desc.find("拉") != -1:
				return "造成伤害，并把目标向施法者方向拉近。用于改变敌方攻击位置。"
			return "造成伤害。选择目标后可预览结算结果。"
		"graverobber_hook_rope":
			return "直线造成伤害并拉近敌人，用来改写敌方攻击线。"
		"bounty_guard_shoulder", "guard_shoulder":
			return "与相邻单位换位并撞伤敌人，用来替建筑承压。"
		"bounty_execute":
			return "限次收尾技，适合击杀残血敌人并完成悬赏。"
		"graverobber_rift_wedge", "rift_wedge":
			return "延迟目标裂隙刷新；若敌人在裂隙上会受到伤害。"
		"graverobber_backhand_throw", "backhand_throw":
			return "直线拉近目标后尝试侧推，适合打断敌方攻击线。"
		"mage_ward_fire", "ward_fire":
			var shield_amount := int(ability.get("shield_amount", 1))
			return "为保护建筑提供护盾，抵消下一次 %d 点伤害。" % maxi(1, shield_amount)
		"mage_sigil", "sigil":
			var duration := int(ability.get("duration_rounds", 2))
			return "在空地布置持续 %d 回合的减速法阵，拖慢敌人进攻。" % maxi(1, duration)
		"wait":
			return "结束当前玩家回合，交给敌方按顺序执行。"
	if desc != "":
		return desc
	return "该技能尚未配置完整说明。"

func _ability_detail_footer_text(ability: Dictionary, force: bool) -> String:
	if not bool(ability.get("active", true)):
		var reason := _ability_unavailable_reason(ability)
		return "不可用：%s。" % (reason if reason != "" else "当前条件不满足")
	if force or bool(ability.get("is_armed", false)):
		return "选择有效目标；再次点击技能可取消瞄准。"
	return "点击技能进入瞄准态。"

func _ability_unavailable_reason(ability: Dictionary) -> String:
	var cooldown_remaining := int(ability.get("cooldown_remaining", 0))
	if cooldown_remaining > 0:
		return "冷却 %d 回合" % cooldown_remaining
	var reason := String(ability.get("disabled_reason", "")).strip_edges()
	if reason != "":
		return reason
	var code := String(ability.get("disabled_reason_code", ""))
	match code:
		"acted":
			return "已行动"
		"uses_exhausted":
			return "次数用尽"
		"no_target":
			return "无有效目标"
		"cooldown":
			return "冷却中"
		"wrong_phase":
			return "非玩家回合"
		"not_equipped":
			return "未装备"
	if not bool(ability.get("active", true)):
		return "当前条件不满足"
	return ""

func _populate_selected_unit_hp_bar(hp: int, max_hp: int) -> void:
	if selected_unit_hp_bar == null:
		return
	_populate_segmented_hp_bar(selected_unit_hp_bar, hp, max_hp, SELECTED_UNIT_HP_BAR_SIZE, UI_HP_FILL, UI_HP_CRITICAL, UI_HP_EMPTY)

func _add_squad_hp_bar(card: Control, hp: int, max_hp: int) -> void:
	var bar := Control.new()
	bar.name = "SquadHpBar"
	bar.offset_left = 63.0
	bar.offset_top = 49.0
	bar.offset_right = bar.offset_left + SQUAD_HP_BAR_SIZE.x
	bar.offset_bottom = bar.offset_top + SQUAD_HP_BAR_SIZE.y
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bar)
	_populate_segmented_hp_bar(bar, hp, max_hp, SQUAD_HP_BAR_SIZE, UI_HP_FILL, UI_HP_CRITICAL, UI_HP_EMPTY)

func _apply_squad_portrait_well_style(panel: Panel, selected: bool, acted: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.012, 0.016, 0.92)
	style.border_color = Color(0.18, 0.27, 0.30, 0.74)
	if selected:
		style.bg_color = Color(0.012, 0.026, 0.030, 0.96)
		style.border_color = Color(0.34, 0.86, 0.92, 0.72)
	elif acted:
		style.bg_color = Color(0.008, 0.010, 0.014, 0.84)
		style.border_color = Color(0.14, 0.17, 0.20, 0.62)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", style)

func _apply_squad_action_badge_style(panel: Panel, unit: Unit) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = _squad_state_color(unit, false)
	style.border_color = Color(0.92, 0.95, 0.95, 0.22)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", style)

func _squad_state_color(unit: Unit, selected: bool) -> Color:
	if unit == null:
		return UI_BORDER_SOFT
	if unit.has_acted:
		return Color(0.32, 0.34, 0.38, 0.82)
	if unit.has_moved:
		return Color(0.92, 0.62, 0.24, 0.92)
	if selected:
		return Color(0.42, 0.95, 1.0, 0.98)
	return UI_SAFE

func _squad_state_text(unit: Unit) -> String:
	if unit == null:
		return ""
	if unit.has_acted:
		return "已行动"
	if unit.has_moved:
		return "已移动"
	return "待命"

func _unit_hud_portrait(unit: Unit) -> Texture2D:
	if unit == null or unit.def == null:
		return null
	if unit.def.ui_portrait != null:
		return unit.def.ui_portrait
	return unit.def.token_texture

func _add_enemy_hp_bar(panel: Control, hp: int, max_hp: int) -> Control:
	var bar := Control.new()
	bar.name = "EnemyHpBar"
	bar.offset_left = 72.0
	bar.offset_top = 31.0
	bar.offset_right = bar.offset_left + ENEMY_HP_BAR_SIZE.x
	bar.offset_bottom = bar.offset_top + ENEMY_HP_BAR_SIZE.y
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar)
	_populate_segmented_hp_bar(bar, hp, max_hp, ENEMY_HP_BAR_SIZE, UI_ENEMY_HP_FILL, UI_ENEMY_HP_CRITICAL, UI_HP_EMPTY)
	return bar

func _populate_segmented_hp_bar(bar: Control, hp: int, max_hp: int, size: Vector2, fill: Color, critical_fill: Color, empty: Color) -> void:
	_clear_children(bar)
	var real_max_hp := maxi(1, max_hp)
	var segment_count := mini(real_max_hp, HP_BAR_MAX_VISIBLE_SEGMENTS)
	var filled_count := int(ceil(float(clampi(hp, 0, real_max_hp)) * float(segment_count) / float(real_max_hp)))
	if hp <= 0:
		filled_count = 0
	var gap := _hp_segment_gap(segment_count)
	var segment_width := maxf(2.0, (size.x - float(segment_count - 1) * gap) / float(segment_count))
	var segment_height := size.y
	var actual_fill := critical_fill if float(hp) / float(real_max_hp) <= 0.25 else fill
	for i in range(segment_count):
		var segment := ColorRect.new()
		segment.name = "HpSegment_%d" % i
		segment.offset_left = float(i) * (segment_width + gap)
		segment.offset_top = 0.0
		segment.offset_right = minf(size.x, segment.offset_left + segment_width)
		segment.offset_bottom = segment_height
		segment.color = actual_fill if i < filled_count else empty
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(segment)

func _hp_segment_gap(segment_count: int) -> float:
	if segment_count <= 6:
		return HP_SEGMENT_GAP
	if segment_count <= 12:
		return 1.0
	return 0.5

func _short_unit_name(unit: Unit) -> String:
	if unit == null or unit.def == null:
		return "守卫"
	match String(unit.def.def_id):
		"warden_bountyhunter":
			return "赏金"
		"warden_graverobber":
			return "盗墓"
		"warden_mage":
			return "法师"
	return unit.def.display_name

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

func _ability_slot_meta(ability: Dictionary) -> String:
	var desc := String(ability.get("desc", ""))
	if desc.strip_edges() == "":
		return "暂未配置"
	var meta := _compact_ability_slot_meta(desc, String(ability.get("target_rule", "")))
	if ability.get("is_armed", false):
		return "%s · 瞄准" % meta if meta != "" else "选择目标"
	return meta

func _compact_ability_slot_meta(desc: String, target_rule: String = "") -> String:
	var clean := desc.strip_edges()
	if clean == "":
		return ""
	if clean.find("未装备") != -1 or clean.find("结束") != -1:
		return clean
	var parts: Array[String] = []
	var range_text := _ability_range_token(clean, target_rule)
	if range_text != "":
		parts.append(range_text)
	var damage_text := _ability_damage_token(clean)
	if damage_text != "":
		parts.append(damage_text)
	var forced_text := _ability_forced_movement_token(clean)
	if forced_text != "":
		parts.append(forced_text)
	for utility in _ability_utility_tokens(clean):
		if not parts.has(utility):
			parts.append(utility)
	var uses_text := _ability_uses_token(clean)
	if uses_text != "":
		parts.append(uses_text)
	if parts.is_empty():
		return clean
	return " · ".join(parts.slice(0, min(4, parts.size())))

func _ability_range_token(desc: String, target_rule: String) -> String:
	if target_rule.find("adjacent") != -1 or desc.find("近战") != -1:
		return "近战"
	if target_rule.find("line") != -1 or desc.find("直线") != -1:
		if target_rule.find("unlimited") != -1 or desc.find("无限") != -1:
			return "无限直线"
		var range_value := _first_number_before(desc, "格")
		if range_value != "":
			return "%s格直线" % range_value
		return "直线"
	if target_rule.find("range") != -1:
		var range_value := _target_rule_range_value(target_rule)
		if range_value != "":
			return "%s格" % range_value
	var inline_range := _first_number_before(desc, "格")
	if inline_range != "":
		return "%s格" % inline_range
	return ""

func _ability_damage_token(desc: String) -> String:
	var damage_value := _first_number_before(desc, "伤")
	if damage_value == "":
		return ""
	return "%s伤" % damage_value

func _ability_forced_movement_token(desc: String) -> String:
	var pull_value := _first_number_after(desc, "拉")
	if pull_value != "":
		return "拉%s" % pull_value
	if desc.find("拉近") != -1:
		return "拉近"
	if desc.find("拉") != -1:
		return "拉"
	var push_value := _first_number_after(desc, "推")
	if push_value != "":
		return "推%s" % push_value
	if desc.find("推") != -1:
		return "推"
	return ""

func _ability_utility_tokens(desc: String) -> Array[String]:
	var tokens: Array[String] = []
	if desc.find("换位") != -1:
		tokens.append("换位")
	if desc.find("侧推") != -1:
		tokens.append("侧推")
	if desc.find("击杀") != -1:
		tokens.append("击杀")
	if desc.find("地裂") != -1 or desc.find("裂隙") != -1:
		tokens.append("地裂")
	if desc.find("护盾") != -1:
		tokens.append("护盾")
	if desc.find("减伤") != -1:
		tokens.append("减伤")
	if desc.find("减速") != -1:
		tokens.append("减速")
	return tokens

func _ability_uses_token(desc: String) -> String:
	var marker_index := desc.rfind("·")
	if marker_index == -1:
		return ""
	var tail := desc.substr(marker_index + 1).strip_edges()
	if tail.find("/") == -1:
		return ""
	return tail.replace(" ", "")

func _target_rule_range_value(target_rule: String) -> String:
	var marker := "range_"
	var marker_index := target_rule.find(marker)
	if marker_index == -1:
		return ""
	var value := ""
	for i in range(marker_index + marker.length(), target_rule.length()):
		var ch := target_rule.substr(i, 1)
		if not ch.is_valid_int():
			break
		value += ch
	return value

func _first_number_before(text: String, marker: String) -> String:
	var marker_index := text.find(marker)
	if marker_index == -1:
		return ""
	var number := ""
	for i in range(marker_index - 1, -1, -1):
		var ch := text.substr(i, 1)
		if ch.is_valid_int():
			number = ch + number
			continue
		if number != "" or not ch.strip_edges().is_empty():
			break
	return number

func _first_number_after(text: String, marker: String) -> String:
	var marker_index := text.find(marker)
	if marker_index == -1:
		return ""
	var number := ""
	for i in range(marker_index + marker.length(), text.length()):
		var ch := text.substr(i, 1)
		if ch.is_valid_int():
			number += ch
			continue
		if number != "" or not ch.strip_edges().is_empty():
			break
	return number

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
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.mouse_entered.connect(func(): enemy_stack_hovered.emit(enemy_id))
		panel.mouse_exited.connect(func(): enemy_stack_hovered.emit(-1))
		enemy_stack_row.add_child(panel)
		var row_art := _add_top_sheen(panel, Color(1.0, 0.78, 0.44, 0.04))

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
		name_label.offset_left = 72.0
		name_label.offset_top = 7.0
		name_label.offset_right = 166.0
		name_label.offset_bottom = 29.0
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.clip_text = true
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(name_label)

		var icon_frame := Panel.new()
		icon_frame.name = "EnemyIconFrame"
		icon_frame.offset_left = 46.0
		icon_frame.offset_top = 8.0
		icon_frame.offset_right = 74.0
		icon_frame.offset_bottom = 34.0
		icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon_frame)

		var enemy_icon := TextureRect.new()
		enemy_icon.name = "EnemyIcon"
		enemy_icon.offset_left = 45.0
		enemy_icon.offset_top = 3.0
		enemy_icon.offset_right = 77.0
		enemy_icon.offset_bottom = 39.0
		enemy_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		enemy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		enemy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(enemy_icon)

		var intent_line := ColorRect.new()
		intent_line.name = "IntentLine"
		intent_line.offset_left = 72.0
		intent_line.offset_top = 37.0
		intent_line.offset_right = 166.0
		intent_line.offset_bottom = 40.0
		intent_line.color = Color(0.50, 0.38, 0.46, 0.62)
		intent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(intent_line)

		var hp_bar := _add_enemy_hp_bar(panel, int(row.get("enemy_hp", 0)), int(row.get("enemy_max_hp", 0)))

		var status_back := Panel.new()
		status_back.name = "StatusBack"
		status_back.offset_left = 174.0
		status_back.offset_top = 10.0
		status_back.offset_right = 200.0
		status_back.offset_bottom = 36.0
		status_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(status_back)

		var status_mark := Panel.new()
		status_mark.name = "StatusMark"
		status_mark.offset_left = 179.0
		status_mark.offset_top = 14.0
		status_mark.offset_right = 195.0
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
			"hp_bar": hp_bar,
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
		var hp_bar: Control = controls.hp_bar
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
			base_panel = Color(0.18, 0.12, 0.07, 0.92)
			border_color = Color(1.0, 0.78, 0.30, 0.86)
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
			row_art.color = Color(1.0, 0.68, 0.20, 0.10)
		elif _enemy_stack_preview_mode:
			row_art.color = Color(1.0, 0.84, 0.36, 0.08 if not is_dimmed else 0.04)
		wash.color = Color(1.0, 0.70, 0.24, 0.07 if _enemy_stack_preview_mode else 0.0)
		rail.color = rail_color
		border.border_color = border_color
		border.border_width = 3.0 if is_executing else 2.0
		intent_line.color = line_color
		order_label.modulate = Color(1.0, 0.90, 0.56, 1.0 if not is_dimmed else 0.60)
		name_label.modulate = Color(0.95, 0.92, 0.88, 1.0 if not is_dimmed else 0.58)
		enemy_icon.modulate = Color(1, 1, 1, 1.0 if not is_dimmed else 0.52)
		hp_bar.modulate = Color(1, 1, 1, 1.0 if not is_dimmed else 0.42)
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
			"%s/%s/%s" % [row.get("target_hp", 0), row.get("enemy_hp", 0), row.get("enemy_max_hp", 0)],
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

func _clear_generated_panel_art(parent: Node) -> void:
	for child in parent.get_children():
		var child_name := String(child.name)
		if child_name == "HUDFrame" or child_name == "HUDInnerTone" or child_name == "HUDTopSheen" or child_name == "HUDBottomRule":
			parent.remove_child(child)
			child.free()

func _install_static_ui_styles() -> void:
	var root := get_node_or_null("Root")
	if root == null:
		return
	var top_bar := root.get_node_or_null("TopBarBg")
	if top_bar is ColorRect:
		top_bar.color = Color(0, 0, 0, 0)
		top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ability_bar_bg != null:
		_apply_command_bar_frame_style()
	if selected_unit_card_bg != null:
		selected_unit_card_bg.color = Color(0, 0, 0, 0)
	if selected_unit_panel_bg != null and selected_unit_panel_bg != ability_bar_bg:
		_apply_panel_frame(selected_unit_panel_bg, UI_BG, Color(0.68, 0.43, 0.18, 0.62), 0, 2)
		_add_top_sheen(selected_unit_panel_bg, Color(1.0, 0.70, 0.28, 0.07))
	if enemy_stack_bg != null:
		_apply_panel_frame(enemy_stack_bg, Color(0.020, 0.021, 0.026, 0.78), Color(0.38, 0.36, 0.32, 0.30), 0, 1)
		_add_top_sheen(enemy_stack_bg, Color(0.72, 0.82, 0.88, 0.025))
	if squad_strip_bg != null:
		_clear_generated_panel_art(squad_strip_bg)
		squad_strip_bg.color = Color(0, 0, 0, 0)
		squad_strip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if reward_panel_bg != null:
		_apply_panel_frame(reward_panel_bg, Color(0.022, 0.023, 0.029, 0.78), Color(0.38, 0.36, 0.32, 0.28), 0, 1)
		_add_top_sheen(reward_panel_bg, Color(0.72, 0.82, 0.88, 0.025))
	if info_panel_bg != null:
		_apply_panel_frame(info_panel_bg, Color(0.024, 0.024, 0.030, 0.80), Color(0.34, 0.30, 0.38, 0.34), 0, 1)
	if boss_status_bg != null:
		_apply_panel_frame(boss_status_bg, Color(0.026, 0.023, 0.024, 0.80), Color(0.52, 0.30, 0.24, 0.34), 0, 1)
		_add_top_sheen(boss_status_bg, Color(1.0, 0.44, 0.28, 0.035))

func _apply_command_bar_frame_style() -> void:
	if ability_bar_bg == null:
		return
	_clear_generated_panel_art(ability_bar_bg)
	ability_bar_bg.color = Color(0, 0, 0, 0)

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
			mark.offset_left = 179.0
			mark.offset_top = 14.0
			mark.offset_right = 195.0
			mark.offset_bottom = 32.0
			style.bg_color = fill
			style.border_color = border.lightened(0.25)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
		BattleEngine.INTENT_STATUS_MISS:
			mark.offset_left = 179.0
			mark.offset_top = 15.0
			mark.offset_right = 195.0
			mark.offset_bottom = 31.0
			style.bg_color = Color(fill.r, fill.g, fill.b, 0.16 * alpha_scale)
			style.border_color = border
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
		BattleEngine.INTENT_STATUS_REMOVED:
			mark.offset_left = 178.0
			mark.offset_top = 22.0
			mark.offset_right = 196.0
			mark.offset_bottom = 26.0
			style.bg_color = Color(fill.r, fill.g, fill.b, 0.64 * alpha_scale)
			style.border_color = Color(border.r, border.g, border.b, 0.34 * alpha_scale)
		_:
			mark.offset_left = 181.0
			mark.offset_top = 22.0
			mark.offset_right = 193.0
			mark.offset_bottom = 26.0
			style.bg_color = Color(fill.r, fill.g, fill.b, 0.54 * alpha_scale)
			style.border_color = Color(border.r, border.g, border.b, 0.28 * alpha_scale)
	mark.add_theme_stylebox_override("panel", style)

func _enemy_stack_palette(status: String) -> Dictionary:
	match status:
		BattleEngine.INTENT_STATUS_HIT:
			return {
				"panel": Color(0.12, 0.055, 0.065, 0.78),
				"border": Color(0.76, 0.26, 0.30, 0.62),
				"status": Color(0.95, 0.42, 0.44, 0.88),
				"rail": Color(0.86, 0.28, 0.32, 0.74),
				"line": Color(0.88, 0.34, 0.38, 0.54),
			}
		BattleEngine.INTENT_STATUS_MISS:
			return {
				"panel": Color(0.075, 0.090, 0.110, 0.70),
				"border": Color(0.42, 0.50, 0.58, 0.52),
				"status": Color(0.58, 0.66, 0.74, 0.86),
				"rail": Color(0.50, 0.60, 0.70, 0.56),
				"line": Color(0.52, 0.62, 0.72, 0.36),
			}
		BattleEngine.INTENT_STATUS_REMOVED:
			return {
				"panel": Color(0.060, 0.060, 0.070, 0.60),
				"border": Color(0.34, 0.34, 0.38, 0.42),
				"status": Color(0.62, 0.62, 0.66, 0.84),
				"rail": Color(0.40, 0.40, 0.44, 0.42),
				"line": Color(0.44, 0.44, 0.48, 0.28),
			}
		_:
			return {
				"panel": Color(0.070, 0.064, 0.084, 0.58),
				"border": Color(0.30, 0.29, 0.36, 0.38),
				"status": Color(0.62, 0.58, 0.68, 0.82),
				"rail": Color(0.48, 0.38, 0.26, 0.36),
				"line": Color(0.48, 0.38, 0.26, 0.22),
			}

func show_outcome(outcome: int, reason: String = "") -> void:
	if banner == null:
		banner = get_node_or_null("Root/Banner")
	if banner == null:
		return
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
