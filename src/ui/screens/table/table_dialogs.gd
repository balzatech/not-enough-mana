class_name TableDialogs
extends TableModule
## Anfitrión de PromptDialog: abrir/cerrar, botones extra y despacho de los
## botones a los módulos. Cada id de botón tiene un único dueño, que lo atiende
## en su `on_dialog_button` (ver docs/TECNICO/division-table.md §4.3): un id
## nuevo lo declara su módulo dueño, este archivo no se toca para añadir botones.
##
## Colocación (V2-33, docs/diseno/escenarios/mesa-5-6-jugadores.md §5): el
## diálogo es una hoja inferior que nunca tapa el panel propio (vida y maná), la
## fila de acciones ni Beber poción; si no cabe, su contenido se desplaza. El
## escrim solo oscurece de la fila de acciones hacia abajo (rivales, centro y
## panel propio se ven con su brillo normal).

## Diálogos que bloquean la ventana de reacción y los prompts del motor.
const BUSY_KINDS: Array[String] = ["target_card", "extra", "rule", "drink_warn", "menu", "artifact"]
## Botones de acción principal de los diálogos (docs/TAREAS.md §2.1): Confirmar
## de cada prompt y Beber poción. El resto son secundarios (>= BUTTON_MIN_H).
const PRIMARY_IDS: Array[String] = ["p_focus", "p_elixir", "p_cap", "p_drink", "p_drink_free", "cards_ok"]
## Margen de la hoja con los bordes de la pantalla y con lo que no debe tapar (px a 1080).
const SHEET_MARGIN: float = 16.0
const SCRIM_ALPHA: float = 0.45

## Tipo del diálogo abierto ("" si no hay ninguno o ya se pulsó).
var kind: String = ""
var dialog: PromptDialog
var dialog_overlay: Control
## Contenedor desplazable de la hoja (su rect es el rect visible del diálogo).
var sheet: ScrollContainer
var scrim: ColorRect

var _placing: bool = false


func build_overlay() -> Control:
	dialog = PromptDialog.new()
	dialog.sheet = true
	dialog.primary_ids = PRIMARY_IDS.duplicate()
	dialog.button_pressed.connect(on_button)
	var parts: Array = make_sheet_overlay(dialog)
	dialog_overlay = parts[0]
	scrim = parts[1]
	sheet = parts[2]
	dialog_overlay.resized.connect(place)
	dialog.minimum_size_changed.connect(place)
	return dialog_overlay


## Capa modal de hoja inferior: [capa, escrim, contenedor desplazable]. Sin añadir a la mesa.
static func make_sheet_overlay(content: Control) -> Array:
	var ov: Control = Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.z_index = 50
	ov.visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, SCRIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(dim)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	ov.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.visible = true
	scroll.add_child(content)
	return [ov, dim, scroll]


## Borde inferior (en coordenadas de la capa) de lo que el diálogo no debe tapar:
## panel propio, fila de acciones, barra de modo y Beber poción.
func protected_bottom(ov: Control) -> float:
	var bottom: float = 0.0
	var inv: Transform2D = ov.get_global_transform().affine_inverse()
	for c: Control in [ctx.players.own_panel, ctx.actions.action_row, ctx.mode_bar.bar, ctx.actions.drink_btn]:
		if c != null and c.is_visible_in_tree():
			var r: Rect2 = c.get_global_rect()
			bottom = maxf(bottom, (inv * r.end).y)
	return bottom


## Coloca la hoja de `ov` bajo lo protegido (y el escrim desde la fila de acciones).
func place_sheet(ov: Control, p_scrim: ColorRect, scroll: ScrollContainer, content: Control) -> void:
	if ov == null or not ov.is_inside_tree() or _placing:
		return
	_placing = true
	var full: Vector2 = ov.size
	var top_limit: float = protected_bottom(ov) + SHEET_MARGIN
	var w: float = full.x - SHEET_MARGIN * 2.0
	content.custom_minimum_size = Vector2(w, 0)
	var want: float = content.get_combined_minimum_size().y
	var h: float = minf(want, maxf(full.y - SHEET_MARGIN - top_limit, 200.0))
	scroll.position = Vector2(SHEET_MARGIN, full.y - SHEET_MARGIN - h)
	scroll.size = Vector2(w, h)
	var own: Control = ctx.players.own_panel
	var scrim_top: float = 0.0
	if own != null and own.is_inside_tree():
		scrim_top = (ov.get_global_transform().affine_inverse() * own.get_global_rect().end).y + 4.0
	p_scrim.position = Vector2(0, scrim_top)
	p_scrim.size = Vector2(full.x, maxf(full.y - scrim_top, 0.0))
	_placing = false


func place() -> void:
	if dialog_overlay != null and dialog_overlay.visible:
		place_sheet(dialog_overlay, scrim, sheet, dialog)


func open(p_kind: String, title: String, message: String, buttons: Array, stepper_max: int = -1,
		with_text: bool = false, placeholder: String = "", stepper_min: int = 0) -> void:
	kind = p_kind
	dialog.open(title, message, buttons, stepper_max, with_text, placeholder, stepper_min)
	if p_kind == "prompt":
		dialog.set_info(_own_line())
	show_overlay()


## Línea informativa de los prompts: vida y maná propios (QA-V2-03-04).
func _own_line() -> String:
	var me: Dictionary = ctx.me()
	return "Tu vida: %d · Tu maná: %d" % [int(me.get("hp", 0)), int(me.get("mana", 0))]


## Diálogo de elección de cartas. No lo muestra: el llamador añade sus botones
## y luego llama a show_overlay().
func open_cards(p_kind: String, title: String, message: String, cards: Array, need: int) -> void:
	kind = p_kind
	dialog.open_cards(title, message, cards, need)


func show_overlay() -> void:
	dialog_overlay.visible = true
	place()
	place.call_deferred()


## Oculta el diálogo sin olvidar su tipo.
func hide_overlay() -> void:
	dialog_overlay.visible = false


func close() -> void:
	dialog_overlay.visible = false
	kind = ""


func is_open() -> bool:
	return dialog_overlay.visible


func is_busy() -> bool:
	return dialog_overlay.visible and kind in BUSY_KINDS


## Texto escrito en el diálogo (sin espacios en los extremos), o "".
func text_value() -> String:
	return dialog.text_input.text.strip_edges() if dialog.text_input != null else ""


## Cartas elegidas en un diálogo de cartas.
func chosen() -> Array[int]:
	return dialog.chosen


func stepper_value(fallback: int) -> int:
	return dialog.stepper.value if dialog.stepper != null else fallback


## Botón pulsado: cierra, pregunta a los módulos (el dueño devuelve true si lo
## consume) y, si nadie lo consume, ejecuta la cola común.
func on_button(id: String) -> void:
	dialog_overlay.visible = false
	var was: String = kind
	kind = ""
	for m: TableModule in ctx.modules:
		if m.on_dialog_button(id):
			return
	if was == "prompt":
		ctx.shown_prompt_id = -1
	if not ctx.view.is_empty():
		ctx.refresh()


## Añade un botón extra al diálogo abierto (open_cards solo trae "Confirmar").
func add_button(text: String, id: String) -> void:
	dialog.add_button(text, id, func() -> void: on_button(id))


## open_cards emite "cards_ok": lo redirigimos a otro id para este diálogo.
func rename_cards_ok(new_id: String) -> void:
	var b: Button = dialog.button_by_id("cards_ok")
	if b == null:
		return
	for conn: Dictionary in b.pressed.get_connections():
		b.pressed.disconnect(conn["callable"] as Callable)
	b.pressed.connect(func() -> void: on_button(new_id))
