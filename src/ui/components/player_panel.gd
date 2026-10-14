class_name PlayerPanel
extends PanelContainer
## Panel de un mago: vida, maná, cartas, pociones, artefactos y maldiciones
## (miniaturas tocables), turno, eliminado, desconectado y estados.
## Legibilidad (V2-33, docs/diseno/escenarios/mesa-5-6-jugadores.md §3): los
## estados son iconos de 48 px de assets/ui/ (sin rótulos de texto) en una fila
## de altura reservada; todo texto >= UiTheme.FONT_MIN.

signal tapped(player_id: String)
signal card_zoom_requested(card: Dictionary, def: Dictionary)

## Lado de un icono de estado y alto reservado de su fila (a 1080).
const ICON_SIZE: int = 48
## Casillas de la fila de iconos de un rival (estados + miniaturas).
const ICON_SLOTS: int = 6
const ICON_GAP: int = 4
const NAME_FONT: int = 28
const NAME_FONT_WIDE: int = 30
const CHIP_FONT: int = 26
const CHIP_FONT_WIDE: int = 28
const TAG_FONT: int = UiTheme.FONT_MIN
## Alto mínimo del panel de rival con estadísticas en 2 filas (6j, 3-4j) y en 1 fila (5j).
const MIN_H_TWO_ROWS: float = 200.0
const MIN_H_ONE_ROW: float = 160.0
## Ancho de las miniaturas de artefactos y maldiciones del panel propio.
const OWN_MINI_W: float = 56.0
const ICON_PATHS: Dictionary = {
	"TURNO": "res://assets/ui/icon_turno_48.png",
	"Bot": "res://assets/ui/icon_bot_48.png",
	"Congelado": "res://assets/ui/icon_congelado_48.png",
	"Cegado": "res://assets/ui/icon_cegado_48.png",
	"Escudo": "res://assets/ui/icon_campo_fuerza_48.png",
	"Maldito": "res://assets/ui/icon_maldito_48.png",
	"ELIMINADO": "res://assets/ui/icon_eliminado_48.png",
}
## Nombre accesible (tooltip) de cada icono.
const ICON_NAMES: Dictionary = {
	"TURNO": "Su turno", "Bot": "Bot", "Congelado": "Congelado", "Cegado": "Cegado",
	"Escudo": "Campo de fuerza", "Maldito": "Maldito", "ELIMINADO": "Eliminado",
}
const TEXT_ELIMINATED: String = "Eliminado"
const TEXT_DISCONNECTED: String = "Desconectado"
## Opacidad del contenido de un panel eliminado (la lápida va a opacidad completa).
const ELIMINATED_ALPHA: float = 0.5

var player_id: String = ""
var wide: bool = false
var panel_width: float = 200.0
## Filas de estadísticas de un rival: 2 (vida+pociones / maná+cartas) o 1 (las cuatro).
var stat_rows: int = 2
var player: Dictionary = {}
var is_turn: bool = false
var pickable: bool = false
var picked: bool = false
## Redibujados reales (para tests del refresco incremental).
var rebuild_count: int = 0
## Fila de iconos de estado (altura reservada) del último redibujado (tests).
var status_row: Control = null

var _sig: String = ""


static func create(p_wide: bool = false, p_width: float = 200.0, p_stat_rows: int = 2) -> PlayerPanel:
	var pp: PlayerPanel = PlayerPanel.new()
	pp.wide = p_wide
	pp.panel_width = p_width
	pp.stat_rows = p_stat_rows
	return pp


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not wide:
		custom_minimum_size = Vector2(panel_width, min_height())
	_rebuild()


## Alto mínimo de un panel de rival según sus filas de estadísticas.
func min_height() -> float:
	return MIN_H_ONE_ROW if stat_rows == 1 else MIN_H_TWO_ROWS


## Cambia ancho y filas de estadísticas (rejilla de rivales). Redibuja si cambian las filas.
func set_layout(p_width: float, p_stat_rows: int) -> void:
	var rows_changed: bool = p_stat_rows != stat_rows
	panel_width = p_width
	stat_rows = p_stat_rows
	if not wide:
		custom_minimum_size = Vector2(p_width, min_height())
	if rows_changed and is_node_ready():
		_rebuild()


## Actualiza con el diccionario de jugador de la vista. Si nada cambió (misma
## firma) no redibuja (bus-presentacion.md §5). Devuelve true si redibujó.
func update_player(p: Dictionary, p_is_turn: bool, p_pickable: bool = false,
		p_picked: bool = false) -> bool:
	var sig: String = "%s|%s|%s|%s" % [JSON.stringify(p), p_is_turn, p_pickable, p_picked]
	if sig == _sig and is_node_ready():
		return false
	_sig = sig
	player = p
	player_id = String(p.get("id", ""))
	is_turn = p_is_turn
	pickable = p_pickable
	picked = p_picked
	if is_node_ready():
		_rebuild()
		return true
	return false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			tapped.emit(player_id)


func is_eliminated() -> bool:
	return bool(player.get("eliminated", false))


func _style() -> void:
	var eliminated: bool = is_eliminated()
	var bg: Color = UiTheme.COL_PANEL
	var border: Color = UiTheme.COL_BORDER
	var bw: int = 3
	if eliminated:
		bg = Color(0.09, 0.09, 0.10, 0.9)
		border = Color(0.25, 0.25, 0.28)
	if is_turn:
		border = UiTheme.COL_ACCENT
		bw = 6
		bg = bg.lightened(0.15)
	if pickable:
		border = Color(0.40, 0.85, 0.55)
		bw = 6
	if picked:
		border = UiTheme.COL_ACCENT
		bw = 9
		bg = Color(0.25, 0.20, 0.10, 0.95)
	add_theme_stylebox_override("panel", UiTheme.box(bg, 20, border, bw, 12, 8))
	# Sin `modulate` del panel: el atenuado de un eliminado va en su contenido
	# para que la lápida se vea a opacidad completa.
	modulate = Color.WHITE


## Estados lógicos del mago (cada uno se dibuja como icono o, sin icono, como texto).
func _tags() -> Array[String]:
	var tags: Array[String] = []
	if is_turn:
		tags.append("TURNO")
	if bool(player.get("eliminated", false)):
		tags.append("ELIMINADO")
	if not bool(player.get("connected", true)):
		tags.append("DESCONECTADO")
	var flags: Dictionary = player.get("flags", {}) as Dictionary
	if int(flags.get("frozen", 0)) > 0:
		tags.append("Congelado")
	if bool(flags.get("blinded", false)):
		tags.append("Cegado")
	if String(flags.get("force_field", "")) != "":
		tags.append("Escudo")
	if not (player.get("curses", []) as Array).is_empty():
		tags.append("Maldito")
	if bool(player.get("is_bot", false)):
		tags.append("Bot")
	return tags


## Iconos de estado visibles en el último redibujado (tests): claves de ICON_PATHS.
func status_icons() -> Array[String]:
	var out: Array[String] = []
	_collect_icons(self, out)
	return out


func _collect_icons(n: Node, out: Array[String]) -> void:
	for c: Node in n.get_children():
		if c.has_meta("status_icon"):
			out.append(String(c.get_meta("status_icon")))
		_collect_icons(c, out)


func _rebuild() -> void:
	rebuild_count += 1
	UiUtil.clear_children(self)
	status_row = null
	if player.is_empty():
		return
	_style()
	var tags: Array[String] = _tags()
	var eliminated: bool = tags.has("ELIMINADO")
	if eliminated:
		var hatch: Hatch = Hatch.new()
		hatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hatch.clip_contents = true
		add_child(hatch)
	if wide:
		_build_wide(tags)
	else:
		_build_compact(tags)


func _name_label(font: int) -> Label:
	var name_label: Label = UiUtil.label(String(player.get("name", "?")), font)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return name_label


func _chip(kind: String, value: int, font: int) -> StatChip:
	var c: StatChip = StatChip.create(kind, value, font)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _chips(font: int) -> Array[StatChip]:
	var hand_n: int = int(player.get("hand_count", (player.get("hand", []) as Array).size()))
	return [_chip(StatChip.KIND_HP, int(player.get("hp", 0)), font),
		_chip(StatChip.KIND_POTION, int(player.get("potions", 0)), font),
		_chip(StatChip.KIND_MANA, int(player.get("mana", 0)), font),
		_chip(StatChip.KIND_CARDS, hand_n, font)] as Array[StatChip]


func _hbox(sep: int) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


## Rival (rejilla): nombre + Bot + Turno; estadísticas en 1 o 2 filas; fila de
## iconos de 48 con altura reservada (estados y miniaturas, hasta ICON_SLOTS).
func _build_compact(tags: Array[String]) -> void:
	var eliminated: bool = tags.has("ELIMINADO")
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", ICON_GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head: HBoxContainer = _hbox(ICON_GAP)
	head.custom_minimum_size = Vector2(0, ICON_SIZE)
	var nm: Label = _name_label(NAME_FONT)
	head.add_child(nm)
	if tags.has("Bot"):
		head.add_child(_status_icon("Bot"))
	if eliminated:
		head.add_child(_status_icon("ELIMINADO"))
	elif tags.has("TURNO"):
		head.add_child(_status_icon("TURNO"))
	col.add_child(head)
	var chips: Array[StatChip] = _chips(CHIP_FONT)
	var dimmed: Array[Control] = [nm]
	if stat_rows == 1:
		var row: HBoxContainer = _hbox(6)
		for c: StatChip in chips:
			row.add_child(c)
		col.add_child(row)
		dimmed.append(row)
	else:
		var r1: HBoxContainer = _hbox(6)
		r1.add_child(chips[0])
		r1.add_child(chips[1])
		var r2: HBoxContainer = _hbox(6)
		r2.add_child(chips[2])
		r2.add_child(chips[3])
		col.add_child(r1)
		col.add_child(r2)
		dimmed.append(r1)
		dimmed.append(r2)
	var icons: HBoxContainer = _hbox(ICON_GAP)
	icons.custom_minimum_size = Vector2(0, ICON_SIZE)
	icons.mouse_filter = Control.MOUSE_FILTER_PASS
	status_row = icons
	col.add_child(icons)
	_fill_status_row(icons, tags, ICON_SLOTS, true)
	if eliminated:
		for d: Control in dimmed:
			d.modulate = Color(1, 1, 1, ELIMINATED_ALPHA)


## Panel propio (ancho completo): [nombre / fila de iconos] [estadísticas 2x2] [miniaturas].
func _build_wide(tags: Array[String]) -> void:
	var eliminated: bool = tags.has("ELIMINADO")
	var row: HBoxContainer = _hbox(12)
	add_child(row)
	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.custom_minimum_size = Vector2(320, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm: Label = _name_label(NAME_FONT_WIDE)
	left.add_child(nm)
	var icons: HBoxContainer = _hbox(ICON_GAP)
	icons.custom_minimum_size = Vector2(0, ICON_SIZE)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_row = icons
	if tags.has("TURNO") and not eliminated:
		icons.add_child(_status_icon("TURNO"))
	if tags.has("Bot"):
		icons.add_child(_status_icon("Bot"))
	_fill_status_row(icons, tags, ICON_SLOTS, false)
	left.add_child(icons)
	row.add_child(left)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 0)
	grid.custom_minimum_size = Vector2(240, 0)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for c: StatChip in _chips(CHIP_FONT_WIDE):
		grid.add_child(c)
	row.add_child(grid)
	var minis: HFlowContainer = HFlowContainer.new()
	minis.mouse_filter = Control.MOUSE_FILTER_PASS
	minis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minis.alignment = FlowContainer.ALIGNMENT_END
	for a: Variant in player.get("artifacts", []) as Array:
		minis.add_child(_mini(a as Dictionary, false, OWN_MINI_W))
	for c: Variant in player.get("curses", []) as Array:
		minis.add_child(_mini(c as Dictionary, true, OWN_MINI_W))
	row.add_child(minis)
	if eliminated:
		nm.modulate = Color(1, 1, 1, ELIMINATED_ALPHA)
		grid.modulate = Color(1, 1, 1, ELIMINATED_ALPHA)


## Estados (Congelado, Cegado, Escudo, Maldito), Eliminado/Desconectado y, si
## `with_minis`, miniaturas de artefactos y maldiciones. Con más de `slots`
## elementos, la última casilla es "+n".
func _fill_status_row(box: HBoxContainer, tags: Array[String], slots: int, with_minis: bool) -> void:
	var items: Array[Control] = []
	if tags.has("ELIMINADO"):
		# Lápida (en la cabecera del rival; aquí en el panel propio) + texto.
		if wide:
			items.append(_status_icon("ELIMINADO"))
		items.append(_tag_label(TEXT_ELIMINATED, UiTheme.COL_DANGER))
	if tags.has("DESCONECTADO"):
		items.append(_tag_label(TEXT_DISCONNECTED, UiTheme.COL_DANGER))
	for t: String in ["Congelado", "Cegado", "Escudo", "Maldito"]:
		if tags.has(t):
			items.append(_status_icon(t))
	if with_minis:
		for a: Variant in player.get("artifacts", []) as Array:
			items.append(_cropped_mini(a as Dictionary, false))
		for c: Variant in player.get("curses", []) as Array:
			items.append(_cropped_mini(c as Dictionary, true))
	var room: int = maxi(slots - box.get_child_count(), 1)
	var shown: int = items.size() if items.size() <= room else room - 1
	for i: int in items.size():
		if i < shown:
			box.add_child(items[i])
		else:
			items[i].free()
	if shown < items.size():
		box.add_child(_tag_label("+%d" % (items.size() - shown), UiTheme.COL_TEXT))


func _status_icon(tag: String) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = UiUtil.load_texture(String(ICON_PATHS.get(tag, "")))
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = String(ICON_NAMES.get(tag, tag))
	icon.set_meta("status_icon", tag)
	return icon


func _tag_label(text: String, color: Color) -> Label:
	var l: Label = UiUtil.label(text, TAG_FONT, color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _mini(table_card: Dictionary, is_curse: bool, width: float) -> CardView:
	var inst: Dictionary = {"iid": int(table_card.get("iid", -1)),
		"card_id": String(table_card.get("card_id", ""))}
	var cv: CardView = CardView.for_instance(inst, width, false, true)
	cv.curse_style = is_curse
	cv.tapped.connect(_on_icon_tapped)
	cv.zoom_requested.connect(_on_icon_zoom)
	return cv


## Miniatura recortada a una casilla de 48x48 (parte superior de la carta).
func _cropped_mini(table_card: Dictionary, is_curse: bool) -> Control:
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(_mini(table_card, is_curse, float(ICON_SIZE)))
	return holder


func _on_icon_tapped(view: CardView) -> void:
	card_zoom_requested.emit(view.card, view.def)


func _on_icon_zoom(c: Dictionary, d: Dictionary) -> void:
	card_zoom_requested.emit(c, d)


## Rayado diagonal de un panel eliminado (forma, no solo color).
class Hatch extends Control:
	func _draw() -> void:
		var step: float = 22.0
		var col: Color = Color(0.55, 0.55, 0.6, 0.35)
		var x: float = -size.y
		while x < size.x:
			draw_line(Vector2(x, size.y), Vector2(x + size.y, 0.0), col, 3.0)
			x += step

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
