class_name ReactionPrompt
extends PanelContainer
## Ventana de reacción: hechizo entrante (y respuestas apiladas), cartas de la
## mano que pueden responder (solo las legales se pueden tocar), Beber poción,
## Pasar y barra de temporizador (si hay deadline_ms).

signal react_requested(card_iid: int)
signal pass_requested
signal drink_requested
signal card_zoom_requested(card: Dictionary, def: Dictionary)

## Medidas compactas (QA-V2-35-04): la ventana cabe entre el registro y el panel propio.
const SPELL_W: float = 190.0
const REPLY_W: float = 150.0
const SPELL_ROW_H: float = 225.0

var deadline_ms: int = 0
var total_ms: int = 0
var _title: Label
var _bar: ProgressBar
var _spell_box: HBoxContainer
var _cards_box: HBoxContainer
var _pass_btn: Button
var _drink_btn: Button
var _stack_label: Label
var _against_label: Label
var _info_label: Label
var _built: bool = false
## Riesgo de la poción (TableActions.potion_risk) y su aviso; lo fija la mesa (QA-V2-32-01).
var drink_risk: int = 0
var _risk_tip: String = ""


func _ready() -> void:
	theme = UiTheme.get_theme()
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.07, 0.13, 1.0), 28,
		UiTheme.COL_ACCENT, 5, 28, 24))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	col.add_child(UiUtil.label("Hechizo entrante", 44, UiTheme.COL_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_title = UiUtil.label("", 30, UiTheme.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	_against_label = UiUtil.label("", 30, UiTheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_against_label.visible = false
	col.add_child(_against_label)
	# Vida y maná propios fijos, como en los prompts del motor (QA-V2-35-04).
	_info_label = UiUtil.label("", UiTheme.FONT_BODY, UiTheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_info_label.visible = false
	col.add_child(_info_label)
	# Cuerpo en horizontal (hechizo | respuestas): la hoja cabe bajo el panel propio.
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	col.add_child(body)
	_spell_box = HBoxContainer.new()
	_spell_box.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_spell_box)
	var replies: VBoxContainer = VBoxContainer.new()
	replies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replies.add_theme_constant_override("separation", 6)
	body.add_child(replies)
	replies.add_child(UiUtil.label("Tus respuestas", 28, UiTheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, SPELL_ROW_H)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	replies.add_child(scroll)
	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 14)
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(_cards_box)
	_stack_label = UiUtil.label("", 26, UiTheme.COL_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_stack_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_stack_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 36)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.value = 1.0
	col.add_child(_bar)
	# Beber poción y Pasar: acción principal (144 a 1080), a 24 px (docs/TAREAS.md §2.1).
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.BUTTON_GAP_POTION)
	_drink_btn = UiUtil.button("Beber poción", 32, UiTheme.BUTTON_PRIMARY_H)
	UiTheme.apply_primary(_drink_btn)
	_drink_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drink_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drink_btn.pressed.connect(func() -> void: drink_requested.emit())
	row.add_child(_drink_btn)
	_apply_risk_style()
	_pass_btn = UiUtil.button("Pasar", 44, UiTheme.BUTTON_PRIMARY_H)
	UiTheme.apply_primary(_pass_btn)
	_pass_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pass_btn.pressed.connect(func() -> void: pass_requested.emit())
	row.add_child(_pass_btn)
	col.add_child(row)
	set_process(false)


## reaction = state.reaction de la vista; hand = mano propia; names = id -> nombre.
## playable = iids que pueden responder ahora (acciones REACT legales); si es
## null se usa is_reactive (maquetas). drink_text = texto del botón de poción.
## against_me: 1 = "Contra ti", 0 = "No va contra ti", -1 = sin dato (no se muestra).
func open(reaction: Dictionary, hand: Array, names: Dictionary, now_ms: int = -1,
		playable: Variant = null, drink_text: String = "Beber poción", can_drink: bool = true,
		against_me: int = -1) -> void:
	_build()
	var spell: Dictionary = reaction.get("spell", {}) as Dictionary
	var card: Dictionary = spell.get("card", {}) as Dictionary
	var def: Dictionary = UiUtil.card_def(String(card.get("card_id", "")))
	var targets: Array[String] = []
	for t: Variant in spell.get("targets", []) as Array:
		targets.append(String(names.get(String(t), String(t))))
	var caster: String = String(names.get(String(spell.get("caster", "")), "?"))
	_title.text = "%s lanza %s%s" % [caster, String(def.get("name", "?")),
		(" contra " + ", ".join(targets)) if not targets.is_empty() else ""]
	_set_against(against_me)
	UiUtil.clear_children(_spell_box)
	var sv: CardView = CardView.create(card, def, SPELL_W)
	sv.zoom_requested.connect(func(c: Dictionary, d: Dictionary) -> void: card_zoom_requested.emit(c, d))
	_spell_box.add_child(sv)
	var stack: Array = reaction.get("stack", []) as Array
	var parts: Array[String] = []
	for r: Variant in stack:
		var rd: Dictionary = r
		var rc: Dictionary = rd.get("card", {}) as Dictionary
		parts.append("%s: %s" % [String(names.get(String(rd.get("caster", "")), "?")),
			String(UiUtil.card_def(String(rc.get("card_id", ""))).get("name", "?"))])
	_stack_label.text = ("Respuestas: " + ", ".join(parts)) if not parts.is_empty() else ""
	_stack_label.visible = not parts.is_empty()
	UiUtil.clear_children(_cards_box)
	var any: bool = false
	var legal: Array = playable as Array if playable is Array else []
	for h: Variant in hand:
		var inst: Dictionary = h
		var cv: CardView = CardView.for_instance(inst, REPLY_W)
		var iid: int = int(inst.get("iid", -1))
		var can: bool = legal.has(iid) if playable is Array else is_reactive(cv.def)
		if can or is_reactive(cv.def):
			any = true
			cv.set_mode(CardView.Mode.SELECTABLE if can else CardView.Mode.DISABLED)
			if can:
				cv.tapped.connect(func(v: CardView) -> void: react_requested.emit(v.get_iid()))
			cv.zoom_requested.connect(func(c: Dictionary, d: Dictionary) -> void: card_zoom_requested.emit(c, d))
			_cards_box.add_child(cv)
		else:
			cv.free()
	if not any:
		_cards_box.add_child(UiUtil.label("No tienes defensivas.", 28, UiTheme.COL_MUTED))
	elif playable is Array and legal.is_empty():
		_cards_box.add_child(UiUtil.label("Te falta maná: bebe una poción para responder.", 24,
			UiTheme.COL_MUTED))
	_drink_btn.text = ("⚠ " + drink_text) if drink_risk > 0 else drink_text
	_drink_btn.tooltip_text = _risk_tip if drink_risk > 0 else ""
	_drink_btn.disabled = not can_drink
	var new_deadline: int = int(reaction.get("deadline_ms", 0))
	var now: int = now_ms if now_ms >= 0 else int(Time.get_unix_time_from_system() * 1000.0)
	# Reabrir con el mismo plazo (p. ej. al redibujar) no reinicia la barra.
	if new_deadline != deadline_ms or total_ms <= 0:
		total_ms = maxi(1, new_deadline - now) if new_deadline > 0 else 0
	deadline_ms = new_deadline
	_bar.visible = deadline_ms > 0
	_bar.value = clampf(float(deadline_ms - now) / float(total_ms), 0.0, 1.0) if total_ms > 0 else 1.0
	set_process(deadline_ms > 0)
	visible = true


## Línea fija "Tu vida: V · Tu maná: M" ("" la oculta).
func set_info(text: String) -> void:
	_build()
	_info_label.text = text
	_info_label.visible = text != ""


## Mismo nivel de riesgo que Beber poción de la mesa (TableActions.apply_potion_risk):
## color, ⚠ y aviso. Se aplica ya y en cada open().
func set_drink_risk(level: int, tooltip: String = "") -> void:
	drink_risk = clampi(level, 0, TableActions.RISK_FILL.size() - 1)
	_risk_tip = tooltip
	if _drink_btn == null:
		return
	_apply_risk_style()
	var plain: String = _drink_btn.text.trim_prefix("⚠ ")
	_drink_btn.text = ("⚠ " + plain) if drink_risk > 0 else plain
	_drink_btn.tooltip_text = _risk_tip if drink_risk > 0 else ""


func _apply_risk_style() -> void:
	_drink_btn.add_theme_stylebox_override("normal",
		UiTheme.box(TableActions.RISK_FILL[drink_risk], 22, TableActions.RISK_BORDER[drink_risk], 4, 16, 16))


func _set_against(against_me: int) -> void:
	_against_label.visible = against_me >= 0
	if against_me == 1:
		_against_label.text = "⚠ " + Strings.AGAINST_YOU
		_against_label.add_theme_color_override("font_color", UiTheme.COL_DANGER)
	elif against_me == 0:
		_against_label.text = Strings.NOT_AGAINST_YOU
		_against_label.add_theme_color_override("font_color", UiTheme.COL_MUTED)


static func is_reactive(def: Dictionary) -> bool:
	return bool(def.get("defensive", false)) or String(def.get("id", "")) == Types.CARD_LIGHTNING


func _process(_delta: float) -> void:
	if deadline_ms <= 0 or total_ms <= 0:
		return
	var left: int = deadline_ms - int(Time.get_unix_time_from_system() * 1000.0)
	_bar.value = clampf(float(left) / float(total_ms), 0.0, 1.0)
	if left <= 0:
		set_process(false)


func set_bar_fraction(f: float) -> void:
	_bar.visible = true
	_bar.value = clampf(f, 0.0, 1.0)
