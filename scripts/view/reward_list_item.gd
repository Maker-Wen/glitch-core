class_name RewardListItem
extends ColorRect

const COLOR_PANEL := Color(0.090, 0.074, 0.060, 0.96)
const COLOR_BADGE := Color(0.16, 0.105, 0.055, 0.95)
const COLOR_LINE := Color(0.37, 0.25, 0.15, 0.62)
const COLOR_TEXT := Color(0.92, 0.89, 0.82, 1.0)
const COLOR_MUTED := Color(0.62, 0.66, 0.70, 1.0)
const COLOR_AMBER := Color(1.00, 0.72, 0.34, 1.0)

func setup(display: Dictionary) -> void:
	name = "RewardListItem"
	color = COLOR_PANEL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_border(self, COLOR_LINE)
	var badge := ColorRect.new()
	badge.position = Vector2(18, 17)
	badge.size = Vector2(44, 44)
	badge.color = COLOR_BADGE
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	_add_border(badge, COLOR_LINE)
	var icon_label := _label(badge, String(display.get("icon_text", "")), Rect2(0, 9, 44, 24), 17, COLOR_AMBER)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(self, String(display.get("title", "")), Rect2(78, 14, 280, 26), 20, COLOR_TEXT)
	_label(self, String(display.get("description", "")), Rect2(78, 42, 320, 22), 15, COLOR_MUTED)
	var amount_text := String(display.get("amount_text", ""))
	if not amount_text.is_empty():
		var amount_color: Color = display.get("amount_color", COLOR_AMBER)
		var amount_label := _label(self, amount_text, Rect2(414, 22, 112, 32), 25, amount_color)
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _label(parent: Node, text: String, rect: Rect2, font_size: int, label_color: Color) -> Label:
	var l := Label.new()
	l.position = rect.position
	l.size = rect.size
	l.text = text
	l.modulate = label_color
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _add_border(parent: Control, border_color: Color) -> void:
	var b := ReferenceRect.new()
	b.anchor_right = 1.0
	b.anchor_bottom = 1.0
	b.offset_right = 0.0
	b.offset_bottom = 0.0
	b.border_width = 2.0
	b.border_color = border_color
	b.editor_only = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
