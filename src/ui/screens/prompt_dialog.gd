class_name PromptDialog
extends PanelContainer
## Diálogo genérico de decisión: título, mensaje, línea informativa opcional,
## selector numérico opcional y botones.
## Modo `sheet` (hoja inferior de la mesa, V2-33): más compacto, botones en filas
## de hasta MAX_PER_ROW (como mucho dos filas en los prompts), el principal a la
## derecha (UiTheme.apply_primary) y el resto >= UiTheme.BUTTON_MIN_H.

signal button_pressed(id: String)

## Botones por fila en modo hoja.
const MAX_PER_ROW: int = 3
## Separación entre botones de la hoja: la de Beber poción (24) vale para todos.
const SHEET_BUTTON_GAP: int = UiTheme.BUTTON_GAP_POTION
## Lado de los botones -/+ del selector (secundarios, 96x96).
const STEPPER_BUTTON: float = 96.0

var stepper: Stepper = null
var text_input: LineEdit = null
var chosen: Array[int] = []
## Hoja inferior (true) o caja centrada (false, por defecto).
var sheet: bool = false
## Ids de botón que son acción principal (alto UiTheme.BUTTON_PRIMARY_H).
var primary_ids: Array[String] = []
## Línea informativa (p. ej. "Tu vida: 10 · Tu maná: 3"); null si no hay.
var info_label: Label = null
## Botones del último open (en orden de pantalla).
var buttons: Array[Button] = []
var _col: VBoxContainer
var _rows: VBoxContainer = null
var _built: bool = false


func _ready() -> void:
	theme = UiTheme.get_theme()
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.07, 0.13, 0.98), 28,
		UiTheme.COL_ACCENT, 5, 32, 28))
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 22)
	add_child(_col)


func _begin(title: String, message: String) -> void:
	_build()
	if sheet:
		add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.07, 0.13, 0.98), 28,
			UiTheme.COL_ACCENT, 5, 24, 18))
		_col.add_theme_constant_override("separation", 12)
	UiUtil.clear_children(_col)
	stepper = null
	text_input = null
	info_label = null
	_rows = null
	buttons.clear()
	_col.add_child(UiUtil.label(title, 38 if sheet else 44, UiTheme.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var msg: Label = UiUtil.label(message, 30 if sheet else 32, UiTheme.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(msg)


## buttons: Array de {id:String, text:String}. stepper_max < 0 => sin selector.
func open(title: String, message: String, p_buttons: Array, stepper_max: int = -1,
		with_text: bool = false, placeholder: String = "", stepper_min: int = 0) -> void:
	_begin(title, message)
	if stepper_max >= 0:
		stepper = Stepper.create(stepper_min, stepper_min, maxi(stepper_min, stepper_max))
		_col.add_child(stepper)
		size_stepper(stepper)
	if with_text:
		text_input = LineEdit.new()
		text_input.placeholder_text = placeholder
		text_input.custom_minimum_size = Vector2(0, 90)
		_col.add_child(text_input)
	for b: Variant in p_buttons:
		var bd: Dictionary = b
		add_button(String(bd["text"]), String(bd["id"]))
	visible = true


## Línea informativa fija bajo el mensaje (sustituye a la anterior).
func set_info(text: String) -> void:
	if info_label != null and is_instance_valid(info_label):
		info_label.queue_free()
	info_label = UiUtil.label(text, UiTheme.FONT_BODY, UiTheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(info_label)
	_col.move_child(info_label, mini(2, _col.get_child_count() - 1))


## Añade un botón. En modo hoja va en las filas de botones (secundarios a la
## izquierda, principales a la derecha); si no, en la columna.
func add_button(text: String, id: String, cb: Callable = Callable()) -> Button:
	var primary: bool = primary_ids.has(id)
	var btn: Button = UiUtil.button(text, 32 if sheet else 36, UiTheme.BUTTON_PRIMARY_H if primary else 110)
	if primary:
		UiTheme.apply_primary(btn)
	if cb.is_valid():
		btn.pressed.connect(cb)
	else:
		btn.pressed.connect(_emit.bind(id))
	btn.set_meta("dialog_id", id)
	if not sheet:
		_col.add_child(btn)
		buttons.append(btn)
		return btn
	btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, float(UiTheme.BUTTON_MIN_H))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buttons.append(btn)
	_layout_rows()
	return btn


## Reparte los botones en filas: los principales al final (derecha).
func _layout_rows() -> void:
	if _rows == null:
		_rows = VBoxContainer.new()
		_rows.add_theme_constant_override("separation", SHEET_BUTTON_GAP)
		_col.add_child(_rows)
	for r: Node in _rows.get_children():
		for c: Node in r.get_children():
			r.remove_child(c)
		_rows.remove_child(r)
		r.queue_free()
	var ordered: Array[Button] = []
	for b: Button in buttons:
		if not primary_ids.has(String(b.get_meta("dialog_id", ""))):
			ordered.append(b)
	for b: Button in buttons:
		if primary_ids.has(String(b.get_meta("dialog_id", ""))):
			ordered.append(b)
	buttons = ordered
	var per_row: int = MAX_PER_ROW if ordered.size() != 4 else 2
	var row: HBoxContainer = null
	for i: int in ordered.size():
		if i % per_row == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", SHEET_BUTTON_GAP)
			_rows.add_child(row)
		row.add_child(ordered[i])


## Botones -/+ del selector a 96x96 (secundarios, docs/TAREAS.md §2.1).
## (Estático: también lo usan las pantallas con selectores, p. ej. LocalSetup.)
static func size_stepper(s: Stepper, big_number: bool = true) -> void:
	if not s.is_node_ready():
		s.ready.connect(size_stepper.bind(s, big_number), CONNECT_ONE_SHOT)
		return
	s.add_theme_constant_override("separation", UiTheme.BUTTON_GAP_MIN)
	for c: Node in s.get_children():
		if c is Button:
			(c as Button).custom_minimum_size = Vector2(STEPPER_BUTTON, STEPPER_BUTTON)
		elif c is Label and big_number:
			(c as Label).add_theme_font_size_override("font_size", UiTheme.FONT_FLOAT)


func _emit(id: String) -> void:
	button_pressed.emit(id)


## Elegir `need` cartas de `cards` (instancias; card_id "" => boca abajo).
## Al confirmar emite button_pressed("cards_ok"); la elección queda en `chosen`.
func open_cards(title: String, message: String, cards: Array, need: int) -> void:
	_begin(title, message)
	chosen.clear()
	var row: HFlowContainer = HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	_col.add_child(row)
	if not primary_ids.has("cards_ok"):
		primary_ids.append("cards_ok")
	var ok: Button = add_button("Confirmar", "cards_ok")
	ok.disabled = need > 0
	for c: Variant in cards:
		var inst: Dictionary = c
		var cv: CardView = CardView.for_instance(inst, 150.0 if sheet else 170.0, String(inst.get("card_id", "")) == "")
		cv.set_mode(CardView.Mode.SELECTABLE)
		cv.tapped.connect(_on_choice_tapped.bind(need, ok))
		row.add_child(cv)
	visible = true


## Botón con ese id del último open, o null.
func button_by_id(id: String) -> Button:
	for b: Button in buttons:
		if is_instance_valid(b) and String(b.get_meta("dialog_id", "")) == id:
			return b
	return null


func _on_choice_tapped(view: CardView, need: int, ok: Button) -> void:
	var iid: int = view.get_iid()
	if chosen.has(iid):
		chosen.erase(iid)
		view.set_mode(CardView.Mode.SELECTABLE)
	else:
		chosen.append(iid)
		view.set_mode(CardView.Mode.SELECTED)
	ok.disabled = chosen.size() != need
