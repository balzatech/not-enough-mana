class_name CardView
extends Control
## Una carta: imagen assets/cards/NNN.webp o placeholder (nombre, coste, texto).
## Mantener pulsado o doble toque => zoom_requested. Un toque => tapped.

signal tapped(view: CardView)
signal zoom_requested(card: Dictionary, def: Dictionary)

enum Mode { NORMAL, SELECTABLE, SELECTED, DISABLED }

const ASPECT: float = 1.4          # alto / ancho
const LONG_PRESS_S: float = 0.45
const DOUBLE_TAP_S: float = 0.35
const MOVE_THRESHOLD: float = 14.0
const FRAME_PLAYABLE: String = "res://assets/ui/frame_jugable_9slice.png"
const FRAME_MARGIN: float = 14.0
const DIM_UNPLAYABLE: Color = Color(0.45, 0.45, 0.52)
const BORDER_UNPLAYABLE: Color = Color(0.42, 0.42, 0.48)

var card: Dictionary = {}
var def: Dictionary = {}
var face_down: bool = false
var is_mini: bool = false
var mode: Mode = Mode.NORMAL
var curse_style: bool = false
## Jugabilidad en la mano: -1 sin dato, 0 no jugable (atenuada), 1 jugable (marco verde).
var play_state: int = -1

var _bg: Panel
var _border: Panel
var _frame: Panel
var _art: TextureRect
var _ph: MarginContainer
var _name_label: Label
var _cost_label: Label
var _meta_label: Label
var _text_label: Label
var _pressing: bool = false
var _moved: bool = false
var _long: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_id: int = 0
var _last_tap_ms: int = -10000


## card = instancia {iid, card_id} ({} para una carta genérica); def = definición.
static func create(p_card: Dictionary, p_def: Dictionary, p_width: float,
		p_face_down: bool = false, p_mini: bool = false) -> CardView:
	var cv: CardView = CardView.new()
	cv.card = p_card
	cv.def = p_def
	cv.face_down = p_face_down
	cv.is_mini = p_mini
	cv.custom_minimum_size = Vector2(p_width, p_width * ASPECT)
	cv.size = cv.custom_minimum_size
	return cv


static func for_instance(p_card: Dictionary, p_width: float, p_face_down: bool = false,
		p_mini: bool = false) -> CardView:
	var d: Dictionary = UiUtil.card_def(String(p_card.get("card_id", ""))) if not p_face_down else {}
	return create(p_card, d, p_width, p_face_down, p_mini)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	_build()
	resized.connect(_apply_fonts)
	_apply_mode()
	_apply_fonts()


func set_mode(m: Mode) -> void:
	mode = m
	if is_node_ready():
		_apply_mode()


## Marca la carta como jugable (true) o no (false) en la mano.
func set_playable(v: bool) -> void:
	play_state = 1 if v else 0
	if is_node_ready():
		_apply_mode()


func get_iid() -> int:
	return int(card.get("iid", -1))


func _build() -> void:
	var radius: int = 8 if is_mini else 14
	_bg = Panel.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bgc: Color = Color(0.20, 0.12, 0.34) if face_down else UiUtil.card_color(def)
	_bg.add_theme_stylebox_override("panel", UiTheme.box(bgc, radius, Color(0, 0, 0, 0), 0, 0, 0))
	add_child(_bg)
	var tex: Texture2D = null
	if face_down:
		tex = UiUtil.card_back_texture()
	else:
		tex = UiUtil.card_texture(def)
	if tex != null:
		_art = TextureRect.new()
		_art.texture = tex
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_SCALE
		_art.set_anchors_preset(Control.PRESET_FULL_RECT)
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_art)
	elif not face_down:
		_build_placeholder()
	else:
		_build_back_placeholder()
	_border = Panel.new()
	_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border)
	_frame = Panel.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = UiUtil.load_texture(FRAME_PLAYABLE)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, FRAME_MARGIN)
	sb.draw_center = false
	_frame.add_theme_stylebox_override("panel", sb)
	_frame.visible = false
	add_child(_frame)


func _build_back_placeholder() -> void:
	var l: Label = UiUtil.label("NEM", 20, Color(0.8, 0.7, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	_name_label = l
	add_child(l)


func _build_placeholder() -> void:
	_ph = MarginContainer.new()
	_ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ph)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ph.add_child(box)
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	_name_label = UiUtil.label(String(def.get("name", "?")), 14, Color.WHITE)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name_label)
	if is_mini:
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		return
	var cost: Dictionary = def.get("cost", {}) as Dictionary
	_cost_label = UiUtil.label(_cost_text(cost), 14, UiTheme.COL_ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	top.add_child(_cost_label)
	var meta: String = UiUtil.type_name(String(def.get("type", "")))
	var el: String = UiUtil.element_name(String(def.get("element", "")))
	if el != "":
		meta += " · " + el
	_meta_label = UiUtil.label(meta, 11, Color(0.85, 0.85, 0.9))
	box.add_child(_meta_label)
	var txt: String = String(def.get("text", ""))
	if txt == "":
		txt = String(def.get("incantation", ""))
	_text_label = UiUtil.label(txt, 11, Color(0.95, 0.95, 0.92))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.clip_text = true
	box.add_child(_text_label)


static func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	var mana: int = int(cost.get("mana", 0))
	if mana > 0:
		parts.append("%d maná" % mana)
	var cards: Array = cost.get("cards", []) as Array
	var n: int = 0
	for r: Variant in cards:
		var rd: Dictionary = r
		n += int(rd.get("count", 1))
	if n > 0:
		parts.append("+%d carta%s" % [n, "s" if n > 1 else ""])
	if parts.is_empty():
		return "0"
	return " ".join(parts)


func _apply_fonts() -> void:
	var w: float = maxf(size.x, 40.0)
	if _name_label != null:
		var fs: int = int(maxf(8.0, w * (0.19 if is_mini else 0.085)))
		if face_down:
			fs = int(maxf(10.0, w * 0.22))
		_name_label.add_theme_font_size_override("font_size", fs)
	if _cost_label != null:
		_cost_label.add_theme_font_size_override("font_size", int(maxf(8.0, w * 0.075)))
	if _meta_label != null:
		_meta_label.add_theme_font_size_override("font_size", int(maxf(7.0, w * 0.058)))
	if _text_label != null:
		_text_label.add_theme_font_size_override("font_size", int(maxf(7.0, w * 0.062)))
	if _ph != null:
		var m: int = int(maxf(4.0, w * 0.05))
		_ph.add_theme_constant_override("margin_left", m)
		_ph.add_theme_constant_override("margin_right", m)
		_ph.add_theme_constant_override("margin_top", m)
		_ph.add_theme_constant_override("margin_bottom", m)
	if _border != null:
		_apply_mode()


func _apply_mode() -> void:
	var radius: int = 8 if is_mini else 14
	var color: Color = Color(0.55, 0.45, 0.20)
	var bw: int = 2 if is_mini else 3
	modulate = Color.WHITE
	match mode:
		Mode.NORMAL:
			if curse_style:
				color = Color(0.70, 0.30, 0.85)
		Mode.SELECTABLE:
			color = Color(0.40, 0.85, 0.55)
			bw = 4 if is_mini else 5
		Mode.SELECTED:
			color = UiTheme.COL_ACCENT
			bw = 5 if is_mini else 8
		Mode.DISABLED:
			modulate = Color(0.5, 0.5, 0.55)
	var framed: bool = play_state == 1 and mode != Mode.DISABLED and mode != Mode.SELECTED
	if play_state == 0 and mode != Mode.DISABLED:
		modulate = DIM_UNPLAYABLE if mode != Mode.SELECTED else Color(0.8, 0.8, 0.85)
		# Sin verde en las no jugables: el verde queda solo para el marco de "jugable"
		# y se distingue aunque la carta esté semitapada (QA-V2-27-03).
		if mode == Mode.SELECTABLE:
			color = BORDER_UNPLAYABLE
			bw = 2 if is_mini else 3
	if framed and mode == Mode.SELECTABLE:
		bw = 0
	if _frame != null:
		_frame.visible = framed
	if _border != null:
		_border.add_theme_stylebox_override("panel",
			UiTheme.box(Color(0, 0, 0, 0), radius, color, bw, 0, 0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressing = true
			_moved = false
			_long = false
			_press_pos = mb.global_position
			_press_id += 1
			get_tree().create_timer(LONG_PRESS_S).timeout.connect(_on_long_press.bind(_press_id))
		else:
			if _pressing and not _moved and not _long:
				_handle_tap()
			_pressing = false
	elif event is InputEventMouseMotion and _pressing:
		var mm: InputEventMouseMotion = event
		if mm.global_position.distance_to(_press_pos) > MOVE_THRESHOLD:
			_moved = true


func _handle_tap() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_tap_ms <= int(DOUBLE_TAP_S * 1000.0):
		_last_tap_ms = -10000
		_request_zoom()
		return
	_last_tap_ms = now
	tapped.emit(self)


func _on_long_press(id: int) -> void:
	if not is_inside_tree() or id != _press_id or not _pressing or _moved:
		return
	_long = true
	_request_zoom()


func _request_zoom() -> void:
	if face_down:
		return
	zoom_requested.emit(card, def)
