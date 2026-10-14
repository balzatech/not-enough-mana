class_name TableNotices
extends TableModule
## Avisos modales, de uno en uno: eventos nuevos (LOG_EVENT_DRAWN) y
## revelaciones privadas del que mira (Twardowsky's Mirror, Magic Hand...).

## Alto máximo de la carta de un aviso en la hoja inferior (mesa-5-6-jugadores.md §5.3).
const CARD_W: float = 200.0

var notice_overlay: Control
var notice_panel: PanelContainer
var notice_scrim: ColorRect
var notice_sheet: ScrollContainer

var _seen_reveals: Dictionary = {}
var _notices: Array[Dictionary] = []


func build_overlay() -> Control:
	notice_panel = PanelContainer.new()
	notice_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.07, 0.13, 0.98), 28,
		UiTheme.COL_ACCENT, 5, 32, 28))
	# Hoja inferior, como los diálogos: no tapa vida y maná propios (V2-33).
	var parts: Array = TableDialogs.make_sheet_overlay(notice_panel)
	notice_overlay = parts[0]
	notice_scrim = parts[1]
	notice_sheet = parts[2]
	notice_overlay.z_index = 55
	notice_overlay.resized.connect(_place)
	return notice_overlay


func _place() -> void:
	if notice_overlay.visible:
		ctx.dialogs.place_sheet(notice_overlay, notice_scrim, notice_sheet, notice_panel)


## Encola un aviso por cada evento revelado (LOG_EVENT_DRAWN) en `entries`.
func queue_event_notices(entries: Array) -> void:
	for e: Variant in entries:
		var ed: Dictionary = e
		if String(ed.get("type", "")) != Types.LOG_EVENT_DRAWN:
			continue
		var data: Dictionary = ed.get("data", {}) as Dictionary
		var cid: String = String(data.get("card_id", ""))
		var def: Dictionary = UiUtil.card_def(cid)
		_notices.append({"title": "Nuevo evento", "text": StringsAyuda.event_notice(String(def.get("name", cid)), bool(def.get("persistent", false))),
			"card": {"iid": int(data.get("iid", -1)), "card_id": cid}})
	if ctx.screen.is_node_ready() and not ctx.view.is_empty():
		show_next()


## Revelaciones privadas nuevas del que mira (Twardowsky's Mirror, Icy Grasp...).
func check_reveals() -> void:
	var view: Dictionary = ctx.view
	var viewer: String = ctx.viewer_id
	var list: Array = (view.get("reveals", {}) as Dictionary).get(viewer, []) as Array
	for r: Variant in list:
		var rd: Dictionary = r
		var key: String = "%s|%s" % [viewer, JSON.stringify(rd)]
		if _seen_reveals.has(key):
			continue
		_seen_reveals[key] = true
		var cards: Array = rd.get("cards", []) as Array
		match String(rd.get("kind", "")):
			"deck_top":
				if not cards.is_empty():
					_notices.append({"title": "Twardowsky's Mirror",
						"text": "Carta de arriba del mazo (solo la ves tú).", "card": cards[0]})
			"card":
				if not cards.is_empty():
					_notices.append({"title": "Carta robada",
						"text": "Te has quedado esta carta de %s." % TableContext.name_of(view, String(rd.get("of", ""))),
						"card": cards[0]})
			"hand":
				if cards.is_empty():
					_notices.append({"title": "Magic Hand",
						"text": "La mano de %s está vacía." % TableContext.name_of(view, String(rd.get("of", ""))),
						"card": {}})


func show_next() -> void:
	if notice_overlay == null or notice_overlay.visible or _notices.is_empty():
		return
	var n: Dictionary = _notices.pop_front()
	UiUtil.clear_children(notice_panel)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	notice_panel.add_child(row)
	var card: Dictionary = n.get("card", {}) as Dictionary
	if not card.is_empty():
		var cv: CardView = CardView.for_instance(card, CARD_W)
		cv.zoom_requested.connect(ctx.zoom)
		cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cv)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiUtil.label(String(n["title"]), 40, UiTheme.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var msg: Label = UiUtil.label(String(n["text"]), 30, UiTheme.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(msg)
	var ok: Button = UiUtil.button("Continuar", 36, UiTheme.BUTTON_MIN_H)
	ok.pressed.connect(on_notice_ok)
	col.add_child(ok)
	notice_overlay.visible = true
	_place()
	_place.call_deferred()


func on_notice_ok() -> void:
	notice_overlay.visible = false
	show_next()


## Avisos pendientes (cola + el que se está mostrando).
func pending() -> int:
	return _notices.size() + (1 if notice_overlay.visible else 0)
