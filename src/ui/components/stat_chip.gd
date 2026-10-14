class_name StatChip
extends Control
## Icono dibujado + número (vida, maná, cartas, pociones).

const KIND_HP: String = "hp"
const KIND_MANA: String = "mana"
const KIND_CARDS: String = "cards"
const KIND_POTION: String = "potion"

var kind: String = KIND_HP
var value: int = 0
var font_size: int = 28


static func create(p_kind: String, p_value: int, p_font_size: int = 28) -> StatChip:
	var c: StatChip = StatChip.new()
	c.kind = p_kind
	c.value = p_value
	# Legibilidad (V2-33): nunca por debajo de UiTheme.FONT_MIN.
	c.font_size = maxi(p_font_size, UiTheme.FONT_MIN)
	return c


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(font_size * 3.0, font_size * 1.5)


func _draw() -> void:
	var h: float = size.y
	var cy: float = h * 0.5
	var r: float = h * 0.36
	var cx: float = r + 2.0
	match kind:
		KIND_HP:
			draw_circle(Vector2(cx - r * 0.5, cy - r * 0.2), r * 0.62, UiTheme.COL_HP)
			draw_circle(Vector2(cx + r * 0.5, cy - r * 0.2), r * 0.62, UiTheme.COL_HP)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - r * 1.08, cy), Vector2(cx + r * 1.08, cy), Vector2(cx, cy + r * 1.05)]),
				UiTheme.COL_HP)
		KIND_MANA:
			draw_circle(Vector2(cx, cy + r * 0.3), r * 0.8, UiTheme.COL_MANA)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - r * 0.72, cy + r * 0.05), Vector2(cx + r * 0.72, cy + r * 0.05),
				Vector2(cx, cy - r * 1.0)]), UiTheme.COL_MANA)
		KIND_CARDS:
			draw_rect(Rect2(cx - r * 0.9, cy - r * 0.8, r * 1.2, r * 1.6), Color(0.55, 0.5, 0.7))
			draw_rect(Rect2(cx - r * 0.4, cy - r * 1.0, r * 1.2, r * 1.6), Color(0.85, 0.82, 0.95))
		KIND_POTION:
			draw_circle(Vector2(cx, cy + r * 0.3), r * 0.8, UiTheme.COL_POTION)
			draw_rect(Rect2(cx - r * 0.25, cy - r * 0.95, r * 0.5, r * 0.9), UiTheme.COL_POTION)
	var font: Font = ThemeDB.fallback_font
	var txt: String = str(value)
	var ty: float = cy + font_size * 0.35
	draw_string(font, Vector2(cx + r * 1.4, ty), txt, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, UiTheme.COL_TEXT)


func set_value(v: int) -> void:
	value = v
	queue_redraw()
