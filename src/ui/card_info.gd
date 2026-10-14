class_name CardInfo
extends PanelContainer
## Ficha de la carta seleccionada (V2-23, criterios-v02 ítem 3).
## Parte estática: `evaluate`/`for_hand` calculan, sin recalcular reglas, si una carta es
## jugable (acciones legales de ActionOptions), su coste efectivo (Damage.card_cost) y el
## motivo si no lo es. Parte visual: nombre completo (con autowrap), maná, tipo, elemento,
## motivo y botón "Ver" (abre el zoom con un toque) con la pista de pulsación larga.

signal view_requested(card: Dictionary, def: Dictionary)

const SETTINGS_PATH: String = "user://settings.cfg"
const HINT_KEY: String = "hold_hint_seen"
const HOLD_HINT: String = "Mantén pulsada una carta para verla"

## Ruta del fichero de ajustes (los tests la cambian para no tocar la real).
static var settings_path: String = SETTINGS_PATH
static var _hint_seen_session: bool = false
## Resúmenes en español (id -> línea). El archivo no se versiona (M19): si falta, no hay resumen.
const SUMMARIES_PATH: String = "res://data/card_summaries_es.json"
static var summaries_path: String = SUMMARIES_PATH
static var _summaries: Dictionary = {}
static var _summaries_loaded: bool = false

var info: Dictionary = {}
var card: Dictionary = {}
var def: Dictionary = {}
var name_label: Label
var mana_label: Label
var cards_label: Label
var type_label: Label
var summary_label: Label
var reason_label: Label
## Si false, el motivo se rellena pero no se muestra (la mesa ya lo enseña en su pista; QA-V2-27-03).
var show_reason: bool = true
var hint_label: Label
var view_button: Button


# ---------------------------------------------------------------- cálculo (estático)

## Info de todas las cartas de la mano de `pid`: iid -> evaluate().
static func for_hand(view: Dictionary, pid: String, opts: ActionOptions) -> Dictionary:
	var out: Dictionary = {}
	var me: Dictionary = Types.get_player(view, pid)
	for c: Variant in me.get("hand", []) as Array:
		var inst: Dictionary = c
		out[int(inst["iid"])] = evaluate(view, pid, opts, inst)
	return out


## {iid, name, type, element, playable, reason, cost, base, mana_line, cards_line,
## type_line, element_line}. `reason` está vacío si es jugable.
static func evaluate(view: Dictionary, pid: String, opts: ActionOptions, inst: Dictionary) -> Dictionary:
	var card_id: String = String(inst.get("card_id", ""))
	var iid: int = int(inst.get("iid", -1))
	var d: Dictionary = _def(card_id)
	var cost_d: Dictionary = d.get("cost", {}) as Dictionary
	var base: int = int(cost_d.get("mana", 0))
	var cost: int = Damage.card_cost(view, pid, d, iid, false)
	var reqs: Array = cost_d.get("cards", []) as Array
	var scroll: bool = _has_wildcard(view, pid)
	var out: Dictionary = {
		"iid": iid, "card_id": card_id, "name": String(d.get("name", Strings.card_name(card_id))),
		"type": String(d.get("type", "")), "element": String(d.get("element", "")),
		"cost": cost, "base": base, "playable": false, "reason": "",
		"mana_line": Strings.mana_line(cost, base),
		"cards_line": Strings.requirement_text(reqs, scroll),
	}
	var el: String = String(out["element"])
	out["type_line"] = "Tipo: " + UiUtil.type_name(String(out["type"]))
	out["element_line"] = "Elemento: " + (UiUtil.element_name(el).to_lower() if UiUtil.element_name(el) != "" else "sin elemento")
	var verdict: Array = _verdict(view, pid, opts, inst, d, cost)
	out["playable"] = bool(verdict[0])
	out["reason"] = String(verdict[1])
	return out


static func _def(card_id: String) -> Dictionary:
	var d: Dictionary = CardCatalog.get_def(card_id)
	if d.is_empty():
		d = UiUtil.card_def(card_id)
	return d


static func _verdict(view: Dictionary, pid: String, opts: ActionOptions, inst: Dictionary,
		d: Dictionary, cost: int) -> Array:
	var iid: int = int(inst.get("iid", -1))
	for pr: Variant in view.get("pending", []) as Array:
		if String((pr as Dictionary).get("player", "")) == pid:
			return [false, Strings.REASON_PROMPT_PENDING]
	if not (view.get("reaction", {}) as Dictionary).is_empty():
		if Decision.responder(view) != pid:
			return [false, Strings.REASON_NOT_YOUR_TURN]
		if not opts.reacts_for(iid).is_empty():
			return [true, ""]
		return [false, Strings.REASON_REACTION_ONLY]
	if not opts.in_turn():
		return [false, Strings.REASON_NOT_YOUR_TURN]
	if not opts.plays_for(iid).is_empty():
		return [true, ""]
	return [false, _why_not(view, pid, inst, d, cost)]


## Primera causa (orden del motor en Game.check_play; defensiva y blinded antes que maná).
static func _why_not(view: Dictionary, pid: String, inst: Dictionary, d: Dictionary, cost: int) -> String:
	var me: Dictionary = Types.get_player(view, pid)
	var t: String = String(d.get("type", ""))
	if t == Types.CARD_TYPE_DEFENSIVE:
		return Strings.REASON_DEFENSIVE_ONLY_IN_REACTION
	if t == Types.CARD_TYPE_EVENT or t == Types.CARD_TYPE_NON_PLAYABLE or not bool(d.get("playable", true)):
		return "Esta carta no se puede jugar."
	if t == Types.CARD_TYPE_OFFENSIVE and bool((me.get("flags", {}) as Dictionary).get("blinded", false)):
		return Strings.REASON_BLINDED
	var mana: int = int(me.get("mana", 0))
	if mana < cost:
		return Strings.reason_mana(cost, mana, _can_drink_enough(view, pid, cost))
	var missing: String = _missing_cards(view, pid, inst, d)
	if missing != "":
		return Strings.reason_missing_cards(missing)
	return Strings.REASON_NO_VALID_TARGET


## ¿Una poción más (sin eliminar) llevaría el maná a `cost`?
static func _can_drink_enough(view: Dictionary, pid: String, cost: int) -> bool:
	var me: Dictionary = Types.get_player(view, pid)
	var cfg: Dictionary = view.get("config", {}) as Dictionary
	if bool(cfg.get("potion_limit_enabled", true)) and int(me.get("potions", 0)) + 1 > int(cfg.get("potion_limit", 10)):
		return false
	var amount: int = Damage.potion_amount(view, pid, false)
	var pool_mana: int = int((view.get("pool", {}) as Dictionary).get("mana", amount))
	return int(me.get("mana", 0)) + mini(amount, pool_mana) >= cost


## Texto del primer requisito de cartas que la mano no cubre ("1 carta de fuego"); "" si todos.
static func _missing_cards(view: Dictionary, pid: String, inst: Dictionary, d: Dictionary) -> String:
	var me: Dictionary = Types.get_player(view, pid)
	var wild: int = 1 if _has_wildcard(view, pid) else 0
	for r: Variant in (d.get("cost", {}) as Dictionary).get("cards", []) as Array:
		var req: Dictionary = r
		var have: int = wild
		for c: Variant in me.get("hand", []) as Array:
			var cd: Dictionary = c
			if int(cd["iid"]) != int(inst.get("iid", -1)) \
					and Game.card_meets(_def(String(cd["card_id"])), req):
				have += 1
		var need: int = int(req.get("count", 1))
		if have < need:
			var shown: Dictionary = req.duplicate()
			shown["count"] = need - have
			return Strings.requirement_one(shown)
	return ""


static func _has_wildcard(view: Dictionary, pid: String) -> bool:
	for a: Variant in Types.get_player(view, pid).get("artifacts", []) as Array:
		if EffectRegistry.get_hook(Types.HOOK_PAY_WILDCARD, String((a as Dictionary)["card_id"])).is_valid():
			return true
	return false


# ---------------------------------------------------------------- resúmenes

## Resumen de una línea de la carta, o "" si no existe (o falta/está roto el archivo).
static func summary(card_id: String) -> String:
	if not _summaries_loaded:
		reload_summaries()
	return String(_summaries.get(card_id, ""))


## Vuelve a leer `summaries_path`; nunca falla (archivo ausente o inválido = sin resúmenes).
static func reload_summaries() -> void:
	_summaries = {}
	_summaries_loaded = true
	if not FileAccess.file_exists(summaries_path):
		return
	var f: FileAccess = FileAccess.open(summaries_path, FileAccess.READ)
	if f == null:
		return
	var json: JSON = JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return
	var parsed: Variant = json.data
	if parsed is Dictionary:
		for k: Variant in (parsed as Dictionary):
			if (parsed as Dictionary)[k] is String:
				_summaries[String(k)] = (parsed as Dictionary)[k]


# ---------------------------------------------------------------- pista "mantén pulsada"

static func hint_seen() -> bool:
	if _hint_seen_session:
		return true
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(settings_path) == OK:
		return bool(cfg.get_value("ui", HINT_KEY, false))
	return false


static func mark_hint_seen() -> void:
	_hint_seen_session = true
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(settings_path)
	cfg.set_value("ui", HINT_KEY, true)
	cfg.save(settings_path)


# ---------------------------------------------------------------- vista

func _init() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.10, 0.08, 0.18, 0.92), 14,
		UiTheme.COL_ACCENT, 2, 10, 8))
	mouse_filter = Control.MOUSE_FILTER_PASS
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	name_label = _lbl(col, 30, UiTheme.COL_ACCENT)
	mana_label = _lbl(col, 24, UiTheme.COL_TEXT)
	cards_label = _lbl(col, 24, UiTheme.COL_TEXT)
	type_label = _lbl(col, 22, UiTheme.COL_MUTED)
	summary_label = _lbl(col, UiTheme.FONT_MIN, UiTheme.COL_TEXT)
	reason_label = _lbl(col, 24, Color(1.0, 0.62, 0.45))
	hint_label = _lbl(col, UiTheme.FONT_MIN, UiTheme.COL_MUTED)
	view_button = UiUtil.button("Ver", 30, UiTheme.BUTTON_MIN_H)
	view_button.custom_minimum_size = Vector2(150, UiTheme.BUTTON_MIN_H)
	view_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	view_button.pressed.connect(_on_view)
	row.add_child(view_button)
	visible = false


func _lbl(parent: Control, fs: int, col: Color) -> Label:
	var l: Label = UiUtil.label("", fs, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


## Muestra la ficha de `p_info` (resultado de evaluate) para la carta `p_card`.
func show_info(p_info: Dictionary, p_card: Dictionary) -> void:
	info = p_info
	card = p_card
	def = _def(String(p_card.get("card_id", "")))
	name_label.text = String(p_info["name"])
	mana_label.text = String(p_info["mana_line"])
	var cl: String = String(p_info["cards_line"])
	cards_label.text = cl
	cards_label.visible = cl != ""
	type_label.text = "%s · %s" % [String(p_info["type_line"]), String(p_info["element_line"])]
	var sm: String = summary(String(p_card.get("card_id", "")))
	summary_label.text = sm
	summary_label.visible = sm != ""
	var why: String = String(p_info["reason"])
	reason_label.text = why
	reason_label.visible = why != "" and show_reason
	var show_hint: bool = not hint_seen()
	hint_label.text = HOLD_HINT if show_hint else ""
	hint_label.visible = show_hint
	visible = true


func clear() -> void:
	info = {}
	card = {}
	visible = false


func _on_view() -> void:
	if card.is_empty():
		return
	mark_hint_seen()
	hint_label.visible = false
	view_requested.emit(card, def)
