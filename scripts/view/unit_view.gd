class_name UnitView extends Node2D
## Visual for a single unit. Uses optional static token art, with a colored
## disc fallback for units whose art is not ready yet.

const RADIUS := 28.0
const RING_RADIUS := 32.0
const TOKEN_DRAW_SIZE := Vector2(84, 84)
const TOKEN_DRAW_OFFSET := Vector2(0, -12)
const TOKEN_BASE_CENTER := Vector2(0, 14)
const COLOR_FACTION_OUTLINE := {
	0: Color(0.7, 0.9, 1.0),   # WARDEN -- pale cyan
	1: Color(0.85, 0.25, 0.3), # ENEMY -- crimson
}

var unit_id: int = -1
var _fill: Color = Color.WHITE
var _faction: int = 0
var _hp: int = 1
var _max_hp: int = 1
var _label: String = ""
var _has_acted: bool = false
var _has_moved: bool = false
var _token_texture: Texture2D = null
## Execution order badge for enemies: 1, 2, 3... When 0, no badge drawn.
var _order_badge: int = 0
var _tween: Tween

func configure(unit: Unit) -> void:
	unit_id = unit.id
	_fill = unit.def.color
	_faction = unit.def.faction
	_hp = unit.hp
	_max_hp = unit.def.max_hp
	_label = unit.def.display_name.substr(0, 1) if unit.def.display_name.length() >= 1 else "?"
	_has_acted = unit.has_acted
	_has_moved = unit.has_moved
	_token_texture = unit.def.token_texture
	queue_redraw()

func set_acted(acted: bool, moved: bool = false) -> void:
	_has_acted = acted
	_has_moved = moved
	queue_redraw()

func set_order_badge(n: int) -> void:
	if _order_badge == n:
		return
	_order_badge = n
	queue_redraw()

func move_to_cell(p: Vector2i, duration: float = 0.18) -> Signal:
	var target := GridView.cell_to_pixel(p)
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE)
	return _tween.finished

## Forceful "knockback" animation: faster, with an impact flash + tiny overshoot.
## Used for UNIT_PUSHED events to make pushes feel different from voluntary moves.
func push_to_cell(p: Vector2i, duration: float = 0.32) -> Signal:
	var target := GridView.cell_to_pixel(p)
	if _tween != null and _tween.is_running():
		_tween.kill()
	# Briefly flash white to signal impact.
	modulate = Color(1.5, 1.5, 1.5)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate", Color(1, 1, 1), duration * 0.5)
	# Use BACK ease for a tiny overshoot at the end, making the knockback "land".
	_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _tween.finished

func snap_to_cell(p: Vector2i) -> void:
	position = GridView.cell_to_pixel(p)

func _draw() -> void:
	var outline: Color = COLOR_FACTION_OUTLINE.get(_faction, Color.WHITE)
	if _token_texture != null:
		_draw_token_art(outline)
	else:
		_draw_placeholder_disc(outline)
		_draw_hp_pips()
	_draw_order_badge()

func _draw_token_art(outline: Color) -> void:
	var rect := Rect2(-TOKEN_DRAW_SIZE * 0.5 + TOKEN_DRAW_OFFSET, TOKEN_DRAW_SIZE)
	var tint := Color.WHITE
	if _has_acted:
		tint = Color(0.45, 0.45, 0.45, 0.9)
	elif _has_moved:
		tint = Color(0.72, 0.72, 0.72, 0.95)
	var shadow_rect := rect.grow(2.0)
	var outline_tint := outline.darkened(0.08)
	outline_tint.a = 0.72
	draw_texture_rect(_token_texture, Rect2(shadow_rect.position + Vector2(0, 1), shadow_rect.size), false, Color(0.0, 0.0, 0.0, 0.38))
	draw_texture_rect(_token_texture, Rect2(rect.position + Vector2(0, -1), rect.size), false, outline_tint)
	draw_texture_rect(_token_texture, rect, false, tint)

func _draw_filled_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)

func _draw_placeholder_disc(outline: Color) -> void:
	# Outer ring shows faction
	draw_circle(Vector2.ZERO, RING_RADIUS, outline)
	# Inner fill shows unit identity. Dim when moved (attack remaining) or
	# fully acted (turn done).
	var fill: Color = _fill
	if _has_acted:
		fill = fill.darkened(0.55)
	elif _has_moved:
		fill = fill.darkened(0.25)
	draw_circle(Vector2.ZERO, RADIUS, fill)
	# Label -- use project theme's default font (CJK-capable system font fallback).
	var font: Font = ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() != null else ThemeDB.fallback_font
	if font == null:
		font = ThemeDB.fallback_font
	var fsize := 22
	var size: Vector2 = font.get_string_size(_label, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
	draw_string(font, -size * 0.5 + Vector2(0, fsize * 0.35), _label, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize, Color.BLACK)

func _draw_hp_pips() -> void:
	# HP pips at the bottom
	var pip_r := 5.0
	var spacing := 14.0
	var total_w := spacing * (_max_hp - 1)
	for i in _max_hp:
		var cx: float = -total_w * 0.5 + i * spacing
		var cy: float = RADIUS - 4.0
		var c: Color = Color(1, 1, 1) if i < _hp else Color(0.25, 0.05, 0.05)
		draw_circle(Vector2(cx, cy), pip_r, c)

func _draw_order_badge() -> void:
	# Order badge for enemies: small numbered circle at top-right.
	if _order_badge > 0:
		var badge_center := Vector2(RING_RADIUS - 4, -RING_RADIUS + 4)
		draw_circle(badge_center, 11.0, Color(0.08, 0.06, 0.1, 0.95))
		draw_arc(badge_center, 11.0, 0, TAU, 16, Color(1.0, 0.85, 0.4), 2.0)
		var bfont: Font = ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() != null else ThemeDB.fallback_font
		if bfont == null:
			bfont = ThemeDB.fallback_font
		var btext: String = str(_order_badge)
		var bsize: Vector2 = bfont.get_string_size(btext, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string(bfont, badge_center - bsize * 0.5 + Vector2(0, 5), btext, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.9, 0.55))
