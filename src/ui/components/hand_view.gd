class_name HandView
extends Control
## Mano propia en abanico, deslizable cuando no cabe.

signal card_tapped(card: Dictionary)
signal card_zoom_requested(card: Dictionary, def: Dictionary)

const MAX_ANGLE_DEG: float = 7.0
## Fracción mínima del ancho de cada carta que queda a la vista en el abanico:
## el nombre impreso (centrado, ~25-75 % del ancho) no lo tapa la carta siguiente
## (QA-V2-27-03). Si no caben así, las cartas se estrechan hasta MIN_CARD_W y luego se desliza.
const MIN_VISIBLE: float = 0.78
const MIN_CARD_W: float = 150.0
## Alto reservado sobre/bajo las cartas (elevación de la seleccionada, arco y margen inferior).
const RESERVE_H: float = 96.0
const BOTTOM_PAD: float = 30.0
## Elevación de una carta jugable (forma además de color, para verla aunque esté semitapada).
const PLAYABLE_LIFT: float = 16.0
const SELECTED_LIFT: float = 54.0

var hand: Array = []
var selected: Array[int] = []
var interactive: bool = true
var disabled_iids: Array[int] = []
## iid -> bool (jugable). Vacío = sin resaltado.
var playable: Dictionary = {}
var scroll_x: float = 0.0
var _views: Array[CardView] = []
var _drag_active: bool = false
var _drag_last: float = 0.0
var _content_w: float = 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout)


func set_hand(p_hand: Array, p_selected: Array[int], p_interactive: bool,
		p_disabled: Array[int] = [], p_playable: Dictionary = {}) -> void:
	playable = p_playable
	hand = p_hand
	selected = p_selected
	interactive = p_interactive
	disabled_iids = p_disabled
	_rebuild()


func _rebuild() -> void:
	for v: CardView in _views:
		remove_child(v)
		v.queue_free()
	_views.clear()
	for c: Variant in hand:
		var inst: Dictionary = c
		var cv: CardView = CardView.for_instance(inst, 200.0)
		if playable.has(int(inst.get("iid", -1))):
			cv.play_state = 1 if bool(playable[int(inst["iid"])]) else 0
		cv.tapped.connect(_on_tapped)
		cv.zoom_requested.connect(_on_zoom)
		add_child(cv)
		_views.append(cv)
	_layout()


func _card_width() -> float:
	var ch: float = minf(size.y - RESERVE_H, 420.0)
	var w: float = maxf(60.0, ch / CardView.ASPECT)
	var n: int = _views.size()
	if n > 1:
		var fit: float = (size.x - 72.0) / (1.0 + MIN_VISIBLE * float(n - 1))
		w = minf(w, maxf(fit, minf(MIN_CARD_W, w)))
	return w


func _layout() -> void:
	var n: int = _views.size()
	if n == 0:
		return
	var w: float = _card_width()
	var h: float = w * CardView.ASPECT
	var pad: float = 36.0
	var avail: float = size.x - pad * 2.0
	var step: float = 0.0
	if n > 1:
		step = clampf((avail - w) / float(n - 1), w * MIN_VISIBLE, w * 0.96)
	_content_w = w + step * float(n - 1)
	var start_x: float = pad + maxf(0.0, (avail - _content_w) * 0.5)
	scroll_x = clampf(scroll_x, 0.0, maxf(0.0, _content_w - avail))
	for i: int in n:
		var cv: CardView = _views[i]
		var t: float = 0.0
		if n > 1:
			t = (float(i) - float(n - 1) * 0.5) / (float(n - 1) * 0.5)
		cv.custom_minimum_size = Vector2(w, h)
		cv.size = Vector2(w, h)
		cv.pivot_offset = Vector2(w * 0.5, h * 1.1)
		cv.rotation = deg_to_rad(t * MAX_ANGLE_DEG)
		var iid: int = cv.get_iid()
		var lift: float = 0.0
		var m: CardView.Mode = CardView.Mode.SELECTABLE if interactive else CardView.Mode.NORMAL
		if disabled_iids.has(iid):
			m = CardView.Mode.DISABLED
		if playable.has(iid):
			cv.set_playable(bool(playable[iid]))
			if bool(playable[iid]) and m != CardView.Mode.DISABLED:
				lift = PLAYABLE_LIFT
		if selected.has(iid):
			m = CardView.Mode.SELECTED
			lift = SELECTED_LIFT
		cv.set_mode(m)
		cv.z_index = 1 if m == CardView.Mode.SELECTED else 0
		var base_y: float = size.y - h - BOTTOM_PAD
		cv.position = Vector2(start_x + step * float(i) - scroll_x, base_y + 26.0 * t * t - lift)


func _on_tapped(view: CardView) -> void:
	if _drag_active:
		return
	card_tapped.emit(view.card)


func _on_zoom(c: Dictionary, d: Dictionary) -> void:
	card_zoom_requested.emit(c, d)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_last = mb.global_position.x
				_drag_active = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_scroll_by(60.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_scroll_by(-60.0)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var dx: float = mm.global_position.x - _drag_last
			if absf(dx) > 3.0:
				_drag_active = true
			if _drag_active:
				_scroll_by(-dx)
				_drag_last = mm.global_position.x
		else:
			_drag_active = false


func _scroll_by(dx: float) -> void:
	var avail: float = size.x - 72.0
	var maxs: float = maxf(0.0, _content_w - avail)
	var ns: float = clampf(scroll_x + dx, 0.0, maxs)
	if ns != scroll_x:
		scroll_x = ns
		_layout()
