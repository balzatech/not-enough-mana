class_name UiTheme
extends RefCounted
## Tema oscuro de la UI. `get_theme()` carga res://src/ui/theme.tres y, si no
## existe, lo construye en código (misma fuente: build()).

const PATH: String = "res://src/ui/theme.tres"

const COL_BG: Color = Color(0.06, 0.06, 0.10)
const COL_PANEL: Color = Color(0.11, 0.11, 0.17, 0.94)
const COL_PANEL_LIGHT: Color = Color(0.17, 0.17, 0.25, 0.96)
const COL_BORDER: Color = Color(0.36, 0.30, 0.50)
const COL_ACCENT: Color = Color(0.96, 0.76, 0.26)
const COL_TEXT: Color = Color(0.94, 0.92, 0.86)
const COL_MUTED: Color = Color(0.62, 0.60, 0.70)
const COL_HP: Color = Color(0.90, 0.25, 0.30)
const COL_MANA: Color = Color(0.30, 0.55, 0.98)
const COL_POTION: Color = Color(0.35, 0.80, 0.45)
const COL_DANGER: Color = Color(0.85, 0.22, 0.22)
const COL_OK: Color = Color(0.30, 0.72, 0.42)

## --- Accesibilidad (V2-18, lineamientos 1 y 12) ---------------------------------
## Referencia: viewport base 1080 px de ancho (a 720 px todo escala x0.667 por stretch).
## Tamaño mínimo de cualquier texto de la UI (px a 1080). Usar para etiquetas secundarias.
const FONT_MIN: int = 22
## Texto de cuerpo (Label, LineEdit).
const FONT_BODY: int = 30
## Texto de botón.
const FONT_BUTTON: int = 32
## Números flotantes de daño/curación.
const FONT_FLOAT: int = 44
## Alto mínimo de un botón (px a 1080). El tema ya lo garantiza con márgenes
## (BUTTON_MARGIN_V); los Developer lo usan en `custom_minimum_size.y` para botones
## con icono o fuente distinta.
const BUTTON_MIN_H: int = 96
## Margen vertical del StyleBox de botón: 2*30 + línea de 32 px (~38) = ~98 >= BUTTON_MIN_H.
const BUTTON_MARGIN_V: int = 30
## Alto mínimo de un botón de ACCIÓN PRINCIPAL (px a 1080; 96 a 720 por el stretch del
## viewport, igual que BUTTON_MIN_H: 144 px = 48 dp). Decisión del Director (TAREAS §2.1).
## Lista de botones principales/secundarios en docs/arte/tecnico.md.
const BUTTON_PRIMARY_H: int = 144
## Tipo de variación de tema para botones principales (hereda de Button).
const VARIATION_PRIMARY: String = "ButtonPrimary"
## Separación mínima entre botones adyacentes y alrededor de Beber poción (px a 1080).
const BUTTON_GAP_MIN: int = 16
const BUTTON_GAP_POTION: int = 24
## Botón principal (QA-V2-27-02): fondo violeta vivo + borde dorado grueso (no solo color:
## el borde de 4 px lo distingue también en daltonismo). Los secundarios son violeta apagado
## con borde gris-violeta de 3 px. Contraste del texto >= 4,5:1 en todos los estados.
const COL_PRIMARY_BG: Color = Color(0.40, 0.20, 0.74)
const COL_PRIMARY_BG_HOVER: Color = Color(0.46, 0.26, 0.82)
const COL_PRIMARY_BG_PRESSED: Color = Color(0.28, 0.14, 0.56)
const COL_PRIMARY_BG_DISABLED: Color = Color(0.18, 0.15, 0.26)
const PRIMARY_BORDER_W: int = 4

## --- Feedback de daño / curación (no solo rojo/verde) ---------------------------
## Daño: bermellón + forma angular (esquinas rectas, rayado diagonal en el shader) + glifo ▼.
## Curación: cian/azul verdoso + forma redondeada (halo suave en el shader) + glifo ▲ .
## Rojo vs azul-verdoso se distingue en deuteranopía/protanopía; además cambian forma y glifo.
const COL_DAMAGE_FX: Color = Color(1.0, 0.32, 0.12)
const COL_HEAL_FX: Color = Color(0.20, 0.85, 0.90)
const GLYPH_DAMAGE: String = "▼"
const GLYPH_HEAL: String = "▲"
## Fuente de respaldo empaquetada (V2-P1, docs/rendimiento/v02-final.md): DejaVu Sans (licencia
## Bitstream Vera, assets/fonts/LICENSE-DejaVu.txt). La fuente por defecto del motor no trae
## ▼ ▲ ⚠ → ✓; sin respaldo, cada texto con ellos busca una fuente del SO (3,7-5,8 ms por texto) y en
## Web/Android puede no haberla (cuadrado). Solo se usa para los glifos que faltan en la principal.
const FONT_FALLBACK_PATH: String = "res://assets/fonts/DejaVuSans.ttf"
## Símbolos que la UI escribe y que la fuente de respaldo debe tener (los comprueba test_glyph_fallback).
const FALLBACK_GLYPHS: String = "▼▲⚠→✓·…—"
const SHADER_PANEL_FLASH: String = "res://src/ui/shaders/panel_flash.gdshader"
const SHADER_FLOAT_NUMBER: String = "res://src/ui/shaders/floating_number.gdshader"

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme == null:
		if ResourceLoader.exists(PATH):
			_theme = load(PATH) as Theme
		if _theme == null:
			_theme = build()
	return _theme


static func box(bg: Color, radius: int = 18, border: Color = Color(0, 0, 0, 0),
		border_w: int = 0, margin_h: int = 20, margin_v: int = 20) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


## Estilo de tinte de panel (alternativa sin shader: usar como "panel" en un override).
## `damage` true = angular y borde grueso; false (curación) = muy redondeado y borde fino.
static func flash_box(damage: bool, alpha: float = 0.35) -> StyleBoxFlat:
	var c: Color = COL_DAMAGE_FX if damage else COL_HEAL_FX
	var sb: StyleBoxFlat = box(Color(c.r, c.g, c.b, alpha), 0 if damage else 34,
			c, 8 if damage else 4, 18, 14)
	return sb


## Texto de número flotante con glifo de forma: "▼ -5" / "▲ +3".
static func float_text(amount: int, damage: bool) -> String:
	return "%s %s%d" % [GLYPH_DAMAGE if damage else GLYPH_HEAL, "-" if damage else "+", absi(amount)]


## ShaderMaterial listo para un ColorRect superpuesto al panel. `amount` 0..1 (animar con Tween);
## `rect_size` = tamaño del ColorRect en px.
static func make_flash_material(damage: bool, rect_size: Vector2 = Vector2(240, 200)) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SHADER_PANEL_FLASH) as Shader
	m.set_shader_parameter("tint", COL_DAMAGE_FX if damage else COL_HEAL_FX)
	m.set_shader_parameter("hatched", damage)
	m.set_shader_parameter("rect_size", rect_size)
	m.set_shader_parameter("amount", 0.0)
	return m


## ShaderMaterial para un Label con tema FloatDamage/FloatHeal (brillo vertical + `fade`).
static func make_float_material(_damage: bool) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SHADER_FLOAT_NUMBER) as Shader
	m.set_shader_parameter("fade", 1.0)
	return m


## Marca `button` como botón de acción principal: variación "ButtonPrimary" y alto mínimo
## `BUTTON_PRIMARY_H` (nunca reduce un mínimo mayor ya puesto). No cambia el ancho.
static func apply_primary(button: Button) -> void:
	button.theme_type_variation = VARIATION_PRIMARY
	var ms: Vector2 = button.custom_minimum_size
	ms.y = maxf(ms.y, float(BUTTON_PRIMARY_H))
	button.custom_minimum_size = ms


## Fuente del tema: la del motor (FontVariation sin `base_font` = misma fuente por defecto, mismo
## aspecto) más DejaVu Sans como respaldo explícito para los símbolos que la principal no tiene.
## `embolden`/`skew` reproducen el negrita (1,2) y la cursiva (0,2) sintéticas del tema por defecto del motor.
static func make_font(embolden: float = 0.0, skew: float = 0.0) -> FontVariation:
	var fv: FontVariation = FontVariation.new()
	fv.fallbacks = [load(FONT_FALLBACK_PATH) as Font]
	fv.variation_embolden = embolden
	fv.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(skew, 1.0), Vector2.ZERO)
	return fv


static func build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = FONT_BODY
	t.default_font = make_font()
	# RichTextLabel: con default_font en el tema, Godot ya no cae a las variaciones de negrita/cursiva
	# del tema por defecto (se perdía el [b] del registro); se redefinen aquí con el mismo aspecto.
	t.set_font("normal_font", "RichTextLabel", make_font())
	t.set_font("bold_font", "RichTextLabel", make_font(1.2))
	t.set_font("italics_font", "RichTextLabel", make_font(0.0, 0.2))
	t.set_font("bold_italics_font", "RichTextLabel", make_font(1.2, 0.2))
	# Label
	t.set_font_size("font_size", "Label", FONT_BODY)
	t.set_color("font_color", "Label", COL_TEXT)
	# Button: margen vertical amplio => altura >= 96 px con fuente 32
	t.set_font_size("font_size", "Button", FONT_BUTTON)
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", COL_ACCENT)
	t.set_color("font_focus_color", "Button", COL_TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.58))
	t.set_stylebox("normal", "Button", box(Color(0.22, 0.18, 0.36), 18, COL_BORDER, 3, 24, BUTTON_MARGIN_V))
	t.set_stylebox("hover", "Button", box(Color(0.28, 0.23, 0.45), 18, COL_ACCENT, 3, 24, BUTTON_MARGIN_V))
	t.set_stylebox("pressed", "Button", box(Color(0.36, 0.28, 0.14), 18, COL_ACCENT, 4, 24, BUTTON_MARGIN_V))
	t.set_stylebox("disabled", "Button", box(Color(0.14, 0.14, 0.19), 18, Color(0.24, 0.24, 0.30), 2, 24, BUTTON_MARGIN_V))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 18, COL_ACCENT, 3, 24, BUTTON_MARGIN_V))
	# Botón de acción principal: el alto lo da apply_primary()/custom_minimum_size
	t.set_type_variation(VARIATION_PRIMARY, "Button")
	t.set_constant("h_separation", VARIATION_PRIMARY, 12)
	# Apariencia propia (QA-V2-27-02). Overrides por instancia (p. ej. drink_btn de la mesa,
	# que pinta su riesgo en normal/hover/pressed) siguen mandando sobre la variación.
	var pv: String = VARIATION_PRIMARY
	t.set_color("font_color", pv, Color.WHITE)
	t.set_color("font_hover_color", pv, Color.WHITE)
	t.set_color("font_pressed_color", pv, COL_ACCENT)
	t.set_color("font_focus_color", pv, Color.WHITE)
	t.set_color("font_disabled_color", pv, COL_MUTED)
	t.set_stylebox("normal", pv, box(COL_PRIMARY_BG, 18, COL_ACCENT, PRIMARY_BORDER_W, 24, BUTTON_MARGIN_V))
	t.set_stylebox("hover", pv, box(COL_PRIMARY_BG_HOVER, 18, Color.WHITE, PRIMARY_BORDER_W, 24, BUTTON_MARGIN_V))
	t.set_stylebox("pressed", pv, box(COL_PRIMARY_BG_PRESSED, 18, Color(1.0, 0.86, 0.45), PRIMARY_BORDER_W + 1, 24, BUTTON_MARGIN_V))
	t.set_stylebox("disabled", pv, box(COL_PRIMARY_BG_DISABLED, 18, Color(0.45, 0.38, 0.22), 3, 24, BUTTON_MARGIN_V))
	t.set_stylebox("focus", pv, box(Color(0, 0, 0, 0), 18, Color.WHITE, PRIMARY_BORDER_W, 24, BUTTON_MARGIN_V))
	# Paneles
	t.set_stylebox("panel", "PanelContainer", box(COL_PANEL, 20, COL_BORDER, 3, 18, 14))
	t.set_stylebox("panel", "Panel", box(COL_PANEL, 20, COL_BORDER, 3, 18, 14))
	# LineEdit
	t.set_font_size("font_size", "LineEdit", FONT_BODY)
	t.set_color("font_color", "LineEdit", COL_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", COL_MUTED)
	t.set_color("caret_color", "LineEdit", COL_ACCENT)
	t.set_stylebox("normal", "LineEdit", box(Color(0.08, 0.08, 0.13), 14, COL_BORDER, 2, 18, 18))
	t.set_stylebox("focus", "LineEdit", box(Color(0.08, 0.08, 0.13), 14, COL_ACCENT, 3, 18, 18))
	t.set_stylebox("read_only", "LineEdit", box(Color(0.08, 0.08, 0.13), 14, COL_BORDER, 2, 18, 18))
	# Barra de progreso (temporizador)
	t.set_stylebox("background", "ProgressBar", box(Color(0.08, 0.08, 0.13), 12, COL_BORDER, 2, 4, 4))
	t.set_stylebox("fill", "ProgressBar", box(COL_ACCENT, 12, Color(0, 0, 0, 0), 0, 4, 4))
	t.set_font_size("font_size", "ProgressBar", FONT_MIN)
	# Números flotantes: variaciones de Label con contorno legible sobre cualquier fondo
	for v: Array in [["FloatDamage", COL_DAMAGE_FX.lightened(0.25)], ["FloatHeal", COL_HEAL_FX.lightened(0.25)]]:
		t.set_type_variation(v[0], "Label")
		t.set_font_size("font_size", v[0], FONT_FLOAT)
		t.set_color("font_color", v[0], v[1])
		t.set_color("font_outline_color", v[0], Color(0.02, 0.02, 0.05, 0.95))
		t.set_constant("outline_size", v[0], 10)
		t.set_color("font_shadow_color", v[0], Color(0, 0, 0, 0.6))
		t.set_constant("shadow_offset_x", v[0], 2)
		t.set_constant("shadow_offset_y", v[0], 3)
	# Scroll
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "HFlowContainer", 6)
	t.set_constant("v_separation", "HFlowContainer", 6)
	return t
