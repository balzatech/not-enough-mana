class_name TableCenter
extends TableModule
## Centro de la mesa: mazo, descarte y evento activo.

var center: HBoxContainer
## Reconstrucciones reales (para tests del refresco incremental).
var rebuild_count: int = 0

var _sig: String = ""

## Alto mínimo del centro (cartas + etiquetas) con 3-4 jugadores y con 5-6, y su
## reparto del espacio sobrante frente a la mano (que se queda con la mayor parte).
const MIN_H: float = 300.0
const MIN_H_CROWDED: float = 266.0
const STRETCH: float = 0.25


func build() -> HBoxContainer:
	center = HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 36)
	center.custom_minimum_size = Vector2(0, 300)
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = STRETCH
	center.resized.connect(rebuild)
	return center


func rebuild() -> void:
	var view: Dictionary = ctx.view
	if view.is_empty():
		return
	var crowded: bool = (view.get("players", []) as Array).size() >= 5
	var min_h: float = MIN_H_CROWDED if crowded else MIN_H
	if absf(center.custom_minimum_size.y - min_h) > 0.5:
		center.custom_minimum_size = Vector2(0, min_h)
	var deck_n: int = int(view.get("deck_count", (view.get("deck", []) as Array).size()))
	var cw: float = clampf((center.size.y - 56.0) / CardView.ASPECT, 150.0, 240.0)
	var discard: Array = view.get("discard", []) as Array
	var ev: Dictionary = view.get("active_event", {}) as Dictionary
	# Firma (bus-presentacion.md §5): si no cambió nada visible, no se toca.
	var top_iid: int = -1
	if not discard.is_empty():
		top_iid = int((discard[discard.size() - 1] as Dictionary).get("iid", -1))
	var sig: String = "%d|%d|%d|%d|%d" % [deck_n, discard.size(), top_iid,
		int(ev.get("iid", -1)) if not ev.is_empty() else -1, roundi(cw)]
	if sig == _sig and center.get_child_count() > 0:
		return
	_sig = sig
	rebuild_count += 1
	UiUtil.clear_children(center)
	var back: CardView = CardView.create({}, {}, cw, true)
	center.add_child(_center_column("Mazo: %d" % deck_n, back))
	var dv: Control
	if discard.is_empty():
		dv = _empty_slot(cw)
	else:
		var cv: CardView = CardView.for_instance(discard[discard.size() - 1] as Dictionary, cw)
		cv.zoom_requested.connect(ctx.zoom)
		cv.tapped.connect(_on_card_tapped)
		dv = cv
	center.add_child(_center_column("Descarte: %d" % discard.size(), dv))
	var evv: Control
	if ev.is_empty():
		evv = _empty_slot(cw)
	else:
		var ec: CardView = CardView.for_instance({"iid": ev["iid"], "card_id": ev["card_id"]}, cw)
		ec.zoom_requested.connect(ctx.zoom)
		ec.tapped.connect(_on_card_tapped)
		evv = ec
	center.add_child(_center_column("Evento", evv))


func _center_column(caption: String, content: Control) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(content)
	col.add_child(UiUtil.label(caption, 26, UiTheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	return col


func _empty_slot(w: float) -> Control:
	var p: Panel = Panel.new()
	p.custom_minimum_size = Vector2(w, w * CardView.ASPECT)
	p.add_theme_stylebox_override("panel",
		UiTheme.box(Color(0.1, 0.1, 0.14, 0.6), 14, Color(0.3, 0.3, 0.38), 2, 0, 0))
	return p


func _on_card_tapped(cv: CardView) -> void:
	ctx.zoom(cv.card, cv.def)
