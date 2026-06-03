class_name PreviewOverlay extends Node2D
## Highlights for movement range, attack targets, hover preview, and enemy
## warnings (intent). Pure visualization -- never mutates state.

const COLOR_MOVE := Color(0.55, 0.85, 0.95, 0.22)
const COLOR_MOVE_BORDER := Color(0.6, 0.9, 1.0, 0.7)
const COLOR_ATTACK := Color(0.9, 0.3, 0.35, 0.30)
const COLOR_ATTACK_BORDER := Color(1.0, 0.4, 0.45, 0.85)
const COLOR_ENEMY_INTENT := Color(0.9, 0.25, 0.5, 0.22)
const COLOR_ENEMY_INTENT_BORDER := Color(0.95, 0.4, 0.6, 0.6)
const COLOR_ENEMY_INTENT_MISS := Color(0.48, 0.60, 0.72, 0.18)
const COLOR_ENEMY_INTENT_MISS_BORDER := Color(0.64, 0.72, 0.82, 0.55)
const COLOR_PREVIEW_GHOST := Color(1, 1, 1, 0.55)
const COLOR_RIFT_PREDICTED := Color(1.0, 0.85, 0.3, 0.95)

var move_cells: Array[Vector2i] = []
var attack_cells: Array[Vector2i] = []
## Each intent: {enemy_id, order, enemy_pos, post_move, move_to, attack_pos}
var enemy_intents: Array = []
var enemy_intents_preview_mode: bool = false
var focused_enemy_id: int = -1  ## When set, only this enemy's intent is shown prominently
var preview_markers: Array = []  # [{pos: Vector2i, kind: String}]
var preview_paths: Array = []   # [{from: Vector2i, to: Vector2i, enemy: bool}]
var predicted_rifts: Array[Vector2i] = []  # rifts that will spawn next round
var _pulse_t: float = 0.0

func set_move_range(cells: Array[Vector2i]) -> void:
	move_cells = cells
	queue_redraw()

func set_attack_targets(cells: Array[Vector2i]) -> void:
	attack_cells = cells
	queue_redraw()

func set_enemy_intents(intents: Array, preview_mode: bool = false) -> void:
	enemy_intents = intents
	enemy_intents_preview_mode = preview_mode
	queue_redraw()

func set_focused_enemy(enemy_id: int) -> void:
	if focused_enemy_id == enemy_id:
		return
	focused_enemy_id = enemy_id
	queue_redraw()

func set_preview_markers(markers: Array, paths: Array) -> void:
	preview_markers = markers
	preview_paths = paths
	queue_redraw()

func clear_preview() -> void:
	preview_markers.clear()
	preview_paths.clear()
	queue_redraw()

func clear_all_ranges() -> void:
	move_cells.clear()
	attack_cells.clear()
	enemy_intents.clear()
	enemy_intents_preview_mode = false
	focused_enemy_id = -1
	preview_markers.clear()
	preview_paths.clear()
	queue_redraw()

func set_predicted_rifts(cells: Array[Vector2i]) -> void:
	predicted_rifts = cells
	queue_redraw()

func _process(delta: float) -> void:
	if predicted_rifts.is_empty():
		return
	_pulse_t += delta
	queue_redraw()

func _draw() -> void:
	for cell in move_cells:
		_fill_cell(cell, COLOR_MOVE, COLOR_MOVE_BORDER)
	for cell in attack_cells:
		_fill_cell(cell, COLOR_ATTACK, COLOR_ATTACK_BORDER)
	# Enemy intents: show strike arrows from enemy -> target. Hit slots are
	# red; miss slots stay visible in grey-blue so resolved threats do not
	# disappear without explanation.
	#
	# Focus (hovering over an enemy) only adjusts brightness -- all attack
	# arrows stay visible regardless of focus state. Hiding non-focused
	# arrows would create the "ghost threat" bug the user reported.
	var damage_badges: Dictionary = {}
	for intent in enemy_intents:
		var eid: int = intent.get("enemy_id", -1)
		var is_focused: bool = (focused_enemy_id == eid)
		var attack_pos: Vector2i = intent.get("attack_pos", Vector2i(-1, -1))
		var status: String = intent.get("status", BattleEngine.INTENT_STATUS_HIT)
		if status == BattleEngine.INTENT_STATUS_REMOVED or status == BattleEngine.INTENT_STATUS_NO_ATTACK:
			continue
		if attack_pos == Vector2i(-1, -1):
			continue
		var is_miss := status == BattleEngine.INTENT_STATUS_MISS
		var attack_fires: bool = intent.get("attack_fires", not is_miss)
		var show_as_live_attack := attack_fires or not is_miss
		# Target cell: warning fill. When this enemy is focused (or no
		# enemy is focused), it's brighter; when a different enemy is focused,
		# this one's threat dims slightly but stays visible.
		var dimmed: bool = focused_enemy_id != -1 and not is_focused
		var fill_a: float
		var border_a: float
		if is_focused:
			fill_a = 0.50 if show_as_live_attack else 0.42
			border_a = 1.0
		elif dimmed:
			fill_a = 0.18 if show_as_live_attack else 0.12
			border_a = 0.55 if show_as_live_attack else 0.42
		else:
			fill_a = 0.30 if show_as_live_attack else 0.22
			border_a = 0.80 if show_as_live_attack else 0.62
		if enemy_intents_preview_mode:
			fill_a *= 0.86
			border_a *= 0.92
		var base_fill := COLOR_ENEMY_INTENT if show_as_live_attack else COLOR_ENEMY_INTENT_MISS
		var base_border := COLOR_ENEMY_INTENT_BORDER if show_as_live_attack else COLOR_ENEMY_INTENT_MISS_BORDER
		var fill: Color = Color(base_fill.r, base_fill.g, base_fill.b, fill_a)
		var border: Color = Color(base_border.r, base_border.g, base_border.b, border_a)
		_fill_cell(attack_pos, fill, border)
		if not is_miss:
			_add_damage_badge(damage_badges, attack_pos, int(intent.get("target_damage", 0)), is_focused, dimmed)
		# Strike arrow from enemy -> target (always visible).
		var enemy_pos: Vector2i = intent.get("enemy_pos", Vector2i(-1, -1))
		if enemy_pos != Vector2i(-1, -1) and enemy_pos != attack_pos:
			var arrow_alpha: float
			if is_focused:
				arrow_alpha = 1.0 if show_as_live_attack else 0.88
			elif dimmed:
				arrow_alpha = 0.55 if show_as_live_attack else 0.36
			else:
				arrow_alpha = 0.85 if show_as_live_attack else 0.58
			if enemy_intents_preview_mode:
				arrow_alpha *= 0.9
			var arrow_width: float = (4.0 if is_focused else (2.0 if dimmed else 3.0)) if show_as_live_attack else 3.0
			var arrow_col := Color(1.0, 0.35, 0.45, arrow_alpha) if show_as_live_attack else Color(0.66, 0.74, 0.84, arrow_alpha)
			_draw_arrow(
				GridView.cell_to_pixel(enemy_pos),
				GridView.cell_to_pixel(attack_pos),
				arrow_col,
				arrow_width
			)
	for cell in damage_badges.keys():
		var badge: Dictionary = damage_badges[cell]
		_draw_damage_badge(
			cell,
			int(badge.get("amount", 0)),
			bool(badge.get("focused", false)),
			bool(badge.get("dimmed", false)),
			enemy_intents_preview_mode,
		)

	# Predicted rift spawns: bright golden cell + pulsing border + large arrow.
	# This is the player's warning "an enemy will spawn here next round".
	# Per design §3.4, the enemy type is hidden -- only the spawn location.
	var pulse: float = 0.55 + 0.35 * sin(_pulse_t * 4.0)
	for r in predicted_rifts:
		var rect := Rect2(Vector2(r) * GridView.CELL_SIZE, Vector2.ONE * GridView.CELL_SIZE)
		var inner_fill: Color = Color(COLOR_RIFT_PREDICTED.r, COLOR_RIFT_PREDICTED.g, COLOR_RIFT_PREDICTED.b, 0.25 * pulse)
		draw_rect(rect, inner_fill)
		var border_color: Color = COLOR_RIFT_PREDICTED
		border_color.a = pulse
		draw_rect(rect, border_color, false, 4.0)
		# Big arrow + hint text "下回合出怪"
		var font: Font = null
		if ThemeDB.get_project_theme() != null:
			font = ThemeDB.get_project_theme().default_font
		if font == null:
			font = ThemeDB.fallback_font
		if font != null:
			var arrow_color: Color = Color(1, 0.95, 0.7, pulse * 1.1)
			arrow_color.a = clampf(arrow_color.a, 0.0, 1.0)
			# Centered "↑" glyph (large)
			var arrow_size := 38
			var arrow_str := "↑"
			var arrow_metric: Vector2 = font.get_string_size(arrow_str, HORIZONTAL_ALIGNMENT_CENTER, -1, arrow_size)
			draw_string(
				font,
				rect.position + Vector2(rect.size.x * 0.5 - arrow_metric.x * 0.5, rect.size.y * 0.5 + 8.0),
				arrow_str,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				arrow_size,
				arrow_color,
			)
			# Small label below the cell
			var label := "下回合"
			var label_size := 11
			var label_metric: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, label_size)
			draw_string(
				font,
				rect.position + Vector2(rect.size.x * 0.5 - label_metric.x * 0.5, rect.size.y - 4.0),
				label,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				label_size,
				border_color,
			)
	# Preview paths (arrows showing displacement)
	for path in preview_paths:
		var from_px: Vector2 = GridView.cell_to_pixel(path.from)
		var to_px: Vector2 = GridView.cell_to_pixel(path.to)
		var color := Color(1.0, 0.5, 0.5, 0.85) if path.enemy else Color(0.65, 0.9, 1.0, 0.85)
		_draw_arrow(from_px, to_px, color, 4.0)
	# Preview markers (ghost / skull / fall)
	for m in preview_markers:
		var pos: Vector2i = m.pos
		var center: Vector2 = GridView.cell_to_pixel(pos)
		match m.kind:
			"fall":
				# Red X with "↘渊" semantic: corner-flick + bold X.
				var s := 22.0
				var col := Color(1, 0.2, 0.2)
				draw_line(center - Vector2(s, s), center + Vector2(s, s), col, 5.0)
				draw_line(center - Vector2(s, -s), center + Vector2(-s, s), col, 5.0)
			"skull":
				# Grey hollow circle with an inner X = "will die here".
				draw_arc(center, 22.0, 0, TAU, 24, Color(0.3, 0.3, 0.3, 0.95), 3.0)
				var s2 := 12.0
				draw_line(center - Vector2(s2, s2), center + Vector2(s2, s2), Color(0.3, 0.3, 0.3, 0.95), 3.0)
				draw_line(center - Vector2(s2, -s2), center + Vector2(-s2, s2), Color(0.3, 0.3, 0.3, 0.95), 3.0)
			"ghost_enemy":
				# Soft red ghost circle at final cell.
				draw_circle(center, 20.0, Color(1.0, 0.5, 0.55, 0.45))
				draw_arc(center, 20.0, 0, TAU, 24, Color(1.0, 0.4, 0.45, 0.9), 2.0)
			"ghost_warden":
				# Soft cyan ghost.
				draw_circle(center, 20.0, Color(0.55, 0.85, 1.0, 0.45))
				draw_arc(center, 20.0, 0, TAU, 24, Color(0.6, 0.9, 1.0, 0.9), 2.0)
			_:
				draw_circle(center, 16.0, Color(1, 1, 1, 0.4))

func _draw_arrow(from_px: Vector2, to_px: Vector2, col: Color, w: float) -> void:
	var dir := (to_px - from_px).normalized()
	# Pull both endpoints in a bit so the arrow doesn't overlap unit tokens.
	var shrink := 26.0
	var start := from_px + dir * shrink
	var end_pt := to_px - dir * (shrink * 0.5)
	if start.distance_to(end_pt) < 8.0:
		return
	draw_line(start, end_pt, col, w)
	# Arrowhead
	var head_size := 12.0
	var left := end_pt - dir * head_size + dir.rotated(PI * 0.5) * (head_size * 0.6)
	var right := end_pt - dir * head_size - dir.rotated(PI * 0.5) * (head_size * 0.6)
	draw_colored_polygon([end_pt, left, right], col)

func _add_damage_badge(badges: Dictionary, cell: Vector2i, amount: int, focused: bool, dimmed: bool) -> void:
	if amount <= 0:
		return
	var badge: Dictionary = badges.get(cell, {
		"amount": 0,
		"focused": false,
		"dimmed": true,
	})
	badge["amount"] = int(badge.get("amount", 0)) + amount
	badge["focused"] = bool(badge.get("focused", false)) or focused
	badge["dimmed"] = bool(badge.get("dimmed", true)) and dimmed
	badges[cell] = badge

func _draw_damage_badge(cell: Vector2i, amount: int, focused: bool, dimmed: bool, preview_mode: bool) -> void:
	if amount <= 0:
		return
	var font: Font = ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() != null else ThemeDB.fallback_font
	if font == null:
		return
	var rect := Rect2(Vector2(cell) * GridView.CELL_SIZE, Vector2.ONE * GridView.CELL_SIZE)
	var center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.22)
	var alpha := 1.0
	if dimmed:
		alpha = 0.46
	elif preview_mode:
		alpha = 0.78
	var radius := 15.0 if focused else 13.0
	draw_circle(center, radius, Color(0.12, 0.03, 0.04, 0.88 * alpha))
	draw_arc(center, radius, 0, TAU, 20, Color(1.0, 0.36, 0.32, 0.95 * alpha), 2.0)
	var text := "-%d" % amount
	var fsize := 15 if focused else 13
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
	draw_string(
		font,
		center - size * 0.5 + Vector2(0, fsize * 0.36),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		fsize,
		Color(1.0, 0.92, 0.86, alpha),
	)

func _fill_cell(p: Vector2i, fill: Color, border: Color) -> void:
	var rect := Rect2(Vector2(p) * GridView.CELL_SIZE, Vector2.ONE * GridView.CELL_SIZE)
	draw_rect(rect, fill)
	draw_rect(rect, border, false, 2.0)
